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
/// Drives the shared \c DeviceToolCodeLoaderBase with the annotated-slot
/// inputs the IR plugin populates at compile time, plus the managed-variable
/// path that's specific to HIP static registration.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
#define LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H

#include "luthier/HSATooling/DeviceToolCodeLoaderBase.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <cstddef>
#include <cstdint>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBuffer.h>
#include <memory>

namespace luthier {

/// \brief Non-templated base of \c DeviceToolCodeFatBinaryLoaderTrait. Owns
/// the HIP-static-specific bookkeeping (managed-vars, host-handle table)
/// and the deferred HSA-side load over all GPU agents.
class DeviceToolCodeFatBinaryLoader : public DeviceToolCodeLoaderBase {
protected:
  /// \brief Per-fat-binary entry produced from a \c __hipRegisterFatBinary
  /// call. \c Bundle points at the raw Clang offload bundle; \c Size is the
  /// bundle's byte extent.
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

  /// Per-managed-variable entry produced from a \c __hipRegisterManagedVar call
  struct HipManagedVarInfo {
    void **Pointer{nullptr};
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

  /// Managed-variable input table — kept because the per-allocation HSA
  /// work happens at load time. The other IR-pass-populated handle tables
  /// (functions, device vars, textures, surfaces) are consumed during
  /// construction to populate \c HandleToName and not stored.
  llvm::ArrayRef<HipManagedVarInfo> InputManagedVars;

  enum class LoadState { Pending, Loaded };
  LoadState State{LoadState::Pending};

  /// Host shadow handle → device-side symbol name, populated at
  /// construction from the IR-pass \c __hipRegister* tables. HSA-free,
  /// so \c lookupNameByHandle works immediately. Only meaningful for
  /// static HIP registration.
  llvm::DenseMap<const void *, std::string> HandleToName;
  llvm::DenseMap<const void *, ManagedVarRec> ManagedVarRecords;

  /// Drive \c base::loadOntoAgents over all GPU agents, then
  /// \c loadManagedVars. Caller's contract: HSA is ready.
  llvm::Error loadAll();

  /// Allocate backing memory for every \c InputManagedVars entry, initialize
  /// it from \c InitValue, grant the listed GPU agents access, and publish
  /// each allocation through the host shadow pointer. Modelled on HIP's
  /// \c __hipRegisterManagedVar + \c Var::allocateManagedVarPtr.
  llvm::Error loadManagedVars(llvm::ArrayRef<hsa_agent_t> Agents);

  /// Symmetric teardown: \c base::clearLoadedState + free managed-var
  /// allocations + clear HIP-static bookkeeping maps. Safe to call from
  /// a destructor.
  void unloadAll() noexcept;

  /// First call runs \c loadAll. On success, subsequent calls short-circuit.
  /// On failure, the caller receives the \c llvm::Error and subsequent calls
  /// retry, so transient failures can recover. Override of the base hook so
  /// the inherited lookups trigger the deferred load.
  llvm::Error ensureLoaded() override;

  /// Build a non-owning \c MemoryBuffer wrapper around the single fat-bin
  /// recorded in \p Slots. Sets \p Err if \p Slots has more than one entry
  /// (Luthier requires one fat binary per loader; multi-fat-bin tools must
  /// use multiple \c Derived instances). Returns \c nullptr if \p Slots is
  /// empty or its sole entry has no bundle.
  static std::unique_ptr<llvm::MemoryBuffer>
  buildBundleBuffer(llvm::ArrayRef<HipFatBinaryInfo> Slots, llvm::Error &Err);

public:
  DeviceToolCodeFatBinaryLoader(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      std::unique_ptr<llvm::MemoryBuffer> Bundle,
      llvm::ArrayRef<HipFunctionInfo> Functions,
      llvm::ArrayRef<HipDeviceVarInfo> DeviceVars,
      llvm::ArrayRef<HipManagedVarInfo> ManagedVars,
      llvm::ArrayRef<HipTextureInfo> Textures,
      llvm::ArrayRef<HipSurfaceInfo> Surfaces, llvm::Error &Err);

  ~DeviceToolCodeFatBinaryLoader();

  /// Resolve a HIP host shadow handle (the \c __hipRegister* host-side
  /// pointer) to its device-side symbol name. Populated at construction,
  /// so this does not trigger \c ensureLoaded — works before HSA is up.
  llvm::Expected<llvm::StringRef> lookupNameByHandle(const void *Handle) {
    std::lock_guard Lock(Mutex);
    auto It = HandleToName.find(Handle);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        It != HandleToName.end(),
        "No device-side symbol registered for the given host handle."));
    return llvm::StringRef{It->second};
  }
};

/// \brief CRTP trait that supplies the per-\c Derived inline-static annotated
/// slots and forwards them into \c DeviceToolCodeFatBinaryLoader.
///
/// A tool MUST be instantiated from exactly one host translation unit (the
/// same requirement \c Singleton<Derived> implicitly places on it). Each TU
/// that ODR-uses the class emits a \c linkonce_odr definition of every
/// annotated slot (forced live by \c [[gnu::used]]). Per the one-loader-one-
/// module rule, the \c HipFatBinaries slot must contain at most one entry;
/// the base constructor enforces this via \p Err.
template <typename Derived>
class DeviceToolCodeFatBinaryLoaderTrait
    : public DeviceToolCodeFatBinaryLoader {
public:
  //===-------------------------------------------------------------------===//
  // Annotated slots populated by LoadHIPFATBinaryInfoPass at IR-compile time.
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
          &Loader,
      llvm::Error &Err)
      : DeviceToolCodeFatBinaryLoader(
            CoreApi, AmdExt, Loader, buildBundleBuffer(HipFatBinaries, Err),
            HipFunctions, HipDeviceVars, HipManagedVars, HipTextureVars,
            HipSurfaceVars, Err) {}
};

} // namespace luthier

#endif // LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
