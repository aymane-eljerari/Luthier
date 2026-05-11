//===-- SubstituteAMDGCNIntrinsicsPass.h -------------------------*- C++-*-===//
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
/// \file SubstituteAMDGCNIntrinsicsPass.h
/// Defines the \c SubstituteAMDGCNIntrinsicsPass which re-writes
/// a set of amdgcn intrinsics that require special lowering in Luthier's
/// code generation to instead use their luthier equivalent.
/// Current rewrites:
///   \c llvm.amdgcn.workgroup.id.{x,y,z} -> \c luthier::workgroupId{X,Y,Z}
///   \c llvm.amdgcn.implicitarg.ptr     -> \c luthier::implicitArgPtr
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_SUBSTITUTE_AMDGCN_INTRINSICS_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_SUBSTITUTE_AMDGCN_INTRINSICS_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class SubstituteAMDGCNIntrinsicsPass
    : public llvm::PassInfoMixin<SubstituteAMDGCNIntrinsicsPass> {
public:
  SubstituteAMDGCNIntrinsicsPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() {
    return "luthier-substitute-amdgcn-intrinsics";
  }
};

} // namespace luthier

#endif
