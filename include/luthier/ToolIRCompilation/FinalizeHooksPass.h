//===-- FinalizeHooksPass.h --------------------------------------*- C++-*-===//
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
/// \file FinalizeHooksPass.h
/// Defines the \c FinalizeHooksPass which drops \c OptimizeNone / \c NoInline
/// and adds \c AlwaysInline to each function carrying the Luthier hook function
/// attribute.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_FINALIZE_HOOKS_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_FINALIZE_HOOKS_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class FinalizeHooksPass : public llvm::PassInfoMixin<FinalizeHooksPass> {
public:
  FinalizeHooksPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() { return "luthier-finalize-hooks"; }
};

} // namespace luthier

#endif
