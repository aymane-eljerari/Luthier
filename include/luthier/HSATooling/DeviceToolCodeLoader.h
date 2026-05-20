//===-- DeviceToolCodeLoader.h -----------------------------------*- C++-*-===//
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
/// \file DeviceToolCodeLoader.h
/// Defines the \c DeviceToolCodeLoader in charge of loading the device code of
/// a single tool onto GPU agents on the system
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_DEVICE_TOOL_CODE_LOADER_H
#define LUTHIER_TOOLING_DEVICE_TOOL_CODE_LOADER_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/Agent.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include <cstdint>
#include <hsa/hsa.h>
#include <hsa/hsa_ext_amd.h>
#include <hsa/hsa_ven_amd_loader.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/MemoryBufferRef.h>
#include <llvm/TargetParser/SubtargetFeature.h>
#include <llvm/TargetParser/Triple.h>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

namespace luthier {

/// \brief In charge of loading the device code of a single Luthier tool
/// translation unit (TU) onto GPU HSA Agents attached to the system. Also
/// extracts and provides access to the LLVM bitcode of the instrumentation
/// module appropriate for the kernel being instrumented
/// \note This class only handles loading the same source (TU) compiled for
/// multiple GPU targets running on the system. For loading multiple TUs, use
/// multiple instances of this class
class DeviceToolCodeLoader {
protected:
  /// Per-agent HSA handles produced by loading one code object (slice) into an
  /// agent attached to the system
  struct SliceLoadRecord {
    hsa_code_object_reader_t Reader{};
    hsa_loaded_code_object_t LCO{};
    hsa_executable_t Executable{};
  };

  /// One entry per distinct LLVM-tuple (Triple/CPU/Features) the loader was
  /// given. Populated at construction (HSA-free); \c loadOntoAgents derives
  /// the \c hsa_isa_t for each entry at load time as needed.
  ///
  /// HSA-level ISA matching is coarser than LLVM's codegen target (wave mode,
  /// cu mode, and other kernel-descriptor-driven feature bits are invisible
  /// to HSA), so a bundle may legitimately ship multiple LLVM-tuple variants
  /// with the same \c hsa_isa_t (e.g. wave32 + wave64 for gfx10+). All of
  /// them are cached and surfaced via \c getEmbeddedModule; the loader picks
  /// one per agent at load time.
  struct SliceCacheEntry {
    /// Non-owning view of the slice's ELF bytes. Lives in
    /// \c RetainedBuffers (bundle path) or in the caller's input buffers
    /// (code-object-array path).
    llvm::MemoryBufferRef CodeObject;
    /// Non-owning view of the slice's \c .llvmbc section bytes.
    llvm::MemoryBufferRef Bitcode;
    /// ISA of the slice
    llvm::Triple TT;
    std::string CPU;
    llvm::SubtargetFeatures Features;
  };

  /// Bookkeeping for an allocated dynamic managed variable. One per
  /// allocation performed by \c loadDynamicManagedVars.
  struct ManagedVarRec {
    /// View into the slice ELF's symbol name (loader-lifetime, alive as
    /// long as \c RetainedBuffers is). Also serves as the lookup key for
    /// \c NameToManagedAlloc, so the lifetimes match.
    llvm::StringRef Name;
    void *Allocation{nullptr};
    /// Bytes actually reserved at the allocation API level — equal to the
    /// requested size on the pool path, and to the page-rounded size on
    /// the SVM/HMM path. \c freeManagedStorage needs this.
    size_t AllocSize{0};
    /// Requested size from the \c .managed companion section. May be less
    /// than \c AllocSize on the SVM path.
    size_t Size{0};
    unsigned Align{0};
    /// True iff this allocation took the SVM/HMM path. Selects the
    /// matching free API.
    bool ViaSvm{false};
  };

  std::recursive_mutex Mutex;

  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiSnapshot;
  const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExtSnapshot;
  const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
      &LoaderApiSnapshot;

  /// Device-side global-variable name → per-agent \c hsa_executable_symbol_t
  /// handle. Populated by \c loadOntoAgents for every global-variable symbol
  /// resolved on every loaded agent. Kernels and indirect functions are
  /// skipped — kernel launch goes through AQL packets with the kernel
  /// descriptor address (separate API), and indirect-function symbols don't
  /// have a meaningful host-side handle. Storing the symbol handle rather
  /// than the address gives callers access to size, alignment, and other
  /// metadata via \c hsa::executableSymbolGet* without re-resolving.
  llvm::StringMap<llvm::DenseMap<hsa_agent_t, hsa_executable_symbol_t>>
      NameToAgentGlobal;

  /// All slices the loader holds, keyed by canonical LLVM ISA string (see
  /// \c canonicalLLVMISAKey). Populated at construction; immutable
  /// thereafter (except for the lazy \c IsaHandle field).
  llvm::StringMap<SliceCacheEntry> Slices;

  /// Bundles + any decompressed payloads the loader has been handed. Owned
  /// for the loader's lifetime so that \c Slices' views into these bytes
  /// remain valid. The code-object-array constructor doesn't populate this
  /// (caller-owned buffers).
  llvm::SmallVector<std::unique_ptr<llvm::MemoryBuffer>, 2> RetainedBuffers;

  /// Load record for every agent the loader successfully loaded a slice on
  llvm::DenseMap<hsa_agent_t, SliceLoadRecord> PerAgentLoadRecords;

  /// One \c ManagedVarRec per allocation produced by
  /// \c loadDynamicManagedVars. Freed by \c freeManagedVars during
  /// \c clearLoadedState.
  llvm::DenseMap<void *, ManagedVarRec> ManagedVarRecords;

  /// Reverse index: managed-variable base symbol name → allocation
  /// pointer. Populated alongside \c ManagedVarRecords in
  /// \c loadDynamicManagedVars; consulted by \c lookupManagedVarAllocation
  /// (used by the fat-binary loader to write each
  /// \c __hipRegisterManagedVar host shadow). Keys are \c StringRefs into
  /// the loader-retained ELF symbol tables.
  llvm::StringMap<void *> NameToManagedAlloc;

  /// Bundle-path constructor: takes ownership of the input \c MemoryBuffer
  /// and parses it as a Clang offload bundle. Sets \p Err on parse failure
  /// or if two slices in the bundle share the same canonical LLVM ISA.
  /// HSA-free.
  DeviceToolCodeLoader(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      std::unique_ptr<llvm::MemoryBuffer> Bundle, llvm::Error &Err);

  /// Code-object-array constructor: each \p CodeObjects entry is treated as
  /// an independent AMDGCN code object with its own LLVM ISA. The loader
  /// holds non-owning views into the caller's buffers — the caller must
  /// keep them alive for the loader's lifetime. Sets \p Err if two entries
  /// share the same canonical LLVM ISA. HSA-free.
  DeviceToolCodeLoader(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      llvm::ArrayRef<std::unique_ptr<llvm::MemoryBuffer>> CodeObjects,
      llvm::Error &Err);

  ~DeviceToolCodeLoader();

  /// Walk \c Slices, resolving each entry's \c IsaHandle on the first
  /// invocation (HSA must be ready by this point — caller's contract).
  /// Then for every agent in \p Agents with a compatible slice, create +
  /// load + freeze a per-agent HSA executable and populate
  /// \c NameToAgentGlobal with its global variables. Idempotent on agents
  /// already loaded.
  llvm::Error loadOntoAgents(llvm::ArrayRef<hsa_agent_t> Agents);

  /// Canonical hashable key for an LLVM ISA tuple. Deterministic: features
  /// are sorted before stringification, so the same logical tuple always
  /// produces the same key regardless of insertion order.
  static std::string canonicalLLVMISAKey(const llvm::Triple &T,
                                         llvm::StringRef CPU,
                                         const llvm::SubtargetFeatures &F);

  /// Symmetric teardown: frees managed-variable allocations, destroys
  /// every HSA executable + code-object reader, clears \c PerAgentLoadRecords
  /// and \c NameToAgentGlobal, and resets \c State to \c Pending. Does NOT
  /// discard the slice cache or retained buffers — those are bound to the
  /// loader for its lifetime. Swallows + logs HSA errors so it is safe to
  /// call from destructors. Idempotent.
  llvm::Error clearLoadedState();

  enum class LoadState { Pending, Loaded };
  LoadState State{LoadState::Pending};

  /// Deferred HSA-side load. First call collects every GPU agent, runs
  /// \c loadOntoAgents, then \c loadDynamicManagedVars. On success
  /// transitions \c State to \c Loaded; on failure invokes
  /// \c clearLoadedState (which frees any partial dynamic-managed-var
  /// state) and stays \c Pending so the next call retries
  llvm::Error ensureLoaded();

  /// Discover and allocate every dynamic managed variable advertised by
  /// the loaded slices. Each slice's ELF symbol table is scanned for
  /// pairs <tt>(&lt;base&gt;, &lt;base&gt;.managed)</tt>: the base symbol
  /// is pointer-sized device storage the kernel reads, and the
  /// \c .managed companion carries the size, alignment, and initial
  /// bytes. The same managed var typically appears in every slice
  /// (different ISAs of the same TU), so discoveries dedup by base name.
  ///
  /// For each unique managed var found, allocates host-coherent storage
  /// via \c allocateManagedStorage (HMM or pool path, picked
  /// automatically), copies the initial bytes in, and publishes the
  /// device-accessible pointer into every agent's loaded image of the
  /// base symbol via \c hsa_memory_copy. The pool/granule query needed
  /// by the non-HMM path is performed lazily on the first allocation
  /// taking that path, so this method is zero-cost when no managed vars
  /// exist.
  llvm::Error loadDynamicManagedVars(llvm::ArrayRef<hsa_agent_t> Agents);

  /// Free every allocation in \c ManagedVarRecords (using
  /// \c hsa_amd_memory_pool_free) and clear the bookkeeping map.
  /// Swallows and logs errors so it is safe to call from destructors.
  /// Idempotent.
  llvm::Error freeManagedVars();

  /// Pick a host fine-grain memory pool suitable for backing managed
  /// variables (HIP's \c hipMallocManaged path uses the CPU agent's
  /// fine-grain pool because it's host-coherent and cross-agent-accessible
  /// via \c hsa_amd_agents_allow_access).
  static llvm::Expected<hsa_amd_memory_pool_t>
  selectManagedVarPool(const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
                       hsa_agent_t CpuAgent);

  /// Result of one managed-variable storage allocation. The full state
  /// needed to free it correctly is captured here so the free path doesn't
  /// have to re-decide which API path was used.
  struct ManagedAlloc {
    /// Allocation pointer. CPU-side memcpy targets, agent base-symbol
    /// publish target, and free input.
    void *Ptr{nullptr};
    /// Bytes actually reserved. On the HMM path this is rounded up to the
    /// system page size; on the pool path this matches the requested size.
    /// \c freeManagedStorage hands this back to the underlying free API.
    size_t AllocSize{0};
    /// True if the allocation came from \c hsa_amd_vmem_address_reserve_align
    /// (HMM path); false if it came from \c hsa_amd_memory_pool_allocate
    /// (legacy non-HMM path). Selects which free API to call.
    bool ViaSvm{false};
  };

  /// HMM-aware managed-storage allocation.
  ///
  /// On HMM-supported systems (\p HmmSupported = true) takes the
  /// \c hipMallocManaged HMM path: reserves a page-aligned VA range via
  /// \c hsa_amd_vmem_address_reserve_align with
  /// \c HSA_AMD_VMEM_ADDRESS_NO_REGISTER, then declares it accessible from
  /// every entry in \p GpuAgents via
  /// \c hsa_amd_svm_attributes_set(\c HSA_AMD_SVM_ATTRIB_AGENT_ACCESSIBLE).
  /// CPU access is implicit; no \c agents_allow_access call. \p Pool is
  /// ignored on this path.
  ///
  /// On non-HMM systems (\p HmmSupported = false) takes the legacy
  /// memory-pool path: \c hsa_amd_memory_pool_allocate(\p Pool) +
  /// \c hsa_amd_agents_allow_access(\p GpuAgents).
  ///
  /// Returns a populated \c ManagedAlloc on success; the caller frees via
  /// \c freeManagedStorage.
  static llvm::Expected<ManagedAlloc>
  allocateManagedStorage(const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
                         llvm::ArrayRef<hsa_agent_t> GpuAgents,
                         hsa_amd_memory_pool_t Pool, size_t Size,
                         unsigned Align, bool HmmSupported);

  /// Free a \c ManagedAlloc previously produced by
  /// \c allocateManagedStorage, dispatching to the matching free API based
  /// on \c ViaSvm.
  static llvm::Error
  freeManagedStorage(const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
                     const ManagedAlloc &Alloc);

  /// Lazily probe \c HSA_AMD_SYSTEM_INFO_SVM_SUPPORTED and cache the
  /// result for the loader's lifetime (HMM support is a system property,
  /// so one query is enough). On query failure returns \c false (matches
  /// HIP's rocclr fallback). Caller must hold \c Mutex (the cache field
  /// is \c std::optional and unsynchronized).
  llvm::Expected<bool> getHmmSupported();

  /// Cached \c HSA_AMD_SYSTEM_INFO_SVM_SUPPORTED query result. Populated
  /// on first \c getHmmSupported() call after HSA is up.
  std::optional<bool> HmmSupportedCache;

  /// Internal helper used by both constructors. Parses one ELF as an AMDGCN
  /// object file, extracts its LLVM ISA tuple + \c .llvmbc bytes, and
  /// inserts a new entry into \c Slices. Returns an error on parse failure
  /// or duplicate ISA. Dynamic managed-var discovery is deferred to load
  /// time (see \c loadDynamicManagedVars).
  llvm::Error addSlice(llvm::MemoryBufferRef CodeObject);

public:
  DeviceToolCodeLoader(const DeviceToolCodeLoader &) = delete;
  DeviceToolCodeLoader &operator=(const DeviceToolCodeLoader &) = delete;

  /// Resolve a device-side global-variable name to its
  /// \c hsa_executable_symbol_t on \p Agent. Callers needing the loaded
  /// address, size, or alignment derive them via
  /// \c hsa::executableSymbolGet*. Kernels are intentionally not cached;
  /// this method returns "not found" for kernel symbols.
  /// Triggers \c ensureLoaded on first call.
  llvm::Expected<hsa_executable_symbol_t>
  lookupGlobalVariable(llvm::StringRef Name, hsa_agent_t Agent) {
    std::lock_guard Lock(Mutex);
    if (auto E = ensureLoaded())
      return std::move(E);
    auto It = NameToAgentGlobal.find(Name);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        It != NameToAgentGlobal.end(),
        "Global variable has no per-agent symbol record."));
    auto AgentIt = It->second.find(Agent);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        AgentIt != It->second.end(),
        "Global variable is not loaded on the requested agent."));
    return AgentIt->second;
  }

  /// Resolve a managed-variable base symbol name to the host-allocated
  /// storage pointer the loader publishes into every agent's image of
  /// that symbol. Subclasses (e.g. the fat-binary loader) use this to
  /// write the \c void** host shadow that
  /// \c __hipRegisterManagedVar registered, so host-side reads of the
  /// managed variable point at the same storage the device kernels see.
  ///
  /// Triggers \c ensureLoaded on first call. The lookup is by
  /// loader-internal base symbol name (ELF symbol minus the \c .managed
  /// suffix), which matches the device name passed to
  /// \c __hipRegisterManagedVar.
  llvm::Expected<void *> lookupManagedVarAllocation(llvm::StringRef Name) {
    std::lock_guard Lock(Mutex);
    if (auto E = ensureLoaded())
      return std::move(E);
    auto It = NameToManagedAlloc.find(Name);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        It != NameToManagedAlloc.end(),
        llvm::formatv("No managed-variable allocation for symbol '{0}'", Name)
            .str()));
    return It->second;
  }

  /// Parse the embedded tool bitcode for the requested LLVM ISA
  /// tuple into \p Ctx
  /// \note This method is safe to use before \c ensureLoad has been invoked
  llvm::Expected<std::unique_ptr<llvm::Module>>
  getEmbeddedModule(const llvm::Triple &T, llvm::StringRef CPU,
                    const llvm::SubtargetFeatures &Features,
                    llvm::LLVMContext &Ctx);
};

} // namespace luthier

#endif // LUTHIER_TOOLING_DEVICE_TOOL_CODE_LOADER_H
