//===-- Attributes.cpp ----------------------------------------------------===//
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
#include "luthier/ToolingCXXCompilation/Attributes.h"
#include "luthier/ToolingCXXCompilation/HostHandleSynthPlugin.h"
#include <clang/AST/Attr.h>
#include <clang/AST/Decl.h>
#include <clang/Sema/Sema.h>
#include <clang/Sema/SemaDiagnostic.h>

namespace luthier {

LuthierExportFunctionHandleAttrInfo::LuthierExportFunctionHandleAttrInfo() {
  static constexpr Spelling S[] = {
      {clang::ParsedAttr::AS_GNU, "luthier_export_function_handle"},
      {clang::ParsedAttr::AS_CXX11, "luthier::export_function_handle"},
      {clang::ParsedAttr::AS_C23, "luthier::export_function_handle"},
  };
  Spellings = S;
}

bool LuthierExportFunctionHandleAttrInfo::diagAppertainsToDecl(
    clang::Sema &S, const clang::ParsedAttr &Attr, const clang::Decl *D) const {
  if (!llvm::isa<clang::FunctionDecl>(D)) {
    S.Diag(Attr.getLoc(), clang::diag::warn_attribute_wrong_decl_type)
        << Attr << Attr.isRegularKeywordAttribute() << clang::ExpectedFunction;
    return false;
  }
  return true;
}

clang::ParsedAttrInfo::AttrHandling
LuthierExportFunctionHandleAttrInfo::handleDeclAttribute(
    clang::Sema &S, clang::Decl *D, const clang::ParsedAttr &Attr) const {
  auto *FD = llvm::cast<clang::FunctionDecl>(D);
  clang::ASTContext &Ctx = S.Context;
  FD->addAttr(clang::AnnotateAttr::Create(Ctx, ExportFunctionHandleMarker,
                                          nullptr, 0, Attr.getRange()));
  // Promote the original __device__ function (or template) to
  // __host__ __device__ so host code can take its address. Sema then
  // accepts &deviceFn from host context (SameSide preference). The
  // consumer rewrites references to the synthesized kernel handle and
  // clears bodies in host mode so emission of host-side code skips
  // device-only intrinsics.
  if (!FD->hasAttr<clang::CUDAHostAttr>())
    FD->addAttr(clang::CUDAHostAttr::CreateImplicit(Ctx));
  return AttributeApplied;
}

} // namespace luthier
