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
/// Defines versions of <tt>llvm::outs</tt>, <tt>llvm::errs</tt>,/// <tt>llvm::nulls</tt>, and <tt>llvm::dbgs</tt> that are  safe to use with
/// Luthier tools.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_STREAMS_H
#define LUTHIER_STREAMS_H
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
/// at process exit and on fatal-signal handlers).
/// \note Always use this function instead of \c llvm::dbgs inside a Luthier
/// tool to ensure the underlying stream is not destroyed before the tool's
/// finalizer function is called
llvm::raw_ostream &dbgs();

} // namespace luthier

#endif