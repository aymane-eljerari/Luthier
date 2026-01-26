//===-- MachineInstrAnnotations.h --------------------------------*-C++-*-===//
// Copyright 2025-2026 @ Northeastern University Computer Architecture Lab
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
/// \file MachineInstrAnnotations.h
/// Describes methods used to query and set annotations and metadata of
/// machine instructions in Luthier's code generation process.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_MACHINE_INSTR_ANNOTATIONS_H
#define LUTHIER_TOOLING_MACHINE_INSTR_ANNOTATIONS_H
#include <SIInstrInfo.h>
#include <llvm/IR/Constants.h>
#include <luthier/Common/GenericLuthierError.h>

namespace luthier {

class TargetMachineInstrMDNode : public llvm::MDTuple {

public:
  static llvm::Expected<TargetMachineInstrMDNode &>
  initializeMDNode(llvm::MachineInstr &MI);

  static TargetMachineInstrMDNode &create(llvm::LLVMContext &Ctx);

  static TargetMachineInstrMDNode *
  getInstrMDNodeIfExists(llvm::MachineInstr &MI);

  void setTraceInstrAddress(llvm::LLVMContext &Ctx, uint64_t Addr);

  [[nodiscard]] std::optional<uint64_t> getTraceInstrAddress() const;

  [[nodiscard]] bool isTraceInstr() const {
    return getTraceInstrAddress().has_value();
  }

  static bool classof(const Metadata *MD);
};

} // namespace luthier

#endif