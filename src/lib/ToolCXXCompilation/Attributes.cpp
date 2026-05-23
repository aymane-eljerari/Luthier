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
#include "luthier/ToolCXXCompilation/Attributes.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <clang/AST/ASTConsumer.h>
#include <clang/AST/Attr.h>
#include <clang/AST/Decl.h>
#include <clang/AST/DeclCXX.h>
#include <clang/AST/DeclGroup.h>
#include <clang/AST/Stmt.h>
#include <clang/Sema/Sema.h>
#include <clang/Sema/SemaDiagnostic.h>
#include <llvm/ADT/SmallVector.h>

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

  /// consteval functions are immediate functions: their address cannot
  /// be taken at runtime (per [expr.const]), so an export-handle on a
  /// consteval function has no operational use — the user could never
  /// form a runtime pointer to register with Luthier. Reject with a
  /// custom diagnostic. constexpr (non-consteval) is fine: address-take
  /// produces a normal runtime pointer; constant-evaluation in host
  /// context resolves to the synthesized non-constexpr sibling and
  /// Sema produces a clean "non-constexpr function called in constant
  /// expression" diagnostic if the user tries that
  if (FD->isConsteval()) {
    unsigned DiagID = S.getDiagnostics().getCustomDiagID(
        clang::DiagnosticsEngine::Error,
        "[[luthier::export_function_handle]] cannot be applied to a consteval "
        "function: an immediate function's address cannot be taken at "
        "runtime, so the export handle has no use");
    S.Diag(Attr.getLoc(), DiagID);
    return AttributeNotApplied;
  }

  /// The marker on the original is what the \c HostHandleSynthConsumer keys off
  /// to detect tagged templates during AST traversal (for the
  /// per-specialization handle synthesis at use sites). For non-templated decls
  /// the host-emittable artifact is the sibling we synthesize below, and that's
  /// the annotation entry the IR pass cares about; the marker on the original
  /// here is mostly documentary
  FD->addAttr(clang::AnnotateAttr::Create(Ctx, ExportFunctionHandleMarker,
                                          /*Args=*/nullptr, /*NumArgs=*/0,
                                          Attr.getRange()));

  /// Templated decls: defer per-specialization synthesis to the
  /// \c HostHandleSynthConsumer (the dual-overload trick is ambiguous for
  /// explicit-template-id address-takes). Promote the template to __host__
  /// __device__ so Sema accepts &myHook<T> from host context at parse time; the
  /// consumer retargets the DeclRefExpr to the per-specialization handle before
  /// TU-end, and drops CUDAHostAttr from both the specialization and the
  /// pattern once the retarget is done
  if (FD->isTemplated() || FD->getDescribedFunctionTemplate()) {
    if (!FD->hasAttr<clang::CUDAHostAttr>())
      FD->addAttr(clang::CUDAHostAttr::CreateImplicit(Ctx));
    return AttributeApplied;
  }

  /// Non-templated case. If a sibling already exists for this name
  /// (\c handleDeclAttribute fired earlier on the in-class declaration and
  /// we're now seeing the out-of-line definition), don't synthesize a second
  /// one. Both siblings would share the Itanium mangling and collide at host
  /// codegen
  /// (Note that, at attribute-processing time the redecl chain hasn't been
  /// wired up so getPreviousDecl() returns null, hence the parent lookup)
  clang::DeclContext *Parent = FD->getDeclContext();
  for (clang::NamedDecl *Existing : Parent->lookup(FD->getDeclName())) {
    if (auto *F = llvm::dyn_cast<clang::FunctionDecl>(Existing))
      if (F != FD && F->hasAttr<clang::CUDAHostAttr>())
        return AttributeApplied;
  }

  /// Synthesize a sibling __host__ overload with the same name and
  /// signature. Sema's CUDA overload resolution routes &deviceFn from
  /// host context to this empty sibling. The original stays pure
  /// __device__, so its body (which may contain AMDGCN intrinsics) is
  /// never visited by host CodeGen — no deferred-diag interaction
  clang::SourceLocation Loc = FD->getLocation();

  clang::FunctionDecl *Sibling;
  /// Support for class static methods
  if (auto *Method = llvm::dyn_cast<clang::CXXMethodDecl>(FD)) {
    Sibling = clang::CXXMethodDecl::Create(
        Ctx, llvm::cast<clang::CXXRecordDecl>(Parent), Loc,
        clang::DeclarationNameInfo(FD->getDeclName(), Loc), FD->getType(),
        FD->getTypeSourceInfo(), Method->getStorageClass(),
        /*UsesFPIntrin=*/false, /*isInline=*/false,
        clang::ConstexprSpecKind::Unspecified, Loc);
    /// The original's access specifier may not be set yet when
    /// \c handleDeclAttribute fires (calling getAccess() in that state
    /// asserts); use the access-unsafe accessor and fall back to public,
    /// which is the intended access for an export-handle hook.
    clang::AccessSpecifier Access = Method->getAccessUnsafe();
    if (Access == clang::AS_none)
      Access = clang::AS_public;
    Sibling->setAccess(Access);
  } else {
    Sibling = clang::FunctionDecl::Create(
        Ctx, Parent, Loc, Loc, FD->getDeclName(), FD->getType(),
        FD->getTypeSourceInfo(), clang::SC_None,
        /*UsesFPIntrin=*/false,
        /*isInline=*/false, /*hasWrittenPrototype=*/true,
        clang::ConstexprSpecKind::Unspecified);
  }

  /// Clone parameter decls so the sibling owns its own ParmVarDecls.
  llvm::SmallVector<clang::ParmVarDecl *, 4> Params;
  for (clang::ParmVarDecl *P : FD->parameters()) {
    Params.push_back(clang::ParmVarDecl::Create(
        Ctx, Sibling, P->getLocation(), P->getLocation(), P->getIdentifier(),
        P->getType(), P->getTypeSourceInfo(), P->getStorageClass(),
        /*DefArg=*/nullptr));
  }
  Sibling->setParams(Params);

  Sibling->addAttr(clang::CUDAHostAttr::CreateImplicit(Ctx));
  Sibling->addAttr(clang::UsedAttr::CreateImplicit(Ctx));
  Sibling->addAttr(clang::AnnotateAttr::Create(Ctx, ExportFunctionHandleMarker,
                                               /*Args=*/nullptr, /*NumArgs=*/0,
                                               Attr.getRange()));
  Sibling->setBody(clang::CompoundStmt::Create(
      Ctx, /*Stmts=*/{}, clang::FPOptionsOverride(), Loc, Loc));

  Parent->addDecl(Sibling);
  if (S.TUScope)
    S.PushOnScopeChains(Sibling, S.TUScope, /*AddToContext=*/false);
  S.MarkFunctionReferenced(Loc, Sibling, /*MightBeOdrUse=*/true);
  S.Consumer.HandleTopLevelDecl(clang::DeclGroupRef(Sibling));

  return AttributeApplied;
}

} // namespace luthier
