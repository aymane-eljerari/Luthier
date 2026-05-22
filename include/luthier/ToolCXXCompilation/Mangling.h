//===-- Mangling.h ---------------------------------------------*- C++-*-===//
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
/// \file Mangling.h
/// Helper for building the kernel-handle stub's base identifier.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CXX_COMPILATION_MANGLING_H
#define LUTHIER_TOOL_CXX_COMPILATION_MANGLING_H
#include <string>

namespace clang {
class ASTContext;
class FunctionDecl;
} // namespace clang

namespace luthier {

/// Returns the base identifier for the synthesized kernel-handle stub:
/// \c __luthier_builtin_hook_handle_<original-mangled-name>. When the
/// original needs Itanium mangling, the suffix is the full Itanium-mangled
/// name verbatim (Itanium names are identifier-safe in the cases relevant
/// to hooks — no Clang clone suffixes, etc.). When the original has C
/// linkage, the suffix is the original's source identifier.
///
/// The resulting identifier is used as the *base* identifier of a plain
/// C++ \c FunctionDecl synthesized at translation-unit scope. Letting
/// Clang Itanium-mangle that decl normally yields a host-side symbol
/// whose \c llvm::ItaniumPartialDemangler::getFunctionBaseName begins
/// with \c __luthier_builtin_hook_handle_ ; dropping that prefix gives
/// the original device function's mangled name directly, suitable for
/// \c Module::getFunction.
std::string buildHandleBaseIdentifier(clang::FunctionDecl *FD,
                                      clang::ASTContext &Ctx);

} // namespace luthier

#endif
