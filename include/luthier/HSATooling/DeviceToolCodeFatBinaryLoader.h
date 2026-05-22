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
/// \c DeviceToolCodeLoader with the annotated-slot inputs the IR
/// plugin populates per-\c Derived, plus the HIP-static-specific
/// host-shadow-pointer managed-variable path.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
#define LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H

#include "luthier/HSATooling/DeviceToolCodeLoader.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <cstddef>
#include <cstdint>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
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
/// \c DeviceToolCodeLoader; on top of it, it adds the
/// \c __hipRegisterManagedVar handle-name table (HSA-free, populated at
/// construction) and the host-shadow publish step (run after the base
/// finishes its dynamic-managed-var allocation).
///
/// Managed-variable storage itself is owned end-to-end by the base class:
/// each \c .managed-suffixed ELF symbol becomes a single managed
/// allocation (HMM path on HMM-supported systems, CPU fine-grain pool
/// otherwise). The fat-binary loader's only managed-var responsibility is
/// to walk the IR-pass-populated \c HipManagedVars table and write the
/// allocation pointer into each entry's \c void** host shadow, so host-side
/// reads of the managed variable resolve to the same storage the device
/// kernels see.
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
class DeviceToolCodeFatBinaryLoader : public DeviceToolCodeLoader {
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
      : DeviceToolCodeLoader(CoreApi, AmdExt, Loader,
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
    // Null out the host shadows so callers that hold on to the
    // \c HipManagedVarInfo entries past the loader's lifetime see a clean
    // \c nullptr rather than a stale pointer into freed storage. The
    // storage itself is owned by the base and gets freed by the base's
    // destructor.
    std::lock_guard Lock(Mutex);
    if (State == LoadState::Loaded)
      nullManagedVarHostShadows();
    DeviceToolCodeLoader::~DeviceToolCodeLoader();
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
  /// managed-var allocation), then mirror each managed-var allocation
  /// pointer into the corresponding \c __hipRegisterManagedVar host
  /// shadow. On local failure, null the partially-written shadows and
  /// roll the base's state back via \c clearLoadedState.
  llvm::Error ensureLoaded() {
    std::lock_guard Lock(Mutex);
    LUTHIER_RETURN_ON_ERROR(DeviceToolCodeLoader::ensureLoaded());
    if (auto E = publishManagedVarHostShadows()) {
      nullManagedVarHostShadows();
      return llvm::joinErrors(std::move(E), clearLoadedState());
    }
    return llvm::Error::success();
  }

protected:
  llvm::ArrayRef<HipManagedVarInfo> InputManagedVars;
  llvm::DenseMap<const void *, std::string> HandleToName;

  /// Walk a Clang offload-bundle header at \p Bundle and return its
  /// total byte extent. Used when \c LoadHIPFATBinaryInfoPass couldn't
  /// determine the size at IR time (split-compile layout produced by
  /// \c luthier_add_tool — the host TU sees only an opaque \c extern
  /// for \c __hip_fatbin and the pass writes \c Size=0). The bundle's
  /// own header carries enough information: an entry table where
  /// every entry's \c (offset+size) pair bounds the bundle bytes;
  /// the high-water mark across all entries is the bundle's end.
  static uint64_t discoverOffloadBundleSize(const void *Bundle) {
    if (Bundle == nullptr)
      return 0;
    static constexpr llvm::StringLiteral Magic{
        "__CLANG_OFFLOAD_BUNDLE__"};
    const auto *P = static_cast<const uint8_t *>(Bundle);
    if (std::memcmp(P, Magic.data(), Magic.size()) != 0)
      return 0;
    P += Magic.size();
    auto ReadU64 = [&]() {
      uint64_t V;
      std::memcpy(&V, P, sizeof(V));
      P += sizeof(V);
      return V;
    };
    const uint64_t NumEntries = ReadU64();
    uint64_t MaxEnd = 0;
    for (uint64_t I = 0; I < NumEntries; ++I) {
      const uint64_t Off = ReadU64();
      const uint64_t Sz = ReadU64();
      const uint64_t TIDLen = ReadU64();
      P += TIDLen;
      const uint64_t End = Off + Sz;
      if (End > MaxEnd)
        MaxEnd = End;
    }
    return MaxEnd;
  }

  /// Build a non-owning \c MemoryBuffer wrapper around the single fat-bin
  /// recorded in \p Slots. Sets \p Err if \p Slots has more than one entry
  /// (Luthier requires one fat binary per loader; multi-fat-bin tools must
  /// use multiple \c Derived instances). Returns \c nullptr if \p Slots is
  /// empty or its sole entry has no bundle.
  ///
  /// If the entry's \c Size is zero (the IR pass couldn't read it at
  /// compile time because the host TU sees \c __hip_fatbin as opaque
  /// \c extern), discover it by parsing the bundle's own header via
  /// \c discoverOffloadBundleSize.
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
    uint64_t Size = S.Size;
    if (Size == 0)
      Size = discoverOffloadBundleSize(S.Bundle);
    if (Size == 0) {
      Err = LUTHIER_MAKE_GENERIC_ERROR(
          "Cannot determine fat-bin bundle size: HipFatBinaries slot "
          "recorded size 0 and the bundle header didn't start with "
          "the Clang offload magic.");
      return nullptr;
    }
    return llvm::MemoryBuffer::getMemBuffer(
        llvm::StringRef(static_cast<const char *>(S.Bundle), Size), "fatbin",
        /*RequiresNullTerminator=*/false);
  }

  /// For each \c HipManagedVars entry, look up the base class's
  /// managed-var allocation by name (the \c __hipRegisterManagedVar
  /// device name matches the ELF base symbol — both are emitted by the
  /// same compiler) and write the allocation pointer into the entry's
  /// \c void** host shadow. After this returns, host-side reads of the
  /// managed variable resolve to the same storage the device kernels see.
  llvm::Error publishManagedVarHostShadows() {
    for (const auto &MV : InputManagedVars) {
      if (MV.Pointer == nullptr || MV.Name == nullptr)
        continue;
      auto AllocOrErr =
          DeviceToolCodeLoader::lookupManagedVarAllocation(MV.Name);
      if (!AllocOrErr)
        return AllocOrErr.takeError();
      *MV.Pointer = *AllocOrErr;
    }
    return llvm::Error::success();
  }

  /// Null every host shadow that \c publishManagedVarHostShadows would
  /// touch. Used on rollback and during destruction so callers that hold
  /// the \c HipManagedVarInfo entries past the loader's lifetime see a
  /// clean \c nullptr instead of a dangling pointer into freed storage.
  void nullManagedVarHostShadows() noexcept {
    for (const auto &MV : InputManagedVars)
      if (MV.Pointer != nullptr)
        *MV.Pointer = nullptr;
  }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_DEVICE_TOOL_CODE_FAT_BINARY_LOADER_H
