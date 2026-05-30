//===-- Stacktrace.h --------------------------------------------*- C++ -*-===//
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
/// Defines \c luthier::Stacktrace, an in-process, fork-free stack trace
/// alternative to \c llvm::PrintStackTrace, to avoid its forking issues when
/// running it from an \c LD_PRELOAD-ed library
///
/// \c Stacktrace provides the following methods:
/// - \c Stacktrace::current() captures only raw return addresses for later use.
/// - \c Stacktrace::print()/Stacktrace::toString() provide the
/// actual symbolization operation, resolving addresses to function names and
/// \c file:line:column. They use \c llvm::symbolize::LLVMSymbolizer
/// in-process (reading each module's DWARF/symbol table directly).
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_STACKTRACE_H
#define LUTHIER_COMMON_STACKTRACE_H
#include <llvm/ADT/ArrayRef.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/raw_ostream.h>
#include <string>

namespace luthier {

/// \brief An in-process, lazily-symbolized stack trace; see the file comment.
class Stacktrace {
  /// Raw return addresses (program counters), innermost frame first.
  llvm::SmallVector<void *, 32> Frames;

public:
  Stacktrace() = default;

  /// \brief Captures the current call stack without symbolizing it.
  /// \param SkipFrames number of innermost frames to drop \em in addition to
  /// \c current() itself (which is always dropped), so the top frame is the
  /// caller of interest.
  static Stacktrace current(unsigned SkipFrames = 0);

  /// \brief Whether any frames were captured.
  [[nodiscard]] bool empty() const { return Frames.empty(); }

  /// \brief The captured raw return addresses, innermost first.
  [[nodiscard]] llvm::ArrayRef<void *> frames() const { return Frames; }

  /// \brief Symbolizes and writes the trace to \p OS, one line per frame
  /// (including inlined frames). Emits \c file:line:column where the module
  /// carries debug info, falling back to \c module(+offset) or the raw address.
  void print(llvm::raw_ostream &OS) const;

  /// \brief Convenience wrapper around \c print() returning a \c std::string.
  [[nodiscard]] std::string toString() const;
};

/// \brief \c llvm::raw_ostream print specialization
inline llvm::raw_ostream &operator<<(llvm::raw_ostream &OS,
                                     const Stacktrace &ST) {
  ST.print(OS);
  return OS;
}

/// \brief Registers (via \c llvm::sys::AddSignalHandler) a fatal-signal handler
/// that writes the raw call stack to \p OS's file descriptor, then lets LLVM
/// re-raise so the process still crashes.
///
/// The handler is strictly async-signal-safe: it does NOT symbolize (no
/// \c malloc, no \c dladdr, no \c LLVMSymbolizer), and it only writes
/// \c module(+offset) frames via \c backtrace_symbols_fd straight to the
/// descriptor. Symbolization must be done offline via \c llvm-symbolizer, e.g.
/// using \c llvm-symbolizer \c --obj=<module> \c <offset>. Because it writes/// directly to the descriptor (bypassing \p OS's own buffer and its object
/// lifetime), prefer an unbuffered stream such as the default \c llvm::errs().
///
/// \note Use this in place of \c llvm::sys::PrintStackTraceOnErrorSignal, which
/// \c fork+exec s \c llvm-symbolizer, causing a fork bomb under \c LD_PRELOAD
/// (the child re-inherits \c LD_PRELOAD and re-loads Luthier), and \c fork from
/// a crashing multithreaded process is unsafe.
void printStackTraceOnFatalSignal(llvm::raw_fd_ostream &OS = llvm::errs());

} // namespace luthier

namespace llvm {

/// \brief \c llvm::formatv specialization of \c Stacktrace
template <> struct format_provider<luthier::Stacktrace> {
  static void format(const luthier::Stacktrace &ST, raw_ostream &OS,
                     StringRef /*Style*/) {
    ST.print(OS);
  }
};

} // namespace llvm

#endif
