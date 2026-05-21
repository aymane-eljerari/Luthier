//===-- InstrumentedKernelLoaderAndLauncher.cpp ---------------------------===//
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
#include "luthier/HSATooling/InstrumentedKernelLoaderAndLauncher.h"

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/CodeObjectReader.h"
#include "luthier/HSA/Executable.h"
#include "luthier/HSA/LoadedCodeObject.h"
#include "luthier/HSATooling/DeviceToolCodeLoader.h"
#include "luthier/Object/AMDGCNObjectFile.h"

#include <llvm/ADT/STLExtras.h>
#include <llvm/ADT/SmallSet.h>
#include <llvm/BinaryFormat/ELF.h>
#include <llvm/Object/SymbolicFile.h>
#include <llvm/Support/FormatVariadic.h>

namespace luthier {

//===----------------------------------------------------------------------===//
// Construction / destruction
//===----------------------------------------------------------------------===//

InstrumentedKernelLoaderAndLauncher::InstrumentedKernelLoaderAndLauncher(
    const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi,
    const rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
        &Loader,
    DeviceToolCodeLoader &DeviceCode)
    : CoreApi(CoreApi), Loader(Loader), DeviceCode(DeviceCode) {}

InstrumentedKernelLoaderAndLauncher::~InstrumentedKernelLoaderAndLauncher() {
  llvm::consumeError(unloadAll());
}

//===----------------------------------------------------------------------===//
// eraseRecordLocked
//===----------------------------------------------------------------------===//

llvm::Error InstrumentedKernelLoaderAndLauncher::eraseRecordLocked(
    llvm::DenseMap<Key, InstrumentedRecord, KeyDenseMapInfo>::iterator It) {
  llvm::Error E = llvm::Error::success();
  InstrumentedRecord &R = It->second;
  const Key K = It->first;
  const auto Core = CoreApi.getTable();

  // Detach from secondary indices first.
  ByOriginalKO.erase({R.OriginalKO, K.Preset});
  if (auto PIt = BySymbolPresets.find(K.OriginalKernel);
      PIt != BySymbolPresets.end()) {
    llvm::erase(PIt->second, K.Preset);
    if (PIt->second.empty())
      BySymbolPresets.erase(PIt);
  }

  // Executable first (releases its references into the reader's host
  // memory), then reader. The retained MemoryBuffer drops with the map
  // entry below.
  E = llvm::joinErrors(std::move(E), hsa::executableDestroy(Core, R.Exec));
  E = llvm::joinErrors(std::move(E),
                       hsa::codeObjectReaderDestroy(R.Reader, Core));

  ByOriginal.erase(It);
  return E;
}

//===----------------------------------------------------------------------===//
// unloadAll
//===----------------------------------------------------------------------===//

llvm::Error InstrumentedKernelLoaderAndLauncher::unloadAll() {
  llvm::sys::ScopedWriter W(Mutex);
  llvm::Error E = llvm::Error::success();
  for (auto It = ByOriginal.begin(); It != ByOriginal.end();) {
    auto Curr = It++;
    E = llvm::joinErrors(std::move(E), eraseRecordLocked(Curr));
  }
  return E;
}

//===----------------------------------------------------------------------===//
// unloadInstrumentedIfExists
//===----------------------------------------------------------------------===//

llvm::Error InstrumentedKernelLoaderAndLauncher::unloadInstrumentedIfExists(
    hsa_executable_symbol_t OriginalKernel, uint64_t Preset) {
  llvm::sys::ScopedWriter W(Mutex);
  auto It = ByOriginal.find(Key{OriginalKernel, Preset});
  if (It == ByOriginal.end())
    return llvm::Error::success();
  return eraseRecordLocked(It);
}

//===----------------------------------------------------------------------===//
// overrideWithInstrumented
//===----------------------------------------------------------------------===//

llvm::Error InstrumentedKernelLoaderAndLauncher::overrideWithInstrumented(
    hsa_kernel_dispatch_packet_t &Packet, uint64_t Preset) {
  llvm::sys::ScopedReader R(Mutex);
  auto It = ByOriginalKO.find({Packet.kernel_object, Preset});
  if (It == ByOriginalKO.end())
    return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
        "No instrumented variant cached for kernel_object {0:x} preset {1}",
        Packet.kernel_object, Preset));

  const InstrumentedRecord &Rec = *It->second;
  Packet.kernel_object = Rec.InstrumentedKO;
  Packet.private_segment_size =
      std::max<uint32_t>(Packet.private_segment_size, Rec.PrivateSegmentSize);
  return llvm::Error::success();
}

//===----------------------------------------------------------------------===//
// invalidateOriginalExec
//===----------------------------------------------------------------------===//

llvm::Error InstrumentedKernelLoaderAndLauncher::invalidateOriginalExec(
    hsa_executable_t Exec) {
  llvm::sys::ScopedWriter W(Mutex);
  llvm::Error E = llvm::Error::success();
  const auto Core = CoreApi.getTable();

  // Walk the destroyed executable's LCOs so we can iterate its
  // per-agent kernel symbols. We do this only on the agents this Exec
  // was loaded onto; SmallSet dedups when an Exec has multiple LCOs on
  // the same agent (uncommon but possible).
  llvm::SmallVector<hsa_loaded_code_object_t, 2> LCOs;
  if (auto Err = hsa::executableGetLoadedCodeObjects(Loader.getTable(), Exec,
                                                     LCOs))
    return llvm::joinErrors(std::move(E), std::move(Err));

  llvm::SmallSet<uint64_t, 2> SeenAgents;
  for (hsa_loaded_code_object_t LCO : LCOs) {
    auto AgentOrErr = hsa::loadedCodeObjectGetAgent(Loader.getTable(), LCO);
    if (!AgentOrErr) {
      E = llvm::joinErrors(std::move(E), AgentOrErr.takeError());
      continue;
    }
    if (!SeenAgents.insert(AgentOrErr->handle).second)
      continue;

    // Collect every (Sym, Preset) loaded under any kernel symbol we
    // find in this exec on this agent. We collect first and erase
    // afterwards so callbacks don't have to worry about iterator
    // invalidation in ByOriginal.
    llvm::SmallVector<Key, 4> Victims;
    auto IterErr = hsa::executableIterateAgentSymbols(
        Core, Exec, *AgentOrErr,
        [&](hsa_executable_symbol_t Sym) -> llvm::Error {
          auto KindOrErr = hsa::executableSymbolGetType(Core, Sym);
          if (!KindOrErr)
            return KindOrErr.takeError();
          if (*KindOrErr != HSA_SYMBOL_KIND_KERNEL)
            return llvm::Error::success();
          auto PIt = BySymbolPresets.find(Sym);
          if (PIt == BySymbolPresets.end())
            return llvm::Error::success();
          for (uint64_t Preset : PIt->second)
            Victims.push_back(Key{Sym, Preset});
          return llvm::Error::success();
        });
    if (IterErr) {
      E = llvm::joinErrors(std::move(E), std::move(IterErr));
      continue;
    }

    for (const Key &K : Victims) {
      auto It = ByOriginal.find(K);
      if (It != ByOriginal.end())
        E = llvm::joinErrors(std::move(E), eraseRecordLocked(It));
    }
  }
  return E;
}

//===----------------------------------------------------------------------===//
// loadInstrumented
//===----------------------------------------------------------------------===//

namespace {

/// Walk the parsed ELF and enumerate kernel-function symbols. Errors
/// unless exactly one exists; errors if its name doesn't match
/// \p ExpectedKernelName (no <tt>.kd</tt> suffix).
llvm::Error verifySingleKernelMatches(const object::AMDGCNObjectFile &Obj,
                                      llvm::StringRef ExpectedKernelName) {
  llvm::Error IterErr = llvm::Error::success();
  unsigned KernelCount = 0;
  bool NameMatched = false;
  for (const auto &KSym : Obj.kernel_functions(IterErr)) {
    ++KernelCount;
    auto NameOrErr = KSym.getName();
    LUTHIER_RETURN_ON_ERROR(NameOrErr.takeError());
    if (*NameOrErr == ExpectedKernelName)
      NameMatched = true;
  }
  LUTHIER_RETURN_ON_ERROR(std::move(IterErr));
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      KernelCount == 1,
      llvm::formatv("Instrumented relocatable must contain exactly one "
                    "kernel function; found {0}",
                    KernelCount)));
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      NameMatched,
      llvm::formatv("Instrumented kernel name does not match original "
                    "kernel name '{0}'",
                    ExpectedKernelName)));
  return llvm::Error::success();
}

/// Pair of (UND global variable name, its resolved device address) the
/// caller will feed into \c hsa_executable_agent_global_variable_define.
struct ExternRef {
  std::string Name;
  void *Address;
};

/// Walk \p Obj 's symbol table. For every undefined global/weak symbol
/// of object type, resolve it via \p DeviceCode on \p Agent and queue
/// it. Errors if any undefined symbol is a function (the codegen
/// pipeline must not emit inter-module function references).
llvm::Expected<llvm::SmallVector<ExternRef, 4>>
collectExternals(const hsa::ApiTableContainer<::CoreApiTable> &Core,
                 const object::AMDGCNObjectFile &Obj,
                 DeviceToolCodeLoader &DeviceCode, hsa_agent_t Agent) {
  llvm::SmallVector<ExternRef, 4> Out;
  for (const auto &Sym : Obj.symbols()) {
    auto FlagsOrErr = Sym.getFlags();
    LUTHIER_RETURN_ON_ERROR(FlagsOrErr.takeError());
    if (!(*FlagsOrErr & llvm::object::SymbolRef::SF_Undefined))
      continue;

    auto NameOrErr = Sym.getName();
    LUTHIER_RETURN_ON_ERROR(NameOrErr.takeError());
    if (NameOrErr->empty())
      continue;

    const uint8_t EType = Sym.getELFType();
    if (EType == llvm::ELF::STT_FUNC) {
      return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
          "Instrumented relocatable references undefined function "
          "symbol '{0}'; inter-module function references are not "
          "supported by the launcher",
          *NameOrErr));
    }
    if (EType != llvm::ELF::STT_OBJECT && EType != llvm::ELF::STT_NOTYPE)
      continue;

    const uint8_t Binding = Sym.getBinding();
    if (Binding != llvm::ELF::STB_GLOBAL && Binding != llvm::ELF::STB_WEAK)
      continue;

    auto ExtSymOrErr = DeviceCode.lookupGlobalVariable(*NameOrErr, Agent);
    LUTHIER_RETURN_ON_ERROR(ExtSymOrErr.takeError());
    auto AddrOrErr = hsa::executableSymbolGetAddress(Core, *ExtSymOrErr);
    LUTHIER_RETURN_ON_ERROR(AddrOrErr.takeError());

    Out.push_back(ExternRef{NameOrErr->str(),
                            reinterpret_cast<void *>(*AddrOrErr)});
  }
  return Out;
}

} // namespace

llvm::Expected<hsa_executable_symbol_t>
InstrumentedKernelLoaderAndLauncher::loadInstrumented(
    std::unique_ptr<llvm::MemoryBuffer> Relocatable,
    hsa_executable_symbol_t OriginalKernel, uint64_t Preset) {
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      Relocatable != nullptr,
      "Null relocatable MemoryBuffer passed to loadInstrumented"));

  const auto Core = CoreApi.getTable();

  // Resolve the original kernel's agent / name / KO up front so the
  // ELF-side checks can compare against them.
  auto AgentOrErr = hsa::executableSymbolGetAgent(Core, OriginalKernel);
  LUTHIER_RETURN_ON_ERROR(AgentOrErr.takeError());
  hsa_agent_t Agent = *AgentOrErr;

  auto NameOrErr = hsa::executableSymbolGetName(Core, OriginalKernel);
  LUTHIER_RETURN_ON_ERROR(NameOrErr.takeError());
  llvm::StringRef KDName(*NameOrErr);
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
      KDName.ends_with(".kd"),
      llvm::formatv("Original kernel symbol name '{0}' does not end with "
                    "'.kd'",
                    KDName)));
  std::string KernelName = KDName.drop_back(3).str();

  auto OrigKOOrErr = hsa::executableSymbolGetAddress(Core, OriginalKernel);
  LUTHIER_RETURN_ON_ERROR(OrigKOOrErr.takeError());
  uint64_t OriginalKO = *OrigKOOrErr;

  llvm::sys::ScopedWriter W(Mutex);

  // Duplicate-key check.
  if (ByOriginal.contains(Key{OriginalKernel, Preset}))
    return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
        "An instrumented variant for kernel '{0}' preset {1} is already "
        "loaded",
        KernelName, Preset));

  // Parse the relocatable as an AMDGCN ELF. The parse is non-owning over
  // the MemoryBuffer's bytes.
  llvm::MemoryBufferRef RelocRef = Relocatable->getMemBufferRef();
  auto ParsedOrErr =
      object::AMDGCNObjectFile::createAMDGCNObjectFile(RelocRef);
  LUTHIER_RETURN_ON_ERROR(ParsedOrErr.takeError());
  std::unique_ptr<object::AMDGCNObjectFile> Parsed = std::move(*ParsedOrErr);

  LUTHIER_RETURN_ON_ERROR(verifySingleKernelMatches(*Parsed, KernelName));

  auto ExternsOrErr = collectExternals(Core, *Parsed, DeviceCode, Agent);
  LUTHIER_RETURN_ON_ERROR(ExternsOrErr.takeError());

  // Stand up the HSA executable. From here on, every failure path must
  // tear down whatever has been built so far.
  auto ExecOrErr = hsa::executableCreate(Core);
  LUTHIER_RETURN_ON_ERROR(ExecOrErr.takeError());
  hsa_executable_t Exec = *ExecOrErr;

  auto FailExec = [&](llvm::Error E) -> llvm::Error {
    return llvm::joinErrors(std::move(E), hsa::executableDestroy(Core, Exec));
  };

  for (const ExternRef &Ext : *ExternsOrErr) {
    if (auto Err = hsa::executableDefineExternalAgentGlobalVariable(
            Core, Exec, Agent, Ext.Name, Ext.Address))
      return FailExec(std::move(Err));
  }

  auto ReaderOrErr =
      hsa::codeObjectReaderCreateFromMemory(Core, RelocRef.getBuffer());
  if (!ReaderOrErr)
    return FailExec(ReaderOrErr.takeError());
  hsa_code_object_reader_t Reader = *ReaderOrErr;

  auto FailExecAndReader = [&](llvm::Error E) -> llvm::Error {
    return llvm::joinErrors(
        llvm::joinErrors(std::move(E), hsa::executableDestroy(Core, Exec)),
        hsa::codeObjectReaderDestroy(Reader, Core));
  };

  if (auto Err = hsa::executableLoadAgentCodeObject(Core, Exec, Reader, Agent)
                     .takeError())
    return FailExecAndReader(std::move(Err));

  if (auto Err = hsa::executableFreeze(Core, Exec))
    return FailExecAndReader(std::move(Err));

  auto InstrSymOrErr =
      hsa::executableGetSymbolByName(Core, Exec, KDName, Agent);
  if (!InstrSymOrErr)
    return FailExecAndReader(InstrSymOrErr.takeError());
  if (!InstrSymOrErr->has_value())
    return FailExecAndReader(LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
        "Instrumented executable does not expose a kernel descriptor "
        "named '{0}'",
        KDName)));
  hsa_executable_symbol_t InstrSym = **InstrSymOrErr;

  auto InstrKOOrErr = hsa::executableSymbolGetAddress(Core, InstrSym);
  if (!InstrKOOrErr)
    return FailExecAndReader(InstrKOOrErr.takeError());

  auto PrivSizeOrErr =
      hsa::executableSymbolGetKernelPrivateSegmentSize(Core, InstrSym);
  if (!PrivSizeOrErr)
    return FailExecAndReader(PrivSizeOrErr.takeError());

  // Commit: insert into ByOriginal first, then point the secondary
  // indices at the live record.
  InstrumentedRecord Rec;
  Rec.RelocatableBuffer = std::move(Relocatable);
  Rec.Reader = Reader;
  Rec.Exec = Exec;
  Rec.InstrumentedKernelSym = InstrSym;
  Rec.InstrumentedKO = *InstrKOOrErr;
  Rec.PrivateSegmentSize = *PrivSizeOrErr;
  Rec.OriginalKO = OriginalKO;
  Rec.Agent = Agent;

  auto [It, Inserted] =
      ByOriginal.try_emplace(Key{OriginalKernel, Preset}, std::move(Rec));
  // We hold the writer lock and already checked above; the insert must
  // succeed.
  assert(Inserted && "Concurrent insert into ByOriginal under writer lock");
  (void)Inserted;
  ByOriginalKO[{OriginalKO, Preset}] = &It->second;
  BySymbolPresets[OriginalKernel].push_back(Preset);

  return InstrSym;
}

} // namespace luthier
