//===-- InstrumentedKernelLoaderAndLauncher.h -------------------*- C++ -*-===//
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
/// \file InstrumentedKernelLoaderAndLauncher.h
/// Defines two collaborating classes:
///   - \c InstrumentedKernelLoaderAndLauncher: non-templated base.
///     Owns the per-tool cache of loaded instrumented-kernel HSA
///     executables and exposes the load / unload / override entry
///     points.
///   - \c InstrumentedKernelLoaderAndLauncherTrait<Derived>: header-only
///     CRTP trait that extends the base and installs an
///     \c hsa_executable_destroy interceptor driving
///     \c invalidateOriginalExec.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_HSA_TOOLING_INSTRUMENTED_KERNEL_LOADER_AND_LAUNCHER_H
#define LUTHIER_HSA_TOOLING_INSTRUMENTED_KERNEL_LOADER_AND_LAUNCHER_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/Common/Singleton.h"
#include "luthier/HSA/ExecutableSymbol.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include "luthier/Rocprofiler/ApiTableWrapperInstaller.h"
#include <cstdint>
#include <hsa/hsa.h>
#include <hsa/hsa_api_trace.h>
#include <hsa/hsa_ven_amd_loader.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/DenseMapInfo.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/RWMutex.h>
#include <memory>
#include <tuple>
#include <utility>

namespace luthier {

class DeviceToolCodeLoader;

/// \brief Per-tool cache of instrumented HSA kernel executables.
///
/// Each cached record packages, for a single
/// <tt>(OriginalKernel, Preset)</tt> tuple, the relocatable ELF bytes
/// (owned), the HSA code-object reader created over them, the HSA
/// executable they were loaded into, and the resulting instrumented
/// kernel symbol + descriptor address + private segment size.
///
/// \c loadInstrumented is the cold-path entry point; it takes ownership
/// of \p Relocatable so the HSA code-object reader's view into host
/// memory stays valid for the record's lifetime. \c
/// overrideWithInstrumented is the hot path called from a packet
/// interceptor and is reader-locked.
///
/// \c invalidateOriginalExec is invoked by the
/// \c InstrumentedKernelLoaderAndLauncherTrait subclass from inside its
/// \c hsa_executable_destroy interceptor whenever an application
/// executable is about to be torn down. It walks that executable's
/// kernel symbols and erases any cache records keyed by those symbols.
class InstrumentedKernelLoaderAndLauncher {
public:
  InstrumentedKernelLoaderAndLauncher(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      DeviceToolCodeLoader &DeviceCode);

  ~InstrumentedKernelLoaderAndLauncher();

  InstrumentedKernelLoaderAndLauncher(
      const InstrumentedKernelLoaderAndLauncher &) = delete;
  InstrumentedKernelLoaderAndLauncher &
  operator=(const InstrumentedKernelLoaderAndLauncher &) = delete;

  /// Parse \p Relocatable as an AMDGCN ELF, require it contain exactly
  /// one kernel function whose name matches \p OriginalKernel, resolve
  /// the relocatable's UND globals against the per-agent symbols
  /// published by the tool's \c DeviceToolCodeLoader on
  /// \p OriginalKernel's agent, create + load + freeze a fresh HSA
  /// executable, and cache the resulting kernel symbol under the key
  /// <tt>(OriginalKernel, Preset)</tt>.
  ///
  /// Takes ownership of \p Relocatable for the lifetime of the
  /// resulting record — the HSA code-object reader keeps a pointer
  /// into it.
  ///
  /// Errors:
  ///   - an entry for the same <tt>(OriginalKernel, Preset)</tt>
  ///     already exists
  ///   - the ELF contains zero, more than one, or a mis-named kernel
  ///   - any UND global symbol does not resolve in the
  ///     \c DeviceToolCodeLoader
  ///   - any UND function symbol is present
  ///   - any HSA failure (create / define / load / freeze /
  ///     symbol lookup)
  llvm::Expected<hsa_executable_symbol_t>
  loadInstrumented(std::unique_ptr<llvm::MemoryBuffer> Relocatable,
                   hsa_executable_symbol_t OriginalKernel, uint64_t Preset = 0);

  /// Tear down the HSA executable + reader cached under
  /// <tt>(OriginalKernel, Preset)</tt> and remove the entry from every
  /// cache index. Idempotent: a missing entry is success. Returns any
  /// joined HSA destruction errors.
  llvm::Error unloadInstrumentedIfExists(hsa_executable_symbol_t OriginalKernel,
                                         uint64_t Preset = 0);

  /// Rewrite \p Packet 's <tt>kernel_object</tt> to the cached
  /// instrumented variant for <tt>(Packet.kernel_object, Preset)</tt>,
  /// and bump <tt>private_segment_size</tt> to at least the cached
  /// value. Returns an error if no such cached variant exists.
  llvm::Error overrideWithInstrumented(hsa_kernel_dispatch_packet_t &Packet,
                                       uint64_t Preset = 0);

  /// Tear down every cached record. Joins all HSA destruction errors
  /// and returns the joined \c llvm::Error (success only if every
  /// teardown succeeded). Idempotent.
  llvm::Error unloadAll();

  /// Walk \p Exec 's kernel symbols and erase any cache records keyed
  /// by those symbols (for every cached preset). Returns a joined
  /// \c llvm::Error of any HSA failures collected along the way.
  /// Called by the trait subclass from inside the
  /// \c hsa_executable_destroy interceptor before chaining to the next
  /// wrapper.
  llvm::Error invalidateOriginalExec(hsa_executable_t Exec);

protected:
  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi;
  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &Loader;
  DeviceToolCodeLoader &DeviceCode;

  /// Reader/writer lock: \c overrideWithInstrumented takes the reader
  /// lock; every cache mutation path (\c loadInstrumented,
  /// \c unloadInstrumentedIfExists, \c unloadAll,
  /// \c invalidateOriginalExec) takes the writer lock.
  mutable llvm::sys::RWMutex Mutex;

  /// One per <tt>(OriginalKernel, Preset)</tt> entry. Stores the
  /// instrumented HSA executable and reader the launcher owns, plus
  /// the cached scalar fields needed by the override hot path.
  struct InstrumentedRecord {
    /// Caller-supplied relocatable bytes. Outlives \c Reader — the HSA
    /// code-object reader holds a non-owning view into this buffer.
    std::unique_ptr<llvm::MemoryBuffer> RelocatableBuffer;
    hsa_code_object_reader_t Reader{};
    hsa_executable_t Exec{};
    hsa_executable_symbol_t InstrumentedKernelSym{};
    /// Cached \c hsa_executable_symbol_get_info(KERNEL_OBJECT) of
    /// \c InstrumentedKernelSym. Goes into the dispatch packet on
    /// override.
    uint64_t InstrumentedKO{0};
    /// Cached \c
    /// hsa_executable_symbol_get_info(KERNEL_PRIVATE_SEGMENT_SIZE) of
    /// \c InstrumentedKernelSym. \c overrideWithInstrumented bumps
    /// \c Packet.private_segment_size to at least this value.
    uint32_t PrivateSegmentSize{0};
    /// Cached \c hsa_executable_symbol_get_info(KERNEL_OBJECT) of the
    /// original kernel. Backs the \c ByOriginalKO lookup that drives
    /// the override hot path.
    uint64_t OriginalKO{0};
    /// Agent the kernel runs on. Held for diagnostics / future use.
    hsa_agent_t Agent{};
  };

  /// Cache key. Layered on top of LLVM's existing
  /// \c DenseMapInfo<hsa_executable_symbol_t> so it composes cleanly.
  struct Key {
    hsa_executable_symbol_t OriginalKernel;
    uint64_t Preset;
  };

  struct KeyDenseMapInfo {
    using SymInfo = llvm::DenseMapInfo<hsa_executable_symbol_t>;
    using U64Info = llvm::DenseMapInfo<uint64_t>;
    static Key getEmptyKey() {
      return Key{SymInfo::getEmptyKey(), U64Info::getEmptyKey()};
    }
    static Key getTombstoneKey() {
      return Key{SymInfo::getTombstoneKey(), U64Info::getTombstoneKey()};
    }
    static unsigned getHashValue(const Key &K) {
      return llvm::detail::combineHashValue(
          SymInfo::getHashValue(K.OriginalKernel),
          U64Info::getHashValue(K.Preset));
    }
    static bool isEqual(const Key &L, const Key &R) {
      return SymInfo::isEqual(L.OriginalKernel, R.OriginalKernel) &&
             L.Preset == R.Preset;
    }
  };

  /// Authoritative storage of every cached record.
  llvm::DenseMap<Key, InstrumentedRecord, KeyDenseMapInfo> ByOriginal;

  /// Override hot-path index: original \c kernel_object + preset →
  /// record pointer. Pointers point into \c ByOriginal; both maps are
  /// mutated together under the writer lock.
  llvm::DenseMap<std::pair<uint64_t /*OriginalKO*/, uint64_t /*Preset*/>,
                 InstrumentedRecord *>
      ByOriginalKO;

  /// Per-original-kernel secondary index used by
  /// \c invalidateOriginalExec to enumerate every preset loaded
  /// for a given kernel symbol.
  llvm::DenseMap<hsa_executable_symbol_t,
                 llvm::SmallVector<uint64_t /*Preset*/, 2>>
      BySymbolPresets;

  /// Destroy the HSA executable + reader pointed to by \p It and erase
  /// the corresponding entries from all three indices. Caller must
  /// hold the writer lock. Returns the joined HSA destruction errors
  /// (success if both teardowns succeeded).
  llvm::Error eraseRecordLocked(
      llvm::DenseMap<Key, InstrumentedRecord, KeyDenseMapInfo>::iterator It);
};

/// \brief CRTP trait that adds an \c hsa_executable_destroy interceptor
/// on top of \c InstrumentedKernelLoaderAndLauncher.
///
/// The wrapper runs the base's \c invalidateOriginalExec on the
/// to-be-destroyed executable before chaining to whatever
/// \c hsa_executable_destroy implementation was previously installed in
/// the HSA table (typically the \c LoadedCodeObjectCacheTrait wrapper,
/// then the real HSA function). This ordering guarantees that no
/// cached instrumented variant references an \c hsa_executable_t whose
/// teardown is already in flight.
///
/// Following the convention used by \c PacketMonitorTrait and
/// \c LoadedCodeObjectCacheTrait, the wrapper is NOT uninstalled at
/// trait teardown — uninstalling while the runtime may still call us
/// would be racy. The wrapper gates on
/// <tt>Singleton<Derived>::isInitialized()</tt>.
template <typename Derived>
class InstrumentedKernelLoaderAndLauncherTrait
    : public InstrumentedKernelLoaderAndLauncher {
private:
  /// Saved pointer to the prior \c hsa_executable_destroy entry. Set by
  /// the wrapper installer; consulted by \c hsaExecutableDestroyWrapper
  /// to chain through.
  inline static decltype(hsa_executable_destroy)
      *UnderlyingHsaExecutableDestroyFn{};

  std::unique_ptr<rocprofiler::HsaApiTableWrapperInstaller<::CoreApiTable>>
      HsaWrapperInstaller;

  static hsa_status_t hsaExecutableDestroyWrapper(hsa_executable_t Exec) {
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        UnderlyingHsaExecutableDestroyFn != nullptr,
        "The underlying hsa_executable_destroy function for "
        "InstrumentedKernelLoaderAndLauncherTrait is nullptr"));
    if (Singleton<Derived>::isInitialized()) {
      auto &Self = static_cast<InstrumentedKernelLoaderAndLauncher &>(
          static_cast<InstrumentedKernelLoaderAndLauncherTrait<Derived> &>(
              Singleton<Derived>::instance()));
      // Swallow the accumulated invalidation error here, as the
      // hsa_executable_destroy ABI cannot surface llvm::Errors.
      llvm::consumeError(Self.invalidateOriginalExec(Exec));
    }
    return UnderlyingHsaExecutableDestroyFn(Exec);
  }

public:
  InstrumentedKernelLoaderAndLauncherTrait(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      DeviceToolCodeLoader &DeviceCode, llvm::Error &Err)
      : InstrumentedKernelLoaderAndLauncher(CoreApi, Loader, DeviceCode) {
    llvm::ErrorAsOutParameter EAO(Err);
    HsaWrapperInstaller = std::make_unique<
        rocprofiler::HsaApiTableWrapperInstaller<::CoreApiTable>>(
        Err, std::make_tuple(&::CoreApiTable::hsa_executable_destroy_fn,
                             std::ref(UnderlyingHsaExecutableDestroyFn),
                             hsaExecutableDestroyWrapper));
  }

  /// Wrapper intentionally not uninstalled — see class doc.
  ~InstrumentedKernelLoaderAndLauncherTrait() = default;

  InstrumentedKernelLoaderAndLauncherTrait(
      const InstrumentedKernelLoaderAndLauncherTrait &) = delete;
  InstrumentedKernelLoaderAndLauncherTrait &
  operator=(const InstrumentedKernelLoaderAndLauncherTrait &) = delete;
};

} // namespace luthier

#endif // LUTHIER_HSA_TOOLING_INSTRUMENTED_KERNEL_LOADER_AND_LAUNCHER_H
