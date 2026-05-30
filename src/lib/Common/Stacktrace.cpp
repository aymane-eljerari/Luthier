//===-- Stacktrace.cpp ----------------------------------------------------===//
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
/// Implements \c luthier::Stacktrace using \c llvm::symbolize::LLVMSymbolizer
/// for in-process symbolization without resorting to using an external
/// \c llvm-symbolizer process.
//===----------------------------------------------------------------------===//
#include "luthier/Common/Stacktrace.h"

#include <llvm/DebugInfo/DIContext.h>
#include <llvm/DebugInfo/Symbolize/Symbolize.h>
#include <llvm/Object/ObjectFile.h>
#include <llvm/Support/Compiler.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/Format.h>
#include <llvm/Support/Path.h>
#include <llvm/Support/Signals.h>
#include <llvm/Support/raw_ostream.h>

#include <cstdint>

#if __has_include(<execinfo.h>)
#include <execinfo.h>
#define LUTHIER_STACKTRACE_HAVE_BACKTRACE 1
#endif

#if __has_include(<dlfcn.h>)
#include <dlfcn.h>
#define LUTHIER_STACKTRACE_HAVE_DLADDR 1
#endif

#if __has_include(<unistd.h>)
#include <unistd.h>
#define LUTHIER_STACKTRACE_HAVE_UNISTD 1
#endif

namespace luthier {

/// Upper bound on the number of frames \c current() will record.
static constexpr unsigned MaxCapturedFrames = 128;

/// \c noinline so that \c current() reliably owns frame 0 of the captured
/// trace, letting us drop it deterministically.
LLVM_ATTRIBUTE_NOINLINE Stacktrace Stacktrace::current(unsigned SkipFrames) {
  Stacktrace ST;
#ifdef LUTHIER_STACKTRACE_HAVE_BACKTRACE
  void *Buffer[MaxCapturedFrames];
  int NumCaptured = ::backtrace(Buffer, MaxCapturedFrames);
  // Frame 0 is this function (current()); always drop it, then SkipFrames more.
  for (int I = static_cast<int>(SkipFrames) + 1; I < NumCaptured; ++I)
    ST.Frames.push_back(Buffer[I]);
#else
  (void)SkipFrames;
#endif
  return ST;
}

#ifdef LUTHIER_STACKTRACE_HAVE_DLADDR
namespace {

/// Best-effort line for \p PC when DWARF symbolization is unavailable, using
/// only what \c dladdr provides (module path + nearest exported symbol).
void printUnsymbolizedFrame(llvm::raw_ostream &OS, const void *PC,
                            const char *ModulePath, const char *SymbolName,
                            uintptr_t Offset) {
  OS << llvm::format_hex(reinterpret_cast<uintptr_t>(PC), 18) << ' ';
  if (SymbolName != nullptr && *SymbolName != '\0')
    OS << SymbolName << ' ';
  OS << '(';
  OS << (ModulePath != nullptr ? llvm::sys::path::filename(ModulePath)
                               : llvm::StringRef("<unknown module>"));
  OS << "+0x";
  OS.write_hex(Offset);
  OS << ")\n";
}

} // namespace
#endif

void Stacktrace::print(llvm::raw_ostream &OS) const {
  if (Frames.empty()) {
    OS << "  <no stack frames captured>\n";
    return;
  }

#ifdef LUTHIER_STACKTRACE_HAVE_DLADDR
  llvm::symbolize::LLVMSymbolizer::Options Opts;
  Opts.Demangle = true;
  Opts.UseSymbolTable = true;
  // Per-call instance: errors are not a hot path, and a fresh symbolizer avoids
  // any cross-thread sharing concerns (LLVMSymbolizer is not documented to be
  // safe for concurrent use).
  llvm::symbolize::LLVMSymbolizer Symbolizer(Opts);

  for (size_t I = 0; I < Frames.size(); ++I) {
    void *PC = Frames[I];
    OS << llvm::format("#%-3zu ", I);

    Dl_info Info;
    // dladdr returns 0 on failure. Note dli_fbase is legitimately 0 for a
    // non-PIE main executable, so it must not be treated as a failure.
    if (::dladdr(PC, &Info) == 0 || Info.dli_fname == nullptr) {
      OS << llvm::format_hex(reinterpret_cast<uintptr_t>(PC), 18) << '\n';
      continue;
    }

    // dli_fbase is the module's load bias, so PC - dli_fbase is the link-time
    // virtual address the symbolizer expects (matches Signals.cpp's
    // PC - dlpi_addr; 0 bias for non-PIE executables yields the absolute
    // vaddr).
    uintptr_t Offset = reinterpret_cast<uintptr_t>(PC) -
                       reinterpret_cast<uintptr_t>(Info.dli_fbase);
    // For non-top frames the PC is a return address; step back one byte so the
    // resolved line is the call site rather than the instruction after it.
    uintptr_t SymOffset = (I == 0) ? Offset : Offset - 1;

    llvm::object::SectionedAddress ModuleOffset{
        SymOffset, llvm::object::SectionedAddress::UndefSection};
    llvm::Expected<llvm::DIInliningInfo> InliningOrErr =
        Symbolizer.symbolizeInlinedCode(Info.dli_fname, ModuleOffset);
    if (!InliningOrErr) {
      llvm::consumeError(InliningOrErr.takeError());
      printUnsymbolizedFrame(OS, PC, Info.dli_fname, Info.dli_sname, Offset);
      continue;
    }

    const llvm::DIInliningInfo &Inlining = *InliningOrErr;
    uint32_t NumInlined = Inlining.getNumberOfFrames();
    if (NumInlined == 0) {
      printUnsymbolizedFrame(OS, PC, Info.dli_fname, Info.dli_sname, Offset);
      continue;
    }

    for (uint32_t F = 0; F < NumInlined; ++F) {
      const llvm::DILineInfo &LI = Inlining.getFrame(F);
      if (F != 0)
        OS << "     (inlined by) ";
      OS << llvm::format_hex(reinterpret_cast<uintptr_t>(PC), 18) << ' ';
      OS << (LI.FunctionName == llvm::DILineInfo::BadString ? "<unknown>"
                                                            : LI.FunctionName);
      // A valid FileName with Line == 0 means there was no real line program
      // (e.g. symbol-table-only resolution from a non-DWARF build, where the
      // file comes from an STT_FILE entry); don't emit a misleading ":0:0".
      if (LI.FileName != llvm::DILineInfo::BadString && !LI.FileName.empty() &&
          LI.Line != 0) {
        OS << " at " << LI.FileName << ':' << LI.Line << ':' << LI.Column;
      } else {
        OS << " (" << llvm::sys::path::filename(Info.dli_fname) << "+0x";
        OS.write_hex(Offset);
        OS << ")";
      }
      OS << '\n';
    }
  }
#else
  // No dladdr: cannot map PCs to modules; emit the raw addresses.
  for (size_t I = 0; I < Frames.size(); ++I)
    OS << llvm::format("#%-3zu ", I)
       << llvm::format_hex(reinterpret_cast<uintptr_t>(Frames[I]), 18) << '\n';
#endif
}

std::string Stacktrace::toString() const {
  std::string Out;
  llvm::raw_string_ostream OS(Out);
  print(OS);
  return Out;
}

namespace {

/// \c raw_fd_ostream::get_fd() is protected. Reach it via the pointer-to-member
/// idiom (The struct is never instantiated — it only serves as the access
/// scope.)
struct RawFdOstreamFdAccessor : llvm::raw_fd_ostream {
  static int getFd(const llvm::raw_fd_ostream &OS) {
    return (OS.*&RawFdOstreamFdAccessor::get_fd)();
  }
};

/// File descriptor the fatal-signal handler writes to; set on install.
int FatalSignalFd = STDERR_FILENO;

/// Runs from LLVM's fatal-signal handler, so it must be strictly
/// async-signal-safe: only write() + backtrace()/backtrace_symbols_fd(), which
/// glibc documents as usable from a signal handler (no malloc). It deliberately
/// does NOT symbolize — module(+offset) frames are meant to be resolved offline
void luthierFatalSignalCaptureHandler(void *) {
#if defined(LUTHIER_STACKTRACE_HAVE_BACKTRACE) &&                              \
    defined(LUTHIER_STACKTRACE_HAVE_UNISTD)
  static const char Header[] =
      "\nLuthier caught a fatal signal; raw stack frames "
      "(symbolize offline with llvm-symbolizer):\n";
  // Short writes are ignored — best effort on an already-crashing process.
  (void)::write(FatalSignalFd, Header, sizeof(Header) - 1);
  void *Frames[MaxCapturedFrames];
  int NumCaptured = ::backtrace(Frames, static_cast<int>(MaxCapturedFrames));
  ::backtrace_symbols_fd(Frames, NumCaptured, FatalSignalFd);
#elif defined(LUTHIER_STACKTRACE_HAVE_UNISTD)
  static const char Msg[] = "\nLuthier caught a fatal signal (no backtrace "
                            "support on this platform).\n";
  (void)::write(FatalSignalFd, Msg, sizeof(Msg) - 1);
#endif
}

} // namespace

void printStackTraceOnFatalSignal(llvm::raw_fd_ostream &OS) {
  static const bool Installed = [&OS] {
    FatalSignalFd = RawFdOstreamFdAccessor::getFd(OS);
#ifdef LUTHIER_STACKTRACE_HAVE_BACKTRACE
    // Prime libgcc's unwinder now so the first backtrace() inside the handler
    // need not dlopen it (dlopen is not async-signal-safe).
    void *Prime[1];
    (void)::backtrace(Prime, 1);
#endif
    llvm::sys::AddSignalHandler(luthierFatalSignalCaptureHandler, nullptr);
    return true;
  }();
  (void)Installed;
}

} // namespace luthier
