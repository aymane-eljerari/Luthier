//===-- DeviceToolCodeLoaderBase.cpp ------------------------------*-C++-*-===//
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
/// \file DeviceToolCodeLoaderBase.cpp
/// HSA-free parse path and HSA-side load path shared by the static
/// fat-binary loader and the dynamic module loader.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/DeviceToolCodeLoaderBase.h"
#include "luthier/HSA/CodeObjectReader.h"
#include "luthier/HSA/Executable.h"
#include "luthier/HSA/ExecutableSymbol.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/HSA/ISA.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include "luthier/Object/ObjectFileUtils.h"
#include <llvm/ADT/STLExtras.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/BinaryFormat/Magic.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/Object/ELFObjectFile.h>
#include <llvm/Object/OffloadBundle.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/raw_ostream.h>

#include <algorithm>

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
// Canonical LLVM ISA key
//===----------------------------------------------------------------------===//

std::string DeviceToolCodeLoaderBase::canonicalLLVMISAKey(
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
DeviceToolCodeLoaderBase::addSlice(llvm::MemoryBufferRef CodeObject) {
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
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// Constructors
//===----------------------------------------------------------------------===//

DeviceToolCodeLoaderBase::DeviceToolCodeLoaderBase(
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

DeviceToolCodeLoaderBase::DeviceToolCodeLoaderBase(
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

DeviceToolCodeLoaderBase::~DeviceToolCodeLoaderBase() { clearLoadedState(); }

//===----------------------------------------------------------------------===//
// loadOntoAgents
//===----------------------------------------------------------------------===//

llvm::Error
DeviceToolCodeLoaderBase::loadOntoAgents(llvm::ArrayRef<hsa_agent_t> Agents) {
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
    PerAgentLoadRecords[Agent] = LoadRecord{*ReaderOrErr, *LCOOrErr, *ExeOrErr};

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

void DeviceToolCodeLoaderBase::clearLoadedState() noexcept {
  auto Core = CoreApiSnapshot.getTable();
  auto Swallow = [](llvm::Error E) {
    if (E) {
      LLVM_DEBUG(llvm::dbgs() << "[luthier] unload: "
                              << llvm::toString(std::move(E)) << "\n");
      consumeError(std::move(E));
    } else {
      consumeError(std::move(E));
    }
  };
  for (auto &KV : PerAgentLoadRecords) {
    Swallow(hsa::executableDestroy(Core, KV.second.Executable));
    Swallow(hsa::codeObjectReaderDestroy(KV.second.Reader, Core));
  }
  PerAgentLoadRecords.clear();
  NameToAgentGlobal.clear();
}

//===----------------------------------------------------------------------===//
// getEmbeddedModule / getCachedISAs
//===----------------------------------------------------------------------===//

llvm::Expected<std::unique_ptr<llvm::Module>>
DeviceToolCodeLoaderBase::getEmbeddedModule(
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

llvm::SmallVector<DeviceToolCodeLoaderBase::CachedISA, 4>
DeviceToolCodeLoaderBase::getCachedISAs() {
  std::lock_guard Lock(Mutex);
  llvm::SmallVector<CachedISA, 4> Out;
  Out.reserve(Slices.size());
  for (const auto &KV : Slices)
    Out.push_back(CachedISA{KV.second.T, KV.second.CPU, KV.second.Features});
  return Out;
}

} // namespace luthier
