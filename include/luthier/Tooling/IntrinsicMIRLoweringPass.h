//===-- IntrinsicMIRLoweringPass.h ------------------------------*- C++ -*-===//
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
/// \file IntrinsicMIRLoweringPass.h
/// Describes the Intrinsic MIR Lowering Pass, in charge of converting inline
/// assembly placeholder instructions with a sequence of Machine Instructions.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_INTRINSIC_MIR_LOWERING_PASS_H
#define LUTHIER_TOOLING_INTRINSIC_MIR_LOWERING_PASS_H
#include "luthier/Intrinsic/IntrinsicProcessor.h"
#include "luthier/Tooling/LegacyPassSupport.h"
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/CodeGen/Register.h>
#include <llvm/IR/Module.h>
#include <llvm/Pass.h>
#include <llvm/PassRegistry.h>

namespace llvm {
class MachineFunction;
} // namespace llvm

namespace luthier {

class IntrinsicMIRLoweringPass;

class StateValueArraySpecs;

LUTHIER_INITIALIZE_LEGACY_PASS_PROTOTYPE(IntrinsicMIRLoweringPass);

class IntrinsicMIRLoweringPass : public llvm::ModulePass {
public:
  /// Describes one pending V_READLANE_B32 to be emitted in phase 2, replacing
  /// an IMPLICIT_DEF SGPR_32 placeholder created during intrinsic lowering.
  struct PendingSVAReadlane {
    /// The IMPLICIT_DEF SGPR_32 virtual register to be replaced
    llvm::Register SGPRPlaceholder;
    /// Which scalar argument this lane belongs to
    ScalarValueArgument SA;
    /// 0-based lane index within the SA's total lane count
    uint8_t LaneWithinSA;
  };

  /// SVA placeholder state collected per MachineFunction during
  /// \c lowerIntrinsics, consumed by phase 2 in \c runOnModule.
  struct PerFunctionSVAInfo {
    /// IMPLICIT_DEF VGPR_32 marked with pcsections !"luthier.sva_vgpr_placeholder";
    /// a later pass resolves this to the actual SVA VGPR.
    llvm::Register SVAVGPRPlaceholder{0};
    /// SGPR_32 placeholders waiting to be replaced by V_READLANE_B32
    llvm::SmallVector<PendingSVAReadlane> Readlanes;
  };

private:
  bool
  lowerIntrinsics(llvm::Module &IModule,
                  llvm::DenseMap<llvm::MachineFunction *, PerFunctionSVAInfo>
                      &SVAInfoByMF,
                  std::unique_ptr<StateValueArraySpecs> &SVASpecs);

public:
  static char ID;

  IntrinsicMIRLoweringPass() : llvm::ModulePass(ID) {};

  [[nodiscard]] llvm::StringRef getPassName() const override {
    return "Luthier Intrinsic MIR Lowering";
  }

  bool runOnModule(llvm::Module &IModule) override;

  void getAnalysisUsage(llvm::AnalysisUsage &AU) const override;
};

} // namespace luthier

#endif
