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
#ifndef LUTHIER_TOOL_CXX_COMPILATION_CONSUMERS_H
#define LUTHIER_TOOL_CXX_COMPILATION_CONSUMERS_H
#include <clang/AST/DeclGroup.h>
#include <clang/Sema/SemaConsumer.h>
#include <llvm/ADT/DenseMap.h>

namespace clang {
class Decl;
class FunctionDecl;
class Sema;
} // namespace clang

namespace luthier {

/// \brief SemaConsumer that materializes host-side handles for tagged
/// device functions and retargets host-context references to them.
///
/// \c LuthierExportFunctionHandleAttrInfo promotes every tagged
/// \c __device__ function to \c __host__ \c __device__ so Sema accepts
/// \c &deviceFn from host context at parse time, but doesn't otherwise
/// touch the AST. This consumer walks every host-context
/// \c DeclRefExpr; if the referent (or, for template specializations,
/// the primary template) carries the export-handle annotation, it
/// synthesizes a concrete \c __host__ \c FunctionDecl with a unique
/// mangled-suffix name, empty body, and the export-handle annotation,
/// then retargets the \c DeclRefExpr. After retargeting it drops
/// \c CUDAHostAttr from the original so any future host reference falls
/// back to the normal \c err_ref_bad_target diagnostic.
class ExportDevFuncHostHandleConsumer : public clang::SemaConsumer {
public:
  ExportDevFuncHostHandleConsumer() = default;

  void InitializeSema(clang::Sema &S) override;

  void ForgetSema() override;

  bool HandleTopLevelDecl(clang::DeclGroupRef DG) override;

private:
  clang::Sema *SemaRef = nullptr;

  /// Canonical original FunctionDecl → its synthesized host handle.
  /// Cleared per TU on \c InitializeSema.
  llvm::DenseMap<clang::FunctionDecl *, clang::FunctionDecl *> OrigToHandle;
};

} // namespace luthier

#endif
