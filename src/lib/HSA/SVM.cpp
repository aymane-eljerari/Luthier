//===-- SVM.cpp -----------------------------------------------------------===//
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
/// \file SVM.cpp
/// Implements the SVM / HMM HSA wrappers declared in \c SVM.h.
//===----------------------------------------------------------------------===//
#include "luthier/HSA/SVM.h"
#include "luthier/HSA/HsaError.h"
#include <hsa/hsa.h>
#include <hsa/hsa_ext_amd.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/FormatVariadic.h>

#define DEBUG_TYPE "luthier-hsa-svm"

namespace luthier::hsa {

llvm::Expected<bool>
systemIsSvmSupported(const ApiTableContainer<::CoreApiTable> &CoreApi) {
  bool Supported = false;
  const hsa_status_t S = CoreApi.callFunction<hsa_system_get_info>(
      static_cast<hsa_system_info_t>(HSA_AMD_SYSTEM_INFO_SVM_SUPPORTED),
      &Supported);
  if (S != HSA_STATUS_SUCCESS) {
    // HIP's rocclr Device::populateOCLDeviceConstants logs + treats this as
    // "HMM disabled" rather than failing. Do the same.
    LLVM_DEBUG(llvm::dbgs() << "[luthier] hsa_system_get_info("
                               "HSA_AMD_SYSTEM_INFO_SVM_SUPPORTED) failed "
                               "with status "
                            << S << "; treating HMM as unsupported.\n");
    return false;
  }
  return Supported;
}

llvm::Error svmAttributesSet(
    const ApiTableContainer<::AmdExtTable> &AmdExt, void *Ptr, size_t Size,
    llvm::MutableArrayRef<hsa_amd_svm_attribute_pair_t> Attributes) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_svm_attributes_set>(
          Ptr, Size, Attributes.data(), Attributes.size()),
      llvm::formatv("hsa_amd_svm_attributes_set failed for {0} (size {1}, "
                    "{2} attributes)",
                    Ptr, Size, Attributes.size()));
}

llvm::Error svmAttributesGet(
    const ApiTableContainer<::AmdExtTable> &AmdExt, void *Ptr, size_t Size,
    llvm::MutableArrayRef<hsa_amd_svm_attribute_pair_t> Attributes) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_svm_attributes_get>(
          Ptr, Size, Attributes.data(), Attributes.size()),
      llvm::formatv("hsa_amd_svm_attributes_get failed for {0} (size {1}, "
                    "{2} attributes)",
                    Ptr, Size, Attributes.size()));
}

llvm::Error
svmPrefetchAsync(const ApiTableContainer<::AmdExtTable> &AmdExt, void *Ptr,
                 size_t Size, hsa_agent_t Agent,
                 llvm::ArrayRef<hsa_signal_t> DepSignals,
                 hsa_signal_t CompletionSignal) {
  return LUTHIER_HSA_CALL_ERROR_CHECK(
      AmdExt.callFunction<hsa_amd_svm_prefetch_async>(
          Ptr, Size, Agent, static_cast<uint32_t>(DepSignals.size()),
          DepSignals.data(), CompletionSignal),
      llvm::formatv("hsa_amd_svm_prefetch_async failed for {0} (size {1}, "
                    "agent {2:x}, {3} dep signals)",
                    Ptr, Size, Agent.handle, DepSignals.size()));
}

} // namespace luthier::hsa
