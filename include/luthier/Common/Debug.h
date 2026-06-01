//===-- Debug.h -------------------------------------------------*- C++ -*-===//
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
/// Defines debug-related functions used in Luthier. Luthier reuses LLVM's debug
/// machinery directly by wrap debug-only code in \c LLVM_DEBUG(...) from/// <tt>llvm/Support/Debug.h</tt>, keyed by a per-file
/// <tt>\#define DEBUG_TYPE "..."</tt>, and emit to \c luthier::dbgs()
/// instead of \c llvm::dbgs().
///
/// This works even when LLVM itself is built \b without debug support, because
/// the runtime symbols \c LLVM_DEBUG depends on — \c llvm::DebugFlag and
/// \c llvm::isCurrentDebugType — are defined in \c libLLVMSupport regardless of
/// LLVM's own \c NDEBUG. The one thing LLVM omits in that configuration is the
/// registration of the \c -debug / \c -debug-only / \c -debug-buffer-size
/// command line options (and a buffered \c llvm::dbgs). This file provides the
/// shim that restores them.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_DEBUG_H
#define LUTHIER_COMMON_DEBUG_H

namespace luthier {

/// \brief Ensures the standard \c -debug, \c -debug-only, and
/// \c -debug-buffer-size command line options exist and drive
/// \c llvm::DebugFlag / \c llvm::setCurrentDebugTypes, even when LLVM was built
/// without debug support.
/// \details Calls \c llvm::initDebugOptions() first (a no-op when LLVM has no
/// debug support, otherwise registering LLVM's own options), then registers a
/// Luthier-owned equivalent for any of the three options still missing. The
/// register-if-absent check (via \c llvm::cl::getRegisteredOptions) means this
/// never double-registers an option LLVM already registered, so it is safe to
/// call unconditionally. Also opts Luthier into buffered debug output by
/// setting \c llvm::EnableDebugBuffering, so \c luthier::dbgs honors
/// \c -debug-buffer-size.
/// \note Must be called \b before \c llvm::cl::ParseCommandLineOptions for the
/// options to take effect.
void registerDebugCLOptions();

} // namespace luthier

#endif // LUTHIER_COMMON_DEBUG_H
