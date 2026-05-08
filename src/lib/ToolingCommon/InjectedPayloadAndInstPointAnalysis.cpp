//===-- InjectedPayloadAndInstPointAnalysis.cpp ---------------------------===//
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
/// \file InjectedPayloadAndInstPointAnalysis.cpp
/// This file implements the \c InjectedPayloadAndInstPointAnalysis class.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/InjectedPayloadAndInstPointAnalysis.h"
#include "luthier/Tooling/FunctionAnnotations.h"
#include "luthier/Tooling/WrapperAnalysisPasses.h"
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/IR/Module.h>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-generate-inst-ir"

namespace luthier {

bool InjectedPayloadAndInstPoint::invalidate(
    llvm::Module &IModule, const llvm::PreservedAnalyses &PA,
    llvm::ModuleAnalysisManager::Invalidator &Inv) {
  /// Invalidates this cached result whenever \c
  /// InjectedPayloadAndInstPointAnalysis is not preserved — i.e., whenever a
  /// pass adds or removes injected payload functions from the IModule.
  auto PAC = PA.getChecker<InjectedPayloadAndInstPointAnalysis>();
  return !PAC.preserved() &&
         !PAC.preservedSet<llvm::AllAnalysesOn<llvm::Module>>();
}

llvm::AnalysisKey InjectedPayloadAndInstPointAnalysis::Key;

InjectedPayloadAndInstPointAnalysis::Result
InjectedPayloadAndInstPointAnalysis::run(llvm::Module &IModule,
                                         llvm::ModuleAnalysisManager &IMAM) {
  InjectedPayloadAndInstPoint Result;

  // Get the target module and its machine module info.
  auto &TargetAppResult =
      IMAM.getResult<TargetAppModuleAndMAMAnalysis>(IModule);
  llvm::Module &TargetModule = TargetAppResult.getTargetAppModule();
  llvm::ModuleAnalysisManager &TargetMAM = TargetAppResult.getTargetAppMAM();

  // Build a reverse map: pcsections MDNode* → MachineInstr* for all target MIs.
  llvm::DenseMap<const llvm::MDNode *, llvm::MachineInstr *> PCSToMI;
  for (llvm::Function &F : TargetModule) {

    llvm::MachineFunctionAnalysis::Result *MFRes =
        TargetMAM
            .getResult<llvm::FunctionAnalysisManagerModuleProxy>(TargetModule)
            .getManager()
            .getCachedResult<llvm::MachineFunctionAnalysis>(F);
    if (MFRes) {
      for (llvm::MachineBasicBlock &MBB : MFRes->getMF()) {
        for (llvm::MachineInstr &MI : MBB) {
          if (llvm::MDNode *PCS = MI.getPCSections())
            PCSToMI.insert({PCS, &MI});
        }
      }
    }
  }

  // Scan IModule functions for !luthier.target_instr_point metadata.
  // Each such function is a collector (injected payload) whose metadata
  // points to the pcsections MDNode of its target MI.
  for (llvm::Function &F : IModule) {
    llvm::MDNode *MD = F.getMetadata(TargetInstrPointAttr);
    if (!MD)
      continue;
    if (auto It = PCSToMI.find(MD); It != PCSToMI.end())
      Result.addEntry(*It->second, F);
  }

  return Result;
}

} // namespace luthier
