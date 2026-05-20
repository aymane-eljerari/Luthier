//===-- DeviceToolCodeFatBinaryLoader.cpp ------------------------*- C++-*-===//
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
/// Drives \c DeviceToolCodeLoaderBase with the annotated-slot inputs the IR
/// plugin populates, plus the managed-variable path that is HIP-static
/// specific.
///
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/DeviceToolCodeFatBinaryLoader.h"
#include "luthier/HSA/Agent.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/HSA/MemoryPool.h"
#include <hsa/hsa_ext_amd.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/MemoryBufferRef.h>

#include <cstring>

#define DEBUG_TYPE "luthier-device-tool-code-fat-binary-loader"

namespace luthier {

/// The IR pass writes a \c { ptr, i64 } struct constant into each placeholder
/// slot, matching \c llvm::ArrayRef<T>'s ABI. If LLVM ever rearranges
/// \c ArrayRef's members, these asserts trip at compile time and the pass
/// needs to be updated in lockstep.
static_assert(sizeof(llvm::ArrayRef<void *>) ==
                  sizeof(void *) + sizeof(uint64_t),
              "llvm::ArrayRef ABI changed: expected { ptr, i64 } layout "
              "matching the IR pass's ConstantStruct initializer.");
static_assert(alignof(llvm::ArrayRef<void *>) == alignof(void *),
              "llvm::ArrayRef alignment changed.");
static_assert(sizeof(decltype(std::declval<llvm::ArrayRef<void *>>().size())) ==
                  sizeof(uint64_t),
              "llvm::ArrayRef length is no longer 64-bit.");

namespace {

/// Find a host fine-grain global memory pool suitable for backing managed
/// variables. HIP's \c hipMallocManaged path uses the CPU agent's
/// fine-grain pool because it's host-coherent and cross-agent-accessible
/// once we hand the pointer to \c hsa_amd_agents_allow_access.
llvm::Expected<hsa_amd_memory_pool_t>
selectManagedVarPool(const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
                     hsa_agent_t CpuAgent) {
  hsa_amd_memory_pool_t Found{};
  bool DidFind = false;
  LUTHIER_RETURN_ON_ERROR(hsa::agentIterateMemoryPools(
      AmdExt, CpuAgent,
      [&](hsa_amd_memory_pool_t Pool) -> llvm::Error {
        if (DidFind)
          return llvm::Error::success();
        llvm::Expected<bool> FGOrErr =
            hsa::memoryPoolIsFineGrained(AmdExt, Pool);
        LUTHIER_RETURN_ON_ERROR(FGOrErr.takeError());
        if (!*FGOrErr)
          return llvm::Error::success();
        llvm::Expected<bool> AllocOrErr =
            hsa::memoryPoolGetRuntimeAllocAllowed(AmdExt, Pool);
        LUTHIER_RETURN_ON_ERROR(AllocOrErr.takeError());
        if (!*AllocOrErr)
          return llvm::Error::success();
        Found = Pool;
        DidFind = true;
        return llvm::Error::success();
      }));
  if (!DidFind)
    return LUTHIER_MAKE_HSA_ERROR(
        "No host fine-grain memory pool available for managed-var allocation.");
  return Found;
}

} // namespace

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::loadAll
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeFatBinaryLoader::loadAll() {
  auto Core = CoreApiSnapshot.getTable();

  llvm::SmallVector<hsa_agent_t, 4> Agents;
  LUTHIER_RETURN_ON_ERROR(
      hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_GPU>(Core, Agents));

  LUTHIER_RETURN_ON_ERROR(loadOntoAgents(Agents));
  LUTHIER_RETURN_ON_ERROR(loadManagedVars(Agents));

  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::loadManagedVars
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeFatBinaryLoader::loadManagedVars(
    llvm::ArrayRef<hsa_agent_t> Agents) {
  if (InputManagedVars.empty())
    return llvm::Error::success();

  const auto Core = CoreApiSnapshot.getTable();
  const auto AmdExt = AmdExtSnapshot.getTable();

  // We need a CPU agent to host the fine-grain pool we allocate from.
  llvm::SmallVector<hsa_agent_t, 1> CpuAgents;
  LUTHIER_RETURN_ON_ERROR(
      hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_CPU>(Core, CpuAgents));
  if (CpuAgents.empty())
    return LUTHIER_MAKE_HSA_ERROR(
        "No CPU agent available for managed-var allocation.");

  auto PoolOrErr = selectManagedVarPool(AmdExt, CpuAgents.front());
  if (!PoolOrErr)
    return PoolOrErr.takeError();
  llvm::Expected<size_t> GranuleOrErr =
      hsa::memoryPoolGetRuntimeAllocGranule(AmdExt, *PoolOrErr);
  if (!GranuleOrErr)
    return GranuleOrErr.takeError();

  for (const auto &MV : InputManagedVars) {
    if (MV.Pointer == nullptr)
      continue;
    if (MV.Align > *GranuleOrErr)
      return LUTHIER_MAKE_HSA_ERROR(llvm::formatv(
          "Managed variable {0} alignment ({1}) exceeds pool granule "
          "({2}); over-aligned managed vars are not modelled.",
          MV.Name ? MV.Name : "<unnamed>", MV.Align, *GranuleOrErr));

    llvm::Expected<void *> AllocOrErr =
        hsa::memoryPoolAllocate(AmdExt, *PoolOrErr, MV.Size, /*Flags=*/0);
    if (!AllocOrErr)
      return AllocOrErr.takeError();
    void *Alloc = *AllocOrErr;

    // Copy initial value (fine-grain host memory => plain CPU store).
    if (MV.InitValue != nullptr && MV.Size > 0)
      std::memcpy(Alloc, MV.InitValue, MV.Size);

    // Grant every GPU agent access to the allocation so kernel-side
    // dereferences of the symbol resolve to this storage.
    if (!Agents.empty()) {
      if (auto E = hsa::agentsAllowAccess(AmdExt, Agents, Alloc))
        return llvm::joinErrors(std::move(E),
                                hsa::memoryPoolFree(AmdExt, Alloc));
    }

    // Publish the device-accessible pointer through the host shadow.
    *MV.Pointer = Alloc;

    ManagedVarRec Rec;
    Rec.HostShadowPtr = MV.Pointer;
    Rec.InitValue = MV.InitValue;
    Rec.Size = MV.Size;
    Rec.Align = MV.Align;
    Rec.Allocation = Alloc;
    ManagedVarRecords[MV.Pointer] = Rec;
  }
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::unloadAll
//===----------------------------------------------------------------------===//

void DeviceToolCodeFatBinaryLoader::unloadAll() noexcept {
  auto AmdExt = AmdExtSnapshot.getTable();

  // Free managed-var backing allocations. Match HIP's path: a single
  // pool_free per variable, no per-agent unmap (the access grant is
  // released implicitly by the free).
  for (auto &KV : ManagedVarRecords) {
    if (KV.second.Allocation == nullptr)
      continue;
    if (KV.second.HostShadowPtr != nullptr)
      *KV.second.HostShadowPtr = nullptr;
    if (auto E = hsa::memoryPoolFree(AmdExt, KV.second.Allocation)) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[luthier] managed-var free failed for "
                 << KV.second.Allocation << ": "
                 << llvm::toString(std::move(E)) << "\n");
    } else {
      consumeError(std::move(E));
    }
  }
  ManagedVarRecords.clear();

  // HandleToName is populated at construction and survives unload/rollback —
  // re-running ensureLoaded() shouldn't re-resolve handle names.

  // Base handles its own state: LoadedAgents, NameToAgentGlobal.
  clearLoadedState();
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::ensureLoaded
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeFatBinaryLoader::ensureLoaded() {
  std::lock_guard Lock(Mutex);
  if (State == LoadState::Loaded)
    return llvm::Error::success();
  if (auto E = loadAll()) {
    // Roll back partial state and stay in Pending so the next call
    // retries; the caller propagates this error and decides how to act.
    unloadAll();
    return E;
  }
  State = LoadState::Loaded;
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader — ctor/dtor
//===----------------------------------------------------------------------===//

std::unique_ptr<llvm::MemoryBuffer>
DeviceToolCodeFatBinaryLoader::buildBundleBuffer(
    llvm::ArrayRef<HipFatBinaryInfo> Slots, llvm::Error &Err) {
  llvm::ErrorAsOutParameter EAO(&Err);
  if (Err)
    return nullptr;
  if (Slots.size() > 1) {
    Err = LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
        "Luthier requires at most one fat binary per loader; received {0}. "
        "Use multiple Derived instances for multi-fat-binary tools.",
        Slots.size()));
    return nullptr;
  }
  if (Slots.empty() || Slots.front().Bundle == nullptr)
    return nullptr;
  const auto &S = Slots.front();
  return llvm::MemoryBuffer::getMemBuffer(
      llvm::StringRef(static_cast<const char *>(S.Bundle), S.Size), "fatbin",
      /*RequiresNullTerminator=*/false);
}

DeviceToolCodeFatBinaryLoader::DeviceToolCodeFatBinaryLoader(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
    const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &Loader,
    std::unique_ptr<llvm::MemoryBuffer> Bundle,
    llvm::ArrayRef<HipFunctionInfo> Functions,
    llvm::ArrayRef<HipDeviceVarInfo> DeviceVars,
    llvm::ArrayRef<HipManagedVarInfo> ManagedVars,
    llvm::ArrayRef<HipTextureInfo> Textures,
    llvm::ArrayRef<HipSurfaceInfo> Surfaces, llvm::Error &Err)
    : DeviceToolCodeLoaderBase(CoreApi, AmdExt, Loader, std::move(Bundle), Err),
      InputManagedVars(ManagedVars) {
  llvm::ErrorAsOutParameter EAO(&Err);
  if (Err)
    return;
  // Populate host-handle → device-name from every IR-pass-populated table.
  // HSA-free; lets lookupNameByHandle work before any deferred load runs.
  auto RecordHandle = [&](const void *Handle, const char *Name) {
    if (Handle != nullptr && Name != nullptr)
      HandleToName[Handle] = std::string(Name);
  };
  for (const auto &E : Functions)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &E : DeviceVars)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &E : Textures)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &E : Surfaces)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &MV : ManagedVars)
    RecordHandle(MV.Pointer, MV.Name);
}

DeviceToolCodeFatBinaryLoader::~DeviceToolCodeFatBinaryLoader() {
  // Skip teardown if loadAll never ran (or already rolled back on failure).
  if (State == LoadState::Loaded)
    unloadAll();
}

} // namespace luthier
