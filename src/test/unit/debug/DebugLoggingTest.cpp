//===-- DebugLoggingTest.cpp ----------------------------------------------===//
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
/// Verifies that Luthier's reuse of \c LLVM_DEBUG behaves identically to LLVM:
/// active in a translation unit compiled without \c NDEBUG, and fully compiled
/// out in one compiled with \c NDEBUG. The two emitter symbols come from the
/// same source (\c DebugEmit.cpp) built twice with opposite \c NDEBUG settings
/// by this directory's CMakeLists.
//===----------------------------------------------------------------------===//
#include "gtest/gtest.h"
#include <llvm/Support/Debug.h>
#include <llvm/Support/raw_ostream.h>
#include <string>

/// Emitter compiled WITHOUT NDEBUG — the LLVM_DEBUG body is present.
extern "C" bool luthierTestEmitDebugOn(llvm::raw_ostream &OS);
/// Emitter compiled WITH NDEBUG — the LLVM_DEBUG body is compiled out.
extern "C" bool luthierTestEmitDebugOff(llvm::raw_ostream &OS);

namespace {

TEST(DebugLogging, MacroActiveWhenCompiledWithoutNDEBUG) {
  llvm::DebugFlag = true; // empty -debug-only => isCurrentDebugType() is true
  std::string Buf;
  llvm::raw_string_ostream OS(Buf);
  EXPECT_TRUE(luthierTestEmitDebugOn(OS));
  OS.flush();
  EXPECT_NE(Buf.find("LUTHIER_DEBUG_MARKER"), std::string::npos);
  llvm::DebugFlag = false;
}

TEST(DebugLogging, MacroCompiledOutWhenNDEBUG) {
  llvm::DebugFlag = true; // even with the flag on, the body is gone under NDEBUG
  std::string Buf;
  llvm::raw_string_ostream OS(Buf);
  EXPECT_FALSE(luthierTestEmitDebugOff(OS));
  OS.flush();
  EXPECT_TRUE(Buf.empty());
  llvm::DebugFlag = false;
}

TEST(DebugLogging, FlagOffSuppressesOutputEvenWithoutNDEBUG) {
  llvm::DebugFlag = false; // present-but-disabled: macro expands, guard is false
  std::string Buf;
  llvm::raw_string_ostream OS(Buf);
  EXPECT_FALSE(luthierTestEmitDebugOn(OS));
  OS.flush();
  EXPECT_TRUE(Buf.empty());
}

} // namespace
