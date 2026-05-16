//===-- ToolExecutableLoaderTrait.h ------------------------------*- C++ -*-===//
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
/// Header-only CRTP trait that maintains the tool's bookkeeping for its
/// own fat-binary contents and the agent-side bitcode/symbols extracted from
/// it. Does NOT intercept HSA or HIP APIs (the tool feeds it the fatbin +
/// handle data directly through \c LuthierHSATool's registration slots).
///
/// The trait owns:
/// \li \c HandleToName — host shadow pointer to device-side symbol name.
/// \li \c NameToAgentAddr — device-side name to per-agent loaded address.
/// \li \c AgentBitcode — per-agent parsed bitcode cached as a
///     \c llvm::orc::ThreadSafeModule; \c loadInstrumentationBitcode clones
///     out a fresh module into the caller's \c LLVMContext.
/// \li \c ManagedVars — host shadow pointer to managed-var record, modeled
///     after HIP's \c Var::DVK_Managed path (immediate-alloc only; deferred
///     loading is not modeled).
///
/// Skeleton bodies are stubs that compile but do not yet execute the
/// HSA-level allocation / symbol-resolution work. Real wiring lands on a
/// physical GPU environment.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_TOOL_EXECUTABLE_LOADER_TRAIT_H
#define LUTHIER_TOOLING_TOOL_EXECUTABLE_LOADER_TRAIT_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/Agent.h"
#include "luthier/HSATooling/LuthierHSATool.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include <hsa/hsa.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/ExecutionEngine/Orc/ThreadSafeModule.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Error.h>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

namespace luthier {

/// \brief CRTP trait owning the tool's fat-binary metadata and per-agent
/// bitcode/symbol bookkeeping. Used by \c InjectedPayloadCreationPassTrait
/// and by the \c instrumentAndLoad path on \c HSATool.
template <typename Derived> class ToolExecutableLoaderTrait {
public:
  /// Tracks one managed variable. Mirrors HIP's \c hip::Var with
  /// \c DVK_Managed, restricted to the immediate-alloc path.
  struct ManagedVarRec {
    /// Host shadow pointer slot; the host compiler emits a pointer-typed
    /// global whose value we set to the device-accessible allocation.
    void **HostShadowPtr{nullptr};
    /// Pointer to the initializer copied into the allocation at registration.
    const void *InitValue{nullptr};
    /// Allocation size in bytes.
    size_t Size{0};
    /// Requested alignment in bytes. Asserted \c <= pool granule (typically
    /// 4 KiB on AMDGPU); over-aligned managed vars are not modeled yet.
    unsigned Align{0};
    /// Per-agent device-accessible allocation. Returned to the runtime so
    /// kernels referencing the underlying device symbol see the same buffer.
    llvm::DenseMap<hsa_agent_t, void *> AgentAlloc;
  };

private:
  mutable std::recursive_mutex Mutex;

  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiSnapshot;
  const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExtSnapshot;
  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &LoaderApiSnapshot;

  /// host shadow pointer (function or variable) -> device-side symbol name.
  llvm::DenseMap<const void *, std::string> HandleToName;

  /// device-side name -> per-agent loaded address (lazily populated as
  /// kernels are launched and the cache resolves the symbol on each agent).
  llvm::StringMap<llvm::DenseMap<hsa_agent_t, uint64_t>> NameToAgentAddr;

  /// per-agent bitcode slice parsed from the fat-binary. Cached as a
  /// \c ThreadSafeModule so \c loadInstrumentationBitcode can clone it into
  /// any \c LLVMContext on demand.
  llvm::DenseMap<hsa_agent_t, llvm::orc::ThreadSafeModule> AgentBitcode;

  /// Managed-variable records keyed by host shadow pointer.
  llvm::DenseMap<const void *, ManagedVarRec> ManagedVars;

public:
  ToolExecutableLoaderTrait(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader)
      : CoreApiSnapshot(CoreApi), AmdExtSnapshot(AmdExt),
        LoaderApiSnapshot(Loader) {}

  /// Wrappers are NOT installed by this trait; nothing to uninstall.
  ~ToolExecutableLoaderTrait() = default;

  ToolExecutableLoaderTrait(const ToolExecutableLoaderTrait &) = delete;
  ToolExecutableLoaderTrait &
  operator=(const ToolExecutableLoaderTrait &) = delete;

  /// Ingest the tool's fat-binary metadata. Called once from the \c HSATool
  /// constructor after the \c LoadHIPFATBinaryInfo plugin has populated the
  /// per-tool globals on \c LuthierHSATool.
  ///
  /// Steps the real implementation will perform (on a physical GPU):
  ///   1. Slice the fat binary by agent and parse each slice into a
  ///      \c ThreadSafeModule, cached in \c AgentBitcode.
  ///   2. Populate \c HandleToName from the function and variable tables.
  ///   3. For each managed-var entry, allocate device-accessible memory of
  ///      \c Size from the agent's fine-grain pool (asserting
  ///      \c Align <= pool granule), \c memcpy the \c InitValue, and write
  ///      the agent allocation back through \c HostShadowPtr.
  ///
  /// The current body is a no-op stub that records the input table sizes.
  llvm::Error initFromHandles(llvm::ArrayRef<void *> FatBinaries,
                              llvm::ArrayRef<HipFunctionInfo> Functions,
                              llvm::ArrayRef<HipDeviceVarInfo> DeviceVars,
                              llvm::ArrayRef<HipManagedVarInfo> ManagedVarsIn,
                              llvm::ArrayRef<HipTextureInfo> TextureVars,
                              llvm::ArrayRef<HipSurfaceInfo> SurfaceVars) {
    std::lock_guard Lock(Mutex);
    (void)FatBinaries;
    (void)Functions;
    (void)DeviceVars;
    (void)ManagedVarsIn;
    (void)TextureVars;
    (void)SurfaceVars;
    /// TODO: real ingestion on a physical GPU.
    return llvm::Error::success();
  }

  /// Resolve a host shadow handle (function pointer or variable shadow) to
  /// the device-side symbol name embedded in the tool's bitcode.
  llvm::Expected<llvm::StringRef>
  lookupNameByHandle(const void *Handle) const {
    std::lock_guard Lock(Mutex);
    auto It = HandleToName.find(Handle);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        It != HandleToName.end(),
        "No device-side symbol registered for the given host handle."));
    return llvm::StringRef{It->second};
  }

  /// Resolve a device-side symbol name to its loaded address on the given
  /// agent. Returns an error if the symbol has not yet been resolved for
  /// that agent.
  llvm::Expected<uint64_t>
  lookupLoadedAddress(llvm::StringRef Name, hsa_agent_t Agent) const {
    std::lock_guard Lock(Mutex);
    auto It = NameToAgentAddr.find(Name);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        It != NameToAgentAddr.end(),
        "Symbol has no per-agent loaded-address record."));
    auto AgentIt = It->second.find(Agent);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        AgentIt != It->second.end(),
        "Symbol is not loaded on the requested agent."));
    return AgentIt->second;
  }

  /// Clone the cached per-agent bitcode into a fresh \c llvm::Module living
  /// in the caller's \c LLVMContext. Used by the
  /// \c InjectedPayloadCreationPassTrait to seed an IModule per
  /// instrumentation request.
  ///
  /// Real implementation will serialize the cached \c ThreadSafeModule's
  /// module out to a bitcode buffer and parse it back into \p Ctx —
  /// \c llvm::CloneModule cannot move IR between contexts.
  llvm::Expected<std::unique_ptr<llvm::Module>>
  loadInstrumentationBitcode(hsa_agent_t Agent, llvm::LLVMContext &Ctx) {
    std::lock_guard Lock(Mutex);
    (void)Agent;
    (void)Ctx;
    /// TODO: bitcode round-trip through \p Ctx; needs the per-agent
    /// bitcode populated by \c initFromHandles first.
    return llvm::make_error<GenericLuthierError>(
        "loadInstrumentationBitcode is not yet implemented");
  }

  /// Link an instrumented relocatable produced by
  /// \c HSATool::buildPipeline into an HSA executable and load it onto the
  /// agent. Stub for now.
  llvm::Error loadInstrumented(hsa_agent_t Agent,
                               llvm::ArrayRef<uint8_t> Relocatable,
                               llvm::StringRef Preset) {
    (void)Agent;
    (void)Relocatable;
    (void)Preset;
    /// TODO: HSA link + load on a physical GPU.
    return llvm::Error::success();
  }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_TOOL_EXECUTABLE_LOADER_TRAIT_H
