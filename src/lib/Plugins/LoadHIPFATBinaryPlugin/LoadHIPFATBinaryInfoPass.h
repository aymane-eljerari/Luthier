//===-- LoadHIPFATBinaryInfo.h ----------------------------------*- C++ -*-===//
// Copyright 2026 @ Northeastern University Computer Architecture Lab
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
/// This file describes a LLVM compiler plugin for deleting __hip_register
/// functions and storing the necessary information to register them with the
/// Tool Executable Loader
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMPILE_PLUGINS_LOAD_HIP_FAT_BINARY_INFO_PASS_HPP
#define LUTHIER_COMPILE_PLUGINS_LOAD_HIP_FAT_BINARY_INFO_PASS_HPP
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
};

} // namespace luthier

#endif