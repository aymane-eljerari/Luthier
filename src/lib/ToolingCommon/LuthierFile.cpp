//===-- LuthierFile.cpp ---------------------------------------------------===//
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
/// \file LuthierFile.cpp
/// Implements \c loadLinkedLuthierFile and \c dumpLuthierFile — the two
/// .luthier I/O functions that require full LLVM IR support.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/LuthierFile.h"
#include "luthier/Common/GenericLuthierError.h"
#include <llvm/ADT/DenseMap.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/CodeGen/MIRParser/MIRParser.h>
#include <llvm/CodeGen/MIRPrinter.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/IR/MDBuilder.h>
#include <llvm/IR/Metadata.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/ModuleSlotTracker.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Support/Base64.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/Support/ToolOutputFile.h>
#include <llvm/Support/raw_ostream.h>

namespace luthier {

llvm::Expected<LuthierFile> readLuthierFile(llvm::MemoryBufferRef Buffer) {
  LuthierFile F;
  llvm::yaml::Input YIN(Buffer.getBuffer());
  YIN >> F;
  if (YIN.error())
    return llvm::createStringError(
        YIN.error(), "YAML parse error in .luthier file '" +
                         Buffer.getBufferIdentifier().str() + "'");
  return F;
}

llvm::Expected<LuthierFile> readLuthierFile(llvm::StringRef Path) {
  auto MBOrErr = llvm::MemoryBuffer::getFile(Path);
  if (!MBOrErr)
    return llvm::createStringError(MBOrErr.getError(),
                                   "Failed to open .luthier file '" +
                                       Path.str() + "'");
  return readLuthierFile((*MBOrErr)->getMemBufferRef());
}

llvm::Error splitLuthierFile(llvm::MemoryBufferRef LuthierFileBuffer,
                             llvm::raw_ostream &TargetOS,
                             llvm::raw_ostream &IModuleOS) {
  auto FOrErr = readLuthierFile(LuthierFileBuffer);
  if (!FOrErr)
    return FOrErr.takeError();
  TargetOS << FOrErr->TargetModule.S;
  IModuleOS << FOrErr->InstrumentationModule.S;
  return llvm::Error::success();
}

namespace {

/// Returns a map from metadata slot number to MDNode pointer for every
/// metadata node reachable from \p M
/// The slot numbers are identical to those that the IR printer assigns, because
/// both use the same \c ModuleSlotTracker logic internally
static llvm::DenseMap<unsigned, const llvm::MDNode *>
buildSlotToMDNodeMap(llvm::Module &M) {
  llvm::ModuleSlotTracker MST(&M, /*ShouldInitializeAllMetadata=*/true);
  llvm::ModuleSlotTracker::MachineMDNodeListType MDList;
  MST.collectMDNodes(MDList, 0, ~0u);
  llvm::DenseMap<unsigned, const llvm::MDNode *> Out;
  Out.reserve(MDList.size());
  for (auto &[Slot, MD] : MDList)
    Out[Slot] = MD;
  return Out;
}

} // namespace

llvm::Expected<
    std::pair<std::unique_ptr<llvm::Module>, std::unique_ptr<llvm::MIRParser>>>
loadIModule(llvm::MemoryBufferRef Buffer, IModuleFormat Format,
            const std::vector<MDSlotEntry> &MDSlotMap, llvm::LLVMContext &Ctx,
            llvm::Module &TargetModule) {
  /// Parse the module and create an MIR parser for the MMI if it's present
  std::unique_ptr<llvm::Module> M;
  std::unique_ptr<llvm::MIRParser> MIRParser;
  switch (Format) {
  case IModuleFormat::IR: {
    llvm::SMDiagnostic Err;
    M = llvm::parseIR(Buffer, Err, Ctx);
    if (!M)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse instrumentation module (IR) from '" +
          Buffer.getBufferIdentifier().str() + "': " + Err.getMessage().str());
    break;
  }
  case IModuleFormat::MIR: {
    auto Buf = llvm::MemoryBuffer::getMemBuffer(Buffer.getBuffer(),
                                                Buffer.getBufferIdentifier());
    MIRParser = llvm::createMIRParser(std::move(Buf), Ctx);
    if (!MIRParser)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to create MIR parser for instrumentation module from '" +
          Buffer.getBufferIdentifier().str() + "'");
    M = MIRParser->parseIRModule();
    if (!M)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse instrumentation module (MIR) from '" +
          Buffer.getBufferIdentifier().str() + "'");
    break;
  }
  case IModuleFormat::Bitcode: {
    std::vector<char> Decoded;
    if (auto Err = llvm::decodeBase64(Buffer.getBuffer(), Decoded))
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to base64-decode bitcode from '" +
          Buffer.getBufferIdentifier().str() +
          "': " + llvm::toString(std::move(Err)));
    auto Buf = llvm::MemoryBuffer::getMemBuffer(
        llvm::StringRef(Decoded.data(), Decoded.size()),
        Buffer.getBufferIdentifier(), /*RequiresNullTerminator=*/false);
    llvm::Error Err =
        llvm::parseBitcodeFile(Buf->getMemBufferRef(), Ctx).moveInto(M);
    if (Err)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse instrumentation module (Bitcode) from '" +
          Buffer.getBufferIdentifier().str() +
          "': " + llvm::toString(std::move(Err)));
    break;
  }
  default:
    llvm_unreachable("unhandled IModuleFormat");
  }
  if (MDSlotMap.empty())
    return std::make_pair(std::move(M), std::move(MIRParser));

  // Build slot → MDNode* maps for both modules, then RAUW each cross-module
  // reference so that IModule MDNodes are replaced by the live TargetModule
  // MDNodes they originally pointed to.
  auto TargetSlotToMD = buildSlotToMDNodeMap(TargetModule);
  auto IModuleSlotToMD = buildSlotToMDNodeMap(*M);

  for (auto &[IModSlot, TgtSlot] : MDSlotMap) {
    auto *IMD = IModuleSlotToMD.lookup(IModSlot);
    auto *TMD = TargetSlotToMD.lookup(TgtSlot);
    if (IMD && TMD && IMD != TMD)
      const_cast<llvm::MDNode *>(IMD)->replaceAllUsesWith(
          const_cast<llvm::MDNode *>(TMD));
  }
  return std::make_pair(std::move(M), std::move(MIRParser));
}

llvm::Error dumpLuthierFile(llvm::StringRef OutputPath,
                            llvm::Module &TargetModule, llvm::Module &IModule,
                            llvm::MachineModuleInfo *IModuleMMI) {
  LuthierFile F;

  // Serialize the target module as IR text.
  {
    llvm::raw_string_ostream OS(F.TargetModule.S);
    TargetModule.print(OS, nullptr);
  }

  // Serialize the instrumentation module: MIR if MMI was provided, IR
  // otherwise.
  if (IModuleMMI) {
    F.Format = IModuleFormat::MIR;
    llvm::raw_string_ostream OS(F.InstrumentationModule.S);
    llvm::printMIR(OS, IModule);
    for (const llvm::Function &Fn : IModule)
      if (auto *MF = IModuleMMI->getMachineFunction(Fn))
        llvm::printMIR(OS, *IModuleMMI, *MF);
  } else {
    llvm::raw_string_ostream OS(F.InstrumentationModule.S);
    IModule.print(OS, nullptr);
  }

  // Find MDNodes shared between both modules (same pointer = same LLVMContext
  // object) and record the slot-number pair so they can be re-linked on load.
  auto TargetSlotToMD = buildSlotToMDNodeMap(TargetModule);
  auto IModuleSlotToMD = buildSlotToMDNodeMap(IModule);

  llvm::DenseMap<const llvm::MDNode *, unsigned> TargetMDToSlot;
  TargetMDToSlot.reserve(TargetSlotToMD.size());
  for (auto &[Slot, MD] : TargetSlotToMD)
    TargetMDToSlot[MD] = Slot;

  for (auto &[IModSlot, MD] : IModuleSlotToMD) {
    if (auto It = TargetMDToSlot.find(MD); It != TargetMDToSlot.end())
      F.MDSlotMap.push_back({IModSlot, It->second});
  }

  std::error_code EC;
  auto OutFile = std::make_unique<llvm::ToolOutputFile>(OutputPath, EC,
                                                        llvm::sys::fs::OF_Text);
  if (EC)
    return LUTHIER_MAKE_GENERIC_ERROR("Failed to open .luthier output file '" +
                                      OutputPath.str() + "': " + EC.message());

  llvm::yaml::Output Yout(OutFile->os());
  Yout << F;
  OutFile->keep();
  return llvm::Error::success();
}

} // namespace luthier
