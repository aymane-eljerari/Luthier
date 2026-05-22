//===-- ExternalizeGlobalsPass.cpp ----------------------------------------===//
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
#include "luthier/ToolIRCompilation/ExternalizeGlobalsPass.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <llvm/ADT/STLExtras.h>
#include <llvm/IR/GlobalValue.h>
#include <llvm/IR/GlobalVariable.h>
#include <llvm/IR/Module.h>

namespace luthier {

llvm::PreservedAnalyses
ExternalizeGlobalsPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &) {
  for (llvm::GlobalVariable &GV : llvm::make_early_inc_range(M.globals())) {
    llvm::StringRef GVName = GV.getName();
    // Preserve `@llvm.compiler.used` / `@llvm.used` — `MarkAnnotationsPass`
    // (the inner pipeline's first step) reanchors hook functions
    // against `@llvm.compiler.used` so the loader's runtime IR pipeline
    // doesn't `GlobalDCE` them. Stripping them here by virtue of their
    // `"llvm.metadata"` section would undo that work and the embedded
    // module would re-arrive at the loader with no hook anchors.
    if (GVName == "llvm.compiler.used" || GVName == "llvm.used")
      continue;
    if (GVName.ends_with(".managed") || GV.getSection() == "llvm.metadata") {
      GV.dropAllReferences();
      GV.eraseFromParent();
    } else if (!GVName.starts_with(HipCUIDPrefix)) {
      GV.setInitializer(nullptr);
      GV.setLinkage(llvm::GlobalValue::ExternalLinkage);
      GV.setVisibility(llvm::GlobalValue::DefaultVisibility);
      GV.setDSOLocal(false);
    }
  }
  return llvm::PreservedAnalyses::none();
}

} // namespace luthier
