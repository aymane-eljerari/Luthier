//===-- LuthierFunctionIndirectionPass.h -------------------------*- C++-*-===//
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
/// \file LuthierFunctionIndirectionPass.h
/// Defines \c LuthierFunctionIndirectionPass, which assigns a stable
/// \c uint64_t function ID to every address-taken device function in the
/// module, emits a per-module function table
/// (\c @__luthier_function_table) whose initializer points at each
/// function's local definition, and rewrites instruction-context
/// address-takes to load through that table. Constant-context uses (e.g.
/// initializers of \c __device__ globals holding function pointers) are
/// left alone — their references flow through LLVM's Use machinery, so
/// downstream JIT renames update the table and the variable initializers
/// alike.
///
/// The pass must run **once on the original device module** before
/// \c CreateAndEmbedIModulePass clones it, so the rewrite is captured in
/// both the embedded \c .llvmbc bitcode (for JIT instrumentation) and the
/// final binary (post-body-strip).
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_LUTHIER_FUNCTION_INDIRECTION_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_LUTHIER_FUNCTION_INDIRECTION_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class LuthierFunctionIndirectionPass
    : public llvm::PassInfoMixin<LuthierFunctionIndirectionPass> {
public:
  LuthierFunctionIndirectionPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() {
    return "luthier-function-indirection";
  }
};

} // namespace luthier

#endif
