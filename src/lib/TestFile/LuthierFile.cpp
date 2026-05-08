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
/// Implements \c LuthierFileParser and the \c writeLuthierFile helpers.
//===----------------------------------------------------------------------===//
#include "luthier/TestFile/LuthierFile.h"
#include "luthier/Common/GenericLuthierError.h"
#include <llvm/ADT/DenseMap.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/CodeGen/MIRParser/MIRParser.h>
#include <llvm/CodeGen/MIRPrinter.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/IR/Metadata.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/ModuleSlotTracker.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Transforms/Utils/ValueMapper.h>
#include <llvm/Support/Base64.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/Support/ToolOutputFile.h>
#include <llvm/Support/YAMLTraits.h>
#include <llvm/Support/raw_ostream.h>

namespace luthier {

//===----------------------------------------------------------------------===//
// Internal YAML helper types
//===----------------------------------------------------------------------===//

/// String wrapper that round-trips through YAML as a literal block scalar
/// (the \c | style), preserving multi-line IR/MIR text without quoting or
/// escaping.  This is an internal implementation detail; callers of
/// \c LuthierFileParser interact only with \c llvm::StringRef
///
/// \c std::string already has \c ScalarTraits in LLVM's YAML library, which
/// escapes newlines into a single quoted line.  \c BlockScalarTraits cannot
/// be attached to \c std::string because that specialization is already
/// taken, so this distinct wrapper type is used instead
struct IRBlockString {
  std::string S;

  IRBlockString() = default;
  operator llvm::StringRef() const { return S; }
};

/// Internal YAML-visible mirror of the \c .luthier file schema
/// \c LuthierFileParser::create parses into this struct and then moves the
/// fields into the parser object; \c writeLuthierFile builds one from the
/// two modules before emitting YAML
struct LuthierFileYaml {
  IRBlockString TargetModuleText;
  IRBlockString InstrumentationModuleText;
  LuthierFileParser::IModuleFormat Format =
      LuthierFileParser::IModuleFormat::IR;
  std::vector<LuthierFileParser::MDSlotEntry> MDSlotMap;
};

} // namespace luthier

//===----------------------------------------------------------------------===//
// YAML traits
//===----------------------------------------------------------------------===//

namespace llvm::yaml {

template <> struct BlockScalarTraits<luthier::IRBlockString> {
  static void output(const luthier::IRBlockString &V, void *,
                     llvm::raw_ostream &OS) {
    OS << V.S;
  }
  static llvm::StringRef input(llvm::StringRef Str, void *,
                               luthier::IRBlockString &V) {
    V.S = Str.str();
    return {};
  }
};

template <> struct MappingTraits<luthier::LuthierFileParser::MDSlotEntry> {
  static void mapping(IO &IO, luthier::LuthierFileParser::MDSlotEntry &E) {
    IO.mapRequired("IModuleSlot", E.IModuleSlot);
    IO.mapRequired("TargetSlot", E.TargetSlot);
  }
};

template <>
struct ScalarEnumerationTraits<luthier::LuthierFileParser::IModuleFormat> {
  static void enumeration(IO &IO,
                          luthier::LuthierFileParser::IModuleFormat &F) {
    IO.enumCase(F, "IR", luthier::LuthierFileParser::IModuleFormat::IR);
    IO.enumCase(F, "Bitcode",
                luthier::LuthierFileParser::IModuleFormat::Bitcode);
    IO.enumCase(F, "MIR", luthier::LuthierFileParser::IModuleFormat::MIR);
  }
};

template <> struct MappingTraits<luthier::LuthierFileYaml> {
  static void mapping(IO &IO, luthier::LuthierFileYaml &F) {
    IO.mapRequired("TargetModule", F.TargetModuleText);
    IO.mapRequired("InstrumentationModule", F.InstrumentationModuleText);
    IO.mapOptional("Format", F.Format,
                   luthier::LuthierFileParser::IModuleFormat::IR);
    IO.mapOptional("MDSlotMap", F.MDSlotMap,
                   std::vector<luthier::LuthierFileParser::MDSlotEntry>{});
  }
};

} // namespace llvm::yaml

LLVM_YAML_IS_SEQUENCE_VECTOR(luthier::LuthierFileParser::MDSlotEntry)

namespace luthier {

namespace {

/// Returns a map from metadata slot number to \c MDNode* for every metadata
/// node reachable from \p M. The slot numbers match the IR printer's
/// assignment because both use \c ModuleSlotTracker
llvm::DenseMap<unsigned, llvm::MDNode *> buildSlotToMDNodeMap(llvm::Module &M) {
  llvm::ModuleSlotTracker MST(&M, /*ShouldInitializeAllMetadata=*/true);
  llvm::ModuleSlotTracker::MachineMDNodeListType MDList;
  MST.collectMDNodes(MDList, 0, ~0u);
  llvm::DenseMap<unsigned, llvm::MDNode *> Out;
  Out.reserve(MDList.size());
  for (auto &[Slot, MD] : MDList)
    Out[Slot] = const_cast<llvm::MDNode *>(MD);
  return Out;
}

} // namespace

//===----------------------------------------------------------------------===//
// LuthierFileParser
//===----------------------------------------------------------------------===//

llvm::Expected<LuthierFileParser>
LuthierFileParser::create(llvm::MemoryBufferRef Buffer) {
  LuthierFileYaml Y;
  llvm::yaml::Input YIN(Buffer.getBuffer());
  YIN >> Y;
  if (YIN.error())
    return llvm::createStringError(
        YIN.error(), "YAML parse error in .luthier file '" +
                         Buffer.getBufferIdentifier().str() + "'");
  LuthierFileParser P;
  P.TargetModuleText = std::move(Y.TargetModuleText.S);
  P.InstrumentationModuleText = std::move(Y.InstrumentationModuleText.S);
  P.Format = Y.Format;
  P.MDSlotMap = std::move(Y.MDSlotMap);
  return P;
}

llvm::Expected<LuthierFileParser>
LuthierFileParser::create(llvm::StringRef Path) {
  auto MBOrErr = llvm::MemoryBuffer::getFile(Path);
  if (!MBOrErr)
    return llvm::createStringError(MBOrErr.getError(),
                                   "Failed to open .luthier file '" +
                                       Path.str() + "'");
  return create((*MBOrErr)->getMemBufferRef());
}

llvm::Expected<
    std::pair<std::unique_ptr<llvm::Module>, std::unique_ptr<llvm::MIRParser>>>
LuthierFileParser::loadTargetModule(
    llvm::LLVMContext &Ctx,
    std::function<std::optional<std::string>(llvm::StringRef, llvm::StringRef)>
        SetDataLayout,
    std::function<void(llvm::Function &)> SetMIRFunctionAttributes) const {
  auto Buf =
      llvm::MemoryBuffer::getMemBuffer(TargetModuleText, "<luthier target>");
  auto FnAttrCB = [&](llvm::Function &F) {
    if (SetMIRFunctionAttributes)
      SetMIRFunctionAttributes(F);
  };
  auto Parser = llvm::createMIRParser(std::move(Buf), Ctx, FnAttrCB);
  if (!Parser)
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Failed to create MIR parser for target module");
  auto DataLayoutCB =
      [&](llvm::StringRef TT,
          llvm::StringRef OldDL) -> std::optional<std::string> {
    if (SetDataLayout)
      return SetDataLayout(TT, OldDL);
    return std::nullopt;
  };
  auto M = Parser->parseIRModule(DataLayoutCB);
  if (!M)
    return LUTHIER_MAKE_GENERIC_ERROR("Failed to parse target module (MIR)");
  return std::make_pair(std::move(M), std::move(Parser));
}

llvm::Expected<
    std::pair<std::unique_ptr<llvm::Module>, std::unique_ptr<llvm::MIRParser>>>
LuthierFileParser::loadIModule(llvm::LLVMContext &Ctx,
                               llvm::Module &TargetModule) const {
  llvm::MemoryBufferRef Buf(InstrumentationModuleText, "<luthier imodule>");

  std::unique_ptr<llvm::Module> M;
  std::unique_ptr<llvm::MIRParser> MIRParser;

  switch (Format) {
  case IModuleFormat::IR: {
    llvm::SMDiagnostic Err;
    M = llvm::parseIR(Buf, Err, Ctx);
    if (!M)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse instrumentation module (IR): " +
          Err.getMessage().str());
    break;
  }
  case IModuleFormat::MIR: {
    auto OwningBuf = llvm::MemoryBuffer::getMemBuffer(
        Buf.getBuffer(), Buf.getBufferIdentifier());
    MIRParser = llvm::createMIRParser(std::move(OwningBuf), Ctx);
    if (!MIRParser)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to create MIR parser for instrumentation module");
    M = MIRParser->parseIRModule();
    if (!M)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse instrumentation module (MIR)");
    break;
  }
  case IModuleFormat::Bitcode: {
    std::vector<char> Decoded;
    if (auto Err = llvm::decodeBase64(Buf.getBuffer(), Decoded))
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to base64-decode instrumentation module bitcode: " +
          llvm::toString(std::move(Err)));
    auto DecodedBuf = llvm::MemoryBuffer::getMemBuffer(
        llvm::StringRef(Decoded.data(), Decoded.size()),
        Buf.getBufferIdentifier(), /*RequiresNullTerminator=*/false);
    llvm::Error Err =
        llvm::parseBitcodeFile(DecodedBuf->getMemBufferRef(), Ctx).moveInto(M);
    if (Err)
      return LUTHIER_MAKE_GENERIC_ERROR(
          "Failed to parse instrumentation module (Bitcode): " +
          llvm::toString(std::move(Err)));
    break;
  }
  }

  // Patch cross-module MDNode references so that IModule metadata points back
  // into the live TargetModule MDNodes it originally shared.
  //
  // We use MapMetadata (from ValueMapper) rather than replaceAllUsesWith
  // because pcsections MDNodes are uniqued (not temporary), so RAUW would
  // assert.  MapMetadata does a recursive, cached walk: leaf nodes in the map
  // are substituted directly; any wrapper MDNode whose operands changed gets a
  // fresh uniqued copy.  RF_NoModuleLevelChanges prevents it from trying to
  // remap Values (globals, functions) that aren't in the map.
  if (!MDSlotMap.empty()) {
    auto TargetSlotToMD = buildSlotToMDNodeMap(TargetModule);
    auto IModuleSlotToMD = buildSlotToMDNodeMap(*M);

    llvm::ValueToValueMapTy VM;
    for (auto &[IModSlot, TgtSlot] : MDSlotMap) {
      llvm::MDNode *IMD = IModuleSlotToMD.lookup(IModSlot);
      llvm::MDNode *TMD = TargetSlotToMD.lookup(TgtSlot);
      if (IMD && TMD && IMD != TMD)
        VM.MD()[IMD].reset(TMD);
    }

    if (!VM.MD().empty()) {
      auto remapAttachments = [&](llvm::GlobalObject &GO) {
        llvm::SmallVector<std::pair<unsigned, llvm::MDNode *>> Attachments;
        GO.getAllMetadata(Attachments);
        for (auto &[KindID, MD] : Attachments)
          if (auto *NewMD =
                  llvm::MapMetadata(MD, VM, llvm::RF_NoModuleLevelChanges))
            GO.setMetadata(KindID, NewMD);
      };

      for (llvm::Function &F : *M) {
        remapAttachments(F);
        for (llvm::BasicBlock &BB : F)
          for (llvm::Instruction &I : BB) {
            llvm::SmallVector<std::pair<unsigned, llvm::MDNode *>> IMDs;
            I.getAllMetadata(IMDs);
            for (auto &[KindID, MD] : IMDs)
              if (auto *NewMD = llvm::MapMetadata(MD, VM,
                                                  llvm::RF_NoModuleLevelChanges))
                I.setMetadata(KindID, NewMD);
          }
      }

      for (llvm::GlobalVariable &GV : M->globals())
        remapAttachments(GV);

      for (llvm::NamedMDNode &NMD : M->named_metadata())
        for (unsigned I = 0, E = NMD.getNumOperands(); I != E; ++I)
          if (auto *NewMD = llvm::MapMetadata(NMD.getOperand(I), VM,
                                              llvm::RF_NoModuleLevelChanges))
            NMD.setOperand(I, NewMD);
    }
  }

  return std::make_pair(std::move(M), std::move(MIRParser));
}

//===----------------------------------------------------------------------===//
// writeLuthierFile
//===----------------------------------------------------------------------===//

llvm::Error writeLuthierFile(llvm::raw_ostream &OS, llvm::Module &TargetModule,
                             llvm::Module &IModule,
                             llvm::MachineModuleInfo *IModuleMMI) {
  LuthierFileYaml Y;

  {
    llvm::raw_string_ostream SS(Y.TargetModuleText.S);
    TargetModule.print(SS, nullptr);
  }

  if (IModuleMMI) {
    Y.Format = LuthierFileParser::IModuleFormat::MIR;
    llvm::raw_string_ostream SS(Y.InstrumentationModuleText.S);
    llvm::printMIR(SS, IModule);
    for (const llvm::Function &Fn : IModule)
      if (auto *MF = IModuleMMI->getMachineFunction(Fn))
        llvm::printMIR(SS, *IModuleMMI, *MF);
  } else {
    llvm::raw_string_ostream SS(Y.InstrumentationModuleText.S);
    IModule.print(SS, nullptr);
  }

  // Record MDNode slot pairs shared between both modules so that loadIModule
  // can restore the cross-module links on reload.
  auto TargetSlotToMD = buildSlotToMDNodeMap(TargetModule);
  auto IModuleSlotToMD = buildSlotToMDNodeMap(IModule);

  llvm::DenseMap<const llvm::MDNode *, unsigned> TargetMDToSlot;
  TargetMDToSlot.reserve(TargetSlotToMD.size());
  for (auto &[Slot, MD] : TargetSlotToMD)
    TargetMDToSlot[MD] = Slot;

  for (auto &[IModSlot, MD] : IModuleSlotToMD) {
    auto It = TargetMDToSlot.find(MD);
    if (It != TargetMDToSlot.end())
      Y.MDSlotMap.push_back({IModSlot, It->second});
  }

  llvm::yaml::Output Yout(OS);
  Yout << Y;
  return llvm::Error::success();
}

llvm::Error writeLuthierFile(llvm::StringRef Path, llvm::Module &TargetModule,
                             llvm::Module &IModule,
                             llvm::MachineModuleInfo *IModuleMMI) {
  std::error_code EC;
  llvm::ToolOutputFile OutFile(Path, EC, llvm::sys::fs::OF_Text);
  if (EC)
    return LUTHIER_MAKE_GENERIC_ERROR("Failed to open .luthier output file '" +
                                      Path.str() + "': " + EC.message());
  if (auto Err =
          writeLuthierFile(OutFile.os(), TargetModule, IModule, IModuleMMI))
    return Err;
  OutFile.keep();
  return llvm::Error::success();
}

} // namespace luthier
