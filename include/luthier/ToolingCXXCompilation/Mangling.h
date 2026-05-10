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
/// Defines helpers for custom mangling in the CXX compilation pipeline.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_CXX_COMPILATION_MANGLING_H
#define LUTHIER_TOOLING_CXX_COMPILATION_MANGLING_H
#include <string>

namespace clang {
class ASTContext;
class FunctionDecl;
} // namespace clang

namespace luthier {

/// Returns \c __luthier_builtin_hook_handle_<sanitized> where \c sanitized
/// is the Itanium-mangled name of \p FD with each non-identifier byte
/// replaced by \c _xx (lowercase hex). Reversible and stable across TUs.
std::string mangleAndSanitize(clang::FunctionDecl *FD, clang::ASTContext &Ctx);

} // namespace luthier

#endif
