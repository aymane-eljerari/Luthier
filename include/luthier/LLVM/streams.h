//===-- streams.h -----------------------------------------------*- C++ -*-===//
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
/// Defines versions of <tt>llvm::outs</tt>, <tt>llvm::errs</tt>,
/// <tt>llvm::nulls</tt>, and <tt>llvm::dbgs</tt> that are safe to use with
/// Luthier tools.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_LLVM_STREAMS_H
#define LUTHIER_LLVM_STREAMS_H
#include <llvm/Support/raw_ostream.h>

namespace luthier {

/// A version of \c llvm::outs that is safe to use within Luthier
/// \note Always use this function instead of \c llvm::outs inside a Luthier
/// tool to ensure the underlying \c llvm::raw_fd_ostream is not destroyed
/// before the tool's finalizer function is called
llvm::raw_fd_ostream &outs();

/// A version of \c llvm::errs that is safe to use within Luthier
/// \note Always use this function instead of \c llvm::errs inside a Luthier
/// tool to ensure the underlying \c llvm::raw_fd_ostream is not destroyed
/// before the tool's finalizer function is called
llvm::raw_fd_ostream &errs();

/// A version of \c llvm::nulls that is safe to use within Luthier
/// \note Always use this function instead of \c llvm::nulls inside a Luthier
/// tool to ensure the underlying \c llvm::raw_fd_ostream is not destroyed
/// before the tool's finalizer function is called
llvm::raw_ostream &nulls();

/// A version of \c llvm::dbgs that is safe to use within Luthier
/// \details Mirrors \c llvm::dbgs: in \c NDEBUG builds it is \c luthier::errs;
/// otherwise it is a \c llvm::circular_raw_ostream layered over
/// \c luthier::errs that honors the standard \c -debug /
/// \c -debug-buffer-size command line options (the buffered content is dumped
/// by \c finalizeStreams and on fatal-signal handlers).
/// \note Always use this function instead of \c llvm::dbgs inside a Luthier
/// tool to ensure the underlying stream is not destroyed before the tool's
/// finalizer function is called
llvm::raw_ostream &dbgs();

/// Eagerly constructs the Luthier standard streams (\c outs, \c errs, \c nulls,
/// and, in non-\c NDEBUG builds, \c dbgs) and installs the debug-log
/// fatal-signal handler. Calling this once during tool initialization makes the
/// streams ready before first use and surfaces any construction error at a
/// controlled point. Idempotent and safe to call more than once.
/// \note Pair with \c finalizeStreams at the very end of tool teardown.
void initializeStreams();

/// Flushes the buffered Luthier standard streams: \c outs and, in non-\c NDEBUG
/// builds, the buffered \c dbgs debug log (which is also dumped with its
/// banner). Because the streams are never destroyed, their destructors never
/// run to flush them — so this must be called at the very end of tool teardown
/// (e.g. the last statement of \c atToolFini) to guarantee the final buffered
/// bytes reach their file descriptor. Idempotent and safe to call more than
/// once; \c errs and \c nulls need no flushing (unbuffered).
void finalizeStreams();

} // namespace luthier

#endif