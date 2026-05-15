//===-- MockInjectionPlugin.cpp - plugin entry for mock injection passes --===//
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
/// \file
/// Luthier-style pass-plugin shim that registers all of the mock injection
/// passes with the Instrumentation PM driver's pipeline parser.
//===----------------------------------------------------------------------===//
#include "MockInjectionPasses.h"
#include "luthier/PassPlugin/LuthierPassPlugin.h"

#include <llvm/Passes/PassBuilder.h>

namespace {

template <typename PassT>
bool tryParsePass(llvm::StringRef Name, llvm::ModulePassManager &MPM) {
  if (Name == PassT::name()) {
    MPM.addPass(PassT());
    return true;
  }
  return false;
}

void registerMockInjectionPasses(llvm::PassBuilder &PB, void *) {
  PB.registerPipelineParsingCallback(
      [](llvm::StringRef Name, llvm::ModulePassManager &MPM,
         llvm::ArrayRef<llvm::PassBuilder::PipelineElement>) {
        using namespace luthier::test;
        return tryParsePass<MockInjectAtFunctionEntryPass>(Name, MPM) ||
               tryParsePass<MockInjectAtMBBEntryPass>(Name, MPM) ||
               tryParsePass<MockInjectAtMBBTerminatorPass>(Name, MPM) ||
               tryParsePass<MockInjectAtAllVALUPass>(Name, MPM) ||
               tryParsePass<MockInjectAtAllScalarPass>(Name, MPM) ||
               tryParsePass<MockInjectAtOpcodePass>(Name, MPM) ||
               tryParsePass<MockInjectAtAllVGPRDefsWithRegArgPass>(Name, MPM);
      });
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::luthier::PassPluginLibraryInfo
luthierGetPassPluginInfo() {
  return {LUTHIER_PASS_PLUGIN_API_VERSION,
          /*PluginName=*/"luthier-mock-injection-plugin",
          /*PluginVersion=*/LLVM_VERSION_STRING,
          /*ExtraArgs=*/nullptr,
          /*IModuleCreationCallback=*/nullptr,
          /*RegisterPreIROptimizationPasses=*/nullptr,
          /*RegisterInstrumentationPassBuilderCallback=*/
          registerMockInjectionPasses,
          /*PreLuthierIRIntrinsicLoweringPassesCallback=*/nullptr,
          /*PostLuthierIRIntrinsicLoweringPassesCallback=*/nullptr,
          /*RegisterLegacyCodegenPassesCallback=*/nullptr,
          /*AugmentTargetPassConfigCallback=*/nullptr};
}
