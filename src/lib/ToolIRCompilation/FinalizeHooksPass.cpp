//===-- FinalizeHooksPass.cpp ---------------------------------------------===//
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
/// \file FinalizeHooksPass.cpp
/// Implements the \c FinalizeHooksPass class.
//===----------------------------------------------------------------------===//
#include "luthier/ToolIRCompilation/FinalizeHooksPass.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <llvm/IR/Attributes.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/Module.h>

namespace luthier {

llvm::PreservedAnalyses FinalizeHooksPass::run(llvm::Module &M,
                                               llvm::ModuleAnalysisManager &) {
  for (llvm::Function &F : M) {
    if (!F.hasFnAttribute(HookAttribute))
      continue;
    F.removeFnAttr(llvm::Attribute::OptimizeNone);
    F.removeFnAttr(llvm::Attribute::NoInline);
    F.addFnAttr(llvm::Attribute::AlwaysInline);
  }
  return llvm::PreservedAnalyses::none();
}

} // namespace luthier
