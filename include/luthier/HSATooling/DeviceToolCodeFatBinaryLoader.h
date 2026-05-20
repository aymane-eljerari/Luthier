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
/// Single templated class that drives the shared
/// \c DeviceToolCodeLoaderBase with the annotated-slot inputs the IR
/// plugin populates per-\c Derived, plus the HIP-static-specific
/// host-shadow-pointer managed-variable path.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
#define LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H

#include "luthier/HSA/Agent.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/HSA/MemoryPool.h"
#include "luthier/HSATooling/DeviceToolCodeLoaderBase.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <hsa/hsa_ext_amd.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/MemoryBuffer.h>
#include <memory>
#include <mutex>
#include <string>
#include <utility>

namespace luthier {

/// The IR pass writes a \c { ptr, i64 } struct constant into each placeholder
/// slot, matching \c llvm::ArrayRef<T>'s ABI. If LLVM ever rearranges
/// \c ArrayRef's members, these asserts trip at compile time and the pass
/// needs to be updated in lockstep.
static_assert(sizeof(llvm::ArrayRef<void *>) ==
                  sizeof(void *) + sizeof(uint64_t),
              "llvm::ArrayRef ABI changed: expected { ptr, i64 } layout "
              "matching the IR pass's ConstantStruct initializer.");
static_assert(alignof(llvm::ArrayRef<void *>) == alignof(void *),
              "llvm::ArrayRef alignment changed.");
static_assert(sizeof(decltype(std::declval<llvm::ArrayRef<void *>>().size())) ==
                  sizeof(uint64_t),
              "llvm::ArrayRef length is no longer 64-bit.");

/// \brief Templated fat-binary loader. The \c Derived template parameter
/// gives each tool its own set of \c inline static annotated slots that
/// \c LoadHIPFATBinaryInfoPass populates at IR-compile time. The class
/// inherits the bulk of the loading machinery from
/// \c DeviceToolCodeLoaderBase and adds the HIP-static path
/// (\c __hipRegisterManagedVar host-shadow publish + handle name table).
///
/// A tool MUST be instantiated from exactly one host translation unit (the
/// same requirement \c Singleton<Derived> implicitly places on it). Each TU
/// that ODR-uses the class emits a \c linkonce_odr definition of every
/// annotated slot (forced live by \c [[gnu::used]]).
///
/// Note on struct layouts: the nested \c Hip*Info types below are
/// per-instantiation types (their mangled names include \c Derived).
/// \c LoadHIPFATBinaryInfoPass identifies the layout by the unparameterized
/// name \c struct.luthier::DeviceToolCodeFatBinaryLoader::Hip*Info — the
/// pass creates that named struct on first use; with opaque pointers the
/// data array initializer and the runtime's struct reads remain
/// byte-compatible regardless of which named type any IR site references.
template <typename Derived>
class DeviceToolCodeFatBinaryLoader : public DeviceToolCodeLoaderBase {
public:
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

  DeviceToolCodeFatBinaryLoader(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      llvm::Error &Err)
      : DeviceToolCodeLoaderBase(CoreApi, AmdExt, Loader,
                                 buildBundleBuffer(HipFatBinaries, Err), Err),
        InputManagedVars(HipManagedVars) {
    llvm::ErrorAsOutParameter EAO(&Err);
    if (Err)
      return;
    // Populate host-handle → device-name from every IR-pass-populated
    // table. HSA-free; lets lookupNameByHandle work before any deferred
    // load runs.
    auto Record = [&](const void *Handle, const char *Name) {
      if (Handle != nullptr && Name != nullptr)
        HandleToName[Handle] = std::string(Name);
    };
    for (const auto &E : HipFunctions)
      Record(E.HostHandle, E.DeviceName);
    for (const auto &E : HipDeviceVars)
      Record(E.HostHandle, E.DeviceName);
    for (const auto &E : HipTextureVars)
      Record(E.HostHandle, E.DeviceName);
    for (const auto &E : HipSurfaceVars)
      Record(E.HostHandle, E.DeviceName);
    for (const auto &MV : HipManagedVars)
      Record(MV.Pointer, MV.Name);
  }

  ~DeviceToolCodeFatBinaryLoader() {
    // Free subclass-owned static-path managed-var allocations before the
    // base destructor tears down its own state. The base only cleans
    // base-owned resources (its dynamic-path allocations get freed via
    // the base's clearLoadedState).
    std::lock_guard Lock(Mutex);
    DeviceToolCodeLoaderBase::~DeviceToolCodeLoaderBase();
    if (State == LoadState::Loaded)
      freeStaticManagedVars();
  }

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

  /// Override: run the base's deferred load first (slices + dynamic
  /// managed vars), then do the static-path managed-var allocation.
  /// On local failure, free the static-path partial state and roll back
  /// the base's state too via \c clearLoadedState.
  llvm::Error ensureLoaded() override {
    std::lock_guard Lock(Mutex);
    LUTHIER_RETURN_ON_ERROR(DeviceToolCodeLoaderBase::ensureLoaded());

    llvm::SmallVector<hsa_agent_t, 4> Agents;
    auto Core = CoreApiSnapshot.getTable();
    LUTHIER_RETURN_ON_ERROR(
        hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_GPU>(Core, Agents));

    if (auto E = loadStaticManagedVars(Agents)) {
      freeStaticManagedVars();
      clearLoadedState(); // resets base state + State back to Pending.
      return E;
    }
    return llvm::Error::success();
  }

protected:
  /// Per-allocation bookkeeping for the static path. Distinct from the
  /// base's \c ManagedVarRecords (which tracks the dynamic-path
  /// allocations).
  struct StaticManagedVarRec {
    void **HostShadowPtr{nullptr};
    const void *InitValue{nullptr};
    size_t Size{0};
    unsigned Align{0};
    void *Allocation{nullptr};
  };

  llvm::ArrayRef<HipManagedVarInfo> InputManagedVars;
  llvm::DenseMap<const void *, std::string> HandleToName;
  llvm::DenseMap<const void *, StaticManagedVarRec> StaticManagedVarRecords;

  /// Build a non-owning \c MemoryBuffer wrapper around the single fat-bin
  /// recorded in \p Slots. Sets \p Err if \p Slots has more than one entry
  /// (Luthier requires one fat binary per loader; multi-fat-bin tools must
  /// use multiple \c Derived instances). Returns \c nullptr if \p Slots is
  /// empty or its sole entry has no bundle.
  static std::unique_ptr<llvm::MemoryBuffer>
  buildBundleBuffer(llvm::ArrayRef<HipFatBinaryInfo> Slots, llvm::Error &Err) {
    llvm::ErrorAsOutParameter EAO(&Err);
    if (Err)
      return nullptr;
    if (Slots.size() > 1) {
      Err = LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
          "Luthier requires at most one fat binary per loader; received {0}. "
          "Use multiple Derived instances for multi-fat-binary tools.",
          Slots.size()));
      return nullptr;
    }
    if (Slots.empty() || Slots.front().Bundle == nullptr)
      return nullptr;
    const auto &S = Slots.front();
    return llvm::MemoryBuffer::getMemBuffer(
        llvm::StringRef(static_cast<const char *>(S.Bundle), S.Size), "fatbin",
        /*RequiresNullTerminator=*/false);
  }

  /// Static-path managed-var load: for each \c InputManagedVars entry,
  /// allocate managed memory from a host fine-grain pool, copy in the
  /// initial bytes from \c InitValue, grant agents access, and publish
  /// the allocation pointer through the entry's host shadow slot
  /// (\c *MV.Pointer).
  llvm::Error loadStaticManagedVars(llvm::ArrayRef<hsa_agent_t> Agents) {
    if (InputManagedVars.empty())
      return llvm::Error::success();

    const auto Core = CoreApiSnapshot.getTable();
    const auto AmdExt = AmdExtSnapshot.getTable();

    llvm::SmallVector<hsa_agent_t, 1> CpuAgents;
    LUTHIER_RETURN_ON_ERROR(
        hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_CPU>(Core, CpuAgents));
    if (CpuAgents.empty())
      return LUTHIER_MAKE_HSA_ERROR(
          "No CPU agent available for managed-var allocation.");

    auto PoolOrErr = selectManagedVarPool(AmdExt, CpuAgents.front());
    if (!PoolOrErr)
      return PoolOrErr.takeError();
    llvm::Expected<size_t> GranuleOrErr =
        hsa::memoryPoolGetRuntimeAllocGranule(AmdExt, *PoolOrErr);
    if (!GranuleOrErr)
      return GranuleOrErr.takeError();

    for (const auto &MV : InputManagedVars) {
      if (MV.Pointer == nullptr)
        continue;
      if (MV.Align > *GranuleOrErr)
        return LUTHIER_MAKE_HSA_ERROR(llvm::formatv(
            "Managed variable {0} alignment ({1}) exceeds pool granule "
            "({2}); over-aligned managed vars are not modelled.",
            MV.Name ? MV.Name : "<unnamed>", MV.Align, *GranuleOrErr));

      llvm::Expected<void *> AllocOrErr =
          hsa::memoryPoolAllocate(AmdExt, *PoolOrErr, MV.Size, /*Flags=*/0);
      if (!AllocOrErr)
        return AllocOrErr.takeError();
      void *Alloc = *AllocOrErr;

      if (MV.InitValue != nullptr && MV.Size > 0)
        std::memcpy(Alloc, MV.InitValue, MV.Size);

      if (!Agents.empty()) {
        if (auto E = hsa::agentsAllowAccess(AmdExt, Agents, Alloc))
          return llvm::joinErrors(std::move(E),
                                  hsa::memoryPoolFree(AmdExt, Alloc));
      }

      *MV.Pointer = Alloc;

      StaticManagedVarRec Rec;
      Rec.HostShadowPtr = MV.Pointer;
      Rec.InitValue = MV.InitValue;
      Rec.Size = MV.Size;
      Rec.Align = MV.Align;
      Rec.Allocation = Alloc;
      StaticManagedVarRecords[MV.Pointer] = Rec;
    }
    return llvm::Error::success();
  }

  /// Free every static-path allocation, null out the host shadow slots,
  /// and clear \c StaticManagedVarRecords. Idempotent.
  void freeStaticManagedVars() noexcept {
    auto AmdExt = AmdExtSnapshot.getTable();
    for (auto &KV : StaticManagedVarRecords) {
      if (KV.second.Allocation == nullptr)
        continue;
      if (KV.second.HostShadowPtr != nullptr)
        *KV.second.HostShadowPtr = nullptr;
      if (auto E = hsa::memoryPoolFree(AmdExt, KV.second.Allocation)) {
        DEBUG_WITH_TYPE("luthier-device-tool-code-fat-binary-loader",
                        llvm::dbgs() << "[luthier] managed-var free failed for "
                                     << KV.second.Allocation << ": "
                                     << llvm::toString(std::move(E)) << "\n");
      } else {
        consumeError(std::move(E));
      }
    }
    StaticManagedVarRecords.clear();
  }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
