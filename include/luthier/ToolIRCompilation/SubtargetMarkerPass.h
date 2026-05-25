//===-- SubtargetMarkerPass.h -------------------------------------*- C++-*-===//
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
/// \file SubtargetMarkerPass.h
/// Emits a small \c i32 global named \c __luthier_subtarget into each
/// AMDGCN device module that records the wave-size and CU-mode settings
/// the slice was compiled with. The loader reads this symbol to
/// disambiguate multiple code objects bundled with the same gfx label
/// (e.g. one wave32+CU and one wave64+CU slice for the same arch) so it
/// can pick the right one at instrumented-kernel dispatch time.
///
/// Encoding (bit positions in the i32 value):
///   bit 0 — set if the slice was compiled with wave64; clear for wave32
///   bit 1 — set if the slice runs in CU mode; clear for WGP mode
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_IR_COMPILATION_SUBTARGET_MARKER_PASS_H
#define LUTHIER_TOOL_IR_COMPILATION_SUBTARGET_MARKER_PASS_H
#include <llvm/IR/PassManager.h>

namespace llvm {
class Module;
}

namespace luthier {

class SubtargetMarkerPass : public llvm::PassInfoMixin<SubtargetMarkerPass> {
public:
  SubtargetMarkerPass() = default;

  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &AM);

  static bool isRequired() { return true; }

  static llvm::StringRef name() { return "luthier-subtarget-marker"; }
};

} // namespace luthier

#endif
