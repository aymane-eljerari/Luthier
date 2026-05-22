//===-- Mangling.cpp ------------------------------------------------------===//
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
#include "luthier/ToolCXXCompilation/Mangling.h"
#include "luthier/ToolCXXCompilation/Annotations.h"
#include <clang/AST/ASTContext.h>
#include <clang/AST/Decl.h>
#include <clang/AST/Mangle.h>
#include <llvm/ADT/Twine.h>
#include <llvm/Support/raw_ostream.h>
#include <memory>

namespace luthier {

std::string buildHandleBaseIdentifier(clang::FunctionDecl *FD,
                                      clang::ASTContext &Ctx) {
  std::string OriginalSymbol;
  llvm::raw_string_ostream OS(OriginalSymbol);
  std::unique_ptr<clang::MangleContext> MC(Ctx.createMangleContext());
  if (MC->shouldMangleDeclName(FD))
    MC->mangleName(FD, OS);
  else
    OS << FD->getName();
  return (llvm::Twine(HookHandleSymbolPrefix) + OriginalSymbol).str();
}

} // namespace luthier
