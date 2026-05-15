//===-- LoadedCodeObjectCache.cpp ----------------------------------------===//
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
/// Implements the plain-class LoadedCodeObjectCache. HSA API-table wrappers
/// for cache invalidation are installed by LoadedCodeObjectCacheTrait, not
/// here.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/LoadedCodeObjectCache.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/LoadedCodeObject.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include <llvm/Object/ELFObjectFile.h>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-hsa-exec-cache"

namespace object = llvm::object;

namespace luthier::hsa {

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

bool LoadedCodeObjectCache::isCached(hsa_loaded_code_object_t LCO) const {
  std::lock_guard Lock(CacheMutex);
  return LCOCache.contains(LCO);
}

llvm::Expected<LoadedCodeObjectCache::LCOCacheEntry &>
LoadedCodeObjectCache::getOrCreateLoadedCodeObjectEntry(
    hsa_loaded_code_object_t LCO) const {
  std::lock_guard Lock(CacheMutex);
  auto LCOEntry = LCOCache.find(LCO);
  /// If not already cached, try querying the storage ELF from the loader API.
  if (LCOEntry == LCOCache.end()) {
    llvm::ArrayRef<uint8_t> LCOStorageMemory;
    LUTHIER_RETURN_ON_ERROR(
        hsa::loadedCodeObjectGetStorageMemory(VenLoaderSnapshot.getTable(), LCO)
            .moveInto(LCOStorageMemory));

    try {
      /// TODO: Install a signal handler to treat segfaults encountered
      /// here as exceptions.
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

} // namespace luthier::hsa
