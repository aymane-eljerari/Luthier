//===-- InstrumentationPMDriver.h -------------------------------*- C++ -*-===//
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
/// \file InstrumentationPMDriver.h
/// Describes the \c InstrumentationPMDriver, a target module pass
/// in charge of driving the high-level instrumentation process in Luthier.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_APPLY_INSTRUMENTATION_PASS_H
#define LUTHIER_TOOL_CODE_GEN_APPLY_INSTRUMENTATION_PASS_H
#include "luthier/Intrinsic/IntrinsicProcessor.h"
#include "luthier/PassPlugin/LuthierPassPlugin.h"
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/Target/TargetMachine.h>

namespace llvm {

class PassRegistry;
}

namespace luthier {

class IntrinsicProcessorRegistry;


struct InstrumentationPMDriverOptions {
  llvm::cl::OptionCategory InstrumentationPMDriverOptionsCat{
      "Instrumentation PM Driver Options",
      "Options regarding the Instrumentation PM driver"};

  llvm::cl::opt<bool> ForceFlatScratchInstructions{
      "force-scratch-insts", llvm::cl::init(true),
      llvm::cl::desc(
          "For targets that support it , forces use of scratch instructions "
          "instead of buffer instructions to access scratch memory."),
      llvm::cl::NotHidden, llvm::cl::cat(InstrumentationPMDriverOptionsCat)};

  llvm::cl::opt<bool> EnableSIDebugLogging{
      "instrumentation-si-logging", llvm::cl::init(false),
      "Enable/Disable debug logging of standard instrumentation in the "
      "instrumentation PM Driver."};

  llvm::cl::opt<std::string> IModulePath{
      "imodule-path", llvm::cl::init(""),
      llvm::cl::desc("Path to the instrumentation module .mir/.ll/.bc file to "
                     "load the instrumentation module's initial state from"),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat)};

  llvm::cl::opt<std::string> IModuleIRPasses{
      "imodule-ir-passes", llvm::cl::init(""),
      llvm::cl::desc(
          "If specified, provides a IR-level textual pass pipeline for the "
          "instrumentation module which overrides the normal instrumentation "
          "process"),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat)};

  llvm::cl::opt<std::string> IModuleMIRPasses{
      "imodule-mir-passes", llvm::cl::init(""),
      llvm::cl::desc(
          "If specified, provides a textual legacy pass pipeline for the "
          "instrumentation module's codegen pipeline; Overrides the default"
          "instrumentation codegen pipeline"),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat)};

  llvm::cl::opt<std::string> IModuleOutput{
      "imodule-output", llvm::cl::init(""),
      llvm::cl::desc("Dump the final instrumentation module state to this "
                     "file after all pipeline stages complete"),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat)};

  /// Dump the target (application) module's MIR after the IModule codegen
  /// pipeline completes. The target module is what \c TargetModulePatcherPass
  /// mutates (non-payload MF clones, stripped num-{vgpr,sgpr} attrs, inlined
  /// payload MIs); \c --imodule-output only shows the IModule side and
  /// won't reflect those changes. Use this flag to FileCheck post-patch
  /// target state. Output is plain MachineFunction print (not YAML
  /// MIRPrinter) to dodge the post-frame-elim stale-stack-object crash
  /// the YAML printer trips on.
  llvm::cl::opt<std::string> TargetModuleOutput{
      "target-module-output", llvm::cl::init(""),
      llvm::cl::desc("Dump the target module's MachineFunctions to this "
                     "file after the IModule codegen pipeline completes "
                     "(captures TargetModulePatcherPass's effects)."),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat)};

  llvm::cl::opt<unsigned> IModuleOptLevel{
      "imodule-O",
      llvm::cl::desc(
          "Optimization level for the instrumentation module IR pipeline "
          "(0=none, 1=less, 2=default, 3=aggressive); defaults to the "
          "global -O level if not specified"),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat), llvm::cl::init(3)};

  /// Skip inserting Luthier's InjectedPayloadPEIPass. Useful when running a
  /// truncated codegen pipeline for testing, or when a downstream consumer
  /// wants to provide its own custom payload PEI variant.
  llvm::cl::opt<bool> DisableInjectedPayloadPEI{
      "disable-injected-payload-pei", llvm::cl::init(false),
      llvm::cl::desc(
          "When set, the default codegen pipeline does NOT insert Luthier's "
          "InjectedPayloadPEIPass after PrologEpilogCodeInserterID. The stock "
          "LLVM PEI still runs (and no-ops for Naked payload functions)."),
      llvm::cl::cat(InstrumentationPMDriverOptionsCat)};
};

class InstrumentationPMDriver
    : public llvm::PassInfoMixin<InstrumentationPMDriver> {

  const InstrumentationPMDriverOptions &Options;

  /// Registry holding the IR/MIR processors for Luthier intrinsics. Owned by
  /// the enclosing tool (e.g. \c HSATool) or by the opt plugin's static
  /// storage; the driver only borrows it.
  IntrinsicProcessorRegistry &Registry;

  /// Luthier pass plugins registered with the outer driver
  llvm::ArrayRef<PassPlugin> PassPlugins{};

  using IModuleCreationFnType =
      std::function<std::unique_ptr<llvm::Module>(llvm::LLVMContext &)>;

  /// Function used to materialize the instrumentation module
  IModuleCreationFnType IModuleCreatorFn;

  /// Function used to augment the pass builder
  /// Can be used to add additional analysis and add passes to the IR
  /// optimization stage
  std::function<void(llvm::PassBuilder &)> PassBuilderAugmentationCallback{};

  /// Callbacks invoked before adding any other passes to the IR pass manager
  std::function<void(llvm::ModulePassManager &)> PreIROptimizationCallback{};

  /// Callback invoked before performing the Luthier Intrinsic IR Lowering
  std::function<void(llvm::ModulePassManager &)>
      PreIRIntrinsicLoweringCallback{};

  /// Callback invoked after performing the Luthier Intrinsic IR Lowering
  std::function<void(llvm::ModulePassManager &)>
      PostIRIntrinsicLoweringCallback{};

  /// Callback to augment the instrumentation code generation legacy pipeline
  std::function<void(llvm::PassRegistry &, llvm::TargetPassConfig &,
                     llvm::TargetMachine &)>
      AugmentTargetPassConfigCallback;

public:
  explicit InstrumentationPMDriver(
      const InstrumentationPMDriverOptions &Options,
      IntrinsicProcessorRegistry &Registry,
      llvm::ArrayRef<PassPlugin> PassPlugins = {},
      IModuleCreationFnType ModuleCreatorFn =
          [](llvm::LLVMContext &Ctx) {
            return std::make_unique<llvm::Module>("Instrumentation Module",
                                                  Ctx);
          },
      std::function<void(llvm::PassBuilder &)> PassBuilderAugmentationCallback =
          [](llvm::PassBuilder &) {},
      std::function<void(llvm::ModulePassManager &)> PreIROptimizationCallback =
          [](llvm::ModulePassManager &) {},
      std::function<void(llvm::ModulePassManager &)>
          PreIRIntrinsicLoweringCallback = [](llvm::ModulePassManager &) {},
      std::function<void(llvm::ModulePassManager &)>
          PostIRIntrinsicLoweringCallback = [](llvm::ModulePassManager &) {},
      std::function<void(llvm::PassRegistry &, llvm::TargetPassConfig &,
                         llvm::TargetMachine &)>
          AugmentTargetPassConfigCallback = [](llvm::PassRegistry &,
                                               llvm::TargetPassConfig &,
                                               llvm::TargetMachine &) {});

  llvm::PreservedAnalyses run(llvm::Module &TargetAppM,
                              llvm::ModuleAnalysisManager &TargetMAM);
};
} // namespace luthier

#endif