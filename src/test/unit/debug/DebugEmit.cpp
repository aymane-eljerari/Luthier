//===-- DebugEmit.cpp -----------------------------------------------------===//
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
/// A single LLVM_DEBUG site, compiled twice by the build system: once without
/// \c NDEBUG (debug logic present) and once with \c NDEBUG (debug logic
/// compiled out). \c LT_EMIT_NAME selects a distinct symbol name per build so
/// both object files can be linked into one test binary. This verifies that
/// Luthier's reuse of \c LLVM_DEBUG is gated purely on the consumer
/// translation unit's \c NDEBUG, exactly like LLVM.
//===----------------------------------------------------------------------===//
#include <llvm/Support/Debug.h>
#include <llvm/Support/raw_ostream.h>

#define DEBUG_TYPE "luthier-debug-logging-test"

#ifndef LT_EMIT_NAME
#define LT_EMIT_NAME luthierTestEmit
#endif

/// Returns true and writes a marker to \p OS iff the LLVM_DEBUG body executed
/// (i.e. the macro was not compiled out and \c llvm::DebugFlag is set).
extern "C" bool LT_EMIT_NAME(llvm::raw_ostream &OS) {
  bool Ran = false;
  LLVM_DEBUG(Ran = true; OS << "LUTHIER_DEBUG_MARKER");
  return Ran;
}
