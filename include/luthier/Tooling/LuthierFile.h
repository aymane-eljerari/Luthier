//===-- LuthierFile.h -------------------------------------------*- C++ -*-===//
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
/// \file LuthierFile.h
/// Defines the \c LuthierFile data structure, YAML I/O traits, and all I/O
/// helpers for the \c .luthier combined module file format.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_LUTHIER_FILE_H
#define LUTHIER_TOOLING_LUTHIER_FILE_H
#include "luthier/Object/AMDGCNObjectFile.h"

#include <llvm/CodeGen/MIRParser/MIRParser.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBufferRef.h>
#include <llvm/Support/YAMLTraits.h>
#include <memory>
#include <string>
#include <vector>

namespace llvm {
class LLVMContext;
class MachineModuleInfo;
class Module;
class raw_ostream;
} // namespace llvm

namespace luthier {

/// \brief Wrapper around \c std::string that serializes as a YAML literal block
/// scalar
/// (\c |) rather than a quoted flow scalar.
///
/// \details \c std::string already has \c ScalarTraits in LLVM's YAML library,
/// which escapes newlines and emits a single-line quoted string.
/// This wrapper is created so that \c BlockScalarTraits can be specialized on
/// it, causing the YAML emitter to preserve multi-line IR/MIR text verbatim
struct IRBlockString {
  std::string S;

  IRBlockString() = default;
  explicit IRBlockString(std::string Str) : S(std::move(Str)) {}

  operator llvm::StringRef() const { return S; }
};

/// One entry in the cross-module metadata slot map embedded in a .luthier file.
/// Maps a metadata slot number in the instrumentation module to the slot
/// number of the same MDNode in the target module.
struct MDSlotEntry {
  unsigned IModuleSlot = 0;
  unsigned TargetSlot = 0;

  bool operator==(const MDSlotEntry &) const = default;
};

/// Encoding of the \c InstrumentationModule field in a .luthier file.
enum class IModuleFormat {
  IR,      ///< LLVM IR text (.ll)
  Bitcode, ///< LLVM bitcode, base64-encoded in the YAML block scalar
  MIR,     ///< Machine IR text (.mir)
};

/// In-memory representation of a .luthier file.
///
/// The format is a YAML mapping with four keys:
///   - \c TargetModule: literal block scalar holding the target module IR/MIR.
///   - \c InstrumentationModule: literal block scalar holding the IModule
///     content (encoding depends on \c Format).
///   - \c Format (optional, default \c IR): encoding of \c
///   InstrumentationModule.
///   - \c MDSlotMap (optional): sequence of \c MDSlotEntry pairs linking shared
///     MDNodes between the two modules.
struct LuthierFile {
  IRBlockString TargetModule;
  IRBlockString InstrumentationModule;
  IModuleFormat Format = IModuleFormat::IR;
  std::vector<MDSlotEntry> MDSlotMap;
};

} // namespace luthier

//===----------------------------------------------------------------------===//
// YAML traits for the Luthier file
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

template <> struct MappingTraits<luthier::MDSlotEntry> {
  static void mapping(IO &IO, luthier::MDSlotEntry &E) {
    IO.mapRequired("IModuleSlot", E.IModuleSlot);
    IO.mapRequired("TargetSlot", E.TargetSlot);
  }
};

template <> struct ScalarEnumerationTraits<luthier::IModuleFormat> {
  static void enumeration(IO &IO, luthier::IModuleFormat &F) {
    IO.enumCase(F, "IR", luthier::IModuleFormat::IR);
    IO.enumCase(F, "Bitcode", luthier::IModuleFormat::Bitcode);
    IO.enumCase(F, "MIR", luthier::IModuleFormat::MIR);
  }
};

template <> struct MappingTraits<luthier::LuthierFile> {
  static void mapping(IO &IO, luthier::LuthierFile &F) {
    IO.mapRequired("TargetModule", F.TargetModule);
    IO.mapRequired("InstrumentationModule", F.InstrumentationModule);
    IO.mapOptional("Format", F.Format, luthier::IModuleFormat::IR);
    IO.mapOptional("MDSlotMap", F.MDSlotMap,
                   std::vector<luthier::MDSlotEntry>{});
  }
};

} // namespace llvm::yaml

LLVM_YAML_IS_SEQUENCE_VECTOR(luthier::MDSlotEntry)

namespace luthier {

/// Parses a \c .luthier file from \p Buffer and returns the structured
/// <tt>LuthierFile</tt>
llvm::Expected<LuthierFile> readLuthierFile(llvm::MemoryBufferRef Buffer);

/// Parses a .luthier file at \p Path and returns the structured
/// \c LuthierFile.
llvm::Expected<LuthierFile> readLuthierFile(llvm::StringRef Path);

/// Extracts the two module texts from \p Buffer, writing the target module to
/// \p TargetOS and the instrumentation module to \p IModuleOS.
llvm::Error splitLuthierFile(llvm::MemoryBufferRef LuthierFileBuffer,
                             llvm::raw_ostream &TargetOS,
                             llvm::raw_ostream &IModuleOS);

/// Parses \p Buffer as an LLVM \c Module according to \p Format.
/// For \c IModuleFormat::Bitcode the buffer must contain the base64-encoded
/// bitcode (as stored in the \c .luthier YAML block scalar).
/// For \c IModuleFormat::MIR, if \p OutMMI is non-null, machine functions are
/// parsed into it via \c MIRParser::parseMachineFunctions after the IR module
/// is constructed; \p OutMMI must already be initialized with the appropriate
/// \c TargetMachine.  \p OutMMI is ignored for \c IR and \c Bitcode formats.
llvm::Expected<
    std::pair<std::unique_ptr<llvm::Module>, std::unique_ptr<llvm::MIRParser>>>
loadIModule(llvm::MemoryBufferRef Buffer, IModuleFormat Format,
            const std::vector<MDSlotEntry> &MDSlotMap, llvm::LLVMContext &Ctx,
            llvm::Module &TargetModule);

/// Serializes \p TargetModule and \p IModule as a .luthier YAML file at
/// \p OutputPath, embedding a cross-module \c MDSlotMap so that
/// \c loadLinkedLuthierFile can restore the inter-module MDNode links.
///
/// If \p IModuleMMI is non-null the instrumentation module is written as MIR
/// (IR declarations followed by machine functions from \p IModuleMMI) and the
/// \c Format field is set to \c MIR.  Otherwise the module is written as LLVM
/// IR text and \c Format is omitted (defaults to \c IR on load).
llvm::Error dumpLuthierFile(llvm::StringRef OutputPath,
                            llvm::Module &TargetModule, llvm::Module &IModule,
                            llvm::MachineModuleInfo *IModuleMMI = nullptr);

} // namespace luthier

#endif
