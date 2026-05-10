//===-- Consumers.h ----------------------------------------------*- C++-*-===//
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
/// \file Consumers.h
/// Defines <tt>clang::SemaConsumer</tt>s used in Luthier tool CXX compilation.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_CXX_COMPILATION_CONSUMERS_H
#define LUTHIER_TOOLING_CXX_COMPILATION_CONSUMERS_H
#include <clang/AST/DeclGroup.h>
#include <clang/Sema/SemaConsumer.h>
#include <llvm/ADT/DenseMap.h>

namespace clang {
class ASTContext;
class Decl;
class FunctionDecl;
class Sema;
} // namespace clang

namespace luthier {

/// \brief A SemaConsumer that, alongside the
/// \c LuthierExportFunctionHandleAttrInfo attribute, synthesizes
/// per-instantiation kernel handles for tagged device functions and rewrites
/// host-side use sites to point at them.
class HostHandleSynthConsumer : public clang::SemaConsumer {
public:
  HostHandleSynthConsumer() = default;

  void InitializeSema(clang::Sema &S) override;
  void ForgetSema() override;
  bool HandleTopLevelDecl(clang::DeclGroupRef DG) override;

private:
  void handleDecl(clang::Decl *D, clang::ASTContext &Ctx, bool IsHostCompile);

  clang::Sema *SemaRef = nullptr;

  /// Per-consumer state: tagged device FunctionDecl -> synthesized kernel
  /// handle FunctionDecl
  /// Lives for the duration of the consumer; reset by \c InitializeSema so
  /// two consecutive TUs don't bleed into each other.
  llvm::DenseMap<clang::FunctionDecl *, clang::FunctionDecl *> DeviceFnToHandle;
};

} // namespace luthier

#endif
