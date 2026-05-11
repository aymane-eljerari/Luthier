//===-- InjectedPayloadPEIPass.h --------------------------------*- C++ -*-===//
// Copyright 2022-2025 @ Northeastern University Computer Architecture Lab
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
///
/// \file
/// This file describes Luthier's Injected Payload Prologue and Epilogue
/// insertion pass, which replaces the normal prologues and epilogues insertion
/// by the CodeGen pipeline.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_INJECTED_PAYLOAD_PEI_PASS_H
#define LUTHIER_TOOL_CODE_GEN_INJECTED_PAYLOAD_PEI_PASS_H
#include "luthier/Intrinsic/IntrinsicProcessor.h"
#include "luthier/ToolCodeGen/IPVectorRegLiveness.h"
#include "luthier/ToolCodeGen/LRCallgraph.h"
#include "luthier/ToolCodeGen/LegacyPassSupport.h"
#include "luthier/ToolCodeGen/PhysicalRegAccessVirtualizationPass.h"
#include "luthier/ToolCodeGen/PrePostAmbleEmitter.h"
#include "luthier/ToolCodeGen/SVStorageAndLoadLocations.h"
#include <llvm/CodeGen/MachineFunctionPass.h>
#include <llvm/IR/PassManager.h>

namespace luthier {

class PhysicalRegAccessVirtualizationPass;

class InjectedPayloadPEIPass;

LUTHIER_INITIALIZE_LEGACY_PASS_PROTOTYPE(InjectedPayloadPEIPass);

class InjectedPayloadPEIPass : public llvm::MachineFunctionPass {
public:
  static char ID;

  InjectedPayloadPEIPass() : llvm::MachineFunctionPass(ID) {};

  [[nodiscard]] llvm::StringRef getPassName() const override {
    return "Luthier Injected Payload Prologue Epilogue Insertion Pass";
  }

  bool runOnMachineFunction(llvm::MachineFunction &MF) override;

  void getAnalysisUsage(llvm::AnalysisUsage &AU) const override;
};

} // namespace luthier

#endif