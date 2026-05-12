//===-- RemoveUnusedHooksPass.cpp ------------------------------------------===//
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
/// \file RemoveUnusedHooksPass.cpp
/// Implements the \c RemoveUnusedHooksPass class.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/RemoveUnusedHooksPass.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <llvm/ADT/SmallPtrSet.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/IR/CallingConv.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/InstIterator.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Debug.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-remove-unused-hooks"

namespace luthier {

namespace {

/// Collect the direct callees and address-takings of \p F into \p Out. Treats
/// any Function referenced by a ConstantExpr / direct call / address-of as a
/// successor in the reachability graph.
void collectFunctionSuccessors(llvm::Function &F,
                               llvm::SmallPtrSetImpl<llvm::Function *> &Out) {
  for (llvm::Instruction &I : llvm::instructions(F)) {
    if (auto *CB = llvm::dyn_cast<llvm::CallBase>(&I)) {
      if (llvm::Function *Callee = CB->getCalledFunction()) {
        Out.insert(Callee);
        continue;
      }
      if (llvm::Value *Op = CB->getCalledOperand()) {
        if (auto *Callee = llvm::dyn_cast<llvm::Function>(Op->stripPointerCasts()))
          Out.insert(Callee);
      }
    }
    for (llvm::Use &U : I.operands()) {
      llvm::Value *V = U.get();
      if (auto *Callee = llvm::dyn_cast<llvm::Function>(V))
        Out.insert(Callee);
      else if (auto *CE = llvm::dyn_cast<llvm::ConstantExpr>(V)) {
        if (auto *Callee = llvm::dyn_cast<llvm::Function>(CE->stripPointerCasts()))
          Out.insert(Callee);
      }
    }
  }
}

} // namespace

llvm::PreservedAnalyses
RemoveUnusedHooksPass::run(llvm::Module &IModule,
                           llvm::ModuleAnalysisManager &) {
  LLVM_DEBUG(llvm::dbgs() << "=== RemoveUnusedHooksPass: module '"
                          << IModule.getName() << "' ===\n");

  bool AnyErased = false;
  while (true) {
    // Roots: injected payload entries and any address-taken Function
    // (conservative — an external user may invoke it).
    llvm::SmallPtrSet<llvm::Function *, 16> Reachable;
    llvm::SmallVector<llvm::Function *, 16> Worklist;

    for (llvm::Function &F : IModule.functions()) {
      if (F.isDeclaration())
        continue;
      bool IsRoot = F.hasFnAttribute(InjectedPayloadAttribute) ||
                    F.hasAddressTaken();
      if (IsRoot && Reachable.insert(&F).second)
        Worklist.push_back(&F);
    }

    while (!Worklist.empty()) {
      llvm::Function *F = Worklist.pop_back_val();
      llvm::SmallPtrSet<llvm::Function *, 8> Succs;
      collectFunctionSuccessors(*F, Succs);
      for (llvm::Function *S : Succs) {
        if (S->isDeclaration())
          continue;
        if (Reachable.insert(S).second)
          Worklist.push_back(S);
      }
    }

    llvm::SmallVector<llvm::Function *, 8> ToErase;
    for (llvm::Function &F : IModule.functions()) {
      if (F.isDeclaration())
        continue;
      if (!F.hasFnAttribute(HookAttribute))
        continue;
      if (Reachable.contains(&F))
        continue;
      ToErase.push_back(&F);
    }

    if (ToErase.empty())
      break;

    LLVM_DEBUG({
      llvm::dbgs() << "  Removing " << ToErase.size() << " unused hook(s):\n";
      for (llvm::Function *F : ToErase)
        llvm::dbgs() << "    - " << F->getName() << "\n";
    });

    for (llvm::Function *F : ToErase) {
      F->replaceAllUsesWith(llvm::UndefValue::get(F->getType()));
      F->dropAllReferences();
    }
    for (llvm::Function *F : ToErase)
      F->eraseFromParent();
    AnyErased = true;
  }

  return AnyErased ? llvm::PreservedAnalyses::none()
                   : llvm::PreservedAnalyses::all();
}

} // namespace luthier
