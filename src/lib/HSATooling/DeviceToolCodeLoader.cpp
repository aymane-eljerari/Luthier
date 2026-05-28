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
#include <llvm/ADT/StringSet.h>
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
///
/// Each AMDGCN slice's bundle-relative start address must be aligned to
/// \c alignof(uint64_t) (LLVM's ELF parser requires \c uint64_t-aligned
/// headers). Bundles produced by \c luthier-tool-compile satisfy this
/// because the rebundle step passes \c --bundle-align=8 to
/// \c clang-offload-bundler. If a foreign bundle arrives with a
/// misaligned slice we return an error — silently copying the bytes to
/// a freshly-aligned buffer would mask producer-side bugs.
llvm::Error
parseOffloadBundle(llvm::MemoryBufferRef Bundle,
                   llvm::SmallVectorImpl<llvm::MemoryBufferRef> &ElfSlices,
                   std::unique_ptr<llvm::MemoryBuffer> &DecompressedHolder) {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] parseOffloadBundle: "
                          << Bundle.getBufferSize() << " bytes\n");
  if (Bundle.getBufferSize() == 0)
    return LUTHIER_MAKE_GENERIC_ERROR("Empty fat-binary bundle.");

  auto Magic = llvm::identify_magic(Bundle.getBuffer());

  llvm::MemoryBufferRef ParseBuf = Bundle;
  bool Decompressed = false;
  if (Magic == llvm::file_magic::offload_bundle_compressed) {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] bundle is CCOB; "
                               "decompressing\n");
    auto Input = llvm::MemoryBuffer::getMemBuffer(
        Bundle, /*RequiresNullTerminator=*/false);
    auto DecompOrErr =
        llvm::object::CompressedOffloadBundle::decompress(*Input, nullptr);
    if (!DecompOrErr)
      return DecompOrErr.takeError();
    DecompressedHolder = std::move(*DecompOrErr);
    ParseBuf = DecompressedHolder->getMemBufferRef();
    Decompressed = true;
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] decompressed payload "
                            << ParseBuf.getBufferSize() << " bytes\n");
  } else if (Magic != llvm::file_magic::offload_bundle) {
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Bundle does not start with __CLANG_OFFLOAD_BUNDLE__ or CCOB magic.");
  } else {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] bundle is uncompressed "
                               "__CLANG_OFFLOAD_BUNDLE__\n");
  }

  auto BundleOrErr = llvm::object::OffloadBundleFatBin::create(
      ParseBuf, /*SectionOffset=*/0, "fatbin", Decompressed);
  if (!BundleOrErr)
    return BundleOrErr.takeError();

  unsigned EntryIdx = 0;
  for (auto &Entry : (*BundleOrErr)->getEntries()) {
    if (Entry.Size == 0) {
      LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] entry " << EntryIdx
                              << " is zero-size, skipping\n");
      ++EntryIdx;
      continue;
    }
    // LLVM's ELF parser requires the buffer start to be aligned to
    // \c alignof(uint64_t). Reject misaligned slices outright rather
    // than masking the producer-side bug with a silent copy.
    llvm::StringRef SliceBytes(ParseBuf.getBufferStart() + Entry.Offset,
                               Entry.Size);
    if (reinterpret_cast<uintptr_t>(SliceBytes.data()) %
            alignof(uint64_t) !=
        0)
      return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
          "Bundle entry {0} starts at byte offset {1} within the bundle, "
          "which is not aligned to alignof(uint64_t) = {2} bytes. Rebuild "
          "the producing bundle with `clang-offload-bundler "
          "--bundle-align={2}` so LLVM's ELF parser can read it in place.",
          EntryIdx, Entry.Offset, alignof(uint64_t)));
    llvm::MemoryBufferRef CodeObjectBuf{SliceBytes, "code object buffer"};
    // The bundle may contain a host slot whose payload isn't a valid
    // object file. Try-parse, and skip rather than fail when the parse
    // doesn't recognize the bytes; AMDGCN slices have a well-formed ELF
    // header and will always succeed.
    auto ObjOrErr = llvm::object::ObjectFile::createObjectFile(CodeObjectBuf);
    if (!ObjOrErr) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[DeviceToolCodeLoader] entry " << EntryIdx << " ("
                 << Entry.Size << " B): unrecognized object, skipping\n");
      llvm::consumeError(ObjOrErr.takeError());
      ++EntryIdx;
      continue;
    }
    if (!llvm::isa<object::AMDGCNObjectFile>(*ObjOrErr)) {
      LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] entry " << EntryIdx
                              << " is not AMDGCN, skipping\n");
      ++EntryIdx;
      continue;
    }
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] entry " << EntryIdx
                            << " is AMDGCN, size=" << Entry.Size << "\n");
    ElfSlices.push_back(CodeObjectBuf);
    ++EntryIdx;
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] parseOffloadBundle "
                             "produced "
                          << ElfSlices.size() << " AMDGCN slice(s)\n");
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
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] found .llvmbc section, "
                            << ContentsOrErr->size() << " bytes\n");
    return llvm::MemoryBufferRef(*ContentsOrErr, "agent-bc");
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ELF slice has no .llvmbc "
                             "section\n");
  return LUTHIER_MAKE_GENERIC_ERROR(
      "ELF slice does not contain a .llvmbc section.");
}

//===----------------------------------------------------------------------===//
// Luthier subtarget marker (`__luthier_subtarget`) extraction
//===----------------------------------------------------------------------===//

/// Reads the \c __luthier_subtarget symbol from \p Obj if present and returns
/// its 4-byte encoded value. \c SubtargetMarkerPass writes this in section
/// \c .luthier.subtarget when the IR plugin runs on the tool's device
/// compile. The encoding is:
///   bit 0 — set if the slice runs in wave64; clear for wave32
///   bit 1 — set if the slice runs in CU mode; clear for WGP mode
///
/// Returns \c std::nullopt for code objects that weren't built through the
/// Luthier IR plugin (e.g. legacy artifacts or HIP TUs compiled with stock
/// hipcc). Callers should treat that as "wave/cumode unknown" and fall back
/// to whatever they were doing before this marker existed.
std::optional<uint32_t>
readSubtargetMarker(const llvm::object::ObjectFile &Obj) {
  for (const auto &Sym : Obj.symbols()) {
    auto NameOrErr = Sym.getName();
    if (!NameOrErr) {
      llvm::consumeError(NameOrErr.takeError());
      continue;
    }
    if (*NameOrErr != "__luthier_subtarget")
      continue;
    auto SecOrErr = Sym.getSection();
    if (!SecOrErr) {
      llvm::consumeError(SecOrErr.takeError());
      continue;
    }
    auto SecIt = *SecOrErr;
    if (SecIt == Obj.section_end())
      continue;
    auto ContentsOrErr = SecIt->getContents();
    if (!ContentsOrErr) {
      llvm::consumeError(ContentsOrErr.takeError());
      continue;
    }
    auto AddrOrErr = Sym.getAddress();
    if (!AddrOrErr) {
      llvm::consumeError(AddrOrErr.takeError());
      continue;
    }
    uint64_t Off = *AddrOrErr - SecIt->getAddress();
    if (Off + sizeof(uint32_t) > ContentsOrErr->size())
      continue;
    uint32_t V;
    std::memcpy(&V, ContentsOrErr->data() + Off, sizeof(uint32_t));
    LLVM_DEBUG(llvm::dbgs()
               << "[DeviceToolCodeLoader] __luthier_subtarget = 0x"
               << llvm::Twine::utohexstr(V) << " (wave64="
               << ((V & 1u) ? "1" : "0") << ", cumode="
               << ((V & 2u) ? "1" : "0") << ")\n");
    return V;
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ELF slice has no "
                             "__luthier_subtarget symbol\n");
  return std::nullopt;
}

} // namespace

//===----------------------------------------------------------------------===//
// selectManagedVarPool
//===----------------------------------------------------------------------===//

llvm::Expected<hsa_amd_memory_pool_t>
DeviceToolCodeLoader::selectManagedVarPool(
    const hsa::ApiTableContainer<::AmdExtTable> &AmdExt, hsa_agent_t CpuAgent) {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] selectManagedVarPool "
                             "for CPU agent "
                          << CpuAgent.handle << "\n");
  hsa_amd_memory_pool_t Found{};
  bool DidFind = false;
  LUTHIER_RETURN_ON_ERROR(hsa::agentIterateMemoryPools(
      AmdExt, CpuAgent, [&](hsa_amd_memory_pool_t Pool) -> llvm::Error {
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
  if (!DidFind) {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] no host fine-grain "
                               "alloc-allowed pool found\n");
    return LUTHIER_MAKE_HSA_ERROR(
        "No host fine-grain memory pool available for managed-var allocation.");
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] selected pool handle "
                          << Found.handle << "\n");
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
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] getHmmSupported: "
                          << (*HmmSupportedCache ? "yes" : "no") << "\n");
  return *HmmSupportedCache;
}

llvm::Expected<DeviceToolCodeLoader::ManagedAlloc>
DeviceToolCodeLoader::allocateManagedStorage(
    const hsa::ApiTableContainer<::AmdExtTable> &AmdExt,
    llvm::ArrayRef<hsa_agent_t> GpuAgents, hsa_amd_memory_pool_t Pool,
    size_t Size, unsigned Align, bool HmmSupported) {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] allocateManagedStorage "
                             "size="
                          << Size << " align=" << Align
                          << " hmm=" << HmmSupported
                          << " gpus=" << GpuAgents.size() << "\n");
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
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] HMM/SVM path, "
                               "page="
                            << PageSize << " rounded=" << RoundedSize << "\n");

    llvm::Expected<void *> VAOrErr = hsa::vmemAddressReserveAlign(
        AmdExt, RoundedSize, /*Address=*/0, /*Alignment=*/PageSize,
        HSA_AMD_VMEM_ADDRESS_NO_REGISTER);
    if (!VAOrErr)
      return VAOrErr.takeError();
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] reserved SVM VA "
                            << *VAOrErr << "\n");

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
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] legacy pool-alloc path\n");
  llvm::Expected<void *> AllocOrErr =
      hsa::memoryPoolAllocate(AmdExt, Pool, Size, /*Flags=*/0);
  if (!AllocOrErr)
    return AllocOrErr.takeError();
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] pool-alloc " << *AllocOrErr
                          << "\n");

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
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] freeManagedStorage "
                          << Alloc.Ptr << " size=" << Alloc.AllocSize
                          << " viaSvm=" << Alloc.ViaSvm << "\n");
  if (Alloc.ViaSvm)
    return hsa::vmemAddressFree(AmdExt, Alloc.Ptr, Alloc.AllocSize);
  return hsa::memoryPoolFree(AmdExt, Alloc.Ptr);
}

//===----------------------------------------------------------------------===//
// Canonical LLVM ISA key
//===----------------------------------------------------------------------===//

std::string
DeviceToolCodeLoader::canonicalLLVMISAKey(const llvm::Triple &T,
                                          llvm::StringRef CPU,
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

llvm::Error DeviceToolCodeLoader::addSlice(llvm::MemoryBufferRef CodeObject) {
  auto ObjOrErr = luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(
      CodeObject.getBuffer());
  if (!ObjOrErr)
    return ObjOrErr.takeError();
  auto TupleOrErr = luthier::object::getObjectFileTargetTuple(**ObjOrErr);
  if (!TupleOrErr)
    return TupleOrErr.takeError();
  auto &[T, CPU, Features] = *TupleOrErr;

  // Read the SubtargetMarkerPass's `__luthier_subtarget` symbol, if the
  // slice has one. `getObjectFileTargetTuple` only recovers what the ELF
  // e_flags encode (xnack, sramecc) — wave size and CU mode aren't in
  // there. Inject them into `Features` so two slices that target the
  // same gfx but differ in wave/cumode get distinct canonical ISA keys
  // and both survive the duplicate-key check below.
  std::optional<bool> SliceWave64;
  std::optional<bool> SliceCuMode;
  if (auto Encoded = readSubtargetMarker(**ObjOrErr)) {
    SliceWave64 = (*Encoded & 1u) != 0;
    SliceCuMode = (*Encoded & 2u) != 0;
    Features.AddFeature("wavefrontsize64", *SliceWave64);
    Features.AddFeature("cumode", *SliceCuMode);
  }

  std::string Key = canonicalLLVMISAKey(T, CPU, Features);
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] addSlice key=[" << Key
                          << "] coSize=" << CodeObject.getBufferSize() << "\n");
  if (Slices.contains(Key))
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Duplicate LLVM ISA in code-object input: " + Key);

  auto BitcodeOrErr = extractEmbeddedBitcode(CodeObject.getBuffer());
  if (!BitcodeOrErr)
    return BitcodeOrErr.takeError();

  SliceCacheEntry Entry;
  Entry.CodeObject = CodeObject;
  Entry.Bitcode = *BitcodeOrErr;
  Entry.TT = std::move(T);
  Entry.CPU = CPU.str();
  Entry.Features = std::move(Features);
  Entry.Wave64 = SliceWave64;
  Entry.CuMode = SliceCuMode;
  Slices.insert({std::move(Key), std::move(Entry)});

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
  if (!Bundle) {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ctor(bundle): null "
                               "bundle, host-only tool\n");
    return; // No bundle is a legitimate "host-only tool" case.
  }

  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ctor(bundle): "
                          << Bundle->getBufferSize() << " bytes\n");
  llvm::MemoryBufferRef BundleRef = Bundle->getMemBufferRef();
  RetainedBuffers.push_back(std::move(Bundle));

  llvm::SmallVector<llvm::MemoryBufferRef, 4> ElfSlices;
  std::unique_ptr<llvm::MemoryBuffer> DecompressedHolder;
  if (auto E =
          parseOffloadBundle(BundleRef, ElfSlices, DecompressedHolder)) {
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
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ctor(bundle): registered "
                          << Slices.size() << " slice(s)\n");
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
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ctor(code-objects): "
                          << CodeObjects.size() << " input(s)\n");
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
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ctor(code-objects): "
                             "registered "
                          << Slices.size() << " slice(s)\n");
}

DeviceToolCodeLoader::~DeviceToolCodeLoader() {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] dtor\n");
  llvm::consumeError(clearLoadedState());
}

//===----------------------------------------------------------------------===//
// loadOntoAgents
//===----------------------------------------------------------------------===//

llvm::Error
DeviceToolCodeLoader::loadOntoAgents(llvm::ArrayRef<hsa_agent_t> Agents) {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] loadOntoAgents: "
                          << Agents.size() << " agent(s), " << Slices.size()
                          << " slice(s)\n");
  auto Core = CoreApiSnapshot.getTable();

  // Build the agent-side lookup map. The HSA ApiTable wasn't ready
  // during \c addSlice, so we resolve each slice's \c hsa_isa_t here.
  // Re-parse the ELF to recover a clean SubtargetFeatures (just what
  // \c e_flags encodes — xnack/sramecc) rather than reuse
  // \c Entry.Features, which has been augmented with the wave/cumode
  // markers for the in-process cache key and would confuse HSA's ISA
  // name grammar.
  llvm::DenseMap<hsa_isa_t, SliceCacheEntry *> SliceByIsaHandle;
  for (auto &KV : Slices) {
    SliceCacheEntry &Entry = KV.second;
    auto ObjOrErr = luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(
        Entry.CodeObject.getBuffer());
    if (!ObjOrErr)
      return ObjOrErr.takeError();
    auto TupleOrErr = luthier::object::getObjectFileTargetTuple(**ObjOrErr);
    if (!TupleOrErr)
      return TupleOrErr.takeError();
    auto &[T, CPU, Features] = *TupleOrErr;
    auto IsaOrErr = hsa::isaFromLLVM(Core, T, CPU, Features);
    if (!IsaOrErr)
      return IsaOrErr.takeError();
    // try_emplace: first slice wins on hsa_isa_t collision (e.g. wave32
    // and wave64 share the same hsa_isa_t — HSA can't differentiate them).
    bool Inserted = SliceByIsaHandle.try_emplace(*IsaOrErr, &Entry).second;
    LLVM_DEBUG(llvm::dbgs()
               << "[DeviceToolCodeLoader]   slice key=[" << KV.first()
               << "] isa=" << IsaOrErr->handle
               << (Inserted ? " (registered)" : " (collision; first wins)")
               << "\n");
  }

  for (hsa_agent_t Agent : Agents) {
    if (PerAgentLoadRecords.contains(Agent)) {
      LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   agent "
                              << Agent.handle << " already loaded, skipping\n");
      continue; // Idempotent on already-loaded agents.
    }

    hsa_isa_t MatchedISA{0};
    for (hsa_isa_t SliceISA : SliceByIsaHandle.keys()) {

      auto MatchedOrErr = hsa::agentFindFirstISA(
          Core, Agent, [&](hsa_isa_t AgentIsa) -> llvm::Expected<bool> {
            llvm::Expected<bool> IsCompatible =
                hsa::isaCompatible(Core, SliceISA, AgentIsa);
            LUTHIER_RETURN_ON_ERROR(IsCompatible.takeError());
            LLVM_DEBUG(
                llvm::Expected<std::string> SliceISANameOrErr =
                    hsa::isaGetName(Core, SliceISA);
                if (!SliceISANameOrErr) return SliceISANameOrErr.takeError();
                llvm::Expected<std::string> AgentISANameOrErr =
                    hsa::isaGetName(Core, AgentIsa);
                if (!AgentISANameOrErr)
                  return AgentISANameOrErr.takeError();
                llvm::dbgs()
                << "[DeviceToolCodeLoader]   compat check: slice ISA=["
                << *SliceISANameOrErr << "] vs agent ISA=["
                << *AgentISANameOrErr << "] -> "
                << (*IsCompatible ? "compatible" : "incompatible") << "\n");
            if (*IsCompatible) {
              MatchedISA = SliceISA;
              return true;
            }
            return false;
          });
      if (!MatchedOrErr)
        return MatchedOrErr.takeError();
    }
    if (MatchedISA.handle == 0) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[DeviceToolCodeLoader]   agent " << Agent.handle
                 << " has no compatible slice, skipping\n");
      continue; // No slice compatible with this agent.
    }
    SliceCacheEntry *Match = SliceByIsaHandle.lookup(MatchedISA);
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   agent " << Agent.handle
                            << " matched slice CPU=" << Match->CPU << "\n");

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

    unsigned VarCount = 0;
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
      ++VarCount;
      return llvm::Error::success();
    };
    if (auto E = hsa::executableIterateAgentSymbols(Core, *ExeOrErr, Agent,
                                                    Callback))
      return E;
    LLVM_DEBUG(llvm::dbgs()
               << "[DeviceToolCodeLoader]   agent " << Agent.handle
               << " loaded; " << VarCount << " variable symbol(s) indexed\n");
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] loadOntoAgents done\n");
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// clearLoadedState
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeLoader::clearLoadedState() {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] clearLoadedState: "
                          << PerAgentLoadRecords.size()
                          << " per-agent record(s)\n");
  // If the HSA api-table snapshot was never populated (e.g. the
  // application aborted before dispatching any kernel, so
  // rocprofiler-sdk never delivered its registration callback), there
  // is no HSA-side state to tear down. Bail out quietly instead of
  // pulling the snapshot through \c getTable() and fatal-erroring.
  if (!CoreApiSnapshot.wasRegistrationCallbackInvoked()) {
    PerAgentLoadRecords.clear();
    NameToAgentGlobal.clear();
    ManagedVarRecords.clear();
    State = LoadState::Pending;
    return llvm::Error::success();
  }
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

llvm::Error
DeviceToolCodeLoader::loadManagedVars(llvm::ArrayRef<hsa_agent_t> Agents) {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] loadManagedVars: "
                          << Agents.size() << " agent(s), " << Slices.size()
                          << " slice(s)\n");
  const auto Core = CoreApiSnapshot.getTable();
  const auto AmdExt = AmdExtSnapshot.getTable();

  llvm::Expected<bool> HmmOrErr = getHmmSupported();
  if (!HmmOrErr)
    return HmmOrErr.takeError();
  const bool HmmSupported = *HmmOrErr;

  // Lazy CPU fine-grain pool resolution: only triggers the first time a
  // non-HMM allocation is about to happen. Stays uninitialized on the HMM
  // path (where the pool is unused) and on the no-managed-vars case (where
  // discovery finds nothing).
  hsa_amd_memory_pool_t Pool{};
  size_t Granule = 0;
  bool PoolResolved = false;
  auto EnsurePool = [&]() -> llvm::Error {
    if (PoolResolved)
      return llvm::Error::success();
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
    PoolResolved = true;
    return llvm::Error::success();
  };

  // Walk every slice's ELF symbol table to find managed-variable companions
  // (symbols named "<base>.managed"). The same managed var typically appears
  // in every slice (different ISAs of the same TU), so dedup by base name —
  // first occurrence wins.
  static constexpr llvm::StringLiteral ManagedSuffix = ".managed";
  llvm::StringSet<> Seen;

  for (const auto &KV : Slices) {
    const SliceCacheEntry &Entry = KV.second;
    auto ObjOrErr = luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(
        Entry.CodeObject.getBuffer());
    if (!ObjOrErr)
      return ObjOrErr.takeError();

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
      if (!Seen.insert(BaseName).second) {
        LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   managed-var "
                                << BaseName << " already seen, skipping\n");
        continue;
      }
      LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   managed-var "
                              << BaseName << " size=" << Size << "\n");

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
      auto VarContentsOrErr = object::getContents(Var);
      if (!VarContentsOrErr) {
        llvm::consumeError(VarContentsOrErr.takeError());
        continue;
      }
      llvm::ArrayRef<uint8_t> InitBytes = *VarContentsOrErr;
      const unsigned Align = (*SectionOrErr)->getAlignment().value();

      // Resolve the CPU pool the first time we need it on the non-HMM
      // path. Skipped entirely when HmmSupported, or when there are no
      // managed vars to allocate.
      if (!HmmSupported) {
        LUTHIER_RETURN_ON_ERROR(EnsurePool());
        if (Align > Granule)
          return LUTHIER_MAKE_HSA_ERROR(llvm::formatv(
              "Managed variable {0} alignment ({1}) exceeds pool granule "
              "({2}); over-aligned managed vars are not modelled.",
              BaseName, Align, Granule));
      }

      auto AllocOrErr = allocateManagedStorage(AmdExt, Agents, Pool, Size,
                                               Align, HmmSupported);
      if (!AllocOrErr)
        return AllocOrErr.takeError();
      ManagedAlloc Alloc = *AllocOrErr;
      LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   managed-var "
                              << BaseName << " allocated at " << Alloc.Ptr
                              << " (allocSize=" << Alloc.AllocSize << ")\n");

      auto FreeOnError = [&](llvm::Error E) {
        return llvm::joinErrors(std::move(E),
                                freeManagedStorage(AmdExt, Alloc));
      };

      // Copy initial value from the .managed-symbol section bytes.
      if (!InitBytes.empty())
        std::memcpy(Alloc.Ptr, InitBytes.data(),
                    std::min<size_t>(InitBytes.size(), Size));

      // Per-agent publish: write the managed-memory pointer into each
      // agent's loaded image of the base symbol so kernels reading the
      // base symbol go to the managed allocation.
      auto NameIt = NameToAgentGlobal.find(BaseName);
      if (NameIt == NameToAgentGlobal.end()) {
        LLVM_DEBUG(
            llvm::dbgs()
            << "[DeviceToolCodeLoader] base symbol not found for managed var "
            << BaseName << "\n");
      } else {
        for (hsa_agent_t Agent : Agents) {
          auto AgentIt = NameIt->second.find(Agent);
          if (AgentIt == NameIt->second.end())
            continue;
          auto AddrOrErr =
              hsa::executableSymbolGetAddress(Core, AgentIt->second);
          if (!AddrOrErr)
            return FreeOnError(AddrOrErr.takeError());
          LLVM_DEBUG(llvm::dbgs()
                     << "[DeviceToolCodeLoader]   publish " << BaseName
                     << " ptr=" << Alloc.Ptr << " to agent " << Agent.handle
                     << " base addr=0x" << llvm::Twine::utohexstr(*AddrOrErr)
                     << "\n");
          if (auto E = LUTHIER_HSA_CALL_ERROR_CHECK(
                  Core.callFunction<hsa_memory_copy>(
                      reinterpret_cast<void *>(*AddrOrErr), &Alloc.Ptr,
                      sizeof(void *)),
                  llvm::formatv("hsa_memory_copy failed publishing managed-var "
                                "pointer for {0}",
                                BaseName)))
            return FreeOnError(std::move(E));
        }
      }

      ManagedVarRec Rec;
      Rec.Allocation = Alloc.Ptr;
      Rec.AllocSize = Alloc.AllocSize;
      Rec.Size = Size;
      Rec.Align = Align;
      Rec.ViaSvm = Alloc.ViaSvm;
      ManagedVarRecords[BaseName] = Rec;
    }
    if (VarIterErr)
      return VarIterErr;
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] loadManagedVars done; "
                          << ManagedVarRecords.size() << " var(s) allocated\n");
  return llvm::Error::success();
}

llvm::Error DeviceToolCodeLoader::freeManagedVars() {
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] freeManagedVars: "
                          << ManagedVarRecords.size() << " record(s)\n");
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
    ManagedAlloc A{KV.second.Allocation, KV.second.AllocSize, KV.second.ViaSvm};
    E = llvm::joinErrors(std::move(E), freeManagedStorage(AmdExt, A));
  }
  ManagedVarRecords.clear();
  return E;
}

//===----------------------------------------------------------------------===//
// ensureLoaded
//===----------------------------------------------------------------------===//

llvm::Error DeviceToolCodeLoader::ensureLoaded() {
  std::lock_guard Lock(Mutex);
  if (State == LoadState::Loaded) {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ensureLoaded: already "
                               "loaded\n");
    return llvm::Error::success();
  }

  auto Core = CoreApiSnapshot.getTable();
  llvm::SmallVector<hsa_agent_t, 4> Agents;
  LUTHIER_RETURN_ON_ERROR(
      hsa::getAllAgentsWithDeviceType<HSA_DEVICE_TYPE_GPU>(Core, Agents));
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ensureLoaded: discovered "
                          << Agents.size() << " GPU agent(s)\n");

  if (auto E = loadOntoAgents(Agents)) {
    E = llvm::joinErrors(std::move(E), clearLoadedState());
    return E;
  }
  if (auto E = loadManagedVars(Agents)) {
    E = llvm::joinErrors(std::move(E), clearLoadedState());
    return E;
  }
  State = LoadState::Loaded;
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] ensureLoaded: complete\n");
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// getEmbeddedModule / getCachedISAs
//===----------------------------------------------------------------------===//

llvm::Expected<std::unique_ptr<llvm::Module>>
DeviceToolCodeLoader::getEmbeddedModule(const llvm::Triple &T,
                                        llvm::StringRef CPU,
                                        const llvm::SubtargetFeatures &Features,
                                        llvm::LLVMContext &Ctx) {
  std::lock_guard Lock(Mutex);
  if (auto E = ensureLoaded())
    return std::move(E);
  std::string Key = canonicalLLVMISAKey(T, CPU, Features);
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader] getEmbeddedModule key=["
                          << Key << "]\n");
  auto It = Slices.find(Key);
  if (It == Slices.end()) {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   exact-key miss; "
                               "attempting CPU-substring fallback for "
                            << CPU << "\n");
    // Fall back to a triple+CPU-only match. The slice's feature list
    // comes from its ELF metadata, which may have fewer qualifiers than
    // an HSA agent reports (e.g. agents surface +sramecc/-xnack while
    // a HIP fat-binary slice typically records bare gfxNNN). The HSA
    // loader does its own compatibility check at load time, so a
    // triple+CPU agreement is sufficient at this stage.
    // Match by CPU substring. Triple stringification differs in dash
    // count between an HSA-derived Triple (which surfaces an empty
    // Environment as a trailing dash) and an ELF-derived Triple (which
    // omits an unset Environment), so the leading prefix isn't stable.
    // CPU names (gfxNNN) are unique enough for an unambiguous match
    // among installed slices.
    std::string CPUMarker = ("-" + CPU + ",").str();
    std::string CPUTail = ("-" + CPU).str();
    for (auto &KV : Slices) {
      llvm::StringRef K = KV.first();
      if (K.contains(CPUMarker) || K.ends_with(CPUTail)) {
        LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   CPU-substring "
                                   "match: ["
                                << K << "]\n");
        It = Slices.find(KV.first());
        break;
      }
    }
  }
  if (It == Slices.end()) {
    LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   no slice matched\n");
    std::string AvailKeys;
    llvm::raw_string_ostream OS(AvailKeys);
    for (const auto &KV : Slices)
      OS << "  [" << KV.first() << "]\n";
    return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
        "No embedded bitcode cached for the requested LLVM ISA tuple. "
        "Requested: [{0}]. Available ({1} slices):\n{2}",
        Key, Slices.size(), AvailKeys));
  }
  LLVM_DEBUG(llvm::dbgs() << "[DeviceToolCodeLoader]   matched slice ["
                          << It->first() << "], parsing "
                          << It->second.Bitcode.getBufferSize()
                          << " bytes of bitcode\n");
  return llvm::parseBitcodeFile(It->second.Bitcode, Ctx);
}

} // namespace luthier
