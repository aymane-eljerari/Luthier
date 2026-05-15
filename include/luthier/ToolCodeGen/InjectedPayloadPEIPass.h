//===-- InjectedPayloadPEIPass.h --------------------------------*- C++ -*-===//
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
///
/// \file
/// Describes Luthier's Injected Payload Prologue and Epilogue insertion pass.
/// Runs *after* LLVM's stock PrologEpilogInserter. Payload functions carry
/// Attribute::Naked (set by InjectedPayloadCreationPass::assignToInject), so
/// the stock PEI is a no-op for them — this pass emits the actual SVA load,
/// frame-register spill into SVA lanes, and the symmetric epilogue. Non-
/// payload device functions still go through the stock PEI normally.
///
/// Key dependencies:
///   - InjectedPayloadAttribute on the MF's Function
///   - The SVA VGPR allocated by IntrinsicMIRLoweringPass; discovered post-RA
///     by walking V_READLANE_B32 instructions in the entry MBB whose lane
///     immediate is < total SA lanes (read-side discovery; MFInfo->WWMReservedRegs
///     is unusable today, see reference_amdgpu_wwm_pipeline memory note)
///   - StateValueArraySpecs for the SVA layout (lanes, used SAs)
///   - StateValueArrayStorage scheme picked by the target-side
///     SVStorageAndLoadLocations analysis (consumed via MAM cache)
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_INJECTED_PAYLOAD_PEI_PASS_H
#define LUTHIER_TOOL_CODE_GEN_INJECTED_PAYLOAD_PEI_PASS_H
#include "luthier/ToolCodeGen/LegacyPassSupport.h"
#include <llvm/CodeGen/MachineFunctionPass.h>

namespace luthier {

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
