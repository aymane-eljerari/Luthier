//===-- LoadedCodeObjectCache.h ----------------------------------*- C++ -*-===//
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
/// Plain non-Singleton cache of parsed storage ELFs for each
/// \c hsa_loaded_code_object_t the tool has seen. Owns no HSA API-table
/// wrappers — those live on \c LoadedCodeObjectCacheTrait.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_HSA_CODE_OBJECT_CACHE_H
#define LUTHIER_HSA_CODE_OBJECT_CACHE_H
#include "luthier/HSA/ApiTable.h"
#include "luthier/HSA/hsa.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <mutex>

namespace luthier {
template <typename Derived> class LoadedCodeObjectCacheTrait;
} // namespace luthier

namespace luthier::hsa {

class LoadedCodeObjectCache final {
public:
  /// Info regarding each cached loaded code object.
  struct LCOCacheEntry {
    std::unique_ptr<llvm::SmallVector<uint8_t>> CodeObject;
    std::unique_ptr<luthier::object::AMDGCNObjectFile> ParsedELF;
  };

private:
  /// Mutex protecting the cache entries.
  mutable std::recursive_mutex CacheMutex;

  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiTableSnapshot;

  /// Loader API snapshot.
  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &VenLoaderSnapshot;

  /// Mapping between every loaded code object and its cached entry.
  mutable llvm::DenseMap<hsa_loaded_code_object_t, LCOCacheEntry> LCOCache;

  /// Mapping between the base load address of an LCO and the LCO itself.
  mutable llvm::DenseMap<const uint8_t *, hsa_loaded_code_object_t>
      LoadedBaseToLCOMap;

  llvm::Expected<LCOCacheEntry &>
  getOrCreateLoadedCodeObjectEntry(hsa_loaded_code_object_t LCO) const;

  // The trait friend needs the private cache state to populate it from the
  // HSA executable-load wrapper.
  template <typename Derived>
  friend class ::luthier::LoadedCodeObjectCacheTrait;

public:
  LoadedCodeObjectCache(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &VenLoader)
      : CoreApiTableSnapshot(CoreApi), VenLoaderSnapshot(VenLoader) {}

  /// Queries whether \p LCO is cached or not.
  bool isCached(hsa_loaded_code_object_t LCO) const;

  llvm::Expected<llvm::ArrayRef<uint8_t>>
  getAssociatedCodeObject(hsa_loaded_code_object_t LCO) const;

  llvm::Expected<luthier::object::AMDGCNObjectFile &>
  getAssociatedObjectFile(hsa_loaded_code_object_t LCO) const;
};

} // namespace luthier::hsa

#endif
