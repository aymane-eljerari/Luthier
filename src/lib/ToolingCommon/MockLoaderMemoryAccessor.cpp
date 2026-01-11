//===-- MockLoaderMemoryAccessor.cpp --------------------------------------===//
// Copyright 2026 @ Northeastern University Computer Architecture Lab
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
/// \file MockLoaderMemoryAccessor.cpp
/// Implements the \c MockLoaderMemoryAccessor class.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/MockLoaderMemoryAccessor.h"

namespace luthier {

llvm::Expected<MemoryAllocationAccessor::AllocationDescriptor>
MockLoaderMemoryAccessor::getAllocationDescriptor(uint64_t DeviceAddr) const {

  for (const MockLoadedCodeObject &LCO : Loader.loaded_code_objects()) {
    llvm::ArrayRef<std::byte> LoadedRegion = LCO.getLoadedRegion();
    auto LoadBase = reinterpret_cast<uint64_t>(LoadedRegion.data());
    uint64_t LoadEnd = LoadBase + LoadedRegion.size();
    if (LoadBase <= DeviceAddr && DeviceAddr < LoadEnd) {

      llvm::ArrayRef Alloc{reinterpret_cast<uint8_t *>(LoadBase),
                           LoadedRegion.size()};
      return AllocationDescriptor{Alloc, Alloc, &LCO.getCodeObject()};
    }
  }
  return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
      "Failed to find any allocations associated with address {0:x}",
      DeviceAddr));
}
} // namespace luthier