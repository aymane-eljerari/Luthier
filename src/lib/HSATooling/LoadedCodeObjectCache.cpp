//===-- LoadedCodeObjectCache.cpp ----------------------------------===//
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
/// This file implements the \c LoadedCodeObjectCache Singleton.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/LoadedCodeObjectCache.h"
#include "hsa/hsa.h"
#include "luthier/HSA/Executable.h"
#include "luthier/HSA/ExecutableSymbol.h"
#include "luthier/HSA/LoadedCodeObject.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include <llvm/Object/ELFObjectFile.h>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-hsa-exec-cache"

namespace object = llvm::object;

namespace luthier {

template <>
hsa::LoadedCodeObjectCache *Singleton<hsa::LoadedCodeObjectCache>::Instance{
    nullptr};

namespace hsa {

decltype(hsa_executable_load_agent_code_object)
    *LoadedCodeObjectCache::UnderlyingHsaExecutableLoadAgentCodeObjectFn =
        nullptr;

decltype(hsa_executable_destroy)
    *LoadedCodeObjectCache::UnderlyingHsaExecutableDestroyFn = nullptr;

hsa_status_t LoadedCodeObjectCache::hsaExecutableLoadAgentCodeObjectWrapper(
    hsa_executable_t Executable, hsa_agent_t Agent,
    hsa_code_object_reader_t CodeObjectReader, const char *Options,
    hsa_loaded_code_object_t *LoadedCodeObject) {

  /// Check if the underlying function is not nullptr
  LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      UnderlyingHsaExecutableLoadAgentCodeObjectFn != nullptr,
      "Underlying hsa_executable_load_agent_code_object of "
      "LoadedCodeObjectCache is nullptr"));

  hsa_loaded_code_object_t LCO;
  /// Call the underlying function
  hsa_status_t Out = UnderlyingHsaExecutableLoadAgentCodeObjectFn(
      Executable, Agent, CodeObjectReader, Options, &LCO);

  /// If the caller of the wrapper requested to get the LCO handle, return it
  if (LoadedCodeObject != nullptr)
    *LoadedCodeObject = LCO;

  /// Return if the loader is not initialized or we encountered an error
  /// executing the underlying function
  if (!isInitialized() || Out != HSA_STATUS_SUCCESS)
    return Out;

  auto &COC = instance();

  llvm::ArrayRef<uint8_t> StorageMemory;
  LUTHIER_REPORT_FATAL_ON_ERROR(hsa::loadedCodeObjectGetStorageMemory(
                                    COC.VenLoaderSnapshot.getTable(), LCO)
                                    .moveInto(StorageMemory));

  auto StorageCopy =
      std::make_unique<llvm::SmallVector<uint8_t>>(StorageMemory);

  auto ParsedElfOrErr =
      object::AMDGCNObjectFile::createAMDGCNObjectFile(*StorageCopy);
  LUTHIER_REPORT_FATAL_ON_ERROR(ParsedElfOrErr.takeError());

  llvm::ArrayRef<uint8_t> LoadedMemory;
  LUTHIER_REPORT_FATAL_ON_ERROR(hsa::loadedCodeObjectGetLoadedMemory(
                                    COC.VenLoaderSnapshot.getTable(), LCO)
                                    .moveInto(LoadedMemory));

  std::lock_guard Lock(COC.CacheMutex);
  {
    COC.LCOCache.insert({LCO, LCOCacheEntry{std::move(StorageCopy),
                                            std::move(*ParsedElfOrErr)}});
    COC.LoadedBaseToLCOMap.insert({LoadedMemory.data(), LCO});
  }

  return Out;
}

hsa_status_t LoadedCodeObjectCache::hsaExecutableDestroyWrapper(
    hsa_executable_t Executable) {
  /// Check if the underlying function is not nullptr
  LUTHIER_REPORT_FATAL_ON_ERROR(
      LUTHIER_GENERIC_ERROR_CHECK(UnderlyingHsaExecutableDestroyFn != nullptr,
                                  "Underlying hsa_executable_destroy of "
                                  "LoadedCodeObjectCache is nullptr"));
  llvm::SmallVector<hsa_loaded_code_object_t, 2> LCOs;
  if (isInitialized()) {
    /// Remove the LCOs of the executable from the cache before it is destroyed
    auto &COC = instance();
    auto &VenTable = COC.VenLoaderSnapshot.getTable();
    LUTHIER_REPORT_FATAL_ON_ERROR(
        hsa::executableGetLoadedCodeObjects(VenTable, Executable, LCOs));
  }

  hsa_status_t Out = UnderlyingHsaExecutableDestroyFn(Executable);
  if (Out != HSA_STATUS_SUCCESS)
    return Out;

  if (isInitialized()) {
    /// Remove the LCOs of the executable from the cache before it is destroyed
    auto &COC = instance();
    std::lock_guard Lock(COC.CacheMutex);
    for (hsa_loaded_code_object_t LCO : LCOs) {
      COC.LCOCache.erase(LCO);

      llvm::ArrayRef<uint8_t> LoadedMemory;
      LUTHIER_REPORT_FATAL_ON_ERROR(hsa::loadedCodeObjectGetLoadedMemory(
                                        COC.VenLoaderSnapshot.getTable(), LCO)
                                        .moveInto(LoadedMemory));
      COC.LoadedBaseToLCOMap.erase(LoadedMemory.data());
    }
  }
  return Out;
}

LoadedCodeObjectCache::LoadedCodeObjectCache(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable>
        &CoreApiTableSnapshot,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &VenLoaderSnapshot,
    llvm::Error &Err)
    : CoreApiTableSnapshot(CoreApiTableSnapshot),
      VenLoaderSnapshot(VenLoaderSnapshot) {
  llvm::ErrorAsOutParameter EAO(Err);
  HsaWrapperInstaller = std::make_unique<
      rocprofiler::HsaApiTableWrapperInstaller<::CoreApiTable>>(
      Err,
      std::make_tuple(&::CoreApiTable::hsa_executable_load_agent_code_object_fn,
                      std::ref(UnderlyingHsaExecutableLoadAgentCodeObjectFn),
                      hsaExecutableLoadAgentCodeObjectWrapper),
      std::make_tuple(&::CoreApiTable::hsa_executable_destroy_fn,
                      std::ref(UnderlyingHsaExecutableDestroyFn),
                      hsaExecutableDestroyWrapper));
}

llvm::Expected<llvm::ArrayRef<uint8_t>>
LoadedCodeObjectCache::getAssociatedCodeObject(
    hsa_loaded_code_object_t LCO) const {
  llvm::Expected<LCOCacheEntry &> EntryOrErr =
      getOrCreateLoadedCodeObjectEntry(LCO);
  LUTHIER_RETURN_ON_ERROR(EntryOrErr.takeError());
  return *EntryOrErr->CodeObject;
}

llvm::Expected<luthier::object::AMDGCNObjectFile &>
LoadedCodeObjectCache::getAssociatedObjectFile(
    hsa_loaded_code_object_t LCO) const {
  llvm::Expected<LCOCacheEntry &> EntryOrErr =
      getOrCreateLoadedCodeObjectEntry(LCO);
  LUTHIER_RETURN_ON_ERROR(EntryOrErr.takeError());
  return *EntryOrErr->ParsedELF;
}

bool LoadedCodeObjectCache::LoadedCodeObjectCache::isCached(
    hsa_loaded_code_object_t LCO) {
  std::lock_guard Lock(CacheMutex);
  return LCOCache.contains(LCO);
}


llvm::Expected<LoadedCodeObjectCache::LCOCacheEntry &>
LoadedCodeObjectCache::getOrCreateLoadedCodeObjectEntry(
    hsa_loaded_code_object_t LCO) const {
  std::lock_guard Lock(CacheMutex);
  auto LCOEntry = LCOCache.find(LCO);
  /// If not already cached, try querying the storage ELF from the loader
  /// API
  if (LCOEntry == LCOCache.end()) {
    llvm::ArrayRef<uint8_t> LCOStorageMemory;
    LUTHIER_RETURN_ON_ERROR(
        hsa::loadedCodeObjectGetStorageMemory(VenLoaderSnapshot.getTable(), LCO)
            .moveInto(LCOStorageMemory));

    try {
      /// TODO: Install a signal handler to treat segfaults encountered
      /// here as exceptions
      auto StorageCopy =
          std::make_unique<llvm::SmallVector<uint8_t>>(LCOStorageMemory);

      auto ParsedElfOrErr =
          object::AMDGCNObjectFile::createAMDGCNObjectFile(*StorageCopy);
      LUTHIER_REPORT_FATAL_ON_ERROR(ParsedElfOrErr.takeError());

      LCOEntry = LCOCache
                     .insert({LCO, LCOCacheEntry{std::move(StorageCopy),
                                                 std::move(*ParsedElfOrErr)}})
                     .first;
    } catch (...) {
      return llvm::make_error<GenericLuthierError>(
          "Failed to obtain the loaded code object's storage memory");
    }
  }
  return LCOEntry->second;
}

} // namespace hsa
} // namespace luthier
