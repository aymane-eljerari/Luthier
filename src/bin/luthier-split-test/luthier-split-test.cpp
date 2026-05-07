//===-- luthier-split-test.cpp --------------------------------------------===//
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
/// \file luthier-split-test.cpp
///
/// Splits a combined Luthier test file (.luthier) into its two constituent
/// .mir files so that lit tests can feed them to separate tools.
///
/// Input format (YAML mapping with two literal block scalars):
/// \code{.yaml}
///   ---
///   TargetModule: |
///     ; <target MIR content>
///   InstrumentationModule: |
///     ; <instrumentation MIR content (IR preamble; MIR blocks optional)>
/// \endcode
///
/// Usage:
///   luthier-split-test <input.luthier> \
///       --target-out <target.mir> --imodule-out <imodule.mir>
//===----------------------------------------------------------------------===//

#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/YAMLTraits.h"
#include "llvm/Support/raw_ostream.h"

struct LuthierTestFile {
  std::string TargetModule;
  std::string InstrumentationModule;
};

template <> struct llvm::yaml::MappingTraits<LuthierTestFile> {
  static void mapping(llvm::yaml::IO &IO, LuthierTestFile &F) {
    IO.mapRequired("TargetModule", F.TargetModule);
    IO.mapRequired("InstrumentationModule", F.InstrumentationModule);
  }
};

static llvm::cl::opt<std::string>
    InputFile(llvm::cl::Positional, llvm::cl::Required,
              llvm::cl::desc("<input.luthier>"));

static llvm::cl::opt<std::string>
    TargetOut("target-out", llvm::cl::Required,
              llvm::cl::desc("Output path for the target module .mir file"));

static llvm::cl::opt<std::string>
    IModuleOut("imodule-out", llvm::cl::Required,
               llvm::cl::desc(
                   "Output path for the instrumentation module .mir file"));

static bool writeFile(llvm::StringRef Path, llvm::StringRef Content) {
  std::error_code EC;
  llvm::raw_fd_ostream OS(Path, EC, llvm::sys::fs::OF_Text);
  if (EC) {
    llvm::errs() << "luthier-split-test: failed to open '" << Path
                 << "': " << EC.message() << "\n";
    return false;
  }
  OS << Content;
  return true;
}

int main(int argc, char **argv) {
  llvm::InitLLVM X(argc, argv);
  llvm::cl::ParseCommandLineOptions(argc, argv,
                                    "Luthier combined test file splitter\n");

  // Read input file.
  auto MBOrErr = llvm::MemoryBuffer::getFile(InputFile);
  if (!MBOrErr) {
    llvm::errs() << "luthier-split-test: failed to open '" << InputFile
                 << "': " << MBOrErr.getError().message() << "\n";
    return 1;
  }

  // Parse YAML.
  LuthierTestFile TestFile;
  llvm::yaml::Input YAMLIn((*MBOrErr)->getBuffer());
  YAMLIn >> TestFile;
  if (YAMLIn.error()) {
    llvm::errs() << "luthier-split-test: YAML parse error in '" << InputFile
                 << "': " << YAMLIn.error().message() << "\n";
    return 1;
  }

  // Write the two output files.
  if (!writeFile(TargetOut, TestFile.TargetModule))
    return 1;
  if (!writeFile(IModuleOut, TestFile.InstrumentationModule))
    return 1;

  return 0;
}
