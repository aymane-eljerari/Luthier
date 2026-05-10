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

using namespace clang;

namespace luthier {

LuthierExportFunctionHandleAttrInfo::LuthierExportFunctionHandleAttrInfo() {
  static constexpr Spelling S[] = {
      {ParsedAttr::AS_GNU, "luthier_export_function_handle"},
      {ParsedAttr::AS_CXX11, "luthier::export_function_handle"},
      {ParsedAttr::AS_C23, "luthier::export_function_handle"},
  };
  Spellings = S;
}

bool LuthierExportFunctionHandleAttrInfo::diagAppertainsToDecl(
    Sema &S, const ParsedAttr &Attr, const Decl *D) const {
  if (!llvm::isa<FunctionDecl>(D)) {
    S.Diag(Attr.getLoc(), diag::warn_attribute_wrong_decl_type)
        << Attr << Attr.isRegularKeywordAttribute() << ExpectedFunction;
    return false;
  }
  return true;
}

ParsedAttrInfo::AttrHandling
LuthierExportFunctionHandleAttrInfo::handleDeclAttribute(
    Sema &S, Decl *D, const ParsedAttr &Attr) const {
  auto *FD = llvm::cast<FunctionDecl>(D);
  ASTContext &Ctx = S.Context;
  FD->addAttr(AnnotateAttr::Create(Ctx, ExportFunctionHandleMarker, nullptr, 0,
                                   Attr.getRange()));
  // Promote the original __device__ function (or template) to
  // __host__ __device__ so host code can take its address. Sema then
  // accepts &deviceFn from host context (SameSide preference). The
  // consumer rewrites references to the synthesized kernel handle and
  // clears bodies in host mode so emission of host-side code skips
  // device-only intrinsics.
  if (!FD->hasAttr<CUDAHostAttr>())
    FD->addAttr(CUDAHostAttr::CreateImplicit(Ctx));
  return AttributeApplied;
}

} // namespace luthier
