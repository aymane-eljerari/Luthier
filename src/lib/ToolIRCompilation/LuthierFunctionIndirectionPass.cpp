//===-- LuthierFunctionIndirectionPass.cpp ---------------------------------===//
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
/// \file LuthierFunctionIndirectionPass.cpp
/// Implements the function-indirection rewrite. See header for design.
//===----------------------------------------------------------------------===//
#include "luthier/ToolIRCompilation/LuthierFunctionIndirectionPass.h"

#include <llvm/ADT/STLExtras.h>
#include <llvm/ADT/SmallSet.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Casting.h>
#include <llvm/TargetParser/Triple.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-function-indirection"

namespace luthier {

namespace {

constexpr llvm::StringLiteral kTableName = "__luthier_function_table";
constexpr llvm::StringLiteral kFunctionIDAttr = "luthier.function-id";

/// \returns \c true if \p U appears anywhere inside a function body
/// (instruction context), or \c false if it lives only in constant
/// contexts (variable initializers, \c @llvm.used arrays, etc.). Walks
/// \c ConstantExpr chains transitively.
bool hasInstructionUser(const llvm::User *U) {
  llvm::SmallVector<const llvm::User *, 8> Worklist{U};
  llvm::SmallPtrSet<const llvm::User *, 8> Seen;
  while (!Worklist.empty()) {
    const llvm::User *W = Worklist.pop_back_val();
    if (!Seen.insert(W).second)
      continue;
    if (llvm::isa<llvm::Instruction>(W))
      return true;
    if (llvm::isa<llvm::Constant>(W)) {
      for (const llvm::User *UU : W->users())
        Worklist.push_back(UU);
    }
  }
  return false;
}

/// Collect every \c Instruction that ultimately references \p F via
/// (zero or more) \c ConstantExpr layers, EXCLUDING the callee operand
/// of a direct \c CallBase. We re-build each such instruction's operand
/// referring to \p F into the table-load equivalent — but direct calls
/// must remain direct calls, even when \p F is classified as
/// address-taken by Phase 1 (which can fire on metadata-like
/// references such as \c @llvm.global.annotations entries from the
/// \c LUTHIER_INTRINSIC_ANNOTATE macro). Rewriting a direct call to an
/// indirect-call-through-table breaks the C calling convention for the
/// caller — the load + indirect call gets tail-call-optimized and the
/// ABI arg setup (\c $vgpr0..3) clobbers caller-side physregs the
/// caller expected to flow through the call unchanged.
void collectInstructionUses(llvm::Function *F,
                            llvm::SmallVectorImpl<llvm::Use *> &Uses) {
  llvm::SmallVector<llvm::Use *, 8> Worklist;
  for (llvm::Use &U : F->uses())
    Worklist.push_back(&U);
  while (!Worklist.empty()) {
    llvm::Use *U = Worklist.pop_back_val();
    llvm::User *Owner = U->getUser();
    if (llvm::isa<llvm::Instruction>(Owner)) {
      Uses.push_back(U);
      continue;
    }
    // ConstantExpr/aggregate: pass through to its users.
    if (auto *CE = llvm::dyn_cast<llvm::Constant>(Owner)) {
      // Only descend through ConstantExprs (e.g. bitcast); plain
      // ConstantStruct/ConstantArray in a GV initializer is genuinely
      // constant-context, leave alone.
      if (llvm::isa<llvm::ConstantExpr>(CE)) {
        for (llvm::Use &UU : CE->uses())
          Worklist.push_back(&UU);
      }
    }
  }
}

} // namespace

llvm::PreservedAnalyses
LuthierFunctionIndirectionPass::run(llvm::Module &M,
                                    llvm::ModuleAnalysisManager &) {
  // Only operate on AMDGCN device modules. The host pipeline registers
  // this pass at OptimizerLastEP unconditionally, so we filter here.
  llvm::Triple T(M.getTargetTriple());
  if (T.getArch() != llvm::Triple::ArchType::amdgcn)
    return llvm::PreservedAnalyses::all();

  // Phase 1: discover address-taken functions (any user that isn't
  // exclusively a direct call). A direct call has the function appearing
  // as the callee operand of a CallBase — we treat that as a non-address-
  // take.
  llvm::SmallVector<llvm::Function *, 16> AddressTaken;
  for (llvm::Function &F : M) {
    if (F.isDeclaration() || F.isIntrinsic())
      continue;
    bool Taken = false;
    for (const llvm::Use &U : F.uses()) {
      const llvm::User *Owner = U.getUser();
      if (const auto *CB = llvm::dyn_cast<llvm::CallBase>(Owner)) {
        if (&CB->getCalledOperandUse() == &U)
          continue; // direct call
      }
      Taken = true;
      break;
    }
    if (Taken)
      AddressTaken.push_back(&F);
  }

  if (AddressTaken.empty())
    return llvm::PreservedAnalyses::all();

  // Phase 2: assign deterministic sequential uint64_t IDs by mangled
  // name. Same source → same ID assignment, byte-for-byte.
  llvm::sort(AddressTaken,
             [](const llvm::Function *A, const llvm::Function *B) {
               return A->getName() < B->getName();
             });

  llvm::LLVMContext &Ctx = M.getContext();
  llvm::Type *PtrTy = llvm::PointerType::getUnqual(Ctx);
  llvm::Type *I64Ty = llvm::Type::getInt64Ty(Ctx);

  // Phase 3: build the table initializer pointing at each function in ID
  // order, and emit it as @__luthier_function_table.
  llvm::SmallVector<llvm::Constant *, 16> Slots;
  Slots.reserve(AddressTaken.size());
  for (llvm::Function *F : AddressTaken)
    Slots.push_back(F);
  auto *TableTy = llvm::ArrayType::get(PtrTy, Slots.size());
  auto *TableInit = llvm::ConstantArray::get(TableTy, Slots);

  if (M.getNamedGlobal(kTableName))
    llvm::report_fatal_error(
        "Module already contains __luthier_function_table; pass run twice?",
        /*gen_crash_diag=*/false);

  // External linkage so the device-tool .hipfb exports the table.
  // The launcher resolves the EMBEDDED bitcode's external `@__luthier_
  // function_table` reference against the symbol the device-tool
  // loader registered from the loaded .hipfb; that handoff only works
  // if the .hipfb actually exports the symbol (internal symbols are
  // invisible to `hsa_executable_iterate_agent_symbols`). The IModule-
  // side copy is then re-externalized + initializer-stripped by
  // ExternalizeGlobalsPass when the embedded clone is built.
  auto *Table = new llvm::GlobalVariable(
      M, TableTy, /*isConstant=*/true,
      llvm::GlobalValue::ExternalLinkage, TableInit, kTableName);

  // Phase 4: stamp each function with its ID attribute and rewrite
  // instruction-context address-takes to load through the table.
  for (uint64_t ID = 0; ID < AddressTaken.size(); ++ID) {
    llvm::Function *F = AddressTaken[ID];
    F->addFnAttr(kFunctionIDAttr, llvm::utostr(ID));

    llvm::SmallVector<llvm::Use *, 8> InstUses;
    collectInstructionUses(F, InstUses);
    if (InstUses.empty())
      continue;

    llvm::Constant *SlotPtr = llvm::ConstantExpr::getGetElementPtr(
        TableTy, Table,
        llvm::ArrayRef<llvm::Constant *>{
            llvm::ConstantInt::get(I64Ty, 0),
            llvm::ConstantInt::get(I64Ty, ID)});

    // Rewrite each use: insert a load right before the using instruction
    // and replace the operand. Multiple uses in the same instruction get
    // a fresh load each (cheap; the AMDGPU backend's GVN will coalesce).
    for (llvm::Use *U : InstUses) {
      auto *I = llvm::cast<llvm::Instruction>(U->getUser());
      llvm::IRBuilder<> B(I);
      llvm::Value *Loaded = B.CreateLoad(PtrTy, SlotPtr,
                                         F->getName() + ".indirected");
      U->set(Loaded);
    }
  }

  return llvm::PreservedAnalyses::none();
}

} // namespace luthier
