//===-- DeviceToolCodeLoader.cpp ----------------------------------*-C++-*-===//
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
/// \file DeviceToolCodeLoader.cpp
/// HSA-free parse path and HSA-side load path shared by the static
/// fat-binary loader and the dynamic module loader.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/DeviceToolCodeLoader.h"
#include "luthier/HSA/Agent.h"
#include "luthier/HSA/CodeObjectReader.h"
#include "luthier/HSA/Executable.h"
#include "luthier/HSA/ExecutableSymbol.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/HSA/ISA.h"
#include "luthier/HSA/MemoryPool.h"
#include "luthier/HSA/SVM.h"
#include "luthier/HSA/VMEM.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include "luthier/Object/ObjectFileUtils.h"
#include <hsa/hsa_ext_amd.h>
#include <llvm/ADT/STLExtras.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/BinaryFormat/Magic.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/Object/ELFObjectFile.h>
#include <llvm/Object/OffloadBundle.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/Process.h>
#include <llvm/Support/raw_ostream.h>

#include <algorithm>
#include <cstring>

#define DEBUG_TYPE "luthier-device-tool-code-loader-base"

namespace luthier {

namespace {

//===----------------------------------------------------------------------===//
// Clang offload bundle parsing (HSA-free)
//===----------------------------------------------------------------------===//

/// Parses a Clang offload \p Bundle into a list of \c MemoryBufferRef views
/// into the contained ELFs. Handles compressed (CCOB) and uncompressed
/// bundles. On a compressed input, \p DecompressedHolder receives the owning
/// buffer of the decompressed payload — caller must retain it.
llvm::Error
parseOffloadBundle(llvm::MemoryBufferRef Bundle,
                   llvm::SmallVectorImpl<llvm::MemoryBufferRef> &ElfSlices,
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
    // Filter non-AMDGCN slices (host slot, etc.) early.
    auto ObjOrErr = llvm::object::ObjectFile::createObjectFile(CodeObjectBuf);
    if (!ObjOrErr)
      return ObjOrErr.takeError();
    if (!llvm::isa<object::AMDGCNObjectFile>(*ObjOrErr))
      continue;
    ElfSlices.push_back(CodeObjectBuf);
  }
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// Embedded bitcode extraction (.llvmbc section)
//===----------------------------------------------------------------------===//

/// Return a non-owning view into the \c .llvmbc section of an ELF slice.
/// The caller guarantees the underlying \p Elf bytes outlive the view.
llvm::Expected<llvm::MemoryBufferRef>
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
    return llvm::MemoryBufferRef(*ContentsOrErr, "agent-bc");
  }
  return LUTHIER_MAKE_GENERIC_ERROR(
      "ELF slice does not contain a .llvmbc section.");
}

} // namespace

//===----------------------------------------------------------------------===//
// selectManagedVarPool
//===----------------------------------------------------------------------===//

llvm::Expected<hsa_amd_memory_pool_t>
DeviceToolCodeLoader::selectManagedVarPool(
    const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
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

//===----------------------------------------------------------------------===//
// HMM-aware managed-storage allocation
//===----------------------------------------------------------------------===//

llvm::Expected<bool> DeviceToolCodeLoader::getHmmSupported() {
  if (HmmSupportedCache)
    return *HmmSupportedCache;
  auto SupportedOrErr = hsa::systemIsSvmSupported(CoreApiSnapshot.getTable());
  if (!SupportedOrErr)
    return SupportedOrErr.takeError();
  HmmSupportedCache = *SupportedOrErr;
  return *HmmSupportedCache;
}

llvm::Expected<DeviceToolCodeLoader::ManagedAlloc>
DeviceToolCodeLoader::allocateManagedStorage(
    const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
    llvm::ArrayRef<hsa_agent_t> GpuAgents, hsa_amd_memory_pool_t Pool,
    size_t Size, unsigned Align, bool HmmSupported) {
  if (Size == 0)
    return LUTHIER_MAKE_GENERIC_ERROR(
        "allocateManagedStorage: zero-sized request.");

  if (HmmSupported) {
    // HMM / SVM path: mirrors HIP's reserveMemory + SvmAllocInit sequence
    // (rocclr Device::svmAlloc on hmmSupported_=true).
    const size_t PageSize = llvm::sys::Process::getPageSizeEstimate();
    if (Align > PageSize)
      return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
          "Managed-var alignment ({0}) exceeds system page size ({1}); "
          "over-aligned managed vars are not modelled on the HMM path.",
          Align, PageSize));
    const size_t RoundedSize = (Size + PageSize - 1) & ~(PageSize - 1);

    llvm::Expected<void *> VAOrErr = hsa::vmemAddressReserveAlign(
        AmdExt, RoundedSize, /*Address=*/0, /*Alignment=*/PageSize,
        HSA_AMD_VMEM_ADDRESS_NO_REGISTER);
    if (!VAOrErr)
      return VAOrErr.takeError();

    // Mark the range accessible from every GPU agent. rocclr's first-alloc
    // path explicitly enumerates every device with
    // HSA_AMD_SVM_ATTRIB_AGENT_ACCESSIBLE (the comment there notes HMM should
    // page-fault its way to access, but the runtime requires the explicit
    // list). CPU access is implicit on HMM — host writes via the VA address
    // are picked up by the page-fault handler.
    llvm::SmallVector<hsa_amd_svm_attribute_pair_t, 8> Attrs;
    Attrs.reserve(GpuAgents.size());
    for (hsa_agent_t Agent : GpuAgents)
      Attrs.push_back({HSA_AMD_SVM_ATTRIB_AGENT_ACCESSIBLE, Agent.handle});

    if (!Attrs.empty()) {
      if (auto E = hsa::svmAttributesSet(AmdExt, *VAOrErr, RoundedSize, Attrs))
        return llvm::joinErrors(
            std::move(E), hsa::vmemAddressFree(AmdExt, *VAOrErr, RoundedSize));
    }

    return ManagedAlloc{*VAOrErr, RoundedSize, /*ViaSvm=*/true};
  }

  // Legacy non-HMM path: CPU fine-grain pool + agents_allow_access.
  llvm::Expected<void *> AllocOrErr =
      hsa::memoryPoolAllocate(AmdExt, Pool, Size, /*Flags=*/0);
  if (!AllocOrErr)
    return AllocOrErr.takeError();

  if (!GpuAgents.empty()) {
    if (auto E = hsa::agentsAllowAccess(AmdExt, GpuAgents, *AllocOrErr))
      return llvm::joinErrors(std::move(E),
                              hsa::memoryPoolFree(AmdExt, *AllocOrErr));
  }
  return ManagedAlloc{*AllocOrErr, Size, /*ViaSvm=*/false};
}

llvm::Error DeviceToolCodeLoader::freeManagedStorage(
    const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
    const ManagedAlloc &Alloc) {
  if (Alloc.Ptr == nullptr)
    return llvm::Error::success();
  if (Alloc.ViaSvm)
    return hsa::vmemAddressFree(AmdExt, Alloc.Ptr, Alloc.AllocSize);
  return hsa::memoryPoolFree(AmdExt, Alloc.Ptr);
}

//===----------------------------------------------------------------------===//
// Canonical LLVM ISA key
//===----------------------------------------------------------------------===//

std::string DeviceToolCodeLoader::canonicalLLVMISAKey(
    const llvm::Triple &T, llvm::StringRef CPU,
    const llvm::SubtargetFeatures &F) {
  std::vector<std::string> Sorted = F.getFeatures();
  std::sort(Sorted.begin(), Sorted.end());
  std::string Out;
  llvm::raw_string_ostream OS(Out);
  OS << T.str() << "--" << CPU;
  for (llvm::StringRef Feat : Sorted)
    OS << ',' << Feat;
  return OS.str();
}

//===----------------------------------------------------------------------===//
// addSlice
//===----------------------------------------------------------------------===//

llvm::Error
DeviceToolCodeLoader::addSlice(llvm::MemoryBufferRef CodeObject) {
  auto ObjOrErr = luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(
      CodeObject.getBuffer());
  if (!ObjOrErr)
    return ObjOrErr.takeError();
  auto TupleOrErr = luthier::object::getObjectFileTargetTuple(**ObjOrErr);
  if (!TupleOrErr)
    return TupleOrErr.takeError();
  auto &[T, CPU, Features] = *TupleOrErr;

  std::string Key = canonicalLLVMISAKey(T, CPU, Features);
  if (Slices.contains(Key))
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Duplicate LLVM ISA in code-object input: " + Key);

  auto BitcodeOrErr = extractEmbeddedBitcode(CodeObject.getBuffer());
  if (!BitcodeOrErr)
    return BitcodeOrErr.takeError();

  SliceCacheEntry Entry;
  Entry.CodeObject = CodeObject;
  Entry.Bitcode = *BitcodeOrErr;
  Entry.T = std::move(T);
  Entry.CPU = CPU.str();
  Entry.Features = std::move(Features);
  Slices.insert({std::move(Key), std::move(Entry)});

  // Discover dynamic managed variables: pairs of (Name, Name.managed)
  // global-object symbols. The .managed companion carries the size +
  // initial bytes; the base symbol is the pointer-sized device storage
  // kernel code dereferences. Failures here log + skip rather than fail
  // the whole construction.
  static constexpr llvm::StringLiteral ManagedSuffix = ".managed";
  llvm::Error VarIterErr = llvm::Error::success();
  for (const auto &Var : (*ObjOrErr)->variables(VarIterErr)) {
    auto NameOrErr = Var.getName();
    if (!NameOrErr) {
      llvm::consumeError(NameOrErr.takeError());
      continue;
    }
    if (!NameOrErr->ends_with(ManagedSuffix))
      continue;
    llvm::StringRef BaseName = NameOrErr->drop_back(ManagedSuffix.size());
    uint64_t Size = Var.getSize();
    if (Size == 0)
      continue;

    auto SectionOrErr = Var.getSection();
    if (!SectionOrErr) {
      llvm::consumeError(SectionOrErr.takeError());
      continue;
    }
    auto ContentsOrErr = (*SectionOrErr)->getContents();
    if (!ContentsOrErr) {
      llvm::consumeError(ContentsOrErr.takeError());
      continue;
    }
    auto SymValOrErr = Var.getValue();
    if (!SymValOrErr) {
      llvm::consumeError(SymValOrErr.takeError());
      continue;
    }
    uint64_t SymVal = *SymValOrErr;
    uint64_t SectAddr = (*SectionOrErr)->getAddress();
    if (SymVal < SectAddr ||
        (SymVal - SectAddr) + Size > ContentsOrErr->size()) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[luthier] managed-var symbol " << *NameOrErr
                 << " out of section bounds, skipping\n");
      continue;
    }
    llvm::ArrayRef<uint8_t> InitBytes(
        reinterpret_cast<const uint8_t *>(ContentsOrErr->data()) +
            (SymVal - SectAddr),
        Size);

    unsigned Align = (*SectionOrErr)->getAlignment().value();

    // Dedup across slices on BaseSymbolName.
    bool AlreadyKnown = false;
    for (const auto &Existing : DynamicManagedVars) {
      if (Existing.BaseSymbolName == BaseName) {
        AlreadyKnown = true;
        break;
      }
    }
    if (AlreadyKnown)
      continue;

    ManagedVarInfo MV;
    MV.BaseSymbolName = BaseName;
    MV.Size = Size;
    MV.Align = Align;
    MV.InitValue = InitBytes;
    DynamicManagedVars.push_back(std::move(MV));
  }
  if (VarIterErr)
    return VarIterErr;
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// Constructors
//===----------------------------------------------------------------------===//

DeviceToolCodeLoader::DeviceToolCodeLoader(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
    const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &Loader,
    std::unique_ptr<llvm::MemoryBuffer> Bundle, llvm::Error &Err)
    : CoreApiSnapshot(CoreApi), AmdExtSnapshot(AmdExt),
      LoaderApiSnapshot(Loader) {
  llvm::ErrorAsOutParameter EAO(&Err);
  if (Err)
    return; // Upstream already recorded a failure; don't overwrite.
  if (!Bundle)
    return; // No bundle is a legitimate "host-only tool" case.

  llvm::MemoryBufferRef BundleRef = Bundle->getMemBufferRef();
  RetainedBuffers.push_back(std::move(Bundle));

  llvm::SmallVector<llvm::MemoryBufferRef, 4> ElfSlices;
  std::unique_ptr<llvm::MemoryBuffer> DecompressedHolder;
  if (auto E = parseOffloadBundle(BundleRef, ElfSlices, DecompressedHolder)) {
    Err = std::move(E);
    return;
  }
  if (DecompressedHolder)
    RetainedBuffers.push_back(std::move(DecompressedHolder));

  for (llvm::MemoryBufferRef Elf : ElfSlices) {
    if (auto E = addSlice(Elf)) {
      Err = std::move(E);
      return;
    }
  }
}

DeviceToolCodeLoader::DeviceToolCodeLoader(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
    const rocprofiler::HsaApiTableSnapshot<::AmdExtTable> &AmdExt,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &Loader,
    llvm::ArrayRef<std::unique_ptr<llvm::MemoryBuffer>> CodeObjects,
    llvm::Error &Err)
    : CoreApiSnapshot(CoreApi), AmdExtSnapshot(AmdExt),
      LoaderApiSnapshot(Loader) {
  llvm::ErrorAsOutParameter EAO(&Err);
  if (Err)
    return;
  for (const auto &CO : CodeObjects) {
    if (!CO) {
      Err = LUTHIER_MAKE_GENERIC_ERROR(
          "Null code-object buffer in code-objects input.");
      return;
    }
    if (auto E = addSlice(CO->getMemBufferRef())) {
      Err = std::move(E);
      return;
    }
  }
}

DeviceToolCodeLoader::~DeviceToolCodeLoader() {
  llvm::consumeError(clearLoadedState());
}

//===----------------------------------------------------------------------===//
// loadOntoAgents
//===----------------------------------------------------------------------===//

llvm::Error
DeviceToolCodeLoader::loadOntoAgents(llvm::ArrayRef<hsa_agent_t> Agents) {
  auto Core = CoreApiSnapshot.getTable();

  // Resolve hsa_isa_t for each slice and build the lookup map. Construction
  // is HSA-free, so this is the first time we make these calls.
  llvm::DenseMap<hsa_isa_t, SliceCacheEntry *> SliceByIsaHandle;
  for (auto &KV : Slices) {
    SliceCacheEntry &Entry = KV.second;
    llvm::Expected<hsa_isa_t> IsaOrErr =
        hsa::isaFromLLVM(Core, Entry.T, Entry.CPU, Entry.Features);
    if (!IsaOrErr)
      return IsaOrErr.takeError();
    // try_emplace: first slice wins on hsa_isa_t collision (e.g. wave32
    // and wave64 share the same hsa_isa_t — HSA can't differentiate them).
    SliceByIsaHandle.try_emplace(*IsaOrErr, &Entry);
  }

  for (hsa_agent_t Agent : Agents) {
    if (PerAgentLoadRecords.contains(Agent))
      continue; // Idempotent on already-loaded agents.

    auto MatchedOrErr = hsa::agentFindFirstISA(
        Core, Agent, [&](hsa_isa_t AgentIsa) -> llvm::Expected<bool> {
          return SliceByIsaHandle.contains(AgentIsa);
        });
    if (!MatchedOrErr)
      return MatchedOrErr.takeError();
    if (!*MatchedOrErr)
      continue; // No slice compatible with this agent.
    SliceCacheEntry *Match = SliceByIsaHandle.lookup(**MatchedOrErr);

    auto ReaderOrErr = hsa::codeObjectReaderCreateFromMemory(
        Core, Match->CodeObject.getBuffer());
    if (!ReaderOrErr)
      return ReaderOrErr.takeError();
    auto ExeOrErr = hsa::executableCreate(Core);
    if (!ExeOrErr)
      return llvm::joinErrors(ExeOrErr.takeError(),
                              hsa::codeObjectReaderDestroy(*ReaderOrErr, Core));
    auto LCOOrErr = hsa::executableLoadAgentCodeObject(Core, *ExeOrErr,
                                                       *ReaderOrErr, Agent);
    if (!LCOOrErr)
      return llvm::joinErrors(
          llvm::joinErrors(LCOOrErr.takeError(),
                           hsa::executableDestroy(Core, *ExeOrErr)),
          hsa::codeObjectReaderDestroy(*ReaderOrErr, Core));
    if (auto E = hsa::executableFreeze(Core, *ExeOrErr))
      return llvm::joinErrors(
          llvm::joinErrors(std::move(E),
                           hsa::executableDestroy(Core, *ExeOrErr)),
          hsa::codeObjectReaderDestroy(*ReaderOrErr, Core));
    PerAgentLoadRecords[Agent] =
        SliceLoadRecord{*ReaderOrErr, *LCOOrErr, *ExeOrErr};

    auto Callback = [&](hsa_executable_symbol_t Sym) -> llvm::Error {
      auto KindOrErr = hsa::executableSymbolGetType(Core, Sym);
      if (!KindOrErr)
        return KindOrErr.takeError();
      if (*KindOrErr != HSA_SYMBOL_KIND_VARIABLE)
        return llvm::Error::success();
      auto NameOrErr = hsa::executableSymbolGetName(Core, Sym);
      if (!NameOrErr)
        return NameOrErr.takeError();
      NameToAgentGlobal[*NameOrErr][Agent] = Sym;
      return llvm::Error::success();
    };
    if (auto E = hsa::executableIterateAgentSymbols(Core, *ExeOrErr, Agent,
                                                    Callback))
      return E;
  }
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// clearLoadedState
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeLoader::clearLoadedState() {
  auto Core = CoreApiSnapshot.getTable();
  llvm::Error E = freeManagedVars();
  for (auto &KV : PerAgentLoadRecords) {
    E = llvm::joinErrors(std::move(E),
                         hsa::executableDestroy(Core, KV.second.Executable));
    E = llvm::joinErrors(std::move(E),
                         hsa::codeObjectReaderDestroy(KV.second.Reader, Core));
  }
  PerAgentLoadRecords.clear();
  NameToAgentGlobal.clear();
  State = LoadState::Pending;
  return E;
}

//===----------------------------------------------------------------------===//
// loadDynamicManagedVars / freeManagedVars
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeLoader::loadDynamicManagedVars(
    llvm::ArrayRef<hsa_agent_t> Agents) {
  if (DynamicManagedVars.empty())
    return llvm::Error::success();

  const auto Core = CoreApiSnapshot.getTable();
  const auto AmdExt = AmdExtSnapshot.getTable();

  llvm::Expected<bool> HmmOrErr = getHmmSupported();
  if (!HmmOrErr)
    return HmmOrErr.takeError();
  const bool HmmSupported = *HmmOrErr;

  // Resolve the CPU fine-grain pool only on the non-HMM path; the HMM path
  // doesn't go through a pool.
  hsa_amd_memory_pool_t Pool{};
  size_t Granule = 0;
  if (!HmmSupported) {
    llvm::SmallVector<hsa_agent_t, 1> CpuAgents;
    LUTHIER_RETURN_ON_ERROR(
        hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_CPU>(Core, CpuAgents));
    if (CpuAgents.empty())
      return LUTHIER_MAKE_HSA_ERROR(
          "No CPU agent available for managed-var allocation.");
    auto PoolOrErr = selectManagedVarPool(AmdExt, CpuAgents.front());
    if (!PoolOrErr)
      return PoolOrErr.takeError();
    Pool = *PoolOrErr;
    auto GranuleOrErr = hsa::memoryPoolGetRuntimeAllocGranule(AmdExt, Pool);
    if (!GranuleOrErr)
      return GranuleOrErr.takeError();
    Granule = *GranuleOrErr;
  }

  for (const auto &MV : DynamicManagedVars) {
    if (MV.Size == 0)
      continue;
    if (!HmmSupported && MV.Align > Granule)
      return LUTHIER_MAKE_HSA_ERROR(llvm::formatv(
          "Managed variable {0} alignment ({1}) exceeds pool granule "
          "({2}); over-aligned managed vars are not modelled.",
          MV.BaseSymbolName, MV.Align, Granule));

    auto AllocOrErr = allocateManagedStorage(AmdExt, Agents, Pool, MV.Size,
                                             MV.Align, HmmSupported);
    if (!AllocOrErr)
      return AllocOrErr.takeError();
    ManagedAlloc Alloc = *AllocOrErr;

    auto FreeOnError = [&](llvm::Error E) {
      return llvm::joinErrors(std::move(E),
                              freeManagedStorage(AmdExt, Alloc));
    };

    // Copy initial value from the cached .managed-symbol bytes.
    if (!MV.InitValue.empty())
      std::memcpy(Alloc.Ptr, MV.InitValue.data(),
                  std::min<size_t>(MV.InitValue.size(), MV.Size));

    // Per-agent publish: write the managed-memory pointer into each
    // agent's loaded image of the base symbol so kernels reading the
    // base symbol go to the managed allocation.
    auto NameIt = NameToAgentGlobal.find(MV.BaseSymbolName);
    if (NameIt == NameToAgentGlobal.end()) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[luthier] base symbol not found for managed var "
                 << MV.BaseSymbolName << "\n");
    } else {
      for (hsa_agent_t Agent : Agents) {
        auto AgentIt = NameIt->second.find(Agent);
        if (AgentIt == NameIt->second.end())
          continue;
        auto AddrOrErr =
            hsa::executableSymbolGetAddress(Core, AgentIt->second);
        if (!AddrOrErr)
          return FreeOnError(AddrOrErr.takeError());
        if (auto E = LUTHIER_HSA_CALL_ERROR_CHECK(
                Core.callFunction<hsa_memory_copy>(
                    reinterpret_cast<void *>(*AddrOrErr), &Alloc.Ptr,
                    sizeof(void *)),
                llvm::formatv(
                    "hsa_memory_copy failed publishing managed-var "
                    "pointer for {0}",
                    MV.BaseSymbolName)))
          return FreeOnError(std::move(E));
      }
    }

    ManagedVarRec Rec;
    Rec.Name = MV.BaseSymbolName;
    Rec.Allocation = Alloc.Ptr;
    Rec.AllocSize = Alloc.AllocSize;
    Rec.Size = MV.Size;
    Rec.Align = MV.Align;
    Rec.ViaSvm = Alloc.ViaSvm;
    ManagedVarRecords[Alloc.Ptr] = Rec;
    NameToManagedAlloc[MV.BaseSymbolName] = Alloc.Ptr;
  }
  return llvm::Error::success();
}

llvm::Error DeviceToolCodeLoader::freeManagedVars() {
  auto AmdExt = AmdExtSnapshot.getTable();
  // Match HIP's path: a single free per variable, no per-agent unmap
  // (the access grant is released implicitly by the free). Per-agent
  // base-symbol storage gets implicitly invalidated when the agent
  // executable is destroyed in clearLoadedState. Dispatch by ViaSvm so
  // SVM allocations go to vmem_address_free and pool allocations to
  // memory_pool_free.
  llvm::Error E = llvm::Error::success();
  for (auto &KV : ManagedVarRecords) {
    if (KV.second.Allocation == nullptr)
      continue;
    ManagedAlloc A{KV.second.Allocation, KV.second.AllocSize,
                   KV.second.ViaSvm};
    E = llvm::joinErrors(std::move(E), freeManagedStorage(AmdExt, A));
  }
  ManagedVarRecords.clear();
  NameToManagedAlloc.clear();
  return E;
}

//===----------------------------------------------------------------------===//
// ensureLoaded
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeLoader::ensureLoaded() {
  std::lock_guard Lock(Mutex);
  if (State == LoadState::Loaded)
    return llvm::Error::success();

  auto Core = CoreApiSnapshot.getTable();
  llvm::SmallVector<hsa_agent_t, 4> Agents;
  LUTHIER_RETURN_ON_ERROR(
      hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_GPU>(Core, Agents));

  if (auto E = loadOntoAgents(Agents)) {
    E = llvm::joinErrors(std::move(E), clearLoadedState());
    return E;
  }
  if (auto E = loadDynamicManagedVars(Agents)) {
    E = llvm::joinErrors(std::move(E), clearLoadedState());
    return E;
  }
  State = LoadState::Loaded;
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// getEmbeddedModule / getCachedISAs
//===----------------------------------------------------------------------===//

llvm::Expected<std::unique_ptr<llvm::Module>>
DeviceToolCodeLoader::getEmbeddedModule(
    const llvm::Triple &T, llvm::StringRef CPU,
    const llvm::SubtargetFeatures &Features, llvm::LLVMContext &Ctx) {
  std::lock_guard Lock(Mutex);
  if (auto E = ensureLoaded())
    return std::move(E);
  std::string Key = canonicalLLVMISAKey(T, CPU, Features);
  auto It = Slices.find(Key);
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      It != Slices.end(),
      "No embedded bitcode cached for the requested LLVM ISA tuple."));
  return llvm::parseBitcodeFile(It->second.Bitcode, Ctx);
}

llvm::SmallVector<DeviceToolCodeLoader::CachedISA, 4>
DeviceToolCodeLoader::getCachedISAs() {
  std::lock_guard Lock(Mutex);
  llvm::SmallVector<CachedISA, 4> Out;
  Out.reserve(Slices.size());
  for (const auto &KV : Slices)
    Out.push_back(CachedISA{KV.second.T, KV.second.CPU, KV.second.Features});
  return Out;
}

} // namespace luthier
