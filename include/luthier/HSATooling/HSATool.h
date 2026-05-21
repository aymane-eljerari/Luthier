//===-- HSATool.h - Luthier HSA Tool Trait ----------------------*- C++ -*-===//
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
/// \file HSATool.h
/// CRTP base class for static Luthier HSA tools. Composes the per-tool traits
/// and exposes frequently used methods in tools written in HIP.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_HSA_TOOL_H
#define LUTHIER_TOOLING_HSA_TOOL_H

#include "luthier/Common/Singleton.h"
#include "luthier/HSATooling/DeviceToolCodeFatBinaryLoader.h"
#include "luthier/HSATooling/InstrumentedKernelLoaderAndLauncher.h"
#include "luthier/HSATooling/LLVMUserTrait.h"
#include "luthier/HSATooling/LoadedCodeObjectCache.h"
#include "luthier/HSATooling/PacketMonitorTrait.h"
#include "luthier/PassPlugin/LuthierPassPlugin.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include "luthier/ToolCodeGen/InjectedPayloadCreationPass.h"
#include "luthier/ToolCodeGen/InstrumentationPMDriver.h"
#include "luthier/ToolCodeGen/IntrinsicProcessorRegistry.h"
#include <llvm/ADT/ArrayRef.h>
#include <llvm/IR/PassManager.h>
#include <llvm/Support/Error.h>

namespace luthier {

/// Per-tool trait that owns the \c IntrinsicProcessorRegistry the tool's
/// instrumentation pipeline consults during IR/MIR intrinsic lowering. The
/// registry default-constructs (its ctor auto-registers the built-in Luthier
/// intrinsics from \c IntrinsicRegistry.def), so the trait needs no
/// constructor arguments and never fails.
template <typename Derived> class IntrinsicProcessorRegistryTraitBase {
  IntrinsicProcessorRegistry Registry;

public:
  IntrinsicProcessorRegistry &getIntrinsicProcessorRegistry() {
    return Registry;
  }

  const IntrinsicProcessorRegistry &getIntrinsicProcessorRegistry() const {
    return Registry;
  }
};

/// \brief CRTP base for static HSA tools. Inherits the HIP fat-binary
/// registration slots and per-agent HSA executable state from
/// \c DeviceToolCodeFatBinaryLoader, and the per-process singleton identity
/// from \c Singleton<Derived>; composes the per-subsystem traits.
///
/// \c Singleton<Derived> is listed first so its constructor runs before any
/// trait's constructor. The traits' destructors run in reverse-inheritance
/// order, i.e. before \c Singleton<Derived>'s destructor clears
/// \c Singleton<Derived>::Instance. This invariant matters once the traits
/// install HSA API-table interceptors that look the tool up via
/// \c Singleton<Derived>::instance().
///
/// Installed HSA API-table wrappers are NOT uninstalled at tool teardown.
/// Trait wrappers are expected to consult \c Singleton<Derived>::isInitialized
/// before doing any tool-specific work; uninstalling a wrapper while the
/// HSA runtime may still call it would be racy and unsafe.
template <typename Derived, typename TargetUnitT = llvm::MachineFunction>
class HSATool : public Singleton<Derived>,
                public LLVMUserTrait<Derived>,
                public LoadedCodeObjectCacheTrait<Derived>,
                public DeviceToolCodeFatBinaryLoader<Derived>,
                public InstrumentedKernelLoaderAndLauncherTrait<Derived>,
                public InjectedPayloadCreationPass<Derived, TargetUnitT>,
                public IntrinsicProcessorRegistryTraitBase<Derived>,
                public PacketMonitorTrait<Derived> {
public:
  HSATool(const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
          const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
          const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
              &VenLoader,
          llvm::Error &Err)
      : Singleton<Derived>(), LLVMUserTrait<Derived>(),
        LoadedCodeObjectCacheTrait<Derived>(CoreApi, VenLoader, Err),
        DeviceToolCodeFatBinaryLoader<Derived>(CoreApi, AmdExt, VenLoader, Err),
        InstrumentedKernelLoaderAndLauncherTrait<Derived>(
            CoreApi, VenLoader, static_cast<DeviceToolCodeLoader &>(*this),
            Err),
        PacketMonitorTrait<Derived>(CoreApi, AmdExt, VenLoader, Err) {}

  /// Build the instrumentation pass pipeline driver for a target application
  /// module. The returned \c InstrumentationPMDriver is a
  /// \c PassInfoMixin-shaped pass to be added to a target module pass manager
  /// by the caller (\c MPM.addPass(tool.buildPipeline(opts, plugins))). The
  /// driver internally materializes an IModule, runs the IR-level
  /// instrumentation stages, lowers Luthier intrinsics, and drives the
  /// per-IModule MIR codegen pipeline.
  InstrumentationPMDriver
  buildPipeline(const InstrumentationPMDriverOptions &Opts,
                llvm::ArrayRef<PassPlugin> Plugins = {}) {
    return InstrumentationPMDriver(Opts, this->getIntrinsicProcessorRegistry(),
                                   Plugins);
  }

  /// Convenience: build the pipeline and immediately run it against \p
  /// TargetAppM. Equivalent to constructing a one-pass MPM that contains
  /// \c buildPipeline() and invoking it. Returned \c PreservedAnalyses
  /// reflects what the driver preserved on the target module's analyses.
  llvm::PreservedAnalyses
  runInstrumentationPipeline(llvm::Module &TargetAppM,
                             llvm::ModuleAnalysisManager &TargetMAM,
                             const InstrumentationPMDriverOptions &Opts,
                             llvm::ArrayRef<PassPlugin> Plugins = {}) {
    return buildPipeline(Opts, Plugins).run(TargetAppM, TargetMAM);
  }

  /// Resolve a payload function's host shadow handle to the corresponding
  /// \c llvm::Function inside the given instrumentation module. Convenience
  /// over a two-step \c Derived::lookupNameByHandle / \c Module::getFunction.
  llvm::Expected<llvm::Function *>
  resolvePayloadHandle(const void *HostHandle,
                       llvm::Module &InstrumentationModule) {
    auto &Self = static_cast<Derived &>(*this);
    auto NameOrErr = Self.lookupNameByHandle(HostHandle);
    LUTHIER_RETURN_ON_ERROR(NameOrErr.takeError());
    llvm::Function *F = InstrumentationModule.getFunction(*NameOrErr);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        F != nullptr,
        "Payload function not present in the instrumentation module."));
    return F;
  }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_HSA_TOOL_H
