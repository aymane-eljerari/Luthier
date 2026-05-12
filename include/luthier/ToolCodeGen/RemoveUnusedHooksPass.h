//===-- RemoveUnusedHooksPass.h --------------------------------*- C++ -*-===//
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
/// \file RemoveUnusedHooksPass.h
/// Describes the \c RemoveUnusedHooksPass, which deletes hook Functions in
/// the instrumentation module that are not transitively reachable from any
/// injected payload entry. Runs first in the IModule IR pipeline, regardless
/// of optimization level.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_REMOVE_UNUSED_HOOKS_PASS_H
#define LUTHIER_TOOL_CODE_GEN_REMOVE_UNUSED_HOOKS_PASS_H
#include <llvm/IR/PassManager.h>

namespace luthier {

class RemoveUnusedHooksPass
    : public llvm::PassInfoMixin<RemoveUnusedHooksPass> {
public:
  RemoveUnusedHooksPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &IModule,
                              llvm::ModuleAnalysisManager &IMAM);
};

} // namespace luthier

#endif
