//===-- LoadHIPFATBinaryInfoPass.h --------------------------------*-C++-*-===//
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
/// \file LoadHIPFATBinaryInfoPass.h
/// Deletes \c __hip_register* host-side functions and stores the
/// information they would have registered so Luthier's tool executable
/// loader can consume it at runtime. The pass operates on host code; on
/// AMD GCN device modules it is a no-op.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_IR_COMPILATION_LOAD_HIP_FAT_BINARY_INFO_PASS_H
#define LUTHIER_TOOLING_IR_COMPILATION_LOAD_HIP_FAT_BINARY_INFO_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
} // namespace llvm

namespace luthier {

class LoadHIPFATBinaryInfoPass
    : public llvm::PassInfoMixin<LoadHIPFATBinaryInfoPass> {
public:
  LoadHIPFATBinaryInfoPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() {
    return "luthier-load-hip-fat-binary-info-pass";
  }
};

} // namespace luthier

#endif
