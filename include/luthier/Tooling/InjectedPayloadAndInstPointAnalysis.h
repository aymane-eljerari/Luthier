//===-- InjectedPayloadAndInstPointAnalysis.h -------------------*- C++ -*-===//
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
/// \file InjectedPayloadAndInstPointAnalysis.h
/// This file describes the \c InjectedPayloadAndInstPointAnalysis which
/// maps injected payload functions in the instrumentation module to their
/// corresponding target \c MachineInstr instrumentation points.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_INJECTED_PAYLOAD_AND_INST_POINT_ANALYSIS_H
#define LUTHIER_TOOLING_INJECTED_PAYLOAD_AND_INST_POINT_ANALYSIS_H
#include <llvm/ADT/DenseMap.h>
#include <llvm/CodeGen/MachineInstr.h>
#include <llvm/IR/PassManager.h>

namespace luthier {

class InjectedPayloadAndInstPoint {
private:
  /// A map to keep track of the injected payload functions inside the
  /// instrumentation module given the MI they will be patched into
  llvm::DenseMap<llvm::MachineInstr *, llvm::Function *>
      AppMIToInjectedPayloadMap;
  /// An inverse mapping of the above DenseMap, relating each injected payload
  /// function to its target MI in the application
  llvm::DenseMap<llvm::Function *, llvm::MachineInstr *>
      InjectedPayloadToAppMIMap;

public:
  InjectedPayloadAndInstPoint() = default;

  void addEntry(llvm::MachineInstr &AppMI, llvm::Function &InjectedPayload) {
    AppMIToInjectedPayloadMap.insert({&AppMI, &InjectedPayload});
    InjectedPayloadToAppMIMap.insert({&InjectedPayload, &AppMI});
  }

  [[nodiscard]] llvm::MachineInstr *
  at(const llvm::Function &InjectedPayload) const {
    return InjectedPayloadToAppMIMap.at(&InjectedPayload);
  }

  [[nodiscard]] unsigned int size() const {
    return InjectedPayloadToAppMIMap.size();
  }

  [[nodiscard]] bool contains(const llvm::Function &InjectedPayload) const {
    return InjectedPayloadToAppMIMap.contains(&InjectedPayload);
  }

  [[nodiscard]] llvm::Function *at(const llvm::MachineInstr &AppMI) const {
    return AppMIToInjectedPayloadMap.at(&AppMI);
  }

  [[nodiscard]] bool contains(const llvm::MachineInstr &AppMI) const {
    return AppMIToInjectedPayloadMap.contains(&AppMI);
  }

  using mi_payload_const_iterator =
      llvm::DenseMap<llvm::MachineInstr *, llvm::Function *>::const_iterator;

  [[nodiscard]] mi_payload_const_iterator mi_payload_begin() const {
    return AppMIToInjectedPayloadMap.begin();
  }

  [[nodiscard]] mi_payload_const_iterator mi_payload_end() const {
    return AppMIToInjectedPayloadMap.end();
  }

  [[nodiscard]] llvm::iterator_range<mi_payload_const_iterator>
  mi_payload() const {
    return llvm::make_range(mi_payload_begin(), mi_payload_end());
  }

  using payload_mi_const_iterator =
      llvm::DenseMap<llvm::Function *, llvm::MachineInstr *>::const_iterator;

  [[nodiscard]] payload_mi_const_iterator payload_mi_begin() const {
    return InjectedPayloadToAppMIMap.begin();
  }

  [[nodiscard]] payload_mi_const_iterator payload_mi_end() const {
    return InjectedPayloadToAppMIMap.end();
  }

  [[nodiscard]] llvm::iterator_range<payload_mi_const_iterator>
  payload_mi() const {
    return llvm::make_range(payload_mi_begin(), payload_mi_end());
  }

  bool invalidate(llvm::Module &IModule, const llvm::PreservedAnalyses &PA,
                  llvm::ModuleAnalysisManager::Invalidator &PAC);
};

class InjectedPayloadAndInstPointAnalysis
    : public llvm::AnalysisInfoMixin<InjectedPayloadAndInstPointAnalysis> {
private:
  friend llvm::AnalysisInfoMixin<InjectedPayloadAndInstPointAnalysis>;

  static llvm::AnalysisKey Key;

public:
  using Result = InjectedPayloadAndInstPoint;

  InjectedPayloadAndInstPointAnalysis() = default;

  Result run(llvm::Module &IModule, llvm::ModuleAnalysisManager &);
};

} // namespace luthier

#endif
