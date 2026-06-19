//===-- TraceCallGraph.cpp - Luthier IR call graph analysis ---------------===//
// Copyright @ Northeastern University Computer Architecture Lab
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//
/// \file
/// Implements the \c TraceCallGraphAnalysis module analysis.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/TraceCallGraph.h"
#include "luthier/LLVM/streams.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include "luthier/ToolCodeGen/TargetMachineInstrMDNode.h"
#include <llvm/ADT/ScopeExit.h>
#include <llvm/ADT/SmallPtrSet.h>
#include <llvm/Analysis/AliasAnalysis.h>
#include <llvm/Analysis/ConstantFolding.h>
#include <llvm/Analysis/MemoryLocation.h>
#include <llvm/Analysis/MemorySSA.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/InstIterator.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/IntrinsicsAMDGPU.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/Format.h>
#include <llvm/Support/raw_ostream.h>
#include <string>

#undef DEBUG_TYPE
#define DEBUG_TYPE "trace-callgraph"

namespace luthier {

bool TraceCallGraph::invalidate(llvm::Module &,
                                const llvm::PreservedAnalyses &PA,
                                llvm::ModuleAnalysisManager::Invalidator &) {
  auto PAC = PA.getChecker<TraceCallGraphAnalysis>();
  return !PAC.preserved() &&
         !PAC.preservedSet<llvm::AllAnalysesOn<llvm::Module>>();
}

llvm::AnalysisKey TraceCallGraphAnalysis::Key;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

using ValConstMap = llvm::DenseMap<llvm::Value *, llvm::Constant *>;

/// Return the trace-instruction address stored in the \c MD_pcsections
/// metadata of \p I, if present.
static std::optional<uint64_t> getTraceAddr(const llvm::Instruction *I) {
  auto *MD = llvm::dyn_cast_or_null<TargetMachineInstrMDNode>(
      I->getMetadata(llvm::LLVMContext::MD_pcsections));
  if (!MD)
    return std::nullopt;
  return MD->getTraceInstrAddress();
}

/// Strip value-preserving pointer reinterpretations (inttoptr / bitcast /
/// addrspacecast) to expose the underlying address expression.
static llvm::Value *stripPtrCasts(llvm::Value *P) {
  while (auto *PI = llvm::dyn_cast<llvm::Instruction>(P)) {
    if (!llvm::isa<llvm::IntToPtrInst, llvm::BitCastInst,
                   llvm::AddrSpaceCastInst>(PI))
      break;
    P = PI->getOperand(0);
  }
  return P;
}

/// \return \c true if \p SI provably writes exactly the bytes \p LI reads back
/// (same address and same byte width), so the loaded value equals the stored
/// value (bit-reinterpreted to the loaded type).  AA proves the address match
/// for GEP-style addressing; for the inttoptr-based scratch/global pointers the
/// translator emits (which AA treats opaquely) we additionally accept
/// syntactically identical address expressions modulo pointer casts.  That
/// shortcut is only sound within one address space: the same numeric offset
/// names different storage in different address spaces, so require matching
/// address spaces (AA never reports must-alias across them).
static bool storeMatchesLoad(llvm::StoreInst *SI, llvm::LoadInst *LI,
                             llvm::AAResults &AA, const llvm::DataLayout &DL) {
  if (!SI->isSimple())
    return false;
  bool SameAddr =
      AA.isMustAlias(llvm::MemoryLocation::get(LI),
                     llvm::MemoryLocation::get(SI)) ||
      (LI->getPointerAddressSpace() == SI->getPointerAddressSpace() &&
       stripPtrCasts(LI->getPointerOperand()) ==
           stripPtrCasts(SI->getPointerOperand()));
  return SameAddr && DL.getTypeStoreSize(SI->getValueOperand()->getType()) ==
                         DL.getTypeStoreSize(LI->getType());
}

/// Symbolically evaluate \p V as a \c Constant, using \p SubstMap for
/// \c Argument substitution and \p Cache for memoisation.  Returns nullptr
/// when \p V cannot be fully folded.
///
/// \p FAM provides the per-function MemorySSA / alias analysis used to trace
/// loads back to their defining store (see the \c LoadInst case below).
///
/// Special cases handled beyond generic \c ConstantFoldInstOperands:
///  - \c call \c \@llvm.amdgcn.s.getpc() with \c MD_pcsections at addr A
///    → folded to the integer constant \c A+4.
///  - \c PHINode → nullptr (ambiguous without knowing the taken edge).
///  - \c LoadInst → value of the unique clobbering store, when MemorySSA finds
///    a single \c StoreInst at the same address whose stored value has the same
///    byte width (bit-reinterpreted to the loaded type). This is address-space
///    agnostic; in practice it recovers callee addresses spilled to scratch
///    (private memory) and reloaded under register pressure, since that is the
///    only spill path on AMDGPU that keeps the value scalar/foldable.
static llvm::Constant *tryEvalConst(llvm::Value *V, const ValConstMap &SubstMap,
                                    ValConstMap &Cache,
                                    const llvm::DataLayout &DL,
                                    llvm::FunctionAnalysisManager &FAM) {
  if (auto It = Cache.find(V); It != Cache.end())
    return It->second;

  auto cache = [&](llvm::Constant *C) -> llvm::Constant * {
    Cache[V] = C;
    return C;
  };

  if (auto *C = llvm::dyn_cast<llvm::Constant>(V))
    return cache(C);

  if (auto It = SubstMap.find(V); It != SubstMap.end())
    return cache(It->second);

  auto *I = llvm::dyn_cast<llvm::Instruction>(V);
  if (!I || llvm::isa<llvm::PHINode>(I))
    return cache(nullptr);

  if (auto *CI = llvm::dyn_cast<llvm::CallInst>(I)) {
    const llvm::Intrinsic::ID IID = CI->getIntrinsicID();

    // amdgcn_s_getpc() with pcsections → addr + 4
    if (IID == llvm::Intrinsic::amdgcn_s_getpc) {
      if (auto Addr = getTraceAddr(CI))
        return cache(llvm::ConstantInt::get(CI->getType(), *Addr + 4));
      return cache(nullptr);
    }

    // ssa.copy is a plain SSA copy — the translator emits it for register
    // moves (e.g. v_mov). Forward through it.
    if (IID == llvm::Intrinsic::ssa_copy)
      return cache(
          tryEvalConst(CI->getArgOperand(0), SubstMap, Cache, DL, FAM));

    // TODO: cross-lane VGPR reads (readfirstlane / readlane / writelane) are
    // NOT traced. Resolving them properly needs IR-translator changes
    // (per-lane register-value tracking across basic blocks, recording a lane
    // value when tracing through VGPRs), which would also enable tracing vector
    // loads from global memory.
  }

  // Load → trace through the unique clobbering store via MemorySSA, in any
  // address space. This recovers callee addresses spilled to memory (commonly
  // scratch/private under register pressure) and reloaded. A MemoryPhi /
  // liveOnEntry clobber is ambiguous.
  if (auto *LI = llvm::dyn_cast<llvm::LoadInst>(I)) {
    if (!LI->isSimple())
      return cache(nullptr);
    llvm::Function &F = *LI->getFunction();
    llvm::MemorySSA &MSSA = FAM.getResult<llvm::MemorySSAAnalysis>(F).getMSSA();
    llvm::AAResults &AA = FAM.getResult<llvm::AAManager>(F);
    auto *Def = llvm::dyn_cast<llvm::MemoryDef>(
        MSSA.getWalker()->getClobberingMemoryAccess(LI));
    if (!Def || MSSA.isLiveOnEntryDef(Def))
      return cache(nullptr);
    auto *SI = llvm::dyn_cast_or_null<llvm::StoreInst>(Def->getMemoryInst());
    if (!SI || !storeMatchesLoad(SI, LI, AA, DL))
      return cache(nullptr);
    // Break potential memory cycles before recursing into the stored value,
    // then bit-reinterpret it to the loaded type (a spilled i64 pointer is
    // reloaded as e.g. <2 x i32>).
    Cache[V] = nullptr;
    llvm::Constant *SC =
        tryEvalConst(SI->getValueOperand(), SubstMap, Cache, DL, FAM);
    llvm::Constant *R = nullptr;
    if (SC)
      R = SC->getType() == LI->getType()
              ? SC
              : llvm::ConstantFoldCastOperand(llvm::Instruction::BitCast, SC,
                                              LI->getType(), DL);
    Cache[V] = R;
    return R;
  }

  // General case: fold all operands then try ConstantFoldInstOperands.
  llvm::SmallVector<llvm::Constant *> Ops;
  Ops.reserve(I->getNumOperands());
  for (llvm::Value *Op : I->operands()) {
    llvm::Constant *C = tryEvalConst(Op, SubstMap, Cache, DL, FAM);
    if (!C)
      return cache(nullptr);
    Ops.push_back(C);
  }
  return cache(llvm::ConstantFoldInstOperands(I, Ops, DL));
}

/// Set-valued companion to \c tryEvalConst for the call-site target operand.
/// Appends to \p Out (deduplicated) every constant \p V may take, enumerating
/// intra-procedural fan-out that \c tryEvalConst (single-valued) cannot:
///   - \c PHINode / \c SelectInst → union over incoming values / both arms;
///   - \c LoadInst with a \c MemoryPhi clobber → union over the values of the
///     same-address stores reaching the load (a callee pointer stored on
///     divergent paths and reloaded — "memory fan-out");
///   - \c CastInst → each element mapped through the cast.
/// Anything else contributes nothing (conservative).  No cartesian products are
/// formed: a value reconstructed from two independently-varying operands (e.g.
/// the lo/hi halves of a pointer phi'd as separate 32-bit registers) is left
/// unresolved rather than expanded into spurious mixed targets.  \p Active is
/// the current DFS path, used to break cycles (loop-carried phis).
static void evalConstTargets(llvm::Value *V, const ValConstMap &SubstMap,
                             const llvm::DataLayout &DL,
                             llvm::FunctionAnalysisManager &FAM,
                             llvm::SmallPtrSetImpl<llvm::Value *> &Active,
                             llvm::SmallVectorImpl<llvm::Constant *> &Out) {
  auto add = [&](llvm::Constant *C) {
    if (C && !llvm::is_contained(Out, C))
      Out.push_back(C);
  };

  // Fast path: anything that folds to a single constant (manifest constants,
  // getpc chains, single-store spills, fully-constant subtrees).
  {
    ValConstMap Cache;
    if (llvm::Constant *C = tryEvalConst(V, SubstMap, Cache, DL, FAM))
      return add(C);
  }

  if (!Active.insert(V).second)
    return; // cycle on the current path
  llvm::scope_exit Pop([&] { Active.erase(V); });

  auto *I = llvm::dyn_cast<llvm::Instruction>(V);
  if (!I)
    return;

  if (auto *P = llvm::dyn_cast<llvm::PHINode>(I)) {
    for (llvm::Value *In : P->incoming_values())
      evalConstTargets(In, SubstMap, DL, FAM, Active, Out);
    return;
  }
  if (auto *Sel = llvm::dyn_cast<llvm::SelectInst>(I)) {
    evalConstTargets(Sel->getTrueValue(), SubstMap, DL, FAM, Active, Out);
    evalConstTargets(Sel->getFalseValue(), SubstMap, DL, FAM, Active, Out);
    return;
  }
  if (auto *Cast = llvm::dyn_cast<llvm::CastInst>(I)) {
    llvm::SmallVector<llvm::Constant *> Ops;
    evalConstTargets(Cast->getOperand(0), SubstMap, DL, FAM, Active, Ops);
    for (llvm::Constant *C : Ops)
      add(llvm::ConstantFoldCastOperand(Cast->getOpcode(), C, Cast->getType(),
                                        DL));
    return;
  }
  if (auto *LI = llvm::dyn_cast<llvm::LoadInst>(I); LI && LI->isSimple()) {
    // tryEvalConst already handled a single clobbering store; reaching here
    // means the clobber is a MemoryPhi (divergent stores). Union each one.
    llvm::Function &F = *LI->getFunction();
    llvm::MemorySSA &MSSA = FAM.getResult<llvm::MemorySSAAnalysis>(F).getMSSA();
    llvm::AAResults &AA = FAM.getResult<llvm::AAManager>(F);
    auto *MPhi = llvm::dyn_cast<llvm::MemoryPhi>(
        MSSA.getWalker()->getClobberingMemoryAccess(LI));
    if (!MPhi)
      return;
    llvm::MemoryLocation Loc = llvm::MemoryLocation::get(LI);
    auto toLoadTy = [&](llvm::Constant *C) -> llvm::Constant * {
      if (!C || C->getType() == LI->getType())
        return C;
      return llvm::ConstantFoldCastOperand(llvm::Instruction::BitCast, C,
                                           LI->getType(), DL);
    };
    for (unsigned Idx = 0, E = MPhi->getNumIncomingValues(); Idx < E; ++Idx) {
      auto *Def = llvm::dyn_cast<llvm::MemoryDef>(
          MSSA.getWalker()->getClobberingMemoryAccess(
              MPhi->getIncomingValue(Idx), Loc));
      if (!Def || MSSA.isLiveOnEntryDef(Def))
        continue;
      auto *SI = llvm::dyn_cast_or_null<llvm::StoreInst>(Def->getMemoryInst());
      if (!SI || !storeMatchesLoad(SI, LI, AA, DL))
        continue;
      llvm::SmallVector<llvm::Constant *> SVals;
      evalConstTargets(SI->getValueOperand(), SubstMap, DL, FAM, Active, SVals);
      for (llvm::Constant *C : SVals)
        add(toLoadTy(C));
    }
    return;
  }
}

/// Extract a uint64_t address from a folded constant (ConstantInt or
/// ConstantExpr wrapping an inttoptr).  Returns 0 on failure.
static uint64_t extractAddr(llvm::Constant *C) {
  if (!C)
    return 0;
  if (auto *CE = llvm::dyn_cast<llvm::ConstantExpr>(C)) {
    if (CE->getOpcode() == llvm::Instruction::IntToPtr)
      if (auto *CI = llvm::dyn_cast<llvm::ConstantInt>(CE->getOperand(0)))
        return CI->getZExtValue();
  }
  if (auto *CI = llvm::dyn_cast<llvm::ConstantInt>(C))
    return CI->getZExtValue();
  return 0;
}

// ---------------------------------------------------------------------------
// Analysis implementation
// ---------------------------------------------------------------------------

TraceCallGraph TraceCallGraphAnalysis::run(llvm::Module &M,
                                           llvm::ModuleAnalysisManager &MAM) {
  TraceCallGraph Out;
  const llvm::DataLayout &DL = M.getDataLayout();

  // Per-function MemorySSA / alias analysis, used to trace spilled-and-reloaded
  // callee addresses (single store via tryEvalConst; divergent stores via the
  // MemoryPhi fan-out in evalConstTargets).
  llvm::FunctionAnalysisManager &FAM =
      MAM.getResult<llvm::FunctionAnalysisManagerModuleProxy>(M).getManager();

  // Build addr → Function* map from functions that have entry-point
  // annotations (device functions only; kernels are excluded because they
  // are never called by other IR functions).
  llvm::DenseMap<uint64_t, llvm::Function *> AddrToFunc;
  for (llvm::Function &F : M) {
    auto EP = getFunctionEntryPoint(F);
    if (!EP || F.getCallingConv() == llvm::CallingConv::AMDGPU_KERNEL)
      continue;
    AddrToFunc[EP->getRawAddress()] = &F;
  }

  // Known-callers map: Function* → list of (call_site, caller_function).
  // Seeded with direct IR calls; extended as indirect calls get resolved.
  using CallerInfo = std::pair<llvm::CallInst *, llvm::Function *>;
  llvm::DenseMap<llvm::Function *, llvm::SmallVector<CallerInfo>> KnownCallers;

  for (llvm::Function &F : M) {
    for (auto &I : llvm::instructions(F)) {
      auto *CI = llvm::dyn_cast<llvm::CallInst>(&I);
      if (!CI)
        continue;
      auto *Callee = CI->getCalledFunction();
      if (!Callee)
        continue;
      KnownCallers[Callee].emplace_back(CI, &F);
      // Record direct call edges in the global call graph
      if (Callee->isIntrinsic() || Callee->isDeclaration())
        continue;
      Out.CallTargets[CI].push_back(Callee);
      if (auto EP = getFunctionEntryPoint(*Callee))
        Out.DiscoveredCallTargetAddresses.insert(EP->getRawAddress());
    }
  }

  // Iterative resolution loop.
  // Each pass may resolve indirect calls, adding new entries to KnownCallers
  // and enabling the next pass to resolve callee-side indirect calls whose
  // target depends on arguments supplied by newly resolved callers.
  bool Changed = true;
  while (Changed) {
    Changed = false;
    for (llvm::Function &F : M) {
      if (F.isDeclaration())
        continue;
      for (auto &I : llvm::instructions(F)) {
        auto *CI = llvm::dyn_cast<llvm::CallInst>(&I);
        if (!CI || CI->getCalledFunction() ||
            llvm::isa<llvm::InlineAsm>(CI->getCalledOperand()))
          continue;

        auto tryResolve = [&](const ValConstMap &SubstMap) {
          llvm::SmallVector<llvm::Constant *> Cs;
          llvm::SmallPtrSet<llvm::Value *, 16> Active;
          evalConstTargets(CI->getCalledOperand(), SubstMap, DL, FAM, Active,
                           Cs);
          for (llvm::Constant *C : Cs) {
            uint64_t Addr = extractAddr(C);
            if (!Addr)
              continue;
            // Always record the raw address so CodeDiscoveryPass can enqueue
            // it as a new entry point even before the callee stub exists.
            Out.DiscoveredCallTargetAddresses.insert(Addr);
            auto It = AddrToFunc.find(Addr);
            if (It == AddrToFunc.end())
              continue;
            llvm::Function *Target = It->second;
            auto &Targets = Out.CallTargets[CI];
            if (llvm::is_contained(Targets, Target))
              continue;
            LLVM_DEBUG(luthier::dbgs()
                       << "[TraceCallGraph] Resolved call in " << F.getName()
                       << " → " << Target->getName() << "\n");
            Targets.push_back(Target);
            KnownCallers[Target].emplace_back(CI, &F);
            Changed = true;
          }
        };

        // Phase 1: evaluate callee with no substitution (manifest constants).
        {
          ValConstMap EmptyMap;
          tryResolve(EmptyMap);
        }

        // Phase 2: inter-procedural — try each known call site of F as a
        // source of argument constants.
        if (auto CallerIt = KnownCallers.find(&F);
            CallerIt != KnownCallers.end()) {
          for (auto &[SiteCI, CallerF] : CallerIt->second) {
            ValConstMap SubstMap;
            ValConstMap SiteCache;
            for (unsigned Idx = 0;
                 Idx < SiteCI->arg_size() && Idx < F.arg_size(); ++Idx) {
              ValConstMap EmptyMap;
              if (llvm::Constant *ArgC = tryEvalConst(
                      SiteCI->getArgOperand(Idx), EmptyMap, SiteCache, DL, FAM))
                SubstMap[F.getArg(Idx)] = ArgC;
            }
            if (!SubstMap.empty())
              tryResolve(SubstMap);
          }
        }
      }
    }
  }

  // Mark incomplete call sites — any indirect call that was not fully
  // resolved (i.e. not present in CallTargets at all, or where at least one
  // call-site of its containing function failed to provide a constant for the
  // callee operand).
  for (llvm::Function &F : M) {
    if (F.isDeclaration())
      continue;
    for (auto &I : llvm::instructions(F)) {
      auto *CI = llvm::dyn_cast<llvm::CallInst>(&I);
      if (!CI || CI->getCalledFunction() ||
          llvm::isa<llvm::InlineAsm>(CI->getCalledOperand()))
        continue;
      if (!Out.CallTargets.contains(CI)) {
        LLVM_DEBUG(luthier::dbgs() << "[TraceCallGraph] Unresolved call in "
                                   << F.getName() << "\n");
        Out.IncompleteCallSites.insert(CI);
        Out.FullyRecovered = false;
      }
    }
  }

  LLVM_DEBUG(luthier::dbgs()
             << "[TraceCallGraph] Resolved " << Out.CallTargets.size()
             << " call sites; " << Out.IncompleteCallSites.size()
             << " incomplete; fully_recovered=" << Out.FullyRecovered << "\n");
  return Out;
}

// ---------------------------------------------------------------------------
// Printing
// ---------------------------------------------------------------------------

void TraceCallGraph::print(llvm::raw_ostream &OS) const {
  OS << "TraceCallGraph (fully_recovered=" << (FullyRecovered ? "yes" : "no")
     << "):\n";

  // CallTargets / IncompleteCallSites are hashed containers with no stable
  // iteration order; format each entry into a string and sort before printing
  // so the output is deterministic across runs.
  auto printSorted = [&OS](llvm::SmallVectorImpl<std::string> &Lines) {
    llvm::sort(Lines);
    for (const std::string &Line : Lines)
      OS << Line << "\n";
  };

  OS << "  Resolved call sites (" << CallTargets.size() << "):\n";
  llvm::SmallVector<std::string> ResolvedLines;
  for (const auto &[CI, Targets] : CallTargets) {
    std::string Line;
    llvm::raw_string_ostream LS(Line);
    LS << "    " << CI->getFunction()->getName() << " -> [";
    llvm::interleaveComma(Targets, LS,
                          [&](llvm::Function *T) { LS << T->getName(); });
    LS << "]";
    ResolvedLines.push_back(std::move(Line));
  }
  printSorted(ResolvedLines);

  OS << "  Incomplete call sites (" << IncompleteCallSites.size() << "):\n";
  llvm::SmallVector<std::string> IncompleteLines;
  for (llvm::CallInst *CI : IncompleteCallSites) {
    std::string Line;
    llvm::raw_string_ostream LS(Line);
    LS << "    " << CI->getFunction()->getName();
    IncompleteLines.push_back(std::move(Line));
  }
  printSorted(IncompleteLines);

  OS << "  Discovered call target addresses ("
     << DiscoveredCallTargetAddresses.size() << "):\n";
  llvm::SmallVector<uint64_t> Sorted(DiscoveredCallTargetAddresses.begin(),
                                     DiscoveredCallTargetAddresses.end());
  llvm::sort(Sorted);
  for (uint64_t Addr : Sorted)
    OS << "    " << llvm::format("0x%" PRIx64 "\n", Addr);
}

#if !defined(NDEBUG) || defined(LLVM_ENABLE_DUMP)
void TraceCallGraph::dump() const { print(luthier::dbgs()); }
#endif

// ---------------------------------------------------------------------------
// Printer pass
// ---------------------------------------------------------------------------

llvm::PreservedAnalyses
TraceCallGraphPrinter::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM) {
  MAM.getResult<TraceCallGraphAnalysis>(M).print(OS);
  return llvm::PreservedAnalyses::all();
}

} // namespace luthier
