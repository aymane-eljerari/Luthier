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
/// Implementation of the non-template helpers consumed by
/// \c DeviceToolCodeFatBinaryLoader<Derived>.
///
/// Fat-binary wrapper layout follows HIP's \c __CudaFatBinaryWrapper
/// (compatible w/ \c clr/hipamd/src/hip_platform.cpp): a 16-byte header
/// followed by an inline pointer to a Clang offload bundle. The bundle
/// uncompressed layout is taken from \c clr/hipamd/src/hip_code_object.hpp:
/// magic \c "__CLANG_OFFLOAD_BUNDLE__" (24 bytes), a 64-bit number of
/// bundles, then each entry \c {u64 offset, u64 size, u64 idSize, char id[]}.
///
/// Bundle entries with id prefixes \c "hip-amdgcn-amd-amdhsa-" or
/// \c "hipv4-amdgcn-amd-amdhsa-" are AMD GPU code objects; everything else
/// (host slots) is ignored. The gfx-id suffix is matched against
/// \c HSA_AGENT_INFO_NAME for each GPU agent.
///
/// Embedded bitcode follows \c CreateAndEmbedIModulePass: the device-side
/// module is bitcode-written and inserted into the ELF as section
/// \c ".llvmbc" via \c llvm::embedBufferInModule.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/DeviceToolCodeFatBinaryLoader.h"
#include "luthier/HSA/Agent.h"
#include "luthier/HSA/CodeObjectReader.h"
#include "luthier/HSA/Executable.h"
#include "luthier/HSA/ExecutableSymbol.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/HSA/ISA.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include "luthier/Object/ObjectFileUtils.h"
#include <hsa/hsa_ext_amd.h>
#include <llvm/ADT/SmallString.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/BinaryFormat/Magic.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/Object/ELFObjectFile.h>
#include <llvm/Object/OffloadBundle.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/MemoryBufferRef.h>

#include <cstring>

#define DEBUG_TYPE "luthier-device-tool-code-fat-binary-loader"

namespace luthier {

/// The IR pass writes a \c { ptr, i64 } struct constant into each placeholder
/// slot, matching \c llvm::ArrayRef<T>'s ABI. If LLVM ever rearranges
/// \c ArrayRef's members, these asserts trip at compile time and the pass
/// needs to be updated in lockstep
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

//===----------------------------------------------------------------------===//
// Clang offload bundle parsing
//===----------------------------------------------------------------------===//

/// One AMD code-object slice extracted from a Clang offload bundle. The
/// LLVM-form ISA comes from \c luthier::object::getObjectFileTargetTuple,
/// which decodes \c e_flags including XNACK/SRAMECC into the
/// \c SubtargetFeatures list. The bundle entry id is not consulted. The
/// xnack/sramecc state is read directly off \c Features whenever the
/// matching logic needs it — no separate cached tri-state.
struct BundleSlice {
  hsa_isa_t IsaHandle{};
  llvm::Triple Triple;
  std::string CPU;
  llvm::SubtargetFeatures Features;
  /// Raw ELF bytes (view into either the supplied bundle buffer for
  /// uncompressed bundles or the decompressed buffer the caller owns
  /// alongside the slice list).
  llvm::StringRef Elf;
};

/// Inspect \p F for a \c +Name/-Name entry. \c std::nullopt means the
/// feature isn't pinned in the ELF (\c Any — portable across both
/// states); \c true means \c +Name (\c On); \c false means \c -Name
/// (\c Off). Matches the semantics LLVM's \c SubtargetFeatures itself
/// uses internally.
std::optional<bool> featureState(const llvm::SubtargetFeatures &F,
                                 llvm::StringRef Name) {
  for (const std::string &S : F.getFeatures()) {
    llvm::StringRef Ref(S);
    if (!Ref.empty() && (Ref.front() == '+' || Ref.front() == '-')) {
      if (Ref.drop_front() == Name)
        return Ref.front() == '+';
    }
  }
  return std::nullopt;
}

/// Number of feature dimensions left as \c Any (i.e. absent from the
/// slice's \c SubtargetFeatures). Lower is more specific — used to sort
/// slices so exact-match entries beat any-match entries when both could
/// satisfy an agent's ISA.
unsigned anyCount(const BundleSlice &S) {
  return (featureState(S.Features, "xnack") ? 0 : 1) +
         (featureState(S.Features, "sramecc") ? 0 : 1);
}

/// Copy \p Source and pin any \c xnack/sramecc dimension that was left
/// as \c Any to a concrete value. Used to expand \c Any features into
/// the concrete ISA names the agent's iterator would yield.
llvm::SubtargetFeatures
concretizeFeatures(const llvm::SubtargetFeatures &Source, bool ConcreteXnackOn,
                   bool ConcreteSrameccOn) {
  llvm::SubtargetFeatures Out = Source;
  if (!featureState(Source, "xnack"))
    Out.AddFeature("xnack", ConcreteXnackOn);
  if (!featureState(Source, "sramecc"))
    Out.AddFeature("sramecc", ConcreteSrameccOn);
  return Out;
}

/// Parses the Clang offload \p Bundle entries into \p Slices
///
/// Handles both compressed and uncompressed FAT binaries
///
/// In case of \p Bundle being a compressed FAT binary, \p DecompressedHolder
/// will hold the owning memory buffer of the decompressed version of \p Bundle
/// on return
///
/// \note The ISA of each Slice entry will be populated by checking the
/// ISA of the code object slice directly; The entry ID is ignored
llvm::Error
parseOffloadBundle(const hsa::ApiTableContainer<::CoreApiTable> &Core,
                   llvm::MemoryBufferRef Bundle,
                   llvm::SmallVectorImpl<BundleSlice> &Slices,
                   std::unique_ptr<llvm::MemoryBuffer> &DecompressedHolder) {
  if (Bundle.getBufferSize() == 0)
    return LUTHIER_MAKE_GENERIC_ERROR("Empty fat-binary bundle.");

  auto Magic = llvm::identify_magic(Bundle.getBuffer());

  llvm::MemoryBufferRef ParseBuf = Bundle;
  bool Decompressed = false;
  if (Magic == llvm::file_magic::offload_bundle_compressed) {
    auto Input = llvm::MemoryBuffer::getMemBuffer(
        Bundle, /*RequiresNullTerminator=*/false);
    auto DecompOrErr =
        llvm::object::CompressedOffloadBundle::decompress(*Input, nullptr);
    if (!DecompOrErr)
      return DecompOrErr.takeError();
    DecompressedHolder = std::move(*DecompOrErr);
    ParseBuf = DecompressedHolder->getMemBufferRef();
    Decompressed = true;
  } else if (Magic != llvm::file_magic::offload_bundle) {
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Bundle does not start with __CLANG_OFFLOAD_BUNDLE__ or CCOB magic.");
  }

  auto BundleOrErr = llvm::object::OffloadBundleFatBin::create(
      ParseBuf, /*SectionOffset=*/0, "fatbin", Decompressed);
  if (!BundleOrErr)
    return BundleOrErr.takeError();

  for (auto &Entry : (*BundleOrErr)->getEntries()) {
    llvm::MemoryBufferRef CodeObjectBuf{
        llvm::StringRef(ParseBuf.getBufferStart() + Entry.Offset, Entry.Size),
        "code object buffer"};
    auto CodeObjectObjFileOrErr =
        llvm::object::ObjectFile::createObjectFile(CodeObjectBuf);
    if (!CodeObjectObjFileOrErr)
      return CodeObjectObjFileOrErr.takeError();

    /// Skip non-AMDGCN object files in the bundle
    if (llvm::isa<object::AMDGCNObjectFile>(*CodeObjectObjFileOrErr))
      continue;

    auto &AMDGCNObjFile =
        llvm::cast<object::AMDGCNObjectFile>(**CodeObjectObjFileOrErr);

    /// Parse the Object File's ISA so that we know where to load it
    auto TupleOrErr = luthier::object::getObjectFileTargetTuple(AMDGCNObjFile);
    if (!TupleOrErr) {
      return TupleOrErr.takeError();
    }
    auto &[Triple, CPU, Features] = *TupleOrErr;

    /// Get the HSA ISA handle associated with the binary
    llvm::Expected<hsa_isa_t> IsaOrErr =
        hsa::isaFromLLVM(Core, Triple, CPU, Features);
    if (!IsaOrErr) {
      return IsaOrErr.takeError();
    }

    BundleSlice Slice;
    Slice.IsaHandle = *IsaOrErr;
    Slice.Triple = std::move(Triple);
    Slice.CPU = CPU.str();
    Slice.Features = std::move(Features);
    Slice.Elf = CodeObjectBuf.getBuffer();
    Slices.push_back(std::move(Slice));
  }
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// Embedded bitcode extraction (.llvmbc section)
//===----------------------------------------------------------------------===//

/// Extract the raw \c .llvmbc section bytes from an agent ELF slice into a
/// caller-owned \c MemoryBuffer. We deliberately do NOT parse the bytes
/// here — parsing into an \c LLVMContext is deferred to
/// \c getEmbeddedModule so the cache stays context-free.
llvm::Expected<std::unique_ptr<llvm::MemoryBuffer>>
extractEmbeddedBitcode(llvm::StringRef Elf) {
  auto ObjOrErr =
      luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(Elf);
  if (!ObjOrErr)
    return ObjOrErr.takeError();
  auto &Obj = **ObjOrErr;
  for (const auto &Section : Obj.sections()) {
    auto NameOrErr = Section.getName();
    if (!NameOrErr)
      return NameOrErr.takeError();
    if (*NameOrErr != ".llvmbc")
      continue;
    auto ContentsOrErr = Section.getContents();
    if (!ContentsOrErr)
      return ContentsOrErr.takeError();
    /// \c Section.getContents() returns a view into the ELF buffer owned
    /// by \c Obj; once \c Obj goes out of scope the view dangles. Copy the
    /// bytes so the cache survives independently.
    return llvm::MemoryBuffer::getMemBufferCopy(*ContentsOrErr, "agent-bc");
  }
  return LUTHIER_MAKE_GENERIC_ERROR(
      "ELF slice does not contain a .llvmbc section.");
}

//===----------------------------------------------------------------------===//
// Symbol-name suffix normalisation
//===----------------------------------------------------------------------===//

/// Drop HSA's ".kd" kernel-descriptor suffix when present. The HIP register
/// tables store the device-side symbol name without the suffix, but
/// \c HSA_EXECUTABLE_SYMBOL_INFO_NAME returns the suffixed form for kernels.
llvm::StringRef stripKDSuffix(llvm::StringRef Name) {
  Name.consume_back(".kd");
  return Name;
}

//===----------------------------------------------------------------------===//
// Managed-variable backing pool selection
//===----------------------------------------------------------------------===//

/// Find a host fine-grain global memory pool suitable for backing managed
/// variables. HIP's \c hipMallocManaged path uses the CPU agent's
/// fine-grain pool because it's host-coherent and cross-agent-accessible
/// once we hand the pointer to \c hsa_amd_agents_allow_access.
llvm::Expected<hsa_amd_memory_pool_t>
selectManagedVarPool(const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
                     hsa_agent_t CpuAgent) {
  struct CBData {
    const hsa::ApiTableContainer<::AmdExtTable> &AmdExt;
    hsa_amd_memory_pool_t Pool{};
    bool Found{false};
    llvm::Error Err{llvm::Error::success()};
  } Data{AmdExt, {}, false, llvm::Error::success()};

  auto Iter = [](hsa_amd_memory_pool_t Pool, void *D) -> hsa_status_t {
    auto *Cb = static_cast<CBData *>(D);
    if (Cb->Found)
      return HSA_STATUS_SUCCESS;
    hsa_amd_segment_t Segment{};
    hsa_status_t S = Cb->AmdExt.callFunction<hsa_amd_memory_pool_get_info>(
        Pool, HSA_AMD_MEMORY_POOL_INFO_SEGMENT, &Segment);
    if (S != HSA_STATUS_SUCCESS)
      return S;
    if (Segment != HSA_AMD_SEGMENT_GLOBAL)
      return HSA_STATUS_SUCCESS;
    uint32_t Flags = 0;
    S = Cb->AmdExt.callFunction<hsa_amd_memory_pool_get_info>(
        Pool, HSA_AMD_MEMORY_POOL_INFO_GLOBAL_FLAGS, &Flags);
    if (S != HSA_STATUS_SUCCESS)
      return S;
    if (!(Flags & HSA_AMD_MEMORY_POOL_GLOBAL_FLAG_FINE_GRAINED))
      return HSA_STATUS_SUCCESS;
    bool AllocAllowed = false;
    S = Cb->AmdExt.callFunction<hsa_amd_memory_pool_get_info>(
        Pool, HSA_AMD_MEMORY_POOL_INFO_RUNTIME_ALLOC_ALLOWED, &AllocAllowed);
    if (S != HSA_STATUS_SUCCESS)
      return S;
    if (!AllocAllowed)
      return HSA_STATUS_SUCCESS;
    Cb->Pool = Pool;
    Cb->Found = true;
    return HSA_STATUS_SUCCESS;
  };
  if (auto E = LUTHIER_HSA_CALL_ERROR_CHECK(
          AmdExt.callFunction<hsa_amd_agent_iterate_memory_pools>(CpuAgent,
                                                                  Iter, &Data),
          "Failed to iterate CPU memory pools for managed-var allocation."))
    return std::move(E);
  if (!Data.Found)
    return LUTHIER_MAKE_HSA_ERROR(
        "No host fine-grain memory pool available for managed-var allocation.");
  return Data.Pool;
}

/// Query the pool's recommended allocation granule (alignment).
llvm::Expected<size_t>
poolAllocGranule(const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
                 hsa_amd_memory_pool_t Pool) {
  size_t Granule = 0;
  if (auto E = LUTHIER_HSA_CALL_ERROR_CHECK(
          AmdExt.callFunction<hsa_amd_memory_pool_get_info>(
              Pool, HSA_AMD_MEMORY_POOL_INFO_RUNTIME_ALLOC_GRANULE, &Granule),
          "Failed to query memory pool allocation granule."))
    return std::move(E);
  return Granule;
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

  // Populate host-handle → device-name
  auto RecordHandle = [&](const void *Handle, const char *Name) {
    if (Handle != nullptr && Name != nullptr)
      HandleToName[Handle] = std::string(Name);
  };
  for (const auto &E : InputFunctions)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &E : InputDeviceVars)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &E : InputTextures)
    RecordHandle(E.HostHandle, E.DeviceName);
  for (const auto &E : InputSurfaces)
    RecordHandle(E.HostHandle, E.DeviceName);

  FatBins.reserve(InputFatBinaries.size());
  for (const auto &[Bundle, Size] : InputFatBinaries) {
    FatBinRecord &Rec = FatBins.emplace_back();
    Rec.Wrapper = Bundle;

    llvm::SmallVector<BundleSlice, 4> Slices;
    // The decompressed buffer (if the bundle is compressed) must outlive
    // the HSA load + bitcode-extraction calls below since the slice
    // StringRefs view into it. HSA copies the ELF internally and the
    // bitcode extractor takes its own owned copy, so the holder can drop
    // at end of this iteration.
    std::unique_ptr<llvm::MemoryBuffer> DecompressedHolder;
    llvm::MemoryBufferRef BundleRef(
        llvm::StringRef(static_cast<const char *>(Bundle), Size), "fatbin");
    LUTHIER_RETURN_ON_ERROR(
        parseOffloadBundle(Core, BundleRef, Slices, DecompressedHolder));

    // Handle-keyed map for the agent-matching predicate. Build it with
    // specificity-aware precedence:
    //   1. Sort slices by ascending \c anyCount — slices with no \c Any
    //      features sort first (most specific).
    //   2. For each slice, register all concrete handles it covers (1, 2,
    //      or 4 depending on how many features are \c Any).
    //   3. Use \c try_emplace so the first-inserted (most-specific) slice
    //      wins on every handle.
    // The result: when \c agentFindFirstISA later walks the agent's ISAs in
    // ROCr's native-first order, the predicate sees a hit for the most
    // specific slice that matches the agent's exact ISA. Perfect match →
    // any-feature match → generic falls out automatically (generics arrive
    // last in the iteration order from ROCr).
    llvm::SmallVector<const BundleSlice *> SortedSlices;
    SortedSlices.reserve(Slices.size());
    for (const auto &S : Slices)
      SortedSlices.push_back(&S);
    llvm::stable_sort(SortedSlices,
                      [](const BundleSlice *A, const BundleSlice *B) {
                        return anyCount(*A) < anyCount(*B);
                      });

    llvm::DenseMap<uint64_t, const BundleSlice *> SliceByIsaHandle;
    for (const BundleSlice *S : SortedSlices) {
      // Always register the canonical handle (the bare form, no
      // Any-expansion). agentFindFirstISA may hit this when the agent's
      // own ISA exactly matches.
      SliceByIsaHandle.try_emplace(S->IsaHandle.handle, S);

      // For each Any-feature dimension (absent from the slice's
      // SubtargetFeatures), fan out to the concrete on/off ISAs. We
      // resolve each via hsa::isaFromLLVM so ROCr returns the same
      // handle the agent's iterator would yield.
      bool XnackAny = !featureState(S->Features, "xnack");
      bool SrameccAny = !featureState(S->Features, "sramecc");
      if (!XnackAny && !SrameccAny)
        continue;
      for (int Xc = 0; Xc < (XnackAny ? 2 : 1); ++Xc) {
        for (int Sc = 0; Sc < (SrameccAny ? 2 : 1); ++Sc) {
          auto ConcreteFeatures =
              concretizeFeatures(S->Features,
                                 /*ConcreteXnackOn=*/Xc != 0,
                                 /*ConcreteSrameccOn=*/Sc != 0);
          auto IsaOrErr =
              hsa::isaFromLLVM(Core, S->Triple, S->CPU, ConcreteFeatures);
          if (!IsaOrErr) {
            consumeError(IsaOrErr.takeError());
            continue;
          }
          SliceByIsaHandle.try_emplace(IsaOrErr->handle, S);
        }
      }
    }

    for (hsa_agent_t Agent : Agents) {
      // \c agentFindFirstISA walks the agent's supported ISAs in ROCr's
      // registry order — native first, then generic (see
      // amd_gpu_agent.cpp:186). The first ISA the predicate accepts wins,
      // so HIP's "native > generic" preference falls out automatically.
      auto MatchedOrErr = hsa::agentFindFirstISA(
          Core, Agent, [&](hsa_isa_t AgentIsa) -> llvm::Expected<bool> {
            return SliceByIsaHandle.contains(AgentIsa.handle);
          });
      if (!MatchedOrErr)
        return MatchedOrErr.takeError();
      if (!*MatchedOrErr)
        continue; // No slice in this bundle is compatible with this agent.
      const BundleSlice *Match =
          SliceByIsaHandle.lookup((*MatchedOrErr)->handle);

      auto ReaderOrErr =
          hsa::codeObjectReaderCreateFromMemory(Core, Match->Elf);
      if (!ReaderOrErr)
        return ReaderOrErr.takeError();
      auto ExeOrErr = hsa::executableCreate(Core);
      if (!ExeOrErr) {
        (void)hsa::codeObjectReaderDestroy(*ReaderOrErr, Core);
        return ExeOrErr.takeError();
      }
      auto LCOOrErr = hsa::executableLoadAgentCodeObject(Core, *ExeOrErr,
                                                         *ReaderOrErr, Agent);
      if (!LCOOrErr) {
        (void)hsa::executableDestroy(Core, *ExeOrErr);
        (void)hsa::codeObjectReaderDestroy(*ReaderOrErr, Core);
        return LCOOrErr.takeError();
      }
      if (auto E = hsa::executableFreeze(Core, *ExeOrErr)) {
        (void)hsa::executableDestroy(Core, *ExeOrErr);
        (void)hsa::codeObjectReaderDestroy(*ReaderOrErr, Core);
        return E;
      }
      Rec.Loaded[Agent] = AgentExecutable{*ReaderOrErr, *LCOOrErr, *ExeOrErr};

      // Populate per-agent loaded-address map for every registered name we
      // can resolve in this executable.
      auto Callback = [&](hsa_executable_symbol_t Sym) -> llvm::Error {
        auto NameOrErr = hsa::executableSymbolGetName(Core, Sym);
        if (!NameOrErr)
          return NameOrErr.takeError();
        llvm::StringRef Name = stripKDSuffix(*NameOrErr);
        auto AddrOrErr = hsa::executableSymbolGetAddress(Core, Sym);
        if (!AddrOrErr)
          return AddrOrErr.takeError();
        NameToAgentAddr[Name][Agent] = *AddrOrErr;
        return llvm::Error::success();
      };
      if (auto E = hsa::executableIterateAgentSymbols(Core, *ExeOrErr, Agent,
                                                      Callback))
        return E;

      // Cache the raw `.llvmbc` bytes once per agent + the slice's
      // LLVM-form ISA pieces for later TargetMachine construction.
      // Parsing into an LLVMContext is deferred to getEmbeddedModule /
      // getEmbeddedTarget.
      if (AgentBitcode.find(Agent) == AgentBitcode.end()) {
        auto BufOrErr = extractEmbeddedBitcode(Match->Elf);
        if (!BufOrErr) {
          LLVM_DEBUG(llvm::dbgs()
                     << "[luthier] no embedded bitcode for "
                        "agent isa handle 0x"
                     << llvm::utohexstr(Match->IsaHandle.handle) << ": "
                     << llvm::toString(BufOrErr.takeError()) << "\n");
          consumeError(BufOrErr.takeError());
        } else {
          AgentBitcode.insert({Agent, std::move(*BufOrErr)});
          AgentISA[Agent] =
              AgentTargetISA{Match->Triple, Match->CPU, Match->Features};
        }
      }
    }
  }

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
  llvm::Expected<size_t> GranuleOrErr = poolAllocGranule(AmdExt, *PoolOrErr);
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

    void *Alloc = nullptr;
    if (auto E = LUTHIER_HSA_CALL_ERROR_CHECK(
            AmdExt.callFunction<hsa_amd_memory_pool_allocate>(
                *PoolOrErr, MV.Size, /*flags=*/0, &Alloc),
            llvm::formatv("Failed to allocate managed-var storage for {0}.",
                          MV.Name ? MV.Name : "<unnamed>")))
      return E;

    // Copy initial value (fine-grain host memory => plain CPU store).
    if (MV.InitValue != nullptr && MV.Size > 0)
      std::memcpy(Alloc, MV.InitValue, MV.Size);

    // Grant every GPU agent access to the allocation so kernel-side
    // dereferences of the symbol resolve to this storage.
    if (!Agents.empty()) {
      if (auto E = LUTHIER_HSA_CALL_ERROR_CHECK(
              AmdExt.callFunction<hsa_amd_agents_allow_access>(
                  Agents.size(), Agents.data(), /*flags=*/nullptr, Alloc),
              llvm::formatv(
                  "Failed to grant GPU agents access to managed var {0}.",
                  MV.Name ? MV.Name : "<unnamed>"))) {
        (void)AmdExt.callFunction<hsa_amd_memory_pool_free>(Alloc);
        return E;
      }
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
    if (MV.Name != nullptr)
      HandleToName[MV.Pointer] = std::string(MV.Name);
  }
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::unloadAll
//===----------------------------------------------------------------------===//

void DeviceToolCodeFatBinaryLoader::unloadAll() noexcept {
  auto Core = CoreApiSnapshot.getTable();
  auto AmdExt = AmdExtSnapshot.getTable();
  auto Swallow = [](llvm::Error E) {
    if (E) {
      LLVM_DEBUG(llvm::dbgs() << "[luthier] unload: "
                              << llvm::toString(std::move(E)) << "\n");
      consumeError(std::move(E));
    } else {
      consumeError(std::move(E));
    }
  };

  for (auto &Rec : FatBins) {
    for (auto &KV : Rec.Loaded) {
      Swallow(hsa::executableDestroy(Core, KV.second.Executable));
      Swallow(hsa::codeObjectReaderDestroy(KV.second.Reader, Core));
    }
  }

  // Free managed-var backing allocations. Match HIP's path: a single
  // pool_free per variable, no per-agent unmap (the access grant is
  // released implicitly by the free).
  for (auto &KV : ManagedVarRecords) {
    if (KV.second.Allocation == nullptr)
      continue;
    if (KV.second.HostShadowPtr != nullptr)
      *KV.second.HostShadowPtr = nullptr;
    hsa_status_t S =
        AmdExt.callFunction<hsa_amd_memory_pool_free>(KV.second.Allocation);
    if (S != HSA_STATUS_SUCCESS) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[luthier] managed-var free failed for "
                 << KV.second.Allocation << " (status " << S << ")\n");
    }
  }

  FatBins.clear();
  HandleToName.clear();
  NameToAgentAddr.clear();
  AgentBitcode.clear();
  AgentISA.clear();
  ManagedVarRecords.clear();
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::getEmbeddedModule
//===----------------------------------------------------------------------===//

llvm::Expected<std::unique_ptr<llvm::Module>>
DeviceToolCodeFatBinaryLoader::getEmbeddedModule(hsa_agent_t Agent,
                                                 llvm::LLVMContext &Ctx) {
  std::lock_guard Lock(Mutex);
  if (auto E = ensureLoaded())
    return std::move(E);
  auto It = AgentBitcode.find(Agent);
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      It != AgentBitcode.end(),
      "No embedded bitcode cached for the requested agent."));
  return llvm::parseBitcodeFile(It->second->getMemBufferRef(), Ctx);
}

//===----------------------------------------------------------------------===//
// DeviceToolCodeFatBinaryLoader::getEmbeddedTarget
//===----------------------------------------------------------------------===//

llvm::Expected<DeviceToolCodeFatBinaryLoader::EmbeddedTarget>
DeviceToolCodeFatBinaryLoader::getEmbeddedTarget(hsa_agent_t Agent,
                                                 llvm::LLVMContext &Ctx) {
  std::lock_guard Lock(Mutex);
  if (auto E = ensureLoaded())
    return std::move(E);
  auto BCIt = AgentBitcode.find(Agent);
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      BCIt != AgentBitcode.end(),
      "No embedded bitcode cached for the requested agent."));
  auto ISAIt = AgentISA.find(Agent);
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      ISAIt != AgentISA.end(),
      "No LLVM-form ISA cached for the requested agent."));
  auto ModOrErr = llvm::parseBitcodeFile(BCIt->second->getMemBufferRef(), Ctx);
  if (!ModOrErr)
    return ModOrErr.takeError();
  EmbeddedTarget Out;
  Out.Module = std::move(*ModOrErr);
  Out.Triple = ISAIt->second.Triple;
  Out.CPU = ISAIt->second.CPU;
  Out.Features = ISAIt->second.Features;
  return Out;
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

DeviceToolCodeFatBinaryLoader::DeviceToolCodeFatBinaryLoader(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
    const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &Loader,
    llvm::ArrayRef<HipFatBinaryInfo> FatBinaries,
    llvm::ArrayRef<HipFunctionInfo> Functions,
    llvm::ArrayRef<HipDeviceVarInfo> DeviceVars,
    llvm::ArrayRef<HipManagedVarInfo> ManagedVars,
    llvm::ArrayRef<HipTextureInfo> Textures,
    llvm::ArrayRef<HipSurfaceInfo> Surfaces)
    : CoreApiSnapshot(CoreApi), AmdExtSnapshot(AmdExt),
      LoaderApiSnapshot(Loader), InputFatBinaries(FatBinaries),
      InputFunctions(Functions), InputDeviceVars(DeviceVars),
      InputManagedVars(ManagedVars), InputTextures(Textures),
      InputSurfaces(Surfaces) {}

DeviceToolCodeFatBinaryLoader::~DeviceToolCodeFatBinaryLoader() {
  // Skip teardown if loadAll never ran (or already rolled back on
  // failure). Saves a needless HSA dispatch on snapshots that may have
  // never been initialized.
  if (State == LoadState::Loaded)
    unloadAll();
}

} // namespace luthier
