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
#include "luthier/ToolingCXXCompilation/Consumers.h"
#include "luthier/ToolingCXXCompilation/HostHandleSynthPlugin.h"
#include "luthier/ToolingCXXCompilation/Mangling.h"
#include <clang/AST/AST.h>
#include <clang/AST/ASTConsumer.h>
#include <clang/AST/Attr.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Sema/Sema.h>
#include <llvm/Support/Casting.h>

namespace luthier {

namespace {

bool hasAnnotation(const clang::FunctionDecl *FD, llvm::StringRef Tag) {
  for (const auto *A : FD->specific_attrs<clang::AnnotateAttr>()) {
    if (A->getAnnotation() == Tag)
      return true;
  }
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
    // Already-processed decls remain in the map after their AnnotateAttrs
    // are dropped, so consult the map first to avoid the attribute check
    // missing them.
    auto It = Map.find(FD);
    if (It == Map.end()) {
      if (!hasExportHandleAttr(FD) || FD->isTemplated())
        return true;
      clang::FunctionDecl *Handle = makeKernelHandle(SemaRef, FD);
      Map[FD] = Handle;
      It = Map.find(FD);
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
      auto It = DeviceFnToHandle.find(FD);
      if (It == DeviceFnToHandle.end()) {
        clang::FunctionDecl *Handle = makeKernelHandle(*SemaRef, FD);
        DeviceFnToHandle[FD] = Handle;
      }
      if (IsHostCompile && FD->hasBody()) {
        // Clear the body and strip the anchors that would otherwise keep
        // the dead host emission alive: UsedAttr (-> @llvm.compiler.used)
        // and AnnotateAttrs (-> @llvm.global.annotations). All host-side
        // DeclRefExprs are rewritten to the synthesized kernel handle
        // below, so nothing references this symbol from host code. The
        // function is still emitted as an empty extern-"C" symbol with
        // no callers; --gc-sections will drop it at link time.
        FD->setBody(clang::CompoundStmt::Create(
            Ctx, {}, clang::FPOptionsOverride(), clang::SourceLocation(),
            clang::SourceLocation()));
        while (FD->hasAttr<clang::UsedAttr>())
          FD->dropAttr<clang::UsedAttr>();
        while (FD->hasAttr<clang::AnnotateAttr>())
          FD->dropAttr<clang::AnnotateAttr>();
      }
    }
  }

  if (auto *FTD = llvm::dyn_cast<clang::FunctionTemplateDecl>(D)) {
    for (clang::FunctionDecl *Spec : FTD->specializations())
      handleDecl(Spec, Ctx, IsHostCompile);
  }

  RewriteVisitor V(*SemaRef, DeviceFnToHandle);
  V.TraverseDecl(D);
}

} // namespace luthier
