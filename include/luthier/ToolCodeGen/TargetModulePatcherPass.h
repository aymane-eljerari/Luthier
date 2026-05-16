//===-- TargetModulePatcherPass.h -------------------------------*- C++ -*-===//
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
/// \file TargetModulePatcherPass.h
/// Master pass that patches the IModule into the target module to produce
/// a fully-instrumented target code. Runs as the final IModule legacy
/// ModulePass. This pass consists of two stages:
///
/// - **SVA Setup & Storage Code Emission**:
///   - For the initial-entry-point kernel: emit the SVA-setup sequence
///     that populates the SVA lanes from kernarg-preloaded SGPRs (see
///     \c emitCodeToSetupScratch \c emitCodeToStoreSGPRKernelArg)
///   - For each target MF: walk SVStorageAndLoadLocations'
///     StateValueStorageIntervals and emit
///     `currentSVS.emitCodeToSwitchSVS(MI, nextSVS)` at every interval
///     boundary, so the SVA migrates between storage schemes correctly
///     across the target's control flow.
///
/// **Phase B — Target Patching**
///   - Clone every non-payload Function + GlobalVariable + GlobalAlias
///     + GlobalIFunc from the IModule into the target module (per user:
///     "consented to having them present in the final binary").
///   - Strip stale `amdgpu-num-vgpr` / `amdgpu-num-sgpr` attributes from
///     target functions (CodeDiscoveryPass set them, and they're no
///     longer correct after instrumentation extends register usage).
///   - First iteration (minimal): every injected payload is outlined.
///     At each AppMI, replace with an `s_branch` to a per-payload label
///     emitted after the host function. Once all outlined payloads are
///     placed, walk the s_branches and relax any whose displacement
///     exceeds the s_branch limit to `s_setpc_b64`-via-scavenged-SGPRs,
///     using IModuleIPPredicatedLivenessAnalysis::getPMBBLiveIns and,
///     as a last resort, two free SVA lanes from
///     `StateValueArraySpecs::findLowestFreeLanes`.
///   - The pass MUST NOT invalidate the target MAM between phases —
///     SVStorageAndLoadLocations, IModuleIPPredicatedLivenessAnalysis,
///     and FunctionPreambleDescriptorAnalysis must all remain queryable
///     in Phase B.
///
/// Pipeline slot: very last legacy ModulePass on the IModule, after
/// `injected-payload-pei` and `machine-passes`.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_TARGET_MODULE_PATCHER_PASS_H
#define LUTHIER_TOOL_CODE_GEN_TARGET_MODULE_PATCHER_PASS_H
#include "luthier/ToolCodeGen/LegacyPassSupport.h"
#include <llvm/Pass.h>

namespace luthier {

class TargetModulePatcherPass;

LUTHIER_INITIALIZE_LEGACY_PASS_PROTOTYPE(TargetModulePatcherPass);

class TargetModulePatcherPass : public llvm::ModulePass {
public:
  static char ID;

  TargetModulePatcherPass() : llvm::ModulePass(ID) {}

  [[nodiscard]] llvm::StringRef getPassName() const override {
    return "Luthier Target Module Patcher Pass";
  }

  bool runOnModule(llvm::Module &IModule) override;

  void getAnalysisUsage(llvm::AnalysisUsage &AU) const override;
};

} // namespace luthier

#endif
