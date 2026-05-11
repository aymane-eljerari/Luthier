//===-- ExternalizeGlobalsPass.h ---------------------------------*- C++-*-===//
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
/// \file ExternalizeGlobalsPass.h
/// Defines \c ExternalizeGlobalsPass which:
/// - Drops static managed variable initializers, as well as any metadata
/// globals from the instrumentation module
/// - Externalizes remaining globals (except \c
/// __hip_cuid_*) so that they can be linked against the copy defined by the
/// instrumentation module's code object.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_EXTERNALIZE_GLOBALS_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_EXTERNALIZE_GLOBALS_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class ExternalizeGlobalsPass
    : public llvm::PassInfoMixin<ExternalizeGlobalsPass> {
public:
  ExternalizeGlobalsPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() { return "luthier-externalize-globals"; }
};

} // namespace luthier

#endif
