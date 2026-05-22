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
#include "luthier/ToolCXXCompilation/Annotations.h"
#include "luthier/ToolCXXCompilation/Mangling.h"
#include <clang/AST/AST.h>
#include <clang/AST/ASTConsumer.h>
#include <clang/AST/Attr.h>
#include <clang/AST/DeclCXX.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Sema/Sema.h>
#include <llvm/Support/Casting.h>

namespace luthier {

namespace {

bool hasAnnotation(const clang::FunctionDecl *FD, llvm::StringRef Tag) {
  // Attributes can live on any redeclaration. Inspect every form before
  // declaring the function untagged so an out-of-line definition whose
  // attribute appears only on the in-class declaration still matches.
  for (const clang::FunctionDecl *Redecl : FD->redecls())
    for (const auto *A : Redecl->specific_attrs<clang::AnnotateAttr>())
      if (A->getAnnotation() == Tag)
        return true;
  return false;
}

bool hasExportHandleAttr(const clang::FunctionDecl *FD) {
  return hasAnnotation(FD, ExportFunctionHandleMarker);
}

/// Synthesizes <tt>extern "C" __global__ __used__ void
/// __luthier_builtin_hook_handle_<key>() {}</tt> at file scope. HIP's dual
/// emission produces both the device kernel symbol (registered with the
/// runtime) and the host stub whose address is what host code will obtain
/// after the use-site rewrite.
clang::FunctionDecl *makeKernelHandle(clang::Sema &S,
                                      clang::FunctionDecl *Original) {
  clang::ASTContext &Ctx = S.Context;
  clang::TranslationUnitDecl *TU = Ctx.getTranslationUnitDecl();

  std::string Name = mangleAndSanitize(Original, Ctx);
  clang::IdentifierInfo &II = Ctx.Idents.get(Name);

  clang::FunctionProtoType::ExtProtoInfo EPI;
  clang::QualType FnTy = Ctx.getFunctionType(Ctx.VoidTy, {}, EPI);

  auto *LS = clang::LinkageSpecDecl::Create(Ctx, TU, clang::SourceLocation(),
                                            clang::SourceLocation(),
                                            clang::LinkageSpecLanguageIDs::C,
                                            /*HasBraces=*/false);

  auto *FD = clang::FunctionDecl::Create(
      Ctx, LS, clang::SourceLocation(), clang::SourceLocation(),
      clang::DeclarationName(&II), FnTy,
      /*TInfo=*/nullptr, clang::SC_Extern, /*UsesFPIntrin=*/false,
      /*isInlineSpecified=*/false, /*hasWrittenPrototype=*/true,
      clang::ConstexprSpecKind::Unspecified);

  FD->addAttr(clang::CUDAGlobalAttr::CreateImplicit(Ctx));
  FD->addAttr(clang::UsedAttr::CreateImplicit(Ctx));

  FD->setBody(clang::CompoundStmt::Create(Ctx, {}, clang::FPOptionsOverride(),
                                          clang::SourceLocation(),
                                          clang::SourceLocation()));

  LS->addDecl(FD);
  TU->addDecl(LS);

  S.PushOnScopeChains(FD, S.TUScope, /*AddToContext=*/false);
  S.MarkFunctionReferenced(clang::SourceLocation(), FD, /*MightBeOdrUse=*/true);
  S.Consumer.HandleTopLevelDecl(clang::DeclGroupRef(LS));
  return FD;
}

class RewriteVisitor : public clang::RecursiveASTVisitor<RewriteVisitor> {
  clang::Sema &SemaRef;
  llvm::DenseMap<clang::FunctionDecl *, clang::FunctionDecl *> &Map;

public:
  RewriteVisitor(
      clang::Sema &S,
      llvm::DenseMap<clang::FunctionDecl *, clang::FunctionDecl *> &M)
      : SemaRef(S), Map(M) {}

  bool VisitDeclRefExpr(clang::DeclRefExpr *E) {
    auto *FD = llvm::dyn_cast<clang::FunctionDecl>(E->getDecl());
    if (!FD)
      return true;
    // Different redeclarations of the same method share a canonical decl;
    // key the map by it so the in-class declaration and the out-of-line
    // definition both resolve to the same synthesized handle.
    clang::FunctionDecl *Key = FD->getCanonicalDecl();
    auto It = Map.find(Key);
    if (It == Map.end()) {
      if (!hasExportHandleAttr(FD) || FD->isTemplated())
        return true;
      clang::FunctionDecl *Handle = makeKernelHandle(SemaRef, FD);
      Map[Key] = Handle;
      It = Map.find(Key);
    }
    clang::FunctionDecl *Handle = It->second;
    E->setDecl(Handle);
    E->setType(Handle->getType());
    return true;
  }
};

} // namespace

void HostHandleSynthConsumer::InitializeSema(clang::Sema &S) {
  SemaRef = &S;
  DeviceFnToHandle.clear();
}

void HostHandleSynthConsumer::ForgetSema() { SemaRef = nullptr; }

bool HostHandleSynthConsumer::HandleTopLevelDecl(clang::DeclGroupRef DG) {
  if (!SemaRef)
    return true;
  clang::ASTContext &Ctx = SemaRef->Context;
  const bool IsHostCompile =
      Ctx.getLangOpts().CUDA && !Ctx.getLangOpts().CUDAIsDevice;
  for (clang::Decl *D : DG)
    handleDecl(D, Ctx, IsHostCompile);
  return true;
}

void HostHandleSynthConsumer::handleDecl(clang::Decl *D, clang::ASTContext &Ctx,
                                         bool IsHostCompile) {
  if (auto *FD = llvm::dyn_cast<clang::FunctionDecl>(D)) {
    if (hasExportHandleAttr(FD) && !FD->isTemplated()) {
      // Always key by the canonical decl so the in-class declaration and
      // the out-of-line definition (different FunctionDecl objects) share
      // one synthesized handle.
      clang::FunctionDecl *Key = FD->getCanonicalDecl();
      auto It = DeviceFnToHandle.find(Key);
      if (It == DeviceFnToHandle.end()) {
        clang::FunctionDecl *Handle = makeKernelHandle(*SemaRef, FD);
        DeviceFnToHandle[Key] = Handle;
      }
      if (IsHostCompile && FD->hasBody()) {
        // Replace the body with an empty CompoundStmt. The function is
        // still emitted host-side as an empty `void name()` symbol so
        // every IR-level anchor the codegen has already registered for
        // it stays valid:
        //   * @llvm.compiler.used (from UsedAttr)
        //   * @llvm.global.annotations (from AnnotateAttr)
        // We deliberately do NOT drop those attributes — CodeGenModule
        // has already deferred annotation emission keyed on this Decl
        // by the time the parser finishes the in-class body, and
        // dropping the AnnotateAttr behind CGM's back trips the
        // `D->hasAttr<AnnotateAttr>()` assert inside
        // `EmitGlobalAnnotations` at module finalize. Keeping the
        // attributes is harmless: the empty body has no AMDGCN
        // intrinsics, so nothing illegal leaks to x86 codegen. Host
        // DeclRefExprs are rewritten to the synthesized kernel handle
        // below, so nothing CALLS this symbol from host code; the
        // empty stub is dead weight that --gc-sections drops at link
        // time.
        FD->setBody(clang::CompoundStmt::Create(
            Ctx, {}, clang::FPOptionsOverride(), clang::SourceLocation(),
            clang::SourceLocation()));
      }
    }
  }

  if (auto *FTD = llvm::dyn_cast<clang::FunctionTemplateDecl>(D)) {
    for (clang::FunctionDecl *Spec : FTD->specializations())
      handleDecl(Spec, Ctx, IsHostCompile);
  }

  // Tagged hooks may be static members of a class (possibly inside a
  // namespace, including an anonymous one). The lit suite only covers
  // namespace-scope free functions, but tool authors are encouraged to
  // group hooks as `static` members of their `HSATool` subclass. Recurse
  // into NamespaceDecl and TagDecl so those nested FunctionDecls are
  // found and processed the same way as top-level ones.
  if (auto *ND = llvm::dyn_cast<clang::NamespaceDecl>(D)) {
    for (clang::Decl *Child : ND->decls())
      handleDecl(Child, Ctx, IsHostCompile);
  } else if (auto *RD = llvm::dyn_cast<clang::CXXRecordDecl>(D)) {
    if (RD->isThisDeclarationADefinition()) {
      for (clang::Decl *Child : RD->decls())
        handleDecl(Child, Ctx, IsHostCompile);
    }
  } else if (auto *TD = llvm::dyn_cast<clang::TagDecl>(D)) {
    if (TD->isThisDeclarationADefinition()) {
      for (clang::Decl *Child : TD->decls())
        handleDecl(Child, Ctx, IsHostCompile);
    }
  } else if (auto *LSD = llvm::dyn_cast<clang::LinkageSpecDecl>(D)) {
    for (clang::Decl *Child : LSD->decls())
      handleDecl(Child, Ctx, IsHostCompile);
  }

  RewriteVisitor V(*SemaRef, DeviceFnToHandle);
  V.TraverseDecl(D);
}

} // namespace luthier
