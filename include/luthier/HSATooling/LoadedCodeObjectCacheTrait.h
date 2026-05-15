//===-- LoadedCodeObjectCacheTrait.h - HSATool LCO-cache trait --*- C++ -*-===//
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
/// Header-only CRTP trait that hosts an \c hsa::LoadedCodeObjectCache and
/// installs the HSA API-table wrappers (\c hsa_executable_load_agent_code_object
/// and \c hsa_executable_destroy) that keep it coherent.
///
/// Wrappers are installed in the trait constructor and NEVER uninstalled —
/// the HSA runtime is free to invoke them on worker threads at any time,
/// including during process teardown. The wrappers themselves consult
/// \c Singleton<Derived>::isInitialized() and short-circuit when the tool
/// has already been destroyed.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_LOADED_CODE_OBJECT_CACHE_TRAIT_H
#define LUTHIER_TOOLING_LOADED_CODE_OBJECT_CACHE_TRAIT_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/Common/Singleton.h"
#include "luthier/HSA/Executable.h"
#include "luthier/HSA/LoadedCodeObject.h"
#include "luthier/HSATooling/LoadedCodeObjectCache.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include "luthier/Rocprofiler/ApiTableWrapperInstaller.h"
#include <hsa/hsa.h>
#include <llvm/ADT/SmallVector.h>
#include <memory>

namespace luthier {

/// \brief CRTP trait that owns the \c hsa::LoadedCodeObjectCache for a tool
/// and installs the HSA executable load/destroy wrappers that keep it
/// coherent across the application's executable lifetime.
///
/// Wrappers find the cache via \c Singleton<Derived>::instance().getCache()
/// after gating on \c Singleton<Derived>::isInitialized(). They are not
/// uninstalled at trait teardown — see file header.
template <typename Derived> class LoadedCodeObjectCacheTrait {
private:
  hsa::LoadedCodeObjectCache Cache;

  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &VenLoaderSnapshot;

  std::unique_ptr<rocprofiler::HsaApiTableWrapperInstaller<::CoreApiTable>>
      HsaWrapperInstaller;

  /// Per-Derived pointers to the wrapped HSA functions. The wrapper
  /// installer rewrites the table slot and writes the original pointer here
  /// during construction. \c inline (C++17) lets these live in the header.
  inline static decltype(hsa_executable_load_agent_code_object)
      *UnderlyingHsaExecutableLoadAgentCodeObjectFn{};

  inline static decltype(hsa_executable_destroy)
      *UnderlyingHsaExecutableDestroyFn{};

  static hsa_status_t hsaExecutableLoadAgentCodeObjectWrapper(
      hsa_executable_t Executable, hsa_agent_t Agent,
      hsa_code_object_reader_t CodeObjectReader, const char *Options,
      hsa_loaded_code_object_t *LoadedCodeObject) {
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        UnderlyingHsaExecutableLoadAgentCodeObjectFn != nullptr,
        "Underlying hsa_executable_load_agent_code_object is nullptr"));

    hsa_loaded_code_object_t LCO;
    hsa_status_t Out = UnderlyingHsaExecutableLoadAgentCodeObjectFn(
        Executable, Agent, CodeObjectReader, Options, &LCO);

    if (LoadedCodeObject != nullptr)
      *LoadedCodeObject = LCO;

    /// Short-circuit if the tool is gone (post-tool-dtor) or if the
    /// underlying call failed.
    if (!Singleton<Derived>::isInitialized() || Out != HSA_STATUS_SUCCESS)
      return Out;

    auto &Trait = static_cast<LoadedCodeObjectCacheTrait<Derived> &>(
        Singleton<Derived>::instance());
    auto &COC = Trait.Cache;

    llvm::ArrayRef<uint8_t> StorageMemory;
    LUTHIER_REPORT_FATAL_ON_ERROR(
        hsa::loadedCodeObjectGetStorageMemory(
            Trait.VenLoaderSnapshot.getTable(), LCO)
            .moveInto(StorageMemory));

    auto StorageCopy =
        std::make_unique<llvm::SmallVector<uint8_t>>(StorageMemory);

    auto ParsedElfOrErr =
        luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(*StorageCopy);
    LUTHIER_REPORT_FATAL_ON_ERROR(ParsedElfOrErr.takeError());

    llvm::ArrayRef<uint8_t> LoadedMemory;
    LUTHIER_REPORT_FATAL_ON_ERROR(
        hsa::loadedCodeObjectGetLoadedMemory(
            Trait.VenLoaderSnapshot.getTable(), LCO)
            .moveInto(LoadedMemory));

    std::lock_guard Lock(COC.CacheMutex);
    COC.LCOCache.insert(
        {LCO, hsa::LoadedCodeObjectCache::LCOCacheEntry{
                  std::move(StorageCopy), std::move(*ParsedElfOrErr)}});
    COC.LoadedBaseToLCOMap.insert({LoadedMemory.data(), LCO});

    return Out;
  }

  static hsa_status_t
  hsaExecutableDestroyWrapper(hsa_executable_t Executable) {
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        UnderlyingHsaExecutableDestroyFn != nullptr,
        "Underlying hsa_executable_destroy is nullptr"));

    llvm::SmallVector<hsa_loaded_code_object_t, 2> LCOs;
    if (Singleton<Derived>::isInitialized()) {
      auto &Trait = static_cast<LoadedCodeObjectCacheTrait<Derived> &>(
          Singleton<Derived>::instance());
      LUTHIER_REPORT_FATAL_ON_ERROR(hsa::executableGetLoadedCodeObjects(
          Trait.VenLoaderSnapshot.getTable(), Executable, LCOs));
    }

    hsa_status_t Out = UnderlyingHsaExecutableDestroyFn(Executable);
    if (Out != HSA_STATUS_SUCCESS)
      return Out;

    if (Singleton<Derived>::isInitialized()) {
      auto &Trait = static_cast<LoadedCodeObjectCacheTrait<Derived> &>(
          Singleton<Derived>::instance());
      auto &COC = Trait.Cache;
      std::lock_guard Lock(COC.CacheMutex);
      for (hsa_loaded_code_object_t LCO : LCOs) {
        COC.LCOCache.erase(LCO);

        llvm::ArrayRef<uint8_t> LoadedMemory;
        LUTHIER_REPORT_FATAL_ON_ERROR(
            hsa::loadedCodeObjectGetLoadedMemory(
                Trait.VenLoaderSnapshot.getTable(), LCO)
                .moveInto(LoadedMemory));
        COC.LoadedBaseToLCOMap.erase(LoadedMemory.data());
      }
    }
    return Out;
  }

public:
  LoadedCodeObjectCacheTrait(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &VenLoader,
      llvm::Error &Err)
      : Cache(CoreApi, VenLoader), VenLoaderSnapshot(VenLoader) {
    llvm::ErrorAsOutParameter EAO(Err);
    HsaWrapperInstaller = std::make_unique<
        rocprofiler::HsaApiTableWrapperInstaller<::CoreApiTable>>(
        Err,
        std::make_tuple(
            &::CoreApiTable::hsa_executable_load_agent_code_object_fn,
            std::ref(UnderlyingHsaExecutableLoadAgentCodeObjectFn),
            hsaExecutableLoadAgentCodeObjectWrapper),
        std::make_tuple(&::CoreApiTable::hsa_executable_destroy_fn,
                        std::ref(UnderlyingHsaExecutableDestroyFn),
                        hsaExecutableDestroyWrapper));
  }

  /// Wrappers are intentionally NOT uninstalled. The HSA runtime may invoke
  /// them on worker threads any time; the wrappers themselves gate on
  /// \c Singleton<Derived>::isInitialized() instead.
  ~LoadedCodeObjectCacheTrait() = default;

  LoadedCodeObjectCacheTrait(const LoadedCodeObjectCacheTrait &) = delete;
  LoadedCodeObjectCacheTrait &
  operator=(const LoadedCodeObjectCacheTrait &) = delete;

  /// Accessor for the underlying cache. Used by the static HSA wrappers to
  /// reach the per-tool cache state, and by tool subsystems that need to
  /// query the cache directly (e.g. \c HsaMemoryAllocationAccessor).
  hsa::LoadedCodeObjectCache &getCache() { return Cache; }
  const hsa::LoadedCodeObjectCache &getCache() const { return Cache; }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_LOADED_CODE_OBJECT_CACHE_TRAIT_H
