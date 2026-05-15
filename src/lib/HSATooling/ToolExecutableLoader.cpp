//===-- ToolExecutableManager.cpp - Luthier Tool Executable Manager -------===//
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
/// This file implements Luthier's Tool Executable Manager Singleton, and
/// instrumentation modules which are passed to the \c CodeGenerator.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/ToolExecutableLoader.h"
#include "luthier/HSA/Agent.h"
#include "luthier/HSA/LoadedCodeObject.h"
#include "luthier/HSA/hsa.h"
#include "luthier/HSATooling/LoadedCodeObjectCache.h"
#include "luthier/HSATooling/TargetManager.h"
#include "luthier/Object/AMDGCNObjectFile.h"
#include "luthier/Object/ObjectFileUtils.h"
#include "llvm/Object/OffloadBundle.h"

#include <llvm/Analysis/ValueTracking.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/IR/Constants.h>
#include <llvm/Transforms/Utils/Cloning.h>

#include <cstring>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-tool-executable-manager"

namespace {

// In uncompressed mode
constexpr char kOffloadBundleUncompressedMagicStr[] =
    "__CLANG_OFFLOAD_BUNDLE__";
static constexpr size_t kOffloadBundleUncompressedMagicStrSize =
    sizeof(kOffloadBundleUncompressedMagicStr);

// In compressed mode
constexpr char kOffloadBundleCompressedMagicStr[] = "CCOB";
static constexpr size_t kOffloadBundleCompressedMagicStrSize =
    sizeof(kOffloadBundleCompressedMagicStr);

constexpr uint32_t HipFatMAGIC2 = 0x48495046;
/// Use the same structure as the hipFatBinary

struct HipFatBinary {
  uint32_t magic;
  uint32_t version;
  void *binary;
  void *dummy1;
};

bool IsCodeObjectUncompressed(const void *Image) {
  return std::memcmp(Image,
                  reinterpret_cast<const void *>(
                  symbols::kOffloadBundleUncompressedMagicStr),
                  sizeof(symbols::kOffloadBundleUncompressedMagicStr) - 1) == 0;         
}

bool IsCodeObjectCompressed(const void *Image) {
  return std::memcmp(Image,
									reinterpret_cast<const void *>(
									symbols::kOffloadBundleCompressedMagicStr),
									sizeof(symbols::kOffloadBundleCompressedMagicStr) - 1) == 0;
}

uint64_t CalculateFatBinarySize(const void *Image, bool &IsCompressed) {
  const char *HeaderPtr = static_cast<const char *>(Image);
  if (IsCodeObjectCompressed(Image)) {
    IsCompressed = true;
    /// Skip the magic
    HeaderPtr += 4;
    uint16_t Version = *reinterpret_cast<const uint16_t *>(HeaderPtr);
    /// Version num consumed and compression method
    HeaderPtr += 4;
    if (Version == 2) {
      uint32_t TotalSize = *reinterpret_cast<const uint32_t *>(HeaderPtr);
      return TotalSize;
    } else if (Version == 3)
      return *reinterpret_cast<const uint64_t *>(HeaderPtr);
    else
      return 0;
  }
  /// TODO: Add FatBin offsets here for reference and above
  else if (IsCodeObjectUncompressed(Image)) {
    // 1. Skip Magic String (24 bytes)
    HeaderPtr += 24;

    // 2. Read Number of Entries
    uint64_t NumOfEntries = *reinterpret_cast<const uint64_t *>(HeaderPtr);
    if (NumOfEntries == 0)
      return 32; // Magic(24) + Count(8)
    HeaderPtr += 8;

    // We track the furthest byte reached in the file to determine TotalSize
    uint64_t FileTail = 0;

    // 3. Walk the Metadata Table
    for (uint64_t i = 0; i < NumOfEntries; ++i) {
      // Read fields exactly as laid out in the "Bundled Code Object Layout"
      uint64_t ObjOffset = *reinterpret_cast<const uint64_t *>(HeaderPtr);
      uint64_t ObjSize = *reinterpret_cast<const uint64_t *>(HeaderPtr + 8);
      uint64_t IDLength = *reinterpret_cast<const uint64_t *>(HeaderPtr + 16);

      // Track the end of the actual binary data blobs
      uint64_t EndOfCurrentBlob = ObjOffset + ObjSize;
      if (EndOfCurrentBlob > FileTail) 
        FileTail = EndOfCurrentBlob;
    
      // Move HeaderPtr to the start of the next entry:
      // Offset(8) + Size(8) + IDLength(8) + The ID String itself
      HeaderPtr += (24 + IDLength);
    }
    // The total size is the end of the last code object found
    return FileTail;
  }
  // Was not expecting an ELF here
  return 0;
}

unsigned GetMach(const AMDGCNObjectFile &Obj) {
  // e_flags contains the machine ID in the bits defined by EF_AMDGPU_MACH
  return Obj.getPlatformFlags() & llvm::ELF::EF_AMDGPU_MACH;
}

/// Helper to count how many features are explicitly defined in the Target ID
int GetSpecificityScore(const std::string& TargetID, bool IsGeneric) {
    int score = 0;
    /// Base architecture match is the baseline
    if (!TargetID.empty()) score = 1;

		/// Give high enough score to make sure non-generic ISA always gets picked
    if(!IsGeneric) score += 10;

    /// Each feature (+ or -) increases the specificity/score
    for (char c : TargetID) {
        if (c == '+' || c == '-') score++;
    }
    return score;
}

hsa_isa_t FindMostCompatibleISA(hsa_isa_t Candidate, bool IsCandidateGeneric, hsa_isa_t CurrentBest, bool IsCurrentBestGeneric) {

		auto CandidateStrOrErr = hsa::isaGetName(Candidate);
		if(!CandidateStrOrErr) return CurrentBest;
		
		auto BestStrOrErr = hsa::isaGetName(CurrentBest);
		if(!BestStrOrErr) return Candidate;

    std::string CandidateStr = std::move(*CandidateStrOrErr);
    std::string BestStr = std::move(*BestStrOrErr);

    /// Get the specificity scores
    int CandidateScore = GetSpecificityScore(CandidateStr, IsCandidateGeneric);
    int BestScore = GetSpecificityScore(BestStr, IsCurrentBestGeneric);

    /// HIP prefers the higher specificity score (more features)
    /// Example: "gfx908:sramecc+:xnack-" (Score 13) wins over "gfx908" (Score 11)
    if (CandidateScore > BestScore) 
        return Candidate;
    
    return CurrentBest;
}

/// Finds the ".llvmbc" section of the host storage ELF
/// \param StorageELF the \c luthier::object::AMDGCNObjectFile reference
/// \return an \c llvm::StringRef to the contents of the ".llvmbc" section
/// if found, or an \c llvm::Error if the bitcode was not found
llvm::Expected<llvm::StringRef>
getBitcodeBufferOfAMDGCNObjectFile(luthier::object::AMDGCNObjectFile &StorageELF) {
  // Find the ".llvmbc" section of the ELF
  for (const llvm::object::SectionRef &Section : StorageELF.sections()) {
    auto SectionName = Section.getName();
    LUTHIER_RETURN_ON_ERROR(SectionName.takeError());
    
    if (*SectionName == BCSectionName) {
      auto SectionContents = Section.getContents();
      LUTHIER_RETURN_ON_ERROR(SectionContents.takeError());
      
      return *SectionContents;
    }
  }
  
  return llvm::make_error<GenericLuthierError>(
      "Failed to find the bitcode section (.llvmbc) inside the AMDGCN storage ELF.");
}

} // namespace

namespace luthier {

template <>
ToolExecutableLoader *Singleton<ToolExecutableLoader>::Instance{nullptr};

t___hipRegisterFunction ToolExecutableLoader::UnderlyingHipRegisterFn{nullptr};

decltype(hsa_executable_freeze)
    *ToolExecutableLoader::UnderlyingHsaExecutableFreezeFn{nullptr};

decltype(hsa_executable_destroy)
    *ToolExecutableLoader::UnderlyingHsaExecutableDestroyFn{nullptr};

void ToolExecutableLoader::hipRegisterFunctionWrapper(
    void **modules, const void *hostFunction, char *deviceFunction,
    const char *deviceName, unsigned int threadLimit, uint3 *tid, uint3 *bid,
    dim3 *blockDim, dim3 *gridDim, int *wSize) {
  /// Check if the underlying function is not nullptr
  LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      UnderlyingHipRegisterFn != nullptr, "Underlying __hipRegisterFunction of "
                                          "ToolExecutableLoader is nullptr"));

  if (isInitialized()) {
    auto &TEL = ToolExecutableLoader::instance();
    // Look for kernels that serve as handles for hooks and register them with
    // the tool executable loader
    if (llvm::StringRef(deviceFunction).find(HookHandlePrefix) !=
        llvm::StringRef::npos) {
      TEL.SIM.HookHandleMap.insert(
          {hostFunction, llvm::StringRef(deviceFunction)
                             .substr(strlen(luthier::HookHandlePrefix))});
    }
  }
  UnderlyingHipRegisterFn(modules, hostFunction, deviceFunction, deviceName,
                          threadLimit, tid, bid, blockDim, gridDim, wSize);
}

hsa_status_t
ToolExecutableLoader::hsaExecutableFreezeWrapper(hsa_executable_t Executable,
                                                 const char *Options) {
  LUTHIER_REPORT_FATAL_ON_ERROR(
      LUTHIER_GENERIC_ERROR_CHECK(UnderlyingHsaExecutableFreezeFn != nullptr,
                                  "Underlying hsa_executable_freeze of "
                                  "ToolExecutableLoader is nullptr"));
  hsa_status_t Out = UnderlyingHsaExecutableFreezeFn(Executable, Options);
  if (Out != HSA_STATUS_SUCCESS)
    return Out;
  if (isInitialized()) {
    auto &TEL = instance();
    // Check if this executable is a static instrumentation module
    auto IsSIMExec =
        StaticInstrumentationModule::isStaticInstrumentationModuleExecutable(
            TEL.CoreApiSnapshot.getTable(), TEL.LoaderApiSnapshot.getTable(),
            Executable);
    LUTHIER_REPORT_FATAL_ON_ERROR(IsSIMExec.takeError());
    if (*IsSIMExec) {
      LUTHIER_REPORT_FATAL_ON_ERROR(TEL.SIM.registerExecutable(Executable));
      LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                     "Executable with handle {0:x} was registered as a static "
                     "instrumentation module.\n",
                     Executable.handle));
    }
  }
  return Out;
}

hsa_status_t
ToolExecutableLoader::hsaExecutableDestroyWrapper(hsa_executable_t Executable) {

  LUTHIER_REPORT_FATAL_ON_ERROR(
      LUTHIER_GENERIC_ERROR_CHECK(UnderlyingHsaExecutableDestroyFn != nullptr,
                                  "Underlying hsa_executable_destroy of "
                                  "ToolExecutableLoader is nullptr"));
  if (isInitialized()) {
    auto &TEL = instance();
    // Check if this belongs to the static instrumentation module
    // If so, then unregister it from the static module
    auto IsSIMExec =
        StaticInstrumentationModule::isStaticInstrumentationModuleExecutable(
            TEL.CoreApiSnapshot.getTable(), TEL.LoaderApiSnapshot.getTable(),
            Executable);
    LUTHIER_REPORT_FATAL_ON_ERROR(IsSIMExec.takeError());
    if (*IsSIMExec) {
      LUTHIER_REPORT_FATAL_ON_ERROR(TEL.SIM.unregisterExecutable(Executable));
      return UnderlyingHsaExecutableDestroyFn(Executable);
    }
    // Check if this executable has been instrumented before. If so,
    // destroy the instrumented versions of this executable, and remove its
    // entries from the internal maps
    if (TEL.OriginalExecutablesWithKernelsInstrumented.contains(Executable)) {
      // 1. Find all instrumented versions of each kernel of Exec
      // 2. For each instrumented kernel, get its executable and insert it in
      // InstrumentedVersionsOfExecutable to be dealt with later
      // 3. Remove instrumented entries of the original kernel
      llvm::SmallVector<hsa_loaded_code_object_t, 1> LCOs;
      LUTHIER_REPORT_FATAL_ON_ERROR(hsa::executableGetLoadedCodeObjects(
          TEL.LoaderApiSnapshot.getTable(), Executable, LCOs));
      const auto &COC = hsa::LoadedCodeObjectCache::instance();
      for (const auto &LCO : LCOs) {
        llvm::SmallVector<std::unique_ptr<hsa::LoadedCodeObjectSymbol>, 4>
            Kernels;
        LUTHIER_REPORT_FATAL_ON_ERROR(COC.getKernelSymbols(LCO, Kernels));
        for (const auto &Symbol : Kernels) {
          const auto &Kernel =
              *llvm::dyn_cast<hsa::LoadedCodeObjectKernel>(Symbol.get());
          hsa_executable_symbol_t ExecSymbol = *Kernel.getExecutableSymbol();
          if (TEL.OriginalToInstrumentedKernelsMap.contains(ExecSymbol)) {
            TEL.OriginalToInstrumentedKernelsMap.erase(
                TEL.OriginalToInstrumentedKernelsMap.find(ExecSymbol));
          }
        }
      }
      // clean up all instrumented versions of Exec

      for (auto &InstrumentedExec :
           TEL.OriginalExecutablesWithKernelsInstrumented[Executable]) {
        LUTHIER_REPORT_FATAL_ON_ERROR(hsa::executableDestroy(
            TEL.CoreApiSnapshot.getTable(), InstrumentedExec));
      }
    }
  }
  return UnderlyingHsaExecutableDestroyFn(Executable);
}

ToolExecutableLoader::ToolExecutableLoader(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiSnapshot,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &LoaderApiSnapshot,
    const hsa::LoadedCodeObjectCache &COC,
    const amdgpu::hsamd::MetadataParser &MDParser, llvm::Error &Err)
    : Singleton<ToolExecutableLoader>(), CoreApiSnapshot(CoreApiSnapshot),
      LoaderApiSnapshot(LoaderApiSnapshot), COC(COC), SIM(LoaderApiSnapshot),
      MDParser(MDParser) {

  CoreApiWrapperInstaller = std::make_unique<
      rocprofiler::HsaApiTableWrapperInstaller<::CoreApiTable>>(
      Err,
      std::make_tuple(&::CoreApiTable::hsa_executable_freeze_fn,
                      std::ref(UnderlyingHsaExecutableFreezeFn),
                      hsaExecutableFreezeWrapper),
      std::make_tuple(&::CoreApiTable::hsa_executable_destroy_fn,
                      std::ref(UnderlyingHsaExecutableDestroyFn),
                      hsaExecutableDestroyWrapper));
  if (Err)
    return;

  HipCompilerWrapperInstaller =
      std::make_unique<rocprofiler::HipCompilerApiTableWrapperInstaller>(
          Err,
          std::make_tuple(&::HipCompilerDispatchTable::__hipRegisterFunction_fn,
                          std::ref(UnderlyingHipRegisterFn),
                          hipRegisterFunctionWrapper));
  if (Err)
    return;
};

llvm::Expected<
    std::pair<hsa_executable_symbol_t, const amdgpu::hsamd::Kernel::Metadata &>>
ToolExecutableLoader::getInstrumentedKernel(
    hsa_executable_symbol_t OriginalKernel, llvm::StringRef Preset) const {
  const auto CoreApiTable = CoreApiSnapshot.getTable();
  llvm::Expected<hsa_symbol_kind_t> SymTypeOrErr =
      hsa::executableSymbolGetType(CoreApiTable, OriginalKernel);
  LUTHIER_RETURN_ON_ERROR(SymTypeOrErr.takeError());

  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      *SymTypeOrErr == HSA_SYMBOL_KIND_KERNEL, "Symbol is not a kernel"));

  // First make sure the OriginalKernel has instrumented entries
  auto InstrumentedKernelsIt =
      OriginalToInstrumentedKernelsMap.find(OriginalKernel);
  if (InstrumentedKernelsIt == OriginalToInstrumentedKernelsMap.end()) {
    auto KernelName =
        hsa::executableSymbolGetName(CoreApiTable, OriginalKernel);
    LUTHIER_RETURN_ON_ERROR(KernelName.takeError());
    return llvm::make_error<GenericLuthierError>(llvm::formatv(
        "Failed to find any instrumented version of kernel {0}.", *KernelName));
  }
  // Then make sure the original kernel was instrumented under the given Preset,
  // and then return the instrumented version
  auto InstrumentedKernelIt = InstrumentedKernelsIt->second.find(Preset);
  if (InstrumentedKernelIt == InstrumentedKernelsIt->second.end()) {
    auto KernelName =
        hsa::executableSymbolGetName(CoreApiTable, OriginalKernel);
    LUTHIER_RETURN_ON_ERROR(KernelName.takeError());
    return llvm::make_error<GenericLuthierError>(
        llvm::formatv("Failed to find any instrumented version of "
                      "kernel {0} under preset {1}.",
                      *KernelName, Preset));
  }
  hsa_executable_symbol_t Out = InstrumentedKernelIt->second;
  const auto &MD = *InstrumentedKernelMetadata.find(Out)->second;
  return std::make_pair(Out, MD);
}

llvm::Error ToolExecutableLoader::loadInstrumentedKernel(
    llvm::ArrayRef<uint8_t> InstrumentedElf,
    const hsa::LoadedCodeObjectKernel &OriginalKernel, llvm::StringRef Preset,
    const llvm::StringMap<const void *> &ExternVariables) {
  std::lock_guard Lock(Mutex);
  // Ensure this kernel was not instrumented under this preset
  if (isKernelInstrumented(OriginalKernel, Preset)) {
    auto OriginalKernelName = OriginalKernel.getName();
    LUTHIER_RETURN_ON_ERROR(OriginalKernelName.takeError());
    return llvm::make_error<GenericLuthierError>(
        llvm::formatv("Kernel {0} is already instrumented under preset {1}.",
                      *OriginalKernelName, Preset));
  }

  auto CoreApiTable = CoreApiSnapshot.getTable();

  // Create the executable
  auto Executable = hsa::executableCreate(CoreApiTable);
  LUTHIER_RETURN_ON_ERROR(Executable.takeError());

  // Define the Agent allocation external variables
  auto Agent = OriginalKernel.getAgent(LoaderApiSnapshot.getTable());
  LUTHIER_RETURN_ON_ERROR(Agent.takeError());

  for (const auto &[EVName, EVAddress] : ExternVariables) {
    LUTHIER_RETURN_ON_ERROR(hsa::executableDefineExternalAgentGlobalVariable(
        CoreApiSnapshot.getTable(), *Executable, *Agent, EVName, EVAddress));
  }

  // Load the code objects into the executable
  auto Reader =
      hsa::codeObjectReaderCreateFromMemory(CoreApiTable, InstrumentedElf);
  LUTHIER_RETURN_ON_ERROR(Reader.takeError());
  auto LCO = hsa::executableLoadAgentCodeObject(CoreApiTable, *Executable,
                                                *Reader, *Agent);
  LUTHIER_RETURN_ON_ERROR(LCO.takeError());
  // Freeze the executable
  LUTHIER_RETURN_ON_ERROR(hsa::executableFreeze(CoreApiTable, *Executable));

  // Find the original kernel in the instrumented executable
  std::string OriginalSymbolName;
  LUTHIER_RETURN_ON_ERROR(
      OriginalKernel.getName().moveInto(OriginalSymbolName));
  OriginalSymbolName.append(".kd");

  auto InstrumentedKernelOrErr = hsa::executableFindFirstAgentSymbol(
      CoreApiTable, *Executable, *Agent,
      [&](hsa_executable_symbol_t Symbol) -> llvm::Expected<bool> {
        llvm::Expected<std::string> SymbolNameOrErr =
            hsa::executableSymbolGetName(CoreApiTable, Symbol);
        LUTHIER_RETURN_ON_ERROR(SymbolNameOrErr.takeError());
        return llvm::StringRef(*SymbolNameOrErr) == OriginalSymbolName;
      });
  LUTHIER_RETURN_ON_ERROR(InstrumentedKernelOrErr.takeError());
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      InstrumentedKernelOrErr->has_value(),
      llvm::formatv("Failed to find the corresponding kernel "
                    "to {0} inside its instrumented executable",
                    OriginalSymbolName)));

  auto InstrumentedKernelType =
      hsa::executableSymbolGetType(CoreApiTable, **InstrumentedKernelOrErr);
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      *InstrumentedKernelType == HSA_SYMBOL_KIND_KERNEL,
      llvm::formatv(
          "Found the symbol associated with kernel {0} inside the instrumented "
          "executable, but it is not of type kernel.",
          OriginalSymbolName)));

  llvm::Expected<hsa_executable_t> OriginalExecutableOrErr =
      OriginalKernel.getExecutable(LoaderApiSnapshot.getTable());
  LUTHIER_RETURN_ON_ERROR(OriginalExecutableOrErr.takeError());

  /// Parse the metadata
  auto ObjFile =
      object::AMDGCNObjectFile::createAMDGCNObjectFile(InstrumentedElf);
  LUTHIER_RETURN_ON_ERROR(ObjFile.takeError());
  std::unique_ptr<llvm::msgpack::Document> InstrumentedExecMDDoc;
  LUTHIER_RETURN_ON_ERROR(
      (*ObjFile)->getMetadataDocument().moveInto(InstrumentedExecMDDoc));

  std::unique_ptr<amdgpu::hsamd::Kernel::Metadata> MD;

  LUTHIER_RETURN_ON_ERROR(
      MDParser.parseKernelMetadata(*InstrumentedExecMDDoc, OriginalSymbolName)
          .moveInto(MD));

  InstrumentedKernelMetadata.insert({**InstrumentedKernelOrErr, std::move(MD)});

  insertInstrumentedKernelIntoMap(*OriginalExecutableOrErr,
                                  *OriginalKernel.getExecutableSymbol(), Preset,
                                  *Executable, **InstrumentedKernelOrErr);
  LUTHIER_RETURN_ON_ERROR(hsa::codeObjectReaderDestroy(*Reader, CoreApiTable));
  return llvm::Error::success();
}

bool ToolExecutableLoader::isKernelInstrumented(
    const hsa::LoadedCodeObjectKernel &Kernel, llvm::StringRef Preset) const {
  return OriginalToInstrumentedKernelsMap.contains(
             *Kernel.getExecutableSymbol()) &&
         OriginalToInstrumentedKernelsMap.find(*Kernel.getExecutableSymbol())
             ->second.contains(Preset);
}

llvm::Error
ToolExecutableLoader::RegisterFatBinary(const void *RawFatBinWrapper) {
  const HipFatBinary *FatBinWrapper =
      static_cast<HipFatBinary *>(RawFatBinWrapper);

  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      FatBinWrapper->version == 1,
      llvm::formatv("Cannot Register fat binary. Invalid version: {0}",
                    FatBinWrapper->version)));

  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      FatBinWrapper->magic == HipFatMAGIC2,
      llvm::formatv("Fat binary wrapper has {0} magic number instead of {1}",
                    FatBinWrapper->magic, HipFatMAGIC2)));

  void *Binary = FatBinWrapper->binary;
  bool IsCompressed = false;

  uint64_t BinarySize = CalculateFatBinarySize(Binary, IsCompressed);

  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      BinarySize != 0, llvm::formatv("Fat binary is malformed or incorrect")));

  if (IsCompressed && BinarySize == 32)
    return llvm::Error::success(); // No binaries to be processed???

  const char *FatBinData = static_cast<const char *>(Binary);
  std::unique_ptr<llvm::MemoryBuffer> RawBuffer =
      llvm::MemoryBuffer::getMemBuffer(llvm::StringRef(FatBinData, BinarySize),
                                       "Fat Binary Buffer",
                                       /*RequiresNullTerminator=*/false);

  std::unique_ptr<llvm::MemoryBuffer> FinalDecompressedBuffer;

  if (IsCompressed) {
    auto DecompressedOrErr =
        llvm::object::CompressedOffloadBundle::decompress(*RawBuffer);

  	LUTHIER_RETURN_ON_ERROR(DecompressedOrErr.takeError());
    // Ownership of the newly allocated, decompressed heap memory is moved here
    FinalDecompressedBuffer = std::move(*DecompressedOrErr);
  } else {
    // If it's not compressed, just pass the raw wrapper right through.
    // Zero allocations, zero copies.
    FinalDecompressedBuffer = std::move(RawBuffer);
  }

	const char *BaseDataPtr = FinalDecompressedBuffer->getBufferStart();

  llvm::MemoryBufferRef FatBinRef = FinalDecompressedBuffer->getMemBufferRef();

  auto FatBinBundleOrErr =
      llvm::object::OffloadBundleFatBin::create(FatBinRef, 0, "hip-fat-binary");

  LUTHIER_RETURN_ON_ERROR(FatBinBundleOrErr.takeError());

  std::unique_ptr<llvm::object::OffloadBundleFatBin> FatBinBundle =
      std::move(*FatBinBundleOrErr);

  llvm::SmallVector<llvm::object::OffloadBundleEntry> FatBinEntries =
      FatBinBundle->GetEntries();

  llvm::SmallVector<hsa_agent_t, 4> AvailableAgents;
  llvm::DenseMap<hsa_agent_t, llvm::SmallVector<hsa_isa_t, 4>> AgentSupportedISA;
	/// Also store if MACH of the code object is generic
  llvm::DenseMap<hsa_agent_t,
                 std::tuple<llvm::object::OffloadBundleEntry, hsa_isa_t, bool, std::unique_ptr<luthier::object::AMDGCNObjectFile>>> AgentCompatibleCO;

  auto Err =
      luthier::hsa::getGpuAgents(CoreApiSnapshot.getTable(), AvailableAgents);
  if (Err != llvm::Error::success())
    return Err;

  for (auto Agent : AvailableAgents) {
    auto Err = luthier::hsa::agentGetSupportedISAs(
        CoreApiSnapshot.getTable(), Agent, AgentSupportedISA[Agent]);
    if (Err != llvm::Error::success())
      return Err;
  }

  for (llvm::object::OffloadBundleEntry BundleEntry : FatBinEntries) {
    void *COData = const_cast<char*>(BaseDataPtr + BundleEntry.Offset);
    size_t COSize = BundleEntry.Size;

    llvm::MemoryBufferRef COBufferRef(llvm::StringRef(COData, COSize), "CO object");

    auto COErr =
        luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(COBufferRef);
  	LUTHIER_RETURN_ON_ERROR(COErr.takeError());

    std::unique_ptr<luthier::object::AMDGCNObjectFile> CO = std::move(*COErr);

    auto TargetTupleOrErr = luthier::object::getObjectFileTargetTuple(*CO);
		LUTHIER_RETURN_ON_ERROR(TargetTupleOrErr.takeError());

    std::tuple<llvm::Triple, llvm::StringRef, llvm::SubtargetFeatures>
        TargetTuple = std::move(*TargetTupleOrErr);

    // Pluck individual items out using their index (0, 1, 2)
    llvm::Triple Triple = std::get<0>(TargetTuple);
    llvm::StringRef CpuName = std::get<1>(TargetTuple);
    llvm::SubtargetFeatures Features = std::get<2>(TargetTuple);

    auto ISAOrErr = luthier::hsa::isaFromLLVM(CoreApiSnapshot.getTable(),
                                              Triple, CpuName, Features);
		LUTHIER_RETURN_ON_ERROR(ISAOrErr.takeError());

    hsa_isa_t CodeObjectISA = *ISAOrErr;

    for (auto Agent : AvailableAgents) {
      /// Loop through AGENT ISA and compare handles
      /// hsa_isa_t only holds an integer handle so copies are not detremental
      for (hsa_isa_t AgentISA : AgentSupportedISA[Agent]) {
				if (AgentISA.handle != CodeObjectISA.handle) continue;
				/// If try_emplace fails this means an entry for this agent exists 
				/// and we need to determine the best CO
				bool IsGeneric = object::isGenericAMDGPUMach(GetMach(*CO));
				auto it = AgentCompatibleCO.find(Agent);

				if (it == AgentCompatibleCO.end()) {
          auto NewCOErr = luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(COBufferRef);
          LUTHIER_RETURN_ON_ERROR(NewCOErr.takeError());
			
          AgentCompatibleCO[Agent] = { BundleEntry, AgentISA, IsGeneric, std::move(*NewCOErr) };
        }
				else {
					hsa_isa_t ExistingISA = std::get<1>(it->second);
          bool ExistingIsGeneric = std::get<2>(it->second);
          hsa_isa_t MostCompatible = FindMostCompatibleISA(AgentISA, IsGeneric, ExistingISA, ExistingIsGeneric);

          if (MostCompatible == AgentISA) {
            auto NewCOErr = luthier::object::AMDGCNObjectFile::createAMDGCNObjectFile(COBufferRef);
            LUTHIER_RETURN_ON_ERROR(NewCOErr.takeError());
						
            it->second = { BundleEntry, AgentISA, IsGeneric, std::move(*NewCOErr) };
          }
				}
				/// If we found a match no use to loop over the rest of the ISAs
				break;
      }
    }
  }
	for(auto& [Agent, COTuple] : AgentCompatibleCO){
		auto& [COEntry, ISA, IsGeneric, AMDObjectFile] = COTuple;

		void *COData = const_cast<char*>(BaseDataPtr + COEntry.Offset);
    size_t COSize = COEntry.Size;

		auto CoreApiTable = CoreApiSnapshot.getTable();

		// Create the executable
		auto Executable = hsa::executableCreate(CoreApiTable);
		LUTHIER_RETURN_ON_ERROR(Executable.takeError());

		llvm::StringRef CORef{ COData, COSize };        
		auto Reader =
				hsa::codeObjectReaderCreateFromMemory(CoreApiTable, CORef);
		LUTHIER_RETURN_ON_ERROR(Reader.takeError());
		auto LCO = hsa::executableLoadAgentCodeObject(CoreApiTable, *Executable,
																									*Reader, Agent);
		LUTHIER_RETURN_ON_ERROR(LCO.takeError());
		// Freeze the executable
		LUTHIER_RETURN_ON_ERROR(hsa::executableFreeze(CoreApiTable, *Executable));

		AgentLoadedExecutables[Agent] = *Executable;

		/// Track Code Object bitcode per agent
		auto BitcodeOrErr = getBitcodeBufferOfAMDGCNObjectFile(*AMDObjectFile);
    LUTHIER_RETURN_ON_ERROR(BitcodeOrErr.takeError());
    AgentExecutableBitcode[Agent] = *BitcodeOrErr;
	}

	ManagedFatBinBuffers.push_back(std::move(FinalDecompressedBuffer));

	return llvm::Error::success();
}

ToolExecutableLoader::~ToolExecutableLoader() {
  // By the time the Tool Executable Manager is deleted, all instrumentation
  // kernels must have been destroyed; If not, print a warning, and clean
  // up anyway
  // TODO: Fix this, again
  //  if (!InstrumentedKernelMetadata.empty()) {
  //    luthier::outs()
  //        << "Tool executable manager is being destroyed while the original "
  //           "executables of its instrumented kernels are still frozen\n";
  //    llvm::DenseSet<hsa::Executable> InstrumentedExecs;
  //    for (auto &[LCO, COR] : InstrumentedKernelMetadata) {
  //      auto Exec = llvm::cantFail(LCO.getExecutable());
  //      InstrumentedExecs.insert(Exec);
  //      if (COR.destroy()) {
  //        luthier::outs() << llvm::formatv(
  //            "Code object reader {0:x} of Loaded Code Object {1:x},
  //            Executable "
  //            "{2:x} got destroyed with errors.\n",
  //            COR.hsaHandle(), LCO.hsaHandle(), Exec.hsaHandle());
  //      }
  //    }
  //    for (auto &Exec : InstrumentedExecs) {
  //      if (Exec.destroy()) {
  //        luthier::outs() << llvm::formatv(
  //            "Executable {0:x} got destroyed with errors.\n",
  //            Exec.hsaHandle());
  //      }
  //    }
  //  }
  OriginalToInstrumentedKernelsMap.clear();
}

} // namespace luthier
