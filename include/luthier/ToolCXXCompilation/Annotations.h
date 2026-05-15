//===-- Annotations.h --------------------------------------------*- C++-*-===//
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
/// \file Annotations.h
/// Defines annotations used in Luthier CXX tool source code.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CXX_COMPILATION_PLUGIN_H
#define LUTHIER_TOOL_CXX_COMPILATION_PLUGIN_H
#include <llvm/ADT/StringRef.h>

namespace luthier {

/// Annotation string the plugin attaches to every \c FunctionDecl carrying
/// the \c [[luthier::export_function_handle]] attribute. External tools
/// can query this via \c AnnotateAttr to decide whether a device function
/// is host-addressable.
inline constexpr llvm::StringLiteral ExportFunctionHandleMarker =
    "luthier.export_function_handle";

/// Symbol-name prefix of every kernel handle the plugin synthesizes. The
/// suffix is a sanitized form of the device function's mangled name.
inline constexpr llvm::StringLiteral HookHandleSymbolPrefix =
    "__luthier_builtin_hook_handle_";

} // namespace luthier

#endif
