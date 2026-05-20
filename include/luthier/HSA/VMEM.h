//===-- VMEM.h --------------------------------------------------*- C++ -*-===//
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
/// \file VMEM.h
/// Wrappers for the AMD HSA virtual-memory-management (VMEM) APIs.
/// The full set covers four areas:
///
///   - VA reservation (\c vmemAddressReserve, \c vmemAddressReserveAlign,
///     \c vmemAddressFree)
///   - Backing-handle lifetime (\c vmemHandleCreate,
///     \c vmemHandleRelease, \c vmemRetainAllocHandle,
///     \c vmemGetAllocPropertiesFromHandle)
///   - VA ↔ handle mapping (\c vmemMap, \c vmemUnmap)
///   - Per-agent access permissions (\c vmemSetAccess, \c vmemGetAccess)
///   - Inter-process / inter-API sharing via dmabuf
///     (\c vmemExportShareableHandle, \c vmemImportShareableHandle)
///
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_HSA_VMEM_H
#define LUTHIER_HSA_VMEM_H
#include "luthier/HSA/ApiTable.h"
#include "luthier/HSA/HsaError.h"
#include <hsa/hsa.h>
#include <hsa/hsa_ext_amd.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/Support/Error.h>
#include <utility>

namespace luthier::hsa {

//===----------------------------------------------------------------------===//
// VA reservation
//===----------------------------------------------------------------------===//

/// Reserve a virtual address range of \p Size bytes using the legacy
/// (unaligned) reservation entry point. \p Size must be a multiple of the
/// system page size. Pass \p Address = 0 to let the runtime pick the
/// base; pass \c HSA_AMD_VMEM_ADDRESS_NO_REGISTER in \p Flags for the HMM
/// allocation path.
///
/// New code should prefer \c vmemAddressReserveAlign — HSA marks this
/// entry point for deprecation in favor of the \c _align form.
/// \sa hsa_amd_vmem_address_reserve
llvm::Expected<void *>
vmemAddressReserve(const ApiTableContainer<::AmdExtTable> &AmdExt, size_t Size,
                   uint64_t Address, uint64_t Flags);

/// Reserve a virtual address range of \p Size bytes, aligned to \p Alignment.
/// \p Size and \p Alignment must each be a multiple of the system page size,
/// and \p Alignment must be a power of two. Pass \p Address = 0 to let the
/// runtime pick the base; pass \c HSA_AMD_VMEM_ADDRESS_NO_REGISTER in
/// \p Flags for the HMM allocation path (the range is reserved but no GPU
/// driver mapping is created until the HMM page-fault handler binds it on
/// first access).
/// \sa hsa_amd_vmem_address_reserve_align
llvm::Expected<void *>
vmemAddressReserveAlign(const ApiTableContainer<::AmdExtTable> &AmdExt,
                        size_t Size, uint64_t Address, uint64_t Alignment,
                        uint64_t Flags);

/// Release a VA range previously reserved by \c vmemAddressReserve or
/// \c vmemAddressReserveAlign. \p Size must match the originally-reserved
/// size.
/// \sa hsa_amd_vmem_address_free
llvm::Error vmemAddressFree(const ApiTableContainer<::AmdExtTable> &AmdExt,
                            void *Ptr, size_t Size);

//===----------------------------------------------------------------------===//
// Backing-handle lifetime
//===----------------------------------------------------------------------===//

/// Allocate a backing-storage handle in \p Pool. \p Size must be a multiple
/// of the pool's \c HSA_AMD_MEMORY_POOL_INFO_RUNTIME_ALLOC_GRANULE; for
/// best fragmentation behavior align to
/// \c HSA_AMD_MEMORY_POOL_INFO_RUNTIME_ALLOC_REC_GRANULE.
/// \sa hsa_amd_vmem_handle_create
llvm::Expected<hsa_amd_vmem_alloc_handle_t>
vmemHandleCreate(const ApiTableContainer<::AmdExtTable> &AmdExt,
                 hsa_amd_memory_pool_t Pool, size_t Size,
                 hsa_amd_memory_type_t Type, uint64_t Flags);

/// Release a backing-storage handle previously produced by
/// \c vmemHandleCreate, \c vmemImportShareableHandle, or
/// \c vmemRetainAllocHandle. Each \c vmemRetainAllocHandle call must be
/// matched with a corresponding release.
/// \sa hsa_amd_vmem_handle_release
llvm::Error vmemHandleRelease(const ApiTableContainer<::AmdExtTable> &AmdExt,
                              hsa_amd_vmem_alloc_handle_t Handle);

/// Return the backing-storage handle currently mapped at \p Addr. The
/// returned handle must be released with a matching call to
/// \c vmemHandleRelease.
/// \sa hsa_amd_vmem_retain_alloc_handle
llvm::Expected<hsa_amd_vmem_alloc_handle_t>
vmemRetainAllocHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                      void *Addr);

/// Query the allocation properties of \p Handle: the pool it was allocated
/// from and its memory type. Returned as a <tt>(pool, type)</tt> pair.
/// \sa hsa_amd_vmem_get_alloc_properties_from_handle
llvm::Expected<std::pair<hsa_amd_memory_pool_t, hsa_amd_memory_type_t>>
vmemGetAllocPropertiesFromHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                                 hsa_amd_vmem_alloc_handle_t Handle);

//===----------------------------------------------------------------------===//
// VA ↔ handle mapping
//===----------------------------------------------------------------------===//

/// Map \p Handle into the previously-reserved VA range starting at \p VA.
/// <tt>[VA, VA + Size)</tt> must be contained within a single
/// previously-reserved range, and \p Size must match the size of
/// \p Handle. \p InOffset and \p Flags are reserved for future use
/// (pass 0). \c vmemSetAccess must follow before agents can read or write
/// the mapping.
/// \sa hsa_amd_vmem_map
llvm::Error vmemMap(const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA,
                    size_t Size, size_t InOffset,
                    hsa_amd_vmem_alloc_handle_t Handle, uint64_t Flags);

/// Unmap a previously-mapped VA range.
/// \sa hsa_amd_vmem_unmap
llvm::Error vmemUnmap(const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA,
                      size_t Size);

//===----------------------------------------------------------------------===//
// Per-agent access permissions
//===----------------------------------------------------------------------===//

/// Update agent-level access permissions on the mapping at
/// <tt>[VA, VA + Size)</tt>. \p Descs lists each agent's desired
/// permission; agents not listed retain their existing permission.
/// \sa hsa_amd_vmem_set_access
llvm::Error vmemSetAccess(const ApiTableContainer<::AmdExtTable> &AmdExt,
                          void *VA, size_t Size,
                          llvm::ArrayRef<hsa_amd_memory_access_desc_t> Descs);

/// Query the current access permission for the mapping at \p VA from
/// the perspective of \p Agent.
/// \sa hsa_amd_vmem_get_access
llvm::Expected<hsa_access_permission_t>
vmemGetAccess(const ApiTableContainer<::AmdExtTable> &AmdExt, void *VA,
              hsa_agent_t Agent);

//===----------------------------------------------------------------------===//
// Inter-process / inter-API sharing (dmabuf)
//===----------------------------------------------------------------------===//

/// Export a dmabuf file descriptor that references the same backing
/// storage as \p Handle. The fd can be transmitted via any POSIX
/// fd-passing mechanism and re-imported with
/// \c vmemImportShareableHandle. \p Flags is reserved for future use
/// (pass 0). Once every shareable handle and the original \p Handle have
/// been released, the backing storage is freed.
/// \sa hsa_amd_vmem_export_shareable_handle
llvm::Expected<int>
vmemExportShareableHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                          hsa_amd_vmem_alloc_handle_t Handle, uint64_t Flags);

/// Import a dmabuf file descriptor previously produced by
/// \c vmemExportShareableHandle into a fresh \c hsa_amd_vmem_alloc_handle_t.
/// Importing a fd that has been closed and its backing storage released is
/// undefined behavior.
/// \sa hsa_amd_vmem_import_shareable_handle
llvm::Expected<hsa_amd_vmem_alloc_handle_t>
vmemImportShareableHandle(const ApiTableContainer<::AmdExtTable> &AmdExt,
                          int DmabufFD);

} // namespace luthier::hsa

#endif // LUTHIER_HSA_VMEM_H
