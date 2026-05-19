//===-- StripDeviceFunctionBodiesPass.cpp ----------------------------------===//
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
/// \file StripDeviceFunctionBodiesPass.cpp
/// Implements the body-strip pass. See header.
//===----------------------------------------------------------------------===//
#include "luthier/ToolIRCompilation/StripDeviceFunctionBodiesPass.h"

#include <llvm/ADT/STLExtras.h>
#include <llvm/IR/BasicBlock.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Module.h>
#include <llvm/TargetParser/Triple.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-strip-device-function-bodies"

namespace luthier {

llvm::PreservedAnalyses
StripDeviceFunctionBodiesPass::run(llvm::Module &M,
                                   llvm::ModuleAnalysisManager &) {
  llvm::Triple T(M.getTargetTriple());
  if (T.getArch() != llvm::Triple::ArchType::amdgcn)
    return llvm::PreservedAnalyses::all();

  llvm::LLVMContext &Ctx = M.getContext();

  for (llvm::Function &F : M) {
    if (F.isDeclaration() || F.isIntrinsic())
      continue;
    // Drop the function's body so codegen emits only a one-instruction
    // trap stub. Keep the symbol — variable initializers and
    // @llvm.used arrays still reference these by address. Drop refs
    // first so any uses inside the soon-to-be-deleted blocks don't
    // dangle; then build a single `unreachable`-terminated block.
    F.dropAllReferences();
    llvm::BasicBlock *Entry =
        llvm::BasicBlock::Create(Ctx, "stub", &F);
    llvm::IRBuilder<> B(Entry);
    B.CreateUnreachable();
  }

  return llvm::PreservedAnalyses::none();
}

} // namespace luthier
