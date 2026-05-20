//===-- VMEM.cpp ----------------------------------------------------------===//
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
/// \file VMEM.cpp
/// Implements the AMD HSA VMEM (virtual-memory-management) wrappers declared
/// in \c VMEM.h.
//===----------------------------------------------------------------------===//
#include "luthier/HSA/VMEM.h"
#include "luthier/HSA/HsaError.h"
#include <hsa/hsa_ext_amd.h>
#include <llvm/Support/FormatVariadic.h>

namespace luthier::hsa {

//===----------------------------------------------------------------------===//
// VA reservation
//===----------------------------------------------------------------------===//

llvm::Expected<void *>
vmemAddressReserve(const ApiTableContainer<::AmdExtTable> &AmdExt, size_t Size,
                   uint64_t Address, uint64_t Flags) {
  void *VA = nullptr;
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_address_reserve>(&VA, Size, Address,
                                                        Flags),
      llvm::formatv("hsa_amd_vmem_address_reserve failed (size {0}, "
                    "flags {1:x})",
                    Size, Flags)));
  return VA;
}

llvm::Expected<void *>
vmemAddressReserveAlign(const ApiTableContainer<::AmdExtTable> &AmdExt,
                        size_t Size, uint64_t Address, uint64_t Alignment,
                        uint64_t Flags) {
  void *VA = nullptr;
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_address_reserve_align>(
          &VA, Size, Address, Alignment, Flags),
      llvm::formatv("hsa_amd_vmem_address_reserve_align failed (size {0}, "
                    "alignment {1}, flags {2:x})",
                    Size, Alignment, Flags)));
  return VA;
}

llvm::Error vmemAddressFree(const ApiTableContainer<::AmdExtTable> &AmdExt,
                            void *Ptr, size_t Size) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_address_free>(Ptr, Size),
      llvm::formatv("hsa_amd_vmem_address_free failed for {0} (size {1})", Ptr,
                    Size));
}

//===----------------------------------------------------------------------===//
// Backing-handle lifetime
//===----------------------------------------------------------------------===//

llvm::Expected<hsa_amd_vmem_alloc_handle_t>
vmemHandleCreate(const ApiTableContainer<::AmdExtTable> &AmdExt,
                 hsa_amd_memory_pool_t Pool, size_t Size,
                 hsa_amd_memory_type_t Type, uint64_t Flags) {
  hsa_amd_vmem_alloc_handle_t Handle{};
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_handle_create>(Pool, Size, Type, Flags,
                                                      &Handle),
      llvm::formatv("hsa_amd_vmem_handle_create failed (pool {0:x}, size "
                    "{1}, type {2}, flags {3:x})",
                    Pool.handle, Size, static_cast<int>(Type), Flags)));
  return Handle;
}

llvm::Error
vmemHandleRelease(const ApiTableContainer<::AmdExtTable> &AmdExt,
                  hsa_amd_vmem_alloc_handle_t Handle) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_handle_release>(Handle),
      llvm::formatv("hsa_amd_vmem_handle_release failed for handle {0:x}",
                    Handle.handle));
}

llvm::Expected<hsa_amd_vmem_alloc_handle_t>
vmemRetainAllocHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                      void *Addr) {
  hsa_amd_vmem_alloc_handle_t Handle{};
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_retain_alloc_handle>(&Handle, Addr),
      llvm::formatv("hsa_amd_vmem_retain_alloc_handle failed for {0}", Addr)));
  return Handle;
}

llvm::Expected<std::pair<hsa_amd_memory_pool_t, hsa_amd_memory_type_t>>
vmemGetAllocPropertiesFromHandle(
    const ApiTableContainer<::AmdExtTable> &AmdExt,
    hsa_amd_vmem_alloc_handle_t Handle) {
  hsa_amd_memory_pool_t Pool{};
  hsa_amd_memory_type_t Type{};
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_get_alloc_properties_from_handle>(
          Handle, &Pool, &Type),
      llvm::formatv("hsa_amd_vmem_get_alloc_properties_from_handle failed "
                    "for handle {0:x}",
                    Handle.handle)));
  return std::make_pair(Pool, Type);
}

//===----------------------------------------------------------------------===//
// VA ↔ handle mapping
//===----------------------------------------------------------------------===//

llvm::Error vmemMap(const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA,
                    size_t Size, size_t InOffset,
                    hsa_amd_vmem_alloc_handle_t Handle, uint64_t Flags) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_map>(VA, Size, InOffset, Handle, Flags),
      llvm::formatv("hsa_amd_vmem_map failed (va {0}, size {1}, handle "
                    "{2:x}, flags {3:x})",
                    VA, Size, Handle.handle, Flags));
}

llvm::Error vmemUnmap(const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA,
                      size_t Size) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_unmap>(VA, Size),
      llvm::formatv("hsa_amd_vmem_unmap failed (va {0}, size {1})", VA, Size));
}

//===----------------------------------------------------------------------===//
// Per-agent access permissions
//===----------------------------------------------------------------------===//

llvm::Error vmemSetAccess(
    const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA, size_t Size,
    llvm::ArrayRef<hsa_amd_memory_access_desc_t> Descs) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_set_access>(VA, Size, Descs.data(),
                                                   Descs.size()),
      llvm::formatv("hsa_amd_vmem_set_access failed (va {0}, size {1}, {2} "
                    "descriptors)",
                    VA, Size, Descs.size()));
}

llvm::Expected<hsa_access_permission_t>
vmemGetAccess(const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA,
              hsa_agent_t Agent) {
  hsa_access_permission_t Perms{};
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_get_access>(VA, &Perms, Agent),
      llvm::formatv("hsa_amd_vmem_get_access failed (va {0}, agent {1:x})",
                    VA, Agent.handle)));
  return Perms;
}

//===----------------------------------------------------------------------===//
// Inter-process / inter-API sharing (dmabuf)
//===----------------------------------------------------------------------===//

llvm::Expected<int>
vmemExportShareableHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                          hsa_amd_vmem_alloc_handle_t Handle, uint64_t Flags) {
  int DmabufFD = 0;
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_export_shareable_handle>(&DmabufFD,
                                                                Handle, Flags),
      llvm::formatv("hsa_amd_vmem_export_shareable_handle failed for handle "
                    "{0:x} (flags {1:x})",
                    Handle.handle, Flags)));
  return DmabufFD;
}

llvm::Expected<hsa_amd_vmem_alloc_handle_t>
vmemImportShareableHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                          int DmabufFD) {
  hsa_amd_vmem_alloc_handle_t Handle{};
  LUTHIER_RETURN_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_vmem_import_shareable_handle>(DmabufFD,
                                                                &Handle),
      llvm::formatv("hsa_amd_vmem_import_shareable_handle failed for fd {0}",
                    DmabufFD)));
  return Handle;
}

} // namespace luthier::hsa
