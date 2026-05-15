//===-- LuthierBranchRelaxation.h ---------------------------------*- C++ -*-===//
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
/// \file LuthierBranchRelaxation.h
/// Luthier-side fork of \c llvm::BranchRelaxation. Tracks the same
/// per-block size + offset model as stock but performs the long-branch
/// emission via a Luthier-owned helper that delegates SGPR scavenging to
/// \c LuthierRegScavenger — letting us protect the SVA storage reg and
/// optionally redirect emergency spills to SVA lanes.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_LUTHIER_BRANCH_RELAXATION_H
#define LUTHIER_TOOL_CODE_GEN_LUTHIER_BRANCH_RELAXATION_H

#include "luthier/ToolCodeGen/LuthierRegScavenger.h"
#include <llvm/ADT/DenseSet.h>

namespace llvm {
class MachineFunction;
} // namespace llvm

namespace luthier {

class LuthierBranchRelaxation {
public:
  /// Construct with optional Luthier-side scavenger configuration. The
  /// \p ReservedRegs set is propagated into the internal scavenger; the
  /// \p SpillSink callback is invoked when the scavenger can't find a
  /// globally-free register in the requested class.
  LuthierBranchRelaxation(
      llvm::DenseSet<llvm::MCPhysReg> ReservedRegs = {},
      LuthierRegScavenger::SVASpillCallback SpillSink = nullptr)
      : ReservedRegs(std::move(ReservedRegs)),
        SpillSink(std::move(SpillSink)) {}

  /// Run branch relaxation on \p MF. Returns true if any branch was
  /// relaxed. Mirrors \c llvm::BranchRelaxation::run.
  bool run(llvm::MachineFunction &MF);

private:
  llvm::DenseSet<llvm::MCPhysReg> ReservedRegs;
  LuthierRegScavenger::SVASpillCallback SpillSink;
};

} // namespace luthier

#endif
