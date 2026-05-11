//===-- CreateAndEmbedIModulePass.h ------------------------------*- C++-*-===//
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
/// \file CreateAndEmbedIModulePass.h
/// Defines \c CreateAndEmbedIModulePass in charge of creating and processing
/// the Luthier tool instrumentation \c llvm::Module and embedding its
/// bitcode into the compiled device code object.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_ORCHESTRATOR_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_ORCHESTRATOR_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class CreateAndEmbedIModulePass
    : public llvm::PassInfoMixin<CreateAndEmbedIModulePass> {
public:
  CreateAndEmbedIModulePass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() { return "luthier-embed-imodule"; }
};

} // namespace luthier

#endif
