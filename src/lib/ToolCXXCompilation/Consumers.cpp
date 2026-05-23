//===-- Consumers.cpp -----------------------------------------------------===//
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
#include "luthier/ToolCXXCompilation/Consumers.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <clang/AST/AST.h>
#include <clang/AST/Attr.h>
#include <clang/AST/DeclTemplate.h>
#include <clang/AST/Mangle.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Basic/Cuda.h>
#include <clang/Sema/Sema.h>
#include <clang/Sema/SemaCUDA.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/Twine.h>
#include <llvm/Support/Casting.h>
#include <llvm/Support/raw_ostream.h>
#include <memory>

namespace luthier {

namespace {

bool hasAnnotation(const clang::FunctionDecl *FD, llvm::StringRef Tag) {
  for (const clang::FunctionDecl *ReDecl : FD->redecls())
    for (const auto *A : ReDecl->specific_attrs<clang::AnnotateAttr>())
      if (A->getAnnotation() == Tag)
        return true;
  return false;
}

/// Returns the tagged template pattern \c FD specializes, or nullptr if
/// \c FD is not a specialization of an export-handle-tagged template.
clang::FunctionDecl *getTaggedPattern(clang::FunctionDecl *FD) {
  if (auto *PrimaryTpl = FD->getPrimaryTemplate()) {
    auto *Pattern = PrimaryTpl->getTemplatedDecl();
    if (hasAnnotation(Pattern, ExportFunctionHandleMarker))
      return Pattern;
  }
  return nullptr;
}

std::string mangleDecl(clang::ASTContext &Ctx, clang::FunctionDecl *FD) {
  std::string Out;
  llvm::raw_string_ostream OS(Out);
  std::unique_ptr<clang::MangleContext> MC(Ctx.createMangleContext());
  if (MC->shouldMangleDeclName(FD))
    MC->mangleName(FD, OS);
  else
    OS << FD->getName();
  return Out;
}

clang::FunctionDecl *makeHandle(clang::Sema &S, clang::FunctionDecl *FD) {
  clang::ASTContext &Ctx = S.Context;
  clang::TranslationUnitDecl *TU = Ctx.getTranslationUnitDecl();
  clang::SourceLocation Loc = FD->getLocation();

  std::string Mangled = mangleDecl(Ctx, FD);
  std::string HandleName = (llvm::Twine(HandlePrefix) + Mangled).str();
  clang::IdentifierInfo &II = Ctx.Idents.get(HandleName);

  auto *Handle = clang::FunctionDecl::Create(
      Ctx, TU, Loc, Loc, clang::DeclarationName(&II), FD->getType(),
      FD->getTypeSourceInfo(), clang::SC_None,
      /*UsesFPIntrin=*/false,
      /*isInline=*/false, /*hasWrittenPrototype=*/true,
      clang::ConstexprSpecKind::Unspecified);

  llvm::SmallVector<clang::ParmVarDecl *, 4> Params;
  for (clang::ParmVarDecl *P : FD->parameters()) {
    Params.push_back(clang::ParmVarDecl::Create(
        Ctx, Handle, P->getLocation(), P->getLocation(), P->getIdentifier(),
        P->getType(), P->getTypeSourceInfo(), P->getStorageClass(),
        /*DefArg=*/nullptr));
  }
  Handle->setParams(Params);

  Handle->addAttr(clang::CUDAHostAttr::CreateImplicit(Ctx));
  Handle->addAttr(clang::UsedAttr::CreateImplicit(Ctx));
  Handle->addAttr(clang::AnnotateAttr::Create(Ctx, ExportFunctionHandleMarker,
                                              /*Args=*/nullptr, /*NumArgs=*/0,
                                              Loc));
  Handle->setBody(clang::CompoundStmt::Create(
      Ctx, /*Stmts=*/{}, clang::FPOptionsOverride(), Loc, Loc));

  TU->addDecl(Handle);
  S.PushOnScopeChains(Handle, S.TUScope, /*AddToContext=*/false);
  S.MarkFunctionReferenced(Loc, Handle, /*MightBeOdrUse=*/true);
  S.Consumer.HandleTopLevelDecl(clang::DeclGroupRef(Handle));
  return Handle;
}

/// Returns true if \p FD is tagged with the export-handle marker, either
/// directly (non-templated case) or via its primary template (template
/// specialization case).
bool isTaggedCallee(clang::FunctionDecl *FD) {
  if (hasAnnotation(FD, ExportFunctionHandleMarker))
    return true;
  if (FD->isFunctionTemplateSpecialization())
    return getTaggedPattern(FD) != nullptr;
  return false;
}

class RewriteVisitor : public clang::RecursiveASTVisitor<RewriteVisitor> {
  clang::Sema &S;

  llvm::DenseMap<clang::FunctionDecl *, clang::FunctionDecl *> &Map;

  /// Stack of enclosing FunctionDecls maintained by the
  /// \c TraverseFunctionDecl override below. Top-of-stack is the
  /// directly-enclosing function of whatever expression we're visiting.
  llvm::SmallVector<clang::FunctionDecl *, 4> EnclosingFn;

public:
  RewriteVisitor(
      clang::Sema &SR,
      llvm::DenseMap<clang::FunctionDecl *, clang::FunctionDecl *> &M)
      : S(SR), Map(M) {}

  bool TraverseFunctionDecl(clang::FunctionDecl *FD) {
    EnclosingFn.push_back(FD);
    bool Ok =
        clang::RecursiveASTVisitor<RewriteVisitor>::TraverseFunctionDecl(FD);
    EnclosingFn.pop_back();
    return Ok;
  }

  bool TraverseCXXMethodDecl(clang::CXXMethodDecl *MD) {
    EnclosingFn.push_back(MD);
    bool Ok =
        clang::RecursiveASTVisitor<RewriteVisitor>::TraverseCXXMethodDecl(MD);
    EnclosingFn.pop_back();
    return Ok;
  }

  bool VisitCallExpr(clang::CallExpr *CE) {
    auto *Callee =
        llvm::dyn_cast_or_null<clang::FunctionDecl>(CE->getCalleeDecl());
    if (!Callee || !isTaggedCallee(Callee))
      return true;
    // Only diagnose calls whose enclosing function is host-context;
    // device→device calls (e.g. an export-handle hook invoked from
    // inside a __global__ kernel during the same TU's host compile —
    // Sema still parses the __global__ body in host compile to type-
    // check it) are legal and must not error.
    if (EnclosingFn.empty())
      return true;
    clang::FunctionDecl *Caller = EnclosingFn.back();
    clang::CUDAFunctionTarget Target = S.CUDA().IdentifyTarget(Caller);
    if (Target != clang::CUDAFunctionTarget::Host &&
        Target != clang::CUDAFunctionTarget::HostDevice)
      return true;
    // Host context: the export-handle attribute only enables host-side
    // address-take of the tagged device function. A direct call would
    // either dispatch to the empty sibling (non-templated case) or to
    // the original whose body uses device-only intrinsics (templated
    // case, with CUDAHostAttr promotion). Both are silently wrong;
    // emit a diagnostic so the user fails loudly instead.
    unsigned DiagID = S.getDiagnostics().getCustomDiagID(
        clang::DiagnosticsEngine::Error,
        "calling a device function tagged with "
        "[[luthier::export_function_handle]] from host context is not "
        "supported; the attribute only enables taking the function's "
        "address");
    S.Diag(CE->getExprLoc(), DiagID);
    return true;
  }

  bool VisitDeclRefExpr(clang::DeclRefExpr *E) {
    auto *FD = llvm::dyn_cast<clang::FunctionDecl>(E->getDecl());
    if (!FD)
      return true;
    // Only template specializations need rewriting; non-template tagged
    // functions are handled at attribute-parse time via the dual-overload
    // sibling synthesized in handleDeclAttribute.
    if (!FD->isFunctionTemplateSpecialization())
      return true;
    clang::FunctionDecl *Pattern = getTaggedPattern(FD);
    if (!Pattern)
      return true;

    clang::FunctionDecl *Key = FD->getCanonicalDecl();
    auto It = Map.find(Key);
    if (It == Map.end()) {
      clang::FunctionDecl *Handle = makeHandle(S, FD);
      Map[Key] = Handle;
      It = Map.find(Key);
    }
    E->setDecl(It->second);
    E->setType(It->second->getType());

    // The CUDAHostAttr on the original specialization (inherited from the
    // template pattern) existed only to let Sema accept the address-take
    // at parse time. With the DeclRefExpr retargeted at the
    // per-specialization handle, the original is no longer addressable
    // from host; drop the attr from both the specialization and the
    // pattern so any future host reference falls back to the normal
    // err_ref_bad_target diag. dropAttr is idempotent.
    FD->dropAttr<clang::CUDAHostAttr>();
    Pattern->dropAttr<clang::CUDAHostAttr>();
    return true;
  }
};

} // namespace

void ExportDevFuncHostHandleConsumer::InitializeSema(clang::Sema &S) {
  SemaRef = &S;
  OrigToHandle.clear();
}

void ExportDevFuncHostHandleConsumer::ForgetSema() { SemaRef = nullptr; }

bool ExportDevFuncHostHandleConsumer::HandleTopLevelDecl(
    clang::DeclGroupRef DG) {
  if (!SemaRef)
    return true;
  clang::ASTContext &Ctx = SemaRef->Context;
  const bool IsHostCompile =
      Ctx.getLangOpts().CUDA && !Ctx.getLangOpts().CUDAIsDevice;
  if (!IsHostCompile)
    return true;
  RewriteVisitor V(*SemaRef, OrigToHandle);
  for (clang::Decl *D : DG)
    V.TraverseDecl(D);
  return true;
}

} // namespace luthier
