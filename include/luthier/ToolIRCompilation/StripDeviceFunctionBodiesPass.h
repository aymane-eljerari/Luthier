//===-- StripDeviceFunctionBodiesPass.h ---------------------------*-C++-*-===//
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
/// \file StripDeviceFunctionBodiesPass.h
/// Defines \c StripDeviceFunctionBodiesPass: replaces every defined
/// function in the device module with a single \c unreachable block.
/// Symbols stay in the ELF for symbol-table consumers, but the actual
/// function logic is gone — Luthier tools dispatch through bitcode-derived
/// JIT-compiled variants instead, and a stub being invoked at runtime is a
/// bug we want to trap loudly. Global variables and the function-table GV
/// emitted by \c LuthierFunctionIndirectionPass are untouched.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_STRIP_DEVICE_FUNCTION_BODIES_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_STRIP_DEVICE_FUNCTION_BODIES_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class StripDeviceFunctionBodiesPass
    : public llvm::PassInfoMixin<StripDeviceFunctionBodiesPass> {
public:
  StripDeviceFunctionBodiesPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() {
    return "luthier-strip-device-function-bodies";
  }
};

} // namespace luthier

#endif
