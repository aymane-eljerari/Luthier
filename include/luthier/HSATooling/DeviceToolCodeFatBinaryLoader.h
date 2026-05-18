//===-- DeviceToolCodeFatBinaryLoader.h --------------------------*- C++-*-===//
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
/// \file DeviceToolCodeFatBinaryLoader.h
/// Defines the \c DeviceToolCodeFatBinaryLoader and its associated trait.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
#define LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/Agent.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <cstddef>
#include <cstdint>
#include <hsa/hsa.h>
#include <hsa/hsa_ven_amd_loader.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBuffer.h>
#include <memory>
#include <mutex>
#include <string>

namespace luthier {

/// \brief Non-templated base of \c DeviceToolCodeFatBinaryLoaderTrait
/// containing the logic for load/unload and state management of the FAT
/// binaries as well as static symbol query methods originally provided by
/// the HIP runtime
class DeviceToolCodeFatBinaryLoader {
protected:
  /// \brief Per-fat-binary entry produced from a \c __hipRegisterFatBinary call
  /// \details \c Bundle points at the raw Clang offload bundle (the \c binary
  /// field of HIP's \c __CudaFatBinaryWrapper) instead of the FAT binary
  /// wrapper struct itself. \c Size is the byte extent of the bundle itself
  struct HipFatBinaryInfo {
    const void *Bundle{nullptr};
    size_t Size{0};
  };

  /// Per-function entry produced from a \c __hipRegisterFunction call
  struct HipFunctionInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  /// Per-device-variable entry produced from a \c __hipRegisterVar call
  struct HipDeviceVarInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  /// Per-managed-variable entry produced from a \c __hipRegisterManagedVar
  struct HipManagedVarInfo {
    /// The host shadow-pointer slot the runtime updates with the
    /// device-accessible allocation
    void **Pointer{nullptr};
    /// Initial value of the bytes to be copied into that allocation at load
    /// time
    void *InitValue{nullptr};
    const char *Name{nullptr};
    unsigned long long Size{0};
    unsigned Align{0};
  };

  /// Per-texture entry produced from a \c __hipRegisterTexture call
  struct HipTextureInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  /// Per-surface entry produced from a \c __hipRegisterSurface call
  struct HipSurfaceInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  /// Per-agent HSA handles created during the load of a single fat binary.
  struct AgentExecutable {
    hsa_code_object_reader_t Reader{};
    hsa_loaded_code_object_t LCO{};
    hsa_executable_t Executable{};
  };

  /// One loaded fat-binary record.
  struct FatBinRecord {
    const void *Wrapper{nullptr};
    llvm::DenseMap<hsa_agent_t, AgentExecutable> Loaded;
  };

  /// Managed-variable bookkeeping. Mirrors HIP's \c Var with \c DVK_Managed
  /// in the immediate-alloc path: a single device-accessible allocation
  /// owned by the loader, with the host shadow pointer pointing at it.
  /// Asserted \c Align <= pool granule (typically 4 KiB on AMDGPU);
  /// over-aligned managed vars are not modelled yet.
  struct ManagedVarRec {
    void **HostShadowPtr{nullptr};
    const void *InitValue{nullptr};
    size_t Size{0};
    unsigned Align{0};
    void *Allocation{nullptr};
  };

  std::recursive_mutex Mutex;

  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiSnapshot;
  const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExtSnapshot;
  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &LoaderApiSnapshot;

  /// FAT binary and variable handles
  llvm::ArrayRef<HipFatBinaryInfo> InputFatBinaries;
  llvm::ArrayRef<HipFunctionInfo> InputFunctions;
  llvm::ArrayRef<HipDeviceVarInfo> InputDeviceVars;
  llvm::ArrayRef<HipManagedVarInfo> InputManagedVars;
  llvm::ArrayRef<HipTextureInfo> InputTextures;
  llvm::ArrayRef<HipSurfaceInfo> InputSurfaces;

  enum class LoadState { Pending, Loaded, Failed };
  LoadState State{LoadState::Pending};
  std::string LoadErrorMsg;

  llvm::SmallVector<FatBinRecord, 1> FatBins;
  llvm::DenseMap<const void *, std::string> HandleToName;
  llvm::StringMap<llvm::DenseMap<hsa_agent_t, uint64_t>> NameToAgentAddr;
  /// Raw per-agent \c .llvmbc bytes copied out of the loaded ELFs. Parsed
  /// into the caller's context on demand by \c getEmbeddedModule, so we
  /// never spin up a long-lived dummy \c LLVMContext.
  llvm::DenseMap<hsa_agent_t, std::unique_ptr<llvm::MemoryBuffer>> AgentBitcode;
  llvm::DenseMap<const void *, ManagedVarRec> ManagedVarRecords;

  /// Full HSA-side load: parse the Clang offload bundles inside each
  /// fat-binary wrapper, load and freeze a per-agent executable for every
  /// compatible GPU, populate symbol lookup tables, extract embedded
  /// \c .llvmbc modules into the per-agent bitcode cache, and allocate
  /// managed-variable storage. On failure, the loader is left in a
  /// teardown-safe partially-loaded state.
  llvm::Error loadAll();

  /// Symmetric teardown: destroys executables and code-object readers, frees
  /// managed allocations, clears the bookkeeping maps. Swallows + logs HSA
  /// errors so it is safe to call from a destructor.
  void unloadAll() noexcept;

  /// Run \c loadAll on first call. Subsequent calls return success (or, if
  /// the first attempt failed, replay the cached error message). Caller
  /// MUST hold \c Mutex (the recursive mutex is re-acquired inside via the
  /// public methods' locks; calls from within those methods are safe).
  llvm::Error ensureLoaded();

public:
  /// Construct a loader bound to the six tables the IR plugin populated.
  /// The HSA-side load is NOT performed here — the rocprofiler API-table
  /// snapshots may not yet be initialized at construction time. Instead,
  /// the first call to any public query method triggers a one-shot load
  /// (see \c ensureLoaded). If that load fails, the cached error is
  /// re-reported on every subsequent query.
  DeviceToolCodeFatBinaryLoader(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      llvm::ArrayRef<HipFatBinaryInfo> FatBinaries,
      llvm::ArrayRef<HipFunctionInfo> Functions,
      llvm::ArrayRef<HipDeviceVarInfo> DeviceVars,
      llvm::ArrayRef<HipManagedVarInfo> ManagedVars,
      llvm::ArrayRef<HipTextureInfo> Textures,
      llvm::ArrayRef<HipSurfaceInfo> Surfaces);

  ~DeviceToolCodeFatBinaryLoader();

  DeviceToolCodeFatBinaryLoader(const DeviceToolCodeFatBinaryLoader &) = delete;
  DeviceToolCodeFatBinaryLoader &
  operator=(const DeviceToolCodeFatBinaryLoader &) = delete;

  /// Resolve a host shadow handle to its device-side symbol name. Triggers
  /// the one-shot HSA load on first call.
  llvm::Expected<llvm::StringRef> lookupNameByHandle(const void *Handle) {
    std::lock_guard Lock(Mutex);
    if (auto E = ensureLoaded())
      return std::move(E);
    auto It = HandleToName.find(Handle);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        It != HandleToName.end(),
        "No device-side symbol registered for the given host handle."));
    return llvm::StringRef{It->second};
  }

  /// Resolve a device-side symbol name to its loaded address on \p Agent.
  /// Triggers the one-shot HSA load on first call.
  llvm::Expected<uint64_t> lookupLoadedAddress(llvm::StringRef Name,
                                               hsa_agent_t Agent) {
    std::lock_guard Lock(Mutex);
    if (auto E = ensureLoaded())
      return std::move(E);
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

  /// Parse the per-agent embedded \c .llvmbc bytes into \p Ctx. The loader
  /// holds the raw bitcode buffer for the lifetime of the loader; this
  /// method is the only step that touches \c LLVMContext, so the buffer
  /// can be parsed into different contexts at different times. Triggers
  /// the one-shot HSA load on first call.
  llvm::Expected<std::unique_ptr<llvm::Module>>
  getEmbeddedModule(hsa_agent_t Agent, llvm::LLVMContext &Ctx);
};

/// \brief CRTP trait that supplies the per-\c Derived inline-static
/// annotated slots and forwards them into \c DeviceToolCodeFatBinaryLoader.
///
/// A tool MUST be instantiated from exactly one host translation unit (the
/// same requirement \c Singleton<Derived> implicitly places on it). Each TU
/// that ODR-uses the class emits a \c linkonce_odr definition of every
/// annotated slot (forced live by \c [[gnu::used]]), so multi-TU duplication
/// would feed the same \c GlobalVariable* into \c llvm.global.annotations
/// more than once. \c LoadHIPFATBinaryInfoPass de-dups defensively, but
/// multi-TU usage still violates the singleton contract.
template <typename Derived>
class DeviceToolCodeFatBinaryLoaderTrait
    : public DeviceToolCodeFatBinaryLoader {
public:
  //===-------------------------------------------------------------------===//
  // Annotated slots populated by LoadHIPFATBinaryInfoPass at IR-compile time.
  // The IR pass matches by annotation string, not by class name; each slot is
  // an inline-static class-template member so no per-tool definitions are
  // needed (replaces the old REGISTER_STRUCTS macro).
  //===-------------------------------------------------------------------===//
  inline static __attribute__((used))
  LUTHIER_ANNOTATE_VARIABLE(LUTHIER_HIP_FAT_BINARIES_ATTR)
      llvm::ArrayRef<HipFatBinaryInfo> HipFatBinaries{};

  inline static __attribute__((used))
  LUTHIER_ANNOTATE_VARIABLE(LUTHIER_HIP_FUNCTIONS_ATTR)
      llvm::ArrayRef<HipFunctionInfo> HipFunctions{};

  inline static __attribute__((used))
  LUTHIER_ANNOTATE_VARIABLE(LUTHIER_HIP_DEVICE_VARS_ATTR)
      llvm::ArrayRef<HipDeviceVarInfo> HipDeviceVars{};

  inline static __attribute__((used))
  LUTHIER_ANNOTATE_VARIABLE(LUTHIER_HIP_MANAGED_VARS_ATTR)
      llvm::ArrayRef<HipManagedVarInfo> HipManagedVars{};

  inline static __attribute__((used))
  LUTHIER_ANNOTATE_VARIABLE(LUTHIER_HIP_TEXTURE_VARS_ATTR)
      llvm::ArrayRef<HipTextureInfo> HipTextureVars{};

  inline static __attribute__((used))
  LUTHIER_ANNOTATE_VARIABLE(LUTHIER_HIP_SURFACE_VARS_ATTR)
      llvm::ArrayRef<HipSurfaceInfo> HipSurfaceVars{};

  DeviceToolCodeFatBinaryLoaderTrait(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader)
      : DeviceToolCodeFatBinaryLoader(
            CoreApi, AmdExt, Loader, HipFatBinaries, HipFunctions,
            HipDeviceVars, HipManagedVars, HipTextureVars, HipSurfaceVars) {}
};

} // namespace luthier

#endif // LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
