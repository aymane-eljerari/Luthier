//===-- ToolExecutableLoaderTrait.h ------------------------------*- C++ -*-===//
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
/// CRTP trait responsible for taking instrumented relocatables produced by
/// the IModule MIR codegen pipeline and loading them onto an HSA agent.
///
/// The tool's own fat-binary state (parsed bundles, per-agent HSA executables,
/// handle → name maps, embedded \c .llvmbc cache, managed-var allocations) is
/// owned by \c DeviceToolCodeFatBinaryLoader; this trait stays narrowly
/// focused on the instrumented-executable path so the two lifecycles don't
/// entangle.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_TOOL_EXECUTABLE_LOADER_TRAIT_H
#define LUTHIER_TOOLING_TOOL_EXECUTABLE_LOADER_TRAIT_H

#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include <hsa/hsa.h>
#include <hsa/hsa_ven_amd_loader.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/Support/Error.h>
#include <cstdint>

namespace luthier {

/// \brief CRTP trait that links + loads instrumented relocatables onto an
/// HSA agent.
template <typename Derived> class ToolExecutableLoaderTrait {
public:
  ToolExecutableLoaderTrait(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader)
      : CoreApiSnapshot(CoreApi), AmdExtSnapshot(AmdExt),
        LoaderApiSnapshot(Loader) {}

  /// Wrappers are NOT installed by this trait; nothing to uninstall.
  ~ToolExecutableLoaderTrait() = default;

  ToolExecutableLoaderTrait(const ToolExecutableLoaderTrait &) = delete;
  ToolExecutableLoaderTrait &
  operator=(const ToolExecutableLoaderTrait &) = delete;

  /// Link an instrumented relocatable produced by \c HSATool::buildPipeline
  /// into an HSA executable and load it onto the agent. Stub for now; the
  /// real HSA link + load lands on a physical GPU.
  llvm::Error loadInstrumented(hsa_agent_t Agent,
                               llvm::ArrayRef<uint8_t> Relocatable,
                               llvm::StringRef Preset) {
    (void)Agent;
    (void)Relocatable;
    (void)Preset;
    return llvm::Error::success();
  }

protected:
  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiSnapshot;
  const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExtSnapshot;
  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &LoaderApiSnapshot;
};

} // namespace luthier

#endif // LUTHIER_TOOLING_TOOL_EXECUTABLE_LOADER_TRAIT_H
