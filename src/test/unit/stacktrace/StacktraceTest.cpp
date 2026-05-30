//===-- StacktraceTest.cpp ------------------------------------*- C++ -*-===//
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
/// \file
/// Unit tests for \c luthier::Stacktrace, verifying in-process capture and
/// symbolization (function names and \c file:line via LLVMSymbolizer reading
/// the test binary's own DWARF / symbol table).
///
/// This source is built into three executables that pin their own debug-info
/// level (see CMakeLists.txt), so the expected resolution is fixed regardless
/// of CMAKE_BUILD_TYPE; each variant sets the LUTHIER_TEST_EXPECT_* macros
/// below accordingly:
///   - StacktraceTest            (-g)                : names + file:line
///   - StacktraceTestNoDebugInfo (-g0)               : names only (from symtab)
///   - StacktraceTestStripped    (-g0, --strip-all)  : neither (module+offset)
//===----------------------------------------------------------------------===//
#include "luthier/Common/Stacktrace.h"
#include <csignal>
#include <gtest/gtest.h>
#include <llvm/Support/Compiler.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/raw_ostream.h>
#include <string>

#if __has_include(<sys/wait.h>) && __has_include(<unistd.h>)
#include <sys/wait.h>
#include <unistd.h>
#define LUTHIER_TEST_HAVE_FORK 1
#endif

// What the running binary's symbolization can resolve depends on how it was
// built. These default to a full debug build; the no-debug-info and stripped
// build variants override them via -D (see CMakeLists.txt):
//   - FUNCTION_NAMES: resolvable from DWARF or the symbol table (.symtab).
//   - LINE_INFO     : resolvable only from DWARF.
#ifndef LUTHIER_TEST_EXPECT_FUNCTION_NAMES
#define LUTHIER_TEST_EXPECT_FUNCTION_NAMES 1
#endif
#ifndef LUTHIER_TEST_EXPECT_LINE_INFO
#define LUTHIER_TEST_EXPECT_LINE_INFO 1
#endif

namespace {

// A distinct, non-inlinable chain of frames so the symbolizer has named
// functions to resolve. The inline-asm barriers defeat tail-call merging.
LLVM_ATTRIBUTE_NOINLINE luthier::Stacktrace stacktraceInnermost() {
  luthier::Stacktrace ST = luthier::Stacktrace::current();
  asm volatile("");
  return ST;
}
LLVM_ATTRIBUTE_NOINLINE luthier::Stacktrace stacktraceMiddle() {
  luthier::Stacktrace ST = stacktraceInnermost();
  asm volatile("");
  return ST;
}
LLVM_ATTRIBUTE_NOINLINE luthier::Stacktrace stacktraceOutermost() {
  luthier::Stacktrace ST = stacktraceMiddle();
  asm volatile("");
  return ST;
}

TEST(StacktraceTest, DefaultConstructedIsEmpty) {
  luthier::Stacktrace ST;
  EXPECT_TRUE(ST.empty());
  EXPECT_TRUE(ST.frames().empty());
  EXPECT_NE(ST.toString().find("no stack frames captured"), std::string::npos);
}

TEST(StacktraceTest, CapturesMultipleFrames) {
  luthier::Stacktrace ST = stacktraceOutermost();
  EXPECT_FALSE(ST.empty());
  // At least the three helpers above plus the test body / gtest frames.
  EXPECT_GE(ST.frames().size(), 3u);
}

TEST(StacktraceTest, SymbolizesFunctionNamesAndSourceLines) {
  luthier::Stacktrace ST = stacktraceOutermost();
  const std::string S = ST.toString();
  // Function names from the capturing chain (proves in-process symbolization).
#if LUTHIER_TEST_EXPECT_FUNCTION_NAMES
  EXPECT_NE(S.find("stacktraceInnermost"), std::string::npos) << S;
  EXPECT_NE(S.find("stacktraceMiddle"), std::string::npos) << S;
  EXPECT_NE(S.find("stacktraceOutermost"), std::string::npos) << S;
#else
  // No symbol table: frames degrade to module(+offset), names unresolved.
  EXPECT_EQ(S.find("stacktraceInnermost"), std::string::npos) << S;
#endif
  // This source file with line info (proves DWARF line resolution).
#if LUTHIER_TEST_EXPECT_LINE_INFO
  EXPECT_NE(S.find("StacktraceTest.cpp:"), std::string::npos) << S;
#else
  EXPECT_EQ(S.find("StacktraceTest.cpp:"), std::string::npos) << S;
#endif
}

TEST(StacktraceTest, RawOstreamOperatorMatchesToString) {
  luthier::Stacktrace ST = stacktraceOutermost();
  std::string ViaOperator;
  llvm::raw_string_ostream OS(ViaOperator);
  OS << ST;
  OS.flush();
  EXPECT_EQ(ViaOperator, ST.toString());
#if LUTHIER_TEST_EXPECT_FUNCTION_NAMES
  EXPECT_NE(ViaOperator.find("stacktraceInnermost"), std::string::npos)
      << ViaOperator;
#endif
}

TEST(StacktraceTest, FormatvProviderMatchesToString) {
  luthier::Stacktrace ST = stacktraceOutermost();
  const std::string ViaFormatv = llvm::formatv("{0}", ST).str();
  EXPECT_EQ(ViaFormatv, ST.toString());
#if LUTHIER_TEST_EXPECT_LINE_INFO
  EXPECT_NE(ViaFormatv.find("StacktraceTest.cpp:"), std::string::npos)
      << ViaFormatv;
#endif
}

TEST(StacktraceTest, SkippingAllFramesYieldsEmptyTrace) {
  // Skipping more frames than exist must degrade gracefully, not crash.
  luthier::Stacktrace ST = luthier::Stacktrace::current(/*SkipFrames=*/100000);
  EXPECT_TRUE(ST.empty());
}

#ifdef LUTHIER_TEST_HAVE_FORK
// Fork-based test: the child installs the fatal-signal handler, raises SIGSEGV,
// and must (a) write the header and at least one raw frame to its stderr, then
// (b) die from the signal — proving the re-raise (a swallowed signal would exit
// 0; a missing re-raise would loop forever). Capturing the output once lets us
// assert the header AND a frame line together (a single regex can't reliably
// span lines across regex engines). The header and the "0x" address that
// backtrace_symbols_fd prints for every frame are emitted independent of build
// flags, so this holds for all three variants. Suite named *DeathTest so gtest
// schedules it before any threads exist.
TEST(StacktraceDeathTest, WritesRawFramesAndReRaisesOnFatalSignal) {
  int Pipe[2];
  ASSERT_EQ(::pipe(Pipe), 0);
  const pid_t Pid = ::fork();
  ASSERT_NE(Pid, -1);
  if (Pid == 0) {
    // Child: send stderr to the pipe, install the handler, and crash.
    ::dup2(Pipe[1], STDERR_FILENO);
    ::close(Pipe[0]);
    ::close(Pipe[1]);
    // Default OS is llvm::errs() (fd 2), now the dup'd pipe write end.
    luthier::printStackTraceOnFatalSignal();
    std::raise(SIGSEGV);
    ::_exit(0); // only reached if the re-raise failed to terminate us
  }
  // Parent: drain the child's output, then reap it.
  ::close(Pipe[1]);
  std::string Output;
  char Buf[4096];
  for (ssize_t N; (N = ::read(Pipe[0], Buf, sizeof(Buf))) > 0;)
    Output.append(Buf, static_cast<size_t>(N));
  ::close(Pipe[0]);
  int Status = 0;
  ASSERT_EQ(::waitpid(Pid, &Status, 0), Pid);

  EXPECT_TRUE(WIFSIGNALED(Status))
      << "child exited instead of dying from the re-raised signal";
  if (WIFSIGNALED(Status))
    EXPECT_EQ(WTERMSIG(Status), SIGSEGV);
  EXPECT_NE(Output.find("Luthier caught a fatal signal"), std::string::npos)
      << Output;
  // backtrace_symbols_fd prints "0x<addr>" for every frame; the header has no
  // "0x", so finding it confirms at least one captured frame line.
  EXPECT_NE(Output.find("0x"), std::string::npos) << Output;
}
#endif

} // namespace
