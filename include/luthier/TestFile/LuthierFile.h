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
/// Defines \c LuthierFileParser — the class responsible for deserializing
/// \c .luthier combined module files — together with the \c writeLuthierFile
/// helper for serialization.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TESTFILE_LUTHIER_FILE_H
#define LUTHIER_TESTFILE_LUTHIER_FILE_H

#include <llvm/ADT/ArrayRef.h>
#include <llvm/CodeGen/MIRParser/MIRParser.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/MemoryBufferRef.h>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace llvm {
class Function;
class LLVMContext;
class MachineModuleInfo;
class Module;
class raw_ostream;
} // namespace llvm

namespace luthier {

/// Parses a \c .luthier YAML file and provides typed access to its contents.
class LuthierFileParser {
public:
  /// One entry in the cross-module metadata slot map embedded in a
  /// \c .luthier file.  Maps a metadata slot number in the instrumentation
  /// module to the slot number of the same \c MDNode in the target module.
  struct MDSlotEntry {
    unsigned IModuleSlot = 0;
    unsigned TargetSlot = 0;

    bool operator==(const MDSlotEntry &) const = default;
  };

  /// Encoding of the \c InstrumentationModule field.
  enum class IModuleFormat {
    IR,      ///< LLVM IR text (.ll)
    Bitcode, ///< LLVM bitcode, base64-encoded in the YAML block scalar
    MIR,     ///< Machine IR text (.mir)
  };

  //===--------------------------------------------------------------------===//
  // Factory
  //===--------------------------------------------------------------------===//

  /// Parses a \c .luthier file from \p Buffer.  The buffer identifier is used
  /// in error messages.
  static llvm::Expected<LuthierFileParser> create(llvm::MemoryBufferRef Buffer);

  /// Parses the \c .luthier file at \p Path.
  static llvm::Expected<LuthierFileParser> create(llvm::StringRef Path);

  //===--------------------------------------------------------------------===//
  // Accessors
  //===--------------------------------------------------------------------===//

  [[nodiscard]] llvm::StringRef getTargetModule() const {
    return TargetModuleText;
  }
  [[nodiscard]] llvm::StringRef getInstrumentationModule() const {
    return InstrumentationModuleText;
  }
  [[nodiscard]] IModuleFormat getFormat() const { return Format; }
  llvm::ArrayRef<MDSlotEntry> getMDSlotMap() const { return MDSlotMap; }

  //===--------------------------------------------------------------------===//
  // Module loading
  //===--------------------------------------------------------------------===//

  /// Parses the \c TargetModule field (MIR text) into an LLVM \c Module.
  /// Returns the module together with the \c MIRParser used.
  ///
  /// \p SetDataLayout is forwarded to \c MIRParser::parseIRModule — use it to
  /// override the data layout and initialize a \c TargetMachine, as \c llc
  /// does.  \p SetMIRFunctionAttributes is forwarded to \c createMIRParser and
  /// applied to every \c Function in the parsed module.  Both callbacks default
  /// to no-ops if omitted.
  llvm::Expected<std::pair<std::unique_ptr<llvm::Module>,
                           std::unique_ptr<llvm::MIRParser>>>
  loadTargetModule(
      llvm::LLVMContext &Ctx,
      std::function<std::optional<std::string>(llvm::StringRef, llvm::StringRef)>
          SetDataLayout = nullptr,
      std::function<void(llvm::Function &)> SetMIRFunctionAttributes =
          nullptr) const;

  /// Parses the \c InstrumentationModule field according to \c Format, patches
  /// cross-module \c MDNode references using the embedded \c MDSlotMap so that
  /// metadata in the instrumentation module points back into the live
  /// \p TargetModule
  /// Returns the parsed module together with the \c MIRParser used (non-null
  /// only when \c Format is \c MIR)
  llvm::Expected<std::pair<std::unique_ptr<llvm::Module>,
                           std::unique_ptr<llvm::MIRParser>>>
  loadIModule(llvm::LLVMContext &Ctx, llvm::Module &TargetModule) const;

private:
  std::string TargetModuleText;
  std::string InstrumentationModuleText;
  IModuleFormat Format = IModuleFormat::IR;
  std::vector<MDSlotEntry> MDSlotMap;
};

//===----------------------------------------------------------------------===//
// Serialization
//===----------------------------------------------------------------------===//

/// Serializes \p TargetModule and \p IModule as a \c .luthier YAML file,
/// writing the result to \p OS.  If \p IModuleMMI is non-null the
/// instrumentation module is written as MIR and \c Format is set to \c MIR;
/// otherwise it is written as LLVM IR text.
llvm::Error writeLuthierFile(llvm::raw_ostream &OS, llvm::Module &TargetModule,
                             llvm::Module &IModule,
                             llvm::MachineModuleInfo *IModuleMMI = nullptr);

/// Convenience overload that opens \p Path and delegates to the stream-based
/// \c writeLuthierFile.
llvm::Error writeLuthierFile(llvm::StringRef Path, llvm::Module &TargetModule,
                             llvm::Module &IModule,
                             llvm::MachineModuleInfo *IModuleMMI = nullptr);

} // namespace luthier

#endif
