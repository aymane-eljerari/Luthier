//===-- Attributes.h ---------------------------------------------*- C++-*-===//
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
/// \file Attributes.h
/// Defines attributes used in Luthier's CXX tool compilation.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CXX_COMPILATION_ATTRIBUTES_H
#define LUTHIER_TOOL_CXX_COMPILATION_ATTRIBUTES_H
#include "clang/Sema/ParsedAttr.h"

namespace luthier {

/// \brief Handles the \c [[luthier::export_function_handle]] ParsedAttrInfo
/// Tagged device functions (and their template instantiations) are
/// promoted to \c __host__ \c __device__ so host code can take their
/// address; the Consumer pass synthesizes the kernel handle and rewrites
/// use sites.
struct LuthierExportFunctionHandleAttrInfo : public clang::ParsedAttrInfo {
  LuthierExportFunctionHandleAttrInfo();

  bool diagAppertainsToDecl(clang::Sema &S, const clang::ParsedAttr &Attr,
                            const clang::Decl *D) const override;

  AttrHandling
  handleDeclAttribute(clang::Sema &S, clang::Decl *D,
                      const clang::ParsedAttr &Attr) const override;
};

} // namespace luthier

#endif
