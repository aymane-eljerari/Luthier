//===-- LuthierCallGraph.cpp - Luthier IR call graph analysis -------------===//
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
/// \file LuthierCallGraph.cpp
/// Implements the \c LuthierCallGraphAnalysis module analysis.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/LuthierCallGraph.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include "luthier/ToolCodeGen/TargetMachineInstrMDNode.h"
#include <llvm/Analysis/ConstantFolding.h>
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

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-callgraph"

namespace luthier {

bool LuthierCallGraph::invalidate(llvm::Module &,
                                  const llvm::PreservedAnalyses &PA,
                                  llvm::ModuleAnalysisManager::Invalidator &) {
  auto PAC = PA.getChecker<LuthierCallGraphAnalysis>();
  return !PAC.preserved() &&
         !PAC.preservedSet<llvm::AllAnalysesOn<llvm::Module>>();
}

llvm::AnalysisKey LuthierCallGraphAnalysis::Key;

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

/// Symbolically evaluate \p V as a \c Constant, using \p SubstMap for
/// \c Argument substitution and \p Cache for memoisation.  Returns nullptr
/// when \p V cannot be fully folded.
///
/// Special cases handled beyond generic \c ConstantFoldInstOperands:
///  - \c call \c \@llvm.amdgcn.s.getpc() with \c MD_pcsections at addr A
///    → folded to the integer constant \c A+4.
///  - \c PHINode → nullptr (ambiguous without knowing the taken edge).
static llvm::Constant *tryEvalConst(llvm::Value *V, const ValConstMap &SubstMap,
                                    ValConstMap &Cache,
                                    const llvm::DataLayout &DL) {
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

  // amdgcn_s_getpc() with pcsections → addr + 4
  if (auto *CI = llvm::dyn_cast<llvm::CallInst>(I)) {
    if (CI->getIntrinsicID() == llvm::Intrinsic::amdgcn_s_getpc) {
      if (auto Addr = getTraceAddr(CI))
        return cache(llvm::ConstantInt::get(CI->getType(), *Addr + 4));
      return cache(nullptr);
    }
  }

  // General case: fold all operands then try ConstantFoldInstOperands.
  llvm::SmallVector<llvm::Constant *> Ops;
  Ops.reserve(I->getNumOperands());
  for (llvm::Value *Op : I->operands()) {
    llvm::Constant *C = tryEvalConst(Op, SubstMap, Cache, DL);
    if (!C)
      return cache(nullptr);
    Ops.push_back(C);
  }
  return cache(llvm::ConstantFoldInstOperands(I, Ops, DL));
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

LuthierCallGraph LuthierCallGraphAnalysis::run(llvm::Module &M,
                                               llvm::ModuleAnalysisManager &) {
  LuthierCallGraph Out;
  const llvm::DataLayout &DL = M.getDataLayout();

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
      if (auto *Callee = CI->getCalledFunction())
        KnownCallers[Callee].emplace_back(CI, &F);
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
          ValConstMap Cache;
          llvm::Constant *C =
              tryEvalConst(CI->getCalledOperand(), SubstMap, Cache, DL);
          uint64_t Addr = extractAddr(C);
          if (!Addr)
            return;
          // Always record the raw address so CodeDiscoveryPass can enqueue
          // it as a new entry point even before the callee stub exists.
          Out.DiscoveredCallTargetAddresses.insert(Addr);
          auto It = AddrToFunc.find(Addr);
          if (It == AddrToFunc.end())
            return;
          llvm::Function *Target = It->second;
          auto &Targets = Out.CallTargets[CI];
          if (llvm::is_contained(Targets, Target))
            return;
          LLVM_DEBUG(llvm::dbgs()
                     << "[LuthierCallGraph] Resolved call in "
                     << F.getName() << " → " << Target->getName() << "\n");
          Targets.push_back(Target);
          KnownCallers[Target].emplace_back(CI, &F);
          Changed = true;
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
              if (llvm::Constant *ArgC =
                      tryEvalConst(SiteCI->getArgOperand(Idx), EmptyMap,
                                   SiteCache, DL))
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
        LLVM_DEBUG(llvm::dbgs() << "[LuthierCallGraph] Unresolved call in "
                                << F.getName() << "\n");
        Out.IncompleteCallSites.insert(CI);
        Out.FullyRecovered = false;
      }
    }
  }

  LLVM_DEBUG(llvm::dbgs() << "[LuthierCallGraph] Resolved "
                          << Out.CallTargets.size() << " call sites; "
                          << Out.IncompleteCallSites.size()
                          << " incomplete; fully_recovered="
                          << Out.FullyRecovered << "\n");
  return Out;
}

// ---------------------------------------------------------------------------
// Printer pass
// ---------------------------------------------------------------------------

llvm::PreservedAnalyses
LuthierCallGraphPrinter::run(llvm::Module &M,
                             llvm::ModuleAnalysisManager &MAM) {
  const LuthierCallGraph &CG = MAM.getResult<LuthierCallGraphAnalysis>(M);

  OS << "LuthierCallGraph (fully_recovered=" << (CG.FullyRecovered ? "yes" : "no")
     << "):\n";

  OS << "  Resolved call sites (" << CG.CallTargets.size() << "):\n";
  for (llvm::Function &F : M) {
    for (llvm::Instruction &I : llvm::instructions(F)) {
      auto *CI = llvm::dyn_cast<llvm::CallInst>(&I);
      if (!CI || CI->getCalledFunction() ||
          llvm::isa<llvm::InlineAsm>(CI->getCalledOperand()))
        continue;
      auto It = CG.CallTargets.find(CI);
      if (It == CG.CallTargets.end())
        continue;
      OS << "    " << F.getName() << " -> [";
      llvm::interleaveComma(It->second, OS,
                            [&](llvm::Function *T) { OS << T->getName(); });
      OS << "]\n";
    }
  }

  OS << "  Incomplete call sites (" << CG.IncompleteCallSites.size() << "):\n";
  for (llvm::CallInst *CI : CG.IncompleteCallSites) {
    llvm::Function *F = CI->getFunction();
    OS << "    " << F->getName() << "\n";
  }

  OS << "  Discovered call target addresses ("
     << CG.DiscoveredCallTargetAddresses.size() << "):\n";
  llvm::SmallVector<uint64_t> Sorted(CG.DiscoveredCallTargetAddresses.begin(),
                                     CG.DiscoveredCallTargetAddresses.end());
  llvm::sort(Sorted);
  for (uint64_t Addr : Sorted)
    OS << "    " << llvm::format("0x%" PRIx64 "\n", Addr);

  return llvm::PreservedAnalyses::all();
}

} // namespace luthier
