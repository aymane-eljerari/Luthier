//===-- ToolIRCompilationPlugin.cpp ---------------------------------------===//
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
/// \file ToolIRCompilationPlugin.cpp
/// LLVM pass plugin for registering Luthier's tool IR compilation passes to
/// the compilation pipeline.
//===----------------------------------------------------------------------===//
#include "luthier/ToolIRCompilation/CreateAndEmbedIModulePass.h"
#include "luthier/ToolIRCompilation/ExternalizeGlobalsPass.h"
#include "luthier/ToolIRCompilation/FinalizeIntrinsicsPass.h"
#include "luthier/ToolIRCompilation/LoadHIPFATBinaryInfoPass.h"
#include "luthier/ToolIRCompilation/MarkAnnotationsPass.h"
#include "luthier/ToolIRCompilation/StripKernelsPass.h"
#include "luthier/ToolIRCompilation/SubstituteAMDGCNIntrinsicsPass.h"
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Plugins/PassPlugin.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-tool-ir-compilation-plugin"

namespace {

template <typename PassT>
bool tryParsePass(llvm::StringRef Name, llvm::ModulePassManager &MPM) {
  if (Name == PassT::name()) {
    MPM.addPass(PassT());
    return true;
  }
  return false;
}

void registerEmbedIModulePasses(llvm::PassBuilder &PB) {
  PB.registerPipelineParsingCallback(
      [](llvm::StringRef Name, llvm::ModulePassManager &MPM,
         llvm::ArrayRef<llvm::PassBuilder::PipelineElement>) {
        return tryParsePass<luthier::MarkAnnotationsPass>(Name, MPM) ||
               tryParsePass<luthier::FinalizeIntrinsicsPass>(Name, MPM) ||
               tryParsePass<luthier::StripKernelsPass>(Name, MPM) ||
               tryParsePass<luthier::ExternalizeGlobalsPass>(Name, MPM) ||
               tryParsePass<luthier::SubstituteAMDGCNIntrinsicsPass>(Name, MPM) ||
               tryParsePass<luthier::LoadHIPFATBinaryInfoPass>(Name, MPM) ||
               tryParsePass<luthier::CreateAndEmbedIModulePass>(Name, MPM);
      });

  // CreateAndEmbedIModulePass clones the AMD GCN device module, runs the
  // worker passes on the clone, and embeds bitcode. It internally bails on
  // non-AMD GCN modules, so registering at the optimizer-last EP is safe.
  PB.registerOptimizerLastEPCallback(
      [](llvm::ModulePassManager &MPM, llvm::OptimizationLevel
#if LLVM_VERSION_MAJOR >= 20
         ,
         llvm::ThinOrFullLTOPhase
#endif
      ) { MPM.addPass(luthier::CreateAndEmbedIModulePass()); });

  // LoadHIPFATBinaryInfoPass rewrites the host-side __hip_register* calls.
  // It internally bails on AMD GCN device modules, so we register at the
  // pipeline-start EP and let it filter by triple.
  PB.registerPipelineStartEPCallback(
      [](llvm::ModulePassManager &MPM, llvm::OptimizationLevel) {
        MPM.addPass(luthier::LoadHIPFATBinaryInfoPass());
      });
}

} // namespace

llvm::PassPluginLibraryInfo getEmbedLuthierBitcodePassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, DEBUG_TYPE, LLVM_VERSION_STRING,
          registerEmbedIModulePasses};
}

#ifndef LLVM_LUTHIERIMODULEEMBEDPLUGIN_LINK_INTO_TOOLS
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getEmbedLuthierBitcodePassPluginInfo();
}
#endif
