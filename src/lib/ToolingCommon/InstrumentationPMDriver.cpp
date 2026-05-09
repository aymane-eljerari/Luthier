//===-- InstrumentationPMDriver.cpp ---------------------------------------===//
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
/// \file InstrumentationPMDriver.cpp
/// Implements the \c InstrumentationPMDriver pass.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/InstrumentationPMDriver.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
// #include "luthier/Tooling/InjectedPayloadAndInstPointAnalysis.h"
// #include "luthier/Tooling/InjectedPayloadPEIPass.h"
// #include "luthier/Tooling/IntrinsicMIRLoweringPass.h"
// #include "luthier/Tooling/IntrinsicProcessorsAnalysis.h"
// #include "luthier/Tooling/PatchLiftedRepresentationPass.h"
// #include "luthier/Tooling/PhysRegsNotInLiveInsAnalysis.h"
// #include "luthier/Tooling/ProcessIntrinsicsAtIRLevelPass.h"
#include "luthier/TestFile/LuthierFile.h"
#include "luthier/Tooling/WrapperAnalysisPasses.h"
#include <AMDGPUTargetMachine.h>
#include <llvm/Analysis/CGSCCPassManager.h>
#include <llvm/Analysis/LoopAnalysisManager.h>
#include <llvm/Analysis/RuntimeLibcallInfo.h>
#include <llvm/CodeGen/MIRParser/MIRParser.h>
#include <llvm/CodeGen/MIRPrinter.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/MachinePassManager.h>
#include <llvm/CodeGen/TargetPassConfig.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/PassManager.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Linker/Linker.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/PassInfo.h>
#include <llvm/PassRegistry.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Passes/StandardInstrumentations.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/Support/ToolOutputFile.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-apply-instrumentation"

namespace luthier {

namespace {

llvm::OptimizationLevel optLevelFromUnsigned(unsigned Level) {
  switch (Level) {
  case 0:
    return llvm::OptimizationLevel::O0;
  case 1:
    return llvm::OptimizationLevel::O1;
  case 3:
    return llvm::OptimizationLevel::O3;
  default:
    return llvm::OptimizationLevel::O2;
  }
}

struct LoadedIModule {
  std::unique_ptr<llvm::Module> Module;
  std::unique_ptr<llvm::MIRParser> MIRParser; // non-null only for .mir inputs
};

llvm::Expected<LoadedIModule> loadIModuleFromFile(llvm::StringRef Path,
                                                  llvm::LLVMContext &Ctx) {
  if (Path.ends_with(".mir")) {
    auto MBOrErr = llvm::MemoryBuffer::getFile(Path);
    if (!MBOrErr)
      return LUTHIER_MAKE_GENERIC_ERROR("Failed to open imodule file '" +
                                        Path.str() +
                                        "': " + MBOrErr.getError().message());
    auto Parser = llvm::createMIRParser(std::move(*MBOrErr), Ctx);
    auto M = Parser->parseIRModule();
    if (!M)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse IR from imodule file '" + Path.str() + "'");
    return LoadedIModule{std::move(M), std::move(Parser)};
  }

  if (Path.ends_with(".ll") || Path.ends_with(".bc")) {
    llvm::SMDiagnostic Err;
    auto M = llvm::parseIRFile(Path, Err, Ctx);
    if (!M)
      return LUTHIER_MAKE_GENERIC_ERROR("Failed to parse imodule file '" +
                                        Path.str() +
                                        "': " + Err.getMessage().str());
    return LoadedIModule{std::move(M), nullptr};
  }

  return LUTHIER_MAKE_GENERIC_ERROR(
      "Unrecognized imodule file extension for '" + Path.str() +
      "': expected .mir, .ll, or .bc");
}

/// Parses a series of codegen pipeline passes specified in \p PipelineStr and
/// adds them into the legacy \p PM
llvm::Error parseCodeGenPipeline(llvm::StringRef PipelineStr,
                                 llvm::legacy::PassManager &PM) {

  llvm::PassRegistry &Registry = *llvm::PassRegistry::getPassRegistry();
  llvm::SmallVector<llvm::StringRef, 8> PassNames;
  PipelineStr.split(PassNames, ',', /*MaxSplit=*/-1, /*KeepEmpty=*/false);
  for (llvm::StringRef Name : PassNames) {
    Name = Name.trim();
    const llvm::PassInfo *PI = Registry.getPassInfo(Name);
    if (!PI || !PI->getNormalCtor())
      return LUTHIER_MAKE_GENERIC_ERROR("Unknown or unregistered MIR pass '" +
                                        Name.str() + "'");
    PM.add(PI->getNormalCtor()());
  }
  return llvm::Error::success();
}

} // namespace

InstrumentationPMDriver::InstrumentationPMDriver(
    const InstrumentationPMDriverOptions &Options,
    llvm::ArrayRef<PassPlugin> PassPlugins,
    IModuleCreationFnType ModuleCreatorFn,
    std::function<void(llvm::PassBuilder &)> PassBuilderAugmentationCallback,
    std::function<void(llvm::ModulePassManager &)> PreIROptimizationCallback,
    std::function<void(llvm::ModulePassManager &)>
        PreIRIntrinsicLoweringCallback,
    std::function<void(llvm::ModulePassManager &)>
        PostIRIntrinsicLoweringCallback,
    std::function<void(llvm::PassRegistry &, llvm::TargetPassConfig &,
                       llvm::TargetMachine &)>
        AugmentTargetPassConfigCallback)
    : Options(Options), PassPlugins(PassPlugins),
      IModuleCreatorFn(std::move(ModuleCreatorFn)),
      PassBuilderAugmentationCallback(
          std::move(PassBuilderAugmentationCallback)),
      PreIROptimizationCallback(std::move(PreIROptimizationCallback)),
      PreIRIntrinsicLoweringCallback(std::move(PreIRIntrinsicLoweringCallback)),
      PostIRIntrinsicLoweringCallback(
          std::move(PostIRIntrinsicLoweringCallback)),
      AugmentTargetPassConfigCallback(
          std::move(AugmentTargetPassConfigCallback)) {
  llvm::PassRegistry *Registry = llvm::PassRegistry::getPassRegistry();
  initializeIModuleMAMWrapperPass(*Registry);
  // TODO: uncomment when production-pipeline dependencies are compiled in:
  // initializePhysicalRegAccessVirtualizationPass(*Registry);
  // initializeInjectedPayloadPEIPass(*Registry);
  // initializeIntrinsicMIRLoweringPass(*Registry);

  for (const auto &Plugin : PassPlugins) {
    Plugin.registerLegacyCodegenPassesCallback(*Registry);
  }
}

llvm::PreservedAnalyses
InstrumentationPMDriver::run(llvm::Module &TargetAppM,
                             llvm::ModuleAnalysisManager &TargetMAM) {
  llvm::LLVMContext &Context = TargetAppM.getContext();

  const auto &TargetAppTM =
      TargetMAM.getResult<llvm::MachineModuleAnalysis>(TargetAppM)
          .getMMI()
          .getTarget();
  const llvm::Target &Target = TargetAppTM.getTarget();

  /// For target machines with absolute flat scratch the AMDGPU backend will
  /// default to using buffer instructions to access scratch unless it is
  /// forced to use scratch instructions by setting "enable-flat-scratch" to
  /// true in its features when creating its target machine
  auto ForceEnableFS = [&]() {
    llvm::SubtargetFeatures TargetAppFeatures(
        TargetAppTM.getTargetFeatureString());
    llvm::SubtargetFeatures IModuleFeatures;
    for (llvm::StringRef Feature : TargetAppFeatures.getFeatures()) {
      if (llvm::SubtargetFeatures::StripFlag(Feature) !=
          "enable-flat-scratch") {
        IModuleFeatures.AddFeature(Feature,
                                   llvm::SubtargetFeatures::hasFlag(Feature));
      }
    }
    IModuleFeatures.AddFeature("enable-flat-scratch");
    return IModuleFeatures.getString();
  };

  /// TODO: Add CL options to control TM options and the codegen optimization
  /// level for the Instrumentation TM
  std::unique_ptr<llvm::GCNTargetMachine> ITM{
      static_cast<llvm::GCNTargetMachine *>(Target.createTargetMachine(
          TargetAppTM.getTargetTriple(), TargetAppTM.getTargetCPU(),
          Options.ForceFlatScratchInstructions
              ? ForceEnableFS()
              : TargetAppTM.getTargetFeatureString(),
          TargetAppTM.Options, TargetAppTM.getRelocationModel(),
          TargetAppTM.getCodeModel(), TargetAppTM.getOptLevel()))};

  /// IModule loading
  std::unique_ptr<llvm::MIRParser> IModuleMIRParser;
  std::unique_ptr<llvm::Module> IModule;

  if (!Options.IModulePath.empty()) {
    llvm::StringRef IModPath = Options.IModulePath.getValue();
    if (IModPath.ends_with(".luthier")) {
      auto ParserOrErr = LuthierFileParser::create(IModPath);
      if (!ParserOrErr) {
        LUTHIER_CTX_EMIT_ON_ERROR(Context, ParserOrErr.takeError());
        return llvm::PreservedAnalyses::all();
      }
      auto IModOrErr = ParserOrErr->loadIModule(Context, TargetAppM);
      if (!IModOrErr) {
        LUTHIER_CTX_EMIT_ON_ERROR(Context, IModOrErr.takeError());
        return llvm::PreservedAnalyses::all();
      }
      IModule = std::move(IModOrErr->first);
      IModuleMIRParser = std::move(IModOrErr->second);
    } else {
      auto LoadedOrErr = loadIModuleFromFile(IModPath, Context);
      if (!LoadedOrErr) {
        LUTHIER_CTX_EMIT_ON_ERROR(Context, LoadedOrErr.takeError());
        return llvm::PreservedAnalyses::all();
      }
      IModule = std::move(LoadedOrErr->Module);
      IModuleMIRParser = std::move(LoadedOrErr->MIRParser);
    }
  } else {
    IModule = IModuleCreatorFn(Context);
  }

  /// Invoke the module creation callbacks in the plugins and link them with
  /// the current instrumentation module
  for (const auto &Plugin : PassPlugins) {
    std::unique_ptr<llvm::Module> PluginIModule =
        Plugin.instrumentationModuleCreationCallback(
            Context, ITM->getTargetTriple(), ITM->getTargetCPU(),
            ITM->getTargetFeatureString());
    if (PluginIModule != nullptr) {
      /// TODO: Add CL parameter to control the linking flag here
      if (llvm::Linker::linkModules(*IModule, std::move(PluginIModule))) {
        LUTHIER_CTX_EMIT_ON_ERROR(
            Context,
            LUTHIER_MAKE_GENERIC_ERROR("Failed to link modules together"));
      }
    }
  }

  /// Analysis-manager and PassBuilder setup for the IR pipeline
  llvm::ModulePassManager IMPM;
  llvm::LoopAnalysisManager ILAM;
  llvm::FunctionAnalysisManager IFAM;
  llvm::CGSCCAnalysisManager ICGAM;
  llvm::ModuleAnalysisManager IMAM;
  llvm::MachineFunctionAnalysisManager IMFAM;
  llvm::PassInstrumentationCallbacks PIC;
  llvm::StandardInstrumentations SI(IModule->getContext(),
                                    Options.EnableSIDebugLogging);

  // Create a PM Builder for the IR pipeline
  llvm::PassBuilder PB(ITM.get(), llvm::PipelineTuningOptions(), std::nullopt,
                       &PIC);

  /// Augment the pass builder
  PassBuilderAugmentationCallback(PB);
  for (const auto &Plugin : PassPlugins) {
    Plugin.registerInstrumentationPassBuilderCallback(PB);
  }

  SI.registerCallbacks(PIC, &IMAM);

  // TODO: re-enable when production-pipeline deps are compiled in:
  // IMAM.registerPass([&]() { return IntrinsicIRLoweringInfoMapAnalysis(); });
  // IMAM.registerPass([&]() { return IntrinsicsProcessorsAnalysis(); });
  // IMAM.registerPass([&]() { return PhysRegsNotInLiveInsAnalysis(); });
  // IMAM.registerPass([&]() { return InjectedPayloadAndInstPointAnalysis(); });

  IMAM.registerPass(
      [&]() { return TargetAppModuleAndMAMAnalysis(TargetMAM, TargetAppM); });

  PB.registerModuleAnalyses(IMAM);
  PB.registerCGSCCAnalyses(ICGAM);
  PB.registerFunctionAnalyses(IFAM);
  PB.registerLoopAnalyses(ILAM);
  PB.crossRegisterProxies(ILAM, IFAM, ICGAM, IMAM);

  auto IRStagePA = llvm::PreservedAnalyses::all();
  {
    llvm::TimeTraceScope Scope("Instrumentation Module IR Optimization");

    bool IsIRPassPipelineNotSpecified =
        Options.IModuleIRPasses.getNumOccurrences() == 0;
    bool IsIRPipelineSpecifiedAndNotEmpty =
        !Options.IModuleIRPasses.getValue().empty();
    bool MustRunIRPipeline =
        IsIRPassPipelineNotSpecified || IsIRPipelineSpecifiedAndNotEmpty;

    if (IsIRPassPipelineNotSpecified) {
      // TODO: IR pipeline — uncomment when deps are available:
      PreIROptimizationCallback(IMPM);
      for (const auto &Plugin : PassPlugins)
        Plugin.registerPreIROptimizationPasses(IMPM);
      unsigned OptLevelVal =
          Options.IModuleOptLevel.getNumOccurrences() > 0
              ? Options.IModuleOptLevel.getValue()
              : static_cast<unsigned>(TargetAppTM.getOptLevel());
      IMPM.addPass(
          PB.buildPerModuleDefaultPipeline(optLevelFromUnsigned(OptLevelVal)));
      PreIRIntrinsicLoweringCallback(IMPM);
      for (const auto &Plugin : PassPlugins)
        Plugin.invokePreLuthierIRIntrinsicLoweringPassesCallback(IMPM);
      // IMPM.addPass(ProcessIntrinsicsAtIRLevelPass(*ITM));
      // PostIRIntrinsicLoweringCallback(IMPM);
      // for (const auto &Plugin : PassPlugins)
      //   Plugin.invokePostLuthierIRIntrinsicLoweringPassesCallback(IMPM);
      // IMPM.run(*IModule, IMAM);
    } else if (IsIRPipelineSpecifiedAndNotEmpty) {
      // Run caller-supplied IR pipeline.
      if (auto Err =
              PB.parsePassPipeline(IMPM, Options.IModuleIRPasses.getValue())) {
        LUTHIER_CTX_EMIT_ON_ERROR(Context, std::move(Err));
        return llvm::PreservedAnalyses::all();
      }
    }
    if (MustRunIRPipeline)
      IRStagePA = IMPM.run(*IModule, IMAM);

    LLVM_DEBUG(llvm::dbgs() << "Instrumentation Module after IR pipeline:\n";
               IModule->print(llvm::dbgs(), nullptr));
  }

  /// MIR / codegen pipeline
  bool MIRModified = false;
  auto MIRLegacyPM = std::make_unique<llvm::legacy::PassManager>();
  auto *MMIWP = new llvm::MachineModuleInfoWrapperPass(ITM.get());
  llvm::MachineModuleInfo &MMI = MMIWP->getMMI();

  /// Parse the MIR file in case it was specified in the opts
  if (IModuleMIRParser &&
      IModuleMIRParser->parseMachineFunctions(*IModule, MMI)) {
    LUTHIER_CTX_EMIT_ON_ERROR(
        Context, LUTHIER_MAKE_GENERIC_ERROR(
                     "Failed to parse machine functions from imodule file '" +
                     Options.IModulePath + "'"));
    return IRStagePA.areAllPreserved() ? llvm::PreservedAnalyses::all()
                                       : llvm::PreservedAnalyses::none();
  }

  {
    llvm::TimeTraceScope Scope(
        "Instrumentation Module MIR CodeGen Optimization");

    auto *TPC = ITM->createPassConfig(*MIRLegacyPM);
    TPC->setDisableVerify(true);
    MIRLegacyPM->add(TPC);
    MIRLegacyPM->add(MMIWP);

    bool MIRPassPipelineNotSpecified =
        Options.IModuleMIRPasses.getNumOccurrences() == 0;
    bool MIRPassPipelineSpecifiedAndNotEmpty =
        !Options.IModuleMIRPasses.getValue().empty();
    bool MustRunCodeGen =
        MIRPassPipelineNotSpecified || MIRPassPipelineSpecifiedAndNotEmpty;

    if (MIRPassPipelineNotSpecified) {
      // TODO: codegen pipeline — uncomment when deps are available:
      // llvm::TargetLibraryInfoImpl TLII(...);
      // auto LegacyIPM = new llvm::legacy::PassManager();
      // auto *IMMIWP = new llvm::MachineModuleInfoWrapperPass(&TargetAppTM);
      // LegacyIPM->add(new IModuleMAMWrapperPass(&IMAM));
      // LegacyIPM->add(new llvm::TargetLibraryInfoWrapperPass(TLII));
      // auto *TPC = ITM->createPassConfig(*LegacyIPM);
      // TPC->setDisableVerify(true);
      // LegacyIPM->add(TPC);
      // LegacyIPM->add(IMMIWP);
      // TPC->addISelPasses();
      // LegacyIPM->add(new PhysicalRegAccessVirtualizationPass());
      // LegacyIPM->add(new IntrinsicMIRLoweringPass());
      // TPC->insertPass(&PrologEpilogCodeInserterID,
      //                 new InjectedPayloadPEIPass());
      // TPC->addMachinePasses();
      // LegacyIPM->add(new PrePostAmbleEmitter());
      // LegacyIPM->add(new PatchLiftedRepresentationPass());
      // llvm::PassRegistry *Registry =
      //     llvm::PassRegistry::getPassRegistry();
      // AugmentTargetPassConfigCallback(*Registry, *TPC, *ITM);
      // for (const auto &Plugin : PassPlugins)
      //   Plugin.invokeAugmentTargetPassConfigCallback(*Registry, *TPC, *ITM);
      // TPC->setInitialized();
      // LegacyIPM->run(*IModule);
      // delete LegacyIPM;
    } else if (MIRPassPipelineSpecifiedAndNotEmpty) {
      llvm::Error ModifiedOrErr = parseCodeGenPipeline(
          Options.IModuleMIRPasses.getValue(), *MIRLegacyPM);
      if (!ModifiedOrErr) {
        LUTHIER_CTX_EMIT_ON_ERROR(Context, std::move(ModifiedOrErr));
        return IRStagePA;
      }
    }
    if (MustRunCodeGen) {
      llvm::StringRef OutPath = Options.IModuleOutput;
      bool IsLuthierOutput = OutPath.ends_with(".luthier");
      bool MustDumpMIR = !OutPath.empty() && !IsLuthierOutput;

      std::unique_ptr<llvm::ToolOutputFile> OutFile;
      if (MustDumpMIR) {
        std::error_code EC;
        OutFile = std::make_unique<llvm::ToolOutputFile>(
            OutPath, EC, llvm::sys::fs::OF_Text);
        if (EC) {
          LUTHIER_CTX_EMIT_ON_ERROR(
              Context, LUTHIER_MAKE_GENERIC_ERROR(
                           "Failed to open imodule output file '" +
                           Options.IModuleOutput + "': " + EC.message()));
          return IRStagePA.areAllPreserved() ? llvm::PreservedAnalyses::all()
                                             : llvm::PreservedAnalyses::none();
        }
      }
      TPC->setInitialized();
      if (MustDumpMIR)
        MIRLegacyPM->add(llvm::createPrintMIRPass(OutFile->os()));
      MIRModified = MIRLegacyPM->run(*IModule);
      if (MustDumpMIR)
        OutFile->keep();

      if (IsLuthierOutput) {
        if (auto Err = writeLuthierFile(OutPath, TargetAppM, *IModule)) {
          LUTHIER_CTX_EMIT_ON_ERROR(Context, std::move(Err));
          return IRStagePA.areAllPreserved() ? llvm::PreservedAnalyses::all()
                                             : llvm::PreservedAnalyses::none();
        }
      }
    }
  }
  /// Conservatively invalidate all other target module passes even if only the
  /// imodule was modified
  bool Modified = IRStagePA.areAllPreserved() || MIRModified;
  return Modified ? llvm::PreservedAnalyses::none()
                  : llvm::PreservedAnalyses::all();
}
} // namespace luthier
