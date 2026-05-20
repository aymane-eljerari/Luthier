//===-- DeviceToolCodeLoaderBase.h -------------------------------*- C++-*-===//
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
/// \file DeviceToolCodeLoaderBase.h
/// Shared base class for the static fat-binary loader
/// (\c DeviceToolCodeFatBinaryLoader) and the dynamic module loader.
///
/// Following the one-loader-one-module rule, the loader's input bytes are
/// supplied at construction. Two input shapes are accepted:
///   - a single Clang offload bundle (compressed or uncompressed)
///   - an array of pre-unbundled code-object buffers, one per LLVM ISA
///
/// Construction is HSA-free: the constructor parses the input, extracts the
/// LLVM-form ISA tuple and the embedded \c .llvmbc bytes of each slice, and
/// caches them in \c Slices keyed by canonical LLVM ISA. Duplicate ISA
/// entries surface as an error.
///
/// HSA-side resolution (mapping each slice to an \c hsa_isa_t and creating
/// per-agent executables) is deferred until \c loadOntoAgents is invoked
/// by a subclass — by which time the caller guarantees the rocprofiler API
/// snapshots are populated.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_DEVICE_TOOL_CODE_LOADER_BASE_H
#define LUTHIER_TOOLING_DEVICE_TOOL_CODE_LOADER_BASE_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/Agent.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include <cstdint>
#include <hsa/hsa.h>
#include <hsa/hsa_ven_amd_loader.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/MemoryBufferRef.h>
#include <llvm/TargetParser/SubtargetFeature.h>
#include <llvm/TargetParser/Triple.h>
#include <memory>
#include <mutex>
#include <string>

namespace luthier {

/// \brief Non-templated, non-public-API base shared by every device-code
/// loader. Provides the HSA-free parse + per-agent code-object-load machinery
/// and the lookup caches; subclasses drive when the deferred HSA-side load
/// runs and what host-side bookkeeping wraps it.
class DeviceToolCodeLoaderBase {
protected:
  /// Per-agent HSA handles produced by loading one code object (slice) into one
  /// agent
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
    llvm::Triple T;
    std::string CPU;
    llvm::SubtargetFeatures Features;
  };

  /// Description of one dynamic managed variable, discovered from the
  /// code-object symbol table. Dynamic managed vars are detected by the
  /// loader itself (no host-side shadow exists) by finding pairs of
  /// symbols where one has a \c ".managed" suffix; the base symbol is
  /// pointer-sized device storage that kernel code dereferences, and the
  /// \c .managed companion carries the size + initial bytes.
  struct ManagedVarInfo {
    /// Non-owning view into the ELF symbol string table for the base
    /// symbol's name. Alive for the loader's lifetime (slice ELFs are
    /// retained).
    llvm::StringRef BaseSymbolName;
    size_t Size{0};
    unsigned Align{0};
    /// View into the slice ELF's \c .managed-companion section bytes.
    /// Alive for the loader's lifetime (slice ELFs are retained).
    llvm::ArrayRef<uint8_t> InitValue;
  };

  /// Bookkeeping for an allocated dynamic managed variable. One per
  /// allocation performed by \c loadDynamicManagedVars.
  struct ManagedVarRec {
    void *Allocation{nullptr};
    size_t Size{0};
    unsigned Align{0};
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

  /// Dynamic managed variables discovered while parsing the loader's
  /// input. Populated at construction (HSA-free) by \c addSlice scanning
  /// each slice's symbol table for \c .managed-suffixed companions.
  llvm::SmallVector<ManagedVarInfo, 0> DynamicManagedVars;

  /// One \c ManagedVarRec per allocation produced by
  /// \c loadDynamicManagedVars. Freed by \c freeManagedVars during
  /// \c clearLoadedState.
  llvm::DenseMap<void *, ManagedVarRec> ManagedVarRecords;

  /// Bundle-path constructor: takes ownership of the input \c MemoryBuffer
  /// and parses it as a Clang offload bundle. Sets \p Err on parse failure
  /// or if two slices in the bundle share the same canonical LLVM ISA.
  /// HSA-free.
  DeviceToolCodeLoaderBase(
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
  DeviceToolCodeLoaderBase(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
      const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
      const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
          &Loader,
      llvm::ArrayRef<std::unique_ptr<llvm::MemoryBuffer>> CodeObjects,
      llvm::Error &Err);

  ~DeviceToolCodeLoaderBase();

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
  void clearLoadedState() noexcept;

  enum class LoadState { Pending, Loaded };
  LoadState State{LoadState::Pending};

  /// Deferred HSA-side load. First call collects every GPU agent, runs
  /// \c loadOntoAgents, then \c loadDynamicManagedVars, then the
  /// \c postLoadHook subclass extension. On success transitions \c State
  /// to \c Loaded; on failure invokes \c preUnloadHook +
  /// \c clearLoadedState and stays \c Pending so the next call retries.
  llvm::Error ensureLoaded();

  /// For every \c ManagedVarInfo discovered in \c DynamicManagedVars,
  /// allocate managed memory from a host fine-grain pool, copy the
  /// initial bytes in (from the cached \c .managed-symbol view), grant
  /// every agent access, and publish the device-accessible pointer into
  /// each agent's loaded image of the base symbol via \c hsa_memory_copy.
  /// No-op if \c DynamicManagedVars is empty.
  llvm::Error loadDynamicManagedVars(llvm::ArrayRef<hsa_agent_t> Agents);

  /// Free every allocation in \c ManagedVarRecords (using
  /// \c hsa_amd_memory_pool_free) and clear the bookkeeping map.
  /// Swallows and logs errors so it is safe to call from destructors.
  /// Idempotent.
  void freeManagedVars() noexcept;

  /// Subclass extension point for additional load-time work, called by
  /// \c ensureLoaded after the base's own load steps. Default no-op.
  /// The static fat-binary loader overrides this for the
  /// \c __hipRegisterManagedVar path (host-shadow-pointer publish).
  virtual llvm::Error postLoadHook(llvm::ArrayRef<hsa_agent_t> Agents) {
    return llvm::Error::success();
  }

  /// Cleanup hook paired with \c postLoadHook. Default no-op. Called by
  /// \c ensureLoaded on rollback, and must be called from the subclass
  /// destructor if \c State is \c Loaded (base destructor only tears
  /// down base state).
  virtual void preUnloadHook() noexcept {}

  /// Internal helper used by both constructors. Parses one ELF as an AMDGCN
  /// object file, extracts its LLVM ISA tuple + \c .llvmbc bytes, and
  /// inserts a new entry into \c Slices. Returns an error on parse failure
  /// or duplicate ISA.
  llvm::Error addSlice(llvm::MemoryBufferRef CodeObject);

public:
  DeviceToolCodeLoaderBase(const DeviceToolCodeLoaderBase &) = delete;
  DeviceToolCodeLoaderBase &
  operator=(const DeviceToolCodeLoaderBase &) = delete;

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

  /// Parse the embedded \c .llvmbc bytes cached for the requested LLVM ISA
  /// tuple into \p Ctx. The bitcode cache is populated at construction
  /// (HSA-free), so this method works even before \c loadOntoAgents has run.
  llvm::Expected<std::unique_ptr<llvm::Module>>
  getEmbeddedModule(const llvm::Triple &T, llvm::StringRef CPU,
                    const llvm::SubtargetFeatures &Features,
                    llvm::LLVMContext &Ctx);

  /// One entry per LLVM ISA tuple currently cached. Lets tools enumerate
  /// the variants the bundle shipped (e.g. wave32 + wave64 of the same
  /// gfx target) before deciding which one to JIT against.
  struct CachedISA {
    llvm::Triple T;
    std::string CPU;
    llvm::SubtargetFeatures Features;
  };
  llvm::SmallVector<CachedISA, 4> getCachedISAs();
};

} // namespace luthier

#endif // LUTHIER_TOOLING_DEVICE_TOOL_CODE_LOADER_BASE_H
