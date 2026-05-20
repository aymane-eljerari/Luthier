//===-- SVM.h ---------------------------------------------------*- C++ -*-===//
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
/// \file SVM.h
/// Wrappers for the HSA shared-virtual-memory (SVM / HMM) primitives:
/// system-level HMM support probe and per-allocation SVM attribute
/// updates. Used by the device-code loader to allocate HIP managed
/// variables on HMM-supported systems (the path \c hipMallocManaged
/// takes when \c HSA_AMD_SYSTEM_INFO_SVM_SUPPORTED is true).
///
/// VA reservation primitives needed by the HMM allocation flow live in
/// \c VMEM.h (they are general virtual-memory-management APIs, not
/// SVM-specific).
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_HSA_SVM_H
#define LUTHIER_HSA_SVM_H
#include "luthier/HSA/ApiTable.h"
#include "luthier/HSA/HsaError.h"
#include <hsa/hsa.h>
#include <hsa/hsa_ext_amd.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/Support/Error.h>

namespace luthier::hsa {

//===----------------------------------------------------------------------===//
// System-level HMM probe
//===----------------------------------------------------------------------===//

/// Queries whether the system supports SVM / HMM (i.e. whether
/// \c hsa_amd_vmem_address_reserve_align + \c hsa_amd_svm_attributes_set is the
/// expected allocation path for managed memory, instead of the legacy CPU
/// fine-grain memory-pool path).
///
/// Mirrors HIP's
/// <tt>hsa_system_get_info(HSA_AMD_SYSTEM_INFO_SVM_SUPPORTED, ...)</tt>
/// detection in \c rocclr's \c Device::populateOCLDeviceConstants. On query
/// failure the function logs and returns \c false (HIP's fallback behavior).
llvm::Expected<bool>
systemIsSvmSupported(const ApiTableContainer<::CoreApiTable> &CoreApi);

//===----------------------------------------------------------------------===//
// SVM attribute updates
//===----------------------------------------------------------------------===//

/// Apply each \p Attributes entry to the SVM range
/// <tt>[Ptr, Ptr + Size)</tt>. Typical first-alloc usage sets
/// \c HSA_AMD_SVM_ATTRIB_AGENT_ACCESSIBLE for every GPU agent that needs
/// access to the range. \p Attributes is non-const because the runtime is
/// allowed to read/write back through the pointer in some attribute types
/// (e.g. \c HSA_AMD_SVM_ATTRIB_ACCESS_QUERY), so the wrapper takes a
/// mutable view to match the underlying ABI.
///
/// The HSA API aligns \p Ptr down and \p Size up to the nearest page
/// boundary. \c HSA_AMD_SVM_ATTRIB_ACCESS_QUERY and
/// \c HSA_AMD_SVM_ATTRIB_PREFETCH_LOCATION may not appear in
/// \p Attributes (use \c svmAttributesGet or \c svmPrefetchAsync
/// respectively).
/// \sa hsa_amd_svm_attributes_set
llvm::Error
svmAttributesSet(const ApiTableContainer<::AmdExtTable> &AmdExt, void *Ptr,
                 size_t Size,
                 llvm::MutableArrayRef<hsa_amd_svm_attribute_pair_t> Attributes);

/// Read SVM attributes back from the range <tt>[Ptr, Ptr + Size)</tt>.
/// Each entry in \p Attributes is updated in place: the entry's
/// \c attribute field selects what to query (and, for
/// \c HSA_AMD_SVM_ATTRIB_ACCESS_QUERY, also conveys the input
/// \c hsa_agent_t in the \c value field), and the wrapper writes the
/// queried value back into \c value.
///
/// \c HSA_AMD_SVM_ATTRIB_AGENT_ACCESSIBLE,
/// \c HSA_AMD_SVM_ATTRIB_AGENT_ACCESSIBLE_IN_PLACE, and
/// \c HSA_AMD_SVM_ATTRIB_PREFETCH_LOCATION may not appear in
/// \p Attributes.
/// \sa hsa_amd_svm_attributes_get
llvm::Error
svmAttributesGet(const ApiTableContainer<::AmdExtTable> &AmdExt, void *Ptr,
                 size_t Size,
                 llvm::MutableArrayRef<hsa_amd_svm_attribute_pair_t> Attributes);

/// Asynchronously migrate the SVM range <tt>[Ptr, Ptr + Size)</tt> to
/// \p Agent.
///
/// Migration begins once every dependency signal in \p DepSignals reaches
/// value zero. \p CompletionSignal (if non-zero-handle) is decremented
/// when the migration finishes; a negative value indicates the runtime
/// reported a failure. Pass \c hsa_signal_t{} (the default) for fire-and-
/// forget.
///
/// \p Ptr is aligned down and \p Size aligned up to the nearest page
/// boundary by the runtime.
/// \sa hsa_amd_svm_prefetch_async
llvm::Error
svmPrefetchAsync(const ApiTableContainer<::AmdExtTable> &AmdExt, void *Ptr,
                 size_t Size, hsa_agent_t Agent,
                 llvm::ArrayRef<hsa_signal_t> DepSignals = {},
                 hsa_signal_t CompletionSignal = hsa_signal_t{});

} // namespace luthier::hsa

#endif // LUTHIER_HSA_SVM_H
