//===-- InitialExecutionPointAnalysis.h ---------------------------*-C++-*-===//
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
/// \file InitialExecutionPointAnalysis.h
/// Describes the \c InitialExecutionPointAnalysis class which provides access
/// to the initial kernel where the initial entry point was launched.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_INITIAL_EXECUTION_POINT_H
#define LUTHIER_TOOLING_INITIAL_EXECUTION_POINT_H
#include <llvm/IR/PassManager.h>
#include <llvm/Support/AMDHSAKernelDescriptor.h>

namespace luthier {

class InitialExecutionPointAnalysis
    : public llvm::AnalysisInfoMixin<InitialExecutionPointAnalysis> {
  friend AnalysisInfoMixin;

  static llvm::AnalysisKey Key;

  std::function<const llvm::amdhsa::kernel_descriptor_t &(
      llvm::Module &, llvm::ModuleAnalysisManager &)>
      ExecutionPointResolver;

public:
  class Result {
    friend InitialExecutionPointAnalysis;

    const llvm::amdhsa::kernel_descriptor_t &InitialExecutionPoint;

    explicit Result(const llvm::amdhsa::kernel_descriptor_t &EP)
        : InitialExecutionPoint(EP) {};

  public:
    [[nodiscard]] const llvm::amdhsa::kernel_descriptor_t &
    getInitialExecutionPoint() const {
      return InitialExecutionPoint;
    }

    bool invalidate(llvm::Module &, const llvm::PreservedAnalyses &,
                    llvm::ModuleAnalysisManager::Invalidator &) {
      return false;
    }
  };

  explicit InitialExecutionPointAnalysis(
      std::function<const llvm::amdhsa::kernel_descriptor_t &(
          llvm::Module &, llvm::ModuleAnalysisManager &)>
          ExecutionPointResolver)
      : ExecutionPointResolver(std::move(ExecutionPointResolver)) {};

  Result run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM) {
    return Result{ExecutionPointResolver(M, MAM)};
  }
};

} // namespace luthier

#endif