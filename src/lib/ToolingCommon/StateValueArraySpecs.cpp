//===-- StateValueArraySpecs.cpp ------------------------------------------===//
// Copyright 2022-2026 @ Northeastern University Computer Architecture Lab
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
///
/// \file StateValueArraySpecs.cpp
/// Implements functions used to query the state value array specs.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/StateValueArraySpecs.h"
#include <GCNSubtarget.h>

namespace luthier {

std::unique_ptr<StateValueArraySpecs>
StateValueArraySpecs::getSVASpecs(const llvm::Module &M,
                                  const llvm::GCNSubtarget &STI) {
  std::unique_ptr<StateValueArraySpecs> Out{new StateValueArraySpecs()};
  uint8_t NextLane = 0;

  /// Determine the frame spill and instrumentation slot values first:
  /// Targets with architected flat scratch: AMDGPU::SP_REG, AMDGPU::FP_REG
  /// Targets with absolute flat scratch: AMDGPU::FLAT_SCRATCH, AMDGPU::SP_REG,
  /// AMDGPU::FP_REG Targets without flat scratch: AMDGPU::PRIVATE_RSRC_REG,
  /// AMDGPU::SP_REG, AMDGPU::FP_REG
  bool IsArchitectedFS = STI.flatScratchIsArchitected();
  if (STI.enableFlatScratch() && !IsArchitectedFS) {
    Out->FrameSpillLanes.insert({llvm::AMDGPU::FLAT_SCR, NextLane});
    NextLane += 2;
    Out->InstrumentationFrameLanes.insert({llvm::AMDGPU::FLAT_SCR, NextLane});
    NextLane += 2;
  } else if (!IsArchitectedFS) {
    Out->FrameSpillLanes.insert({llvm::AMDGPU::PRIVATE_RSRC_REG, NextLane});
    NextLane += 4;
    Out->InstrumentationFrameLanes.insert(
        {llvm::AMDGPU::PRIVATE_RSRC_REG, NextLane});
    NextLane += 4;
  }
  Out->FrameSpillLanes.insert({llvm::AMDGPU::SP_REG, NextLane++});
  Out->InstrumentationFrameLanes.insert({llvm::AMDGPU::SP_REG, NextLane++});
  Out->FrameSpillLanes.insert({llvm::AMDGPU::FP_REG, NextLane++});

  /// Next determine the scalar values used via the named MD in the module
  using SVArgUnderlyingType = std::underlying_type_t<ScalarValueArgument>;

  auto GetSingleArgIfPresent = [&]<SVArgUnderlyingType SVArg>() {
    if (constexpr auto CastedSVArg = static_cast<ScalarValueArgument>(SVArg);
        M.getNamedMetadata(ScalarValueArgumentInfo<CastedSVArg>::NamedMD)) {
      Out->ScalarArguments.insert({CastedSVArg, NextLane});
      NextLane += ScalarValueArgumentInfo<CastedSVArg>::NumLanes;
    }
  };

  constexpr auto SVArgSequence =
      std::make_integer_sequence<SVArgUnderlyingType,
                                 SCALAR_VALUE_ARGUMENT_LAST>{};

  [&]<SVArgUnderlyingType... SVArgs>(
      std::integer_sequence<SVArgUnderlyingType, SVArgs...>) {
    (GetSingleArgIfPresent.operator()<SVArgs>(), ...);
  }(SVArgSequence);
  return std::move(Out);
}

std::unique_ptr<StateValueArraySpecs> StateValueArraySpecs::setModuleSVASpec(
    llvm::Module &M, const llvm::GCNSubtarget &STI,
    const llvm::SmallDenseSet<ScalarValueArgument> &RequestedSVArgs) {

  using SVArgUnderlyingType = std::underlying_type_t<ScalarValueArgument>;

  auto InsertSingleArgIfPresent = [&]<SVArgUnderlyingType SVArg>() {
    if (constexpr auto CastedSVArg = static_cast<ScalarValueArgument>(SVArg);
        RequestedSVArgs.contains(CastedSVArg)) {
      (void)M.getOrInsertNamedMetadata(
          ScalarValueArgumentInfo<CastedSVArg>::NamedMD);
    }
  };

  constexpr auto SVArgSequence =
      std::make_integer_sequence<SVArgUnderlyingType,
                                 SCALAR_VALUE_ARGUMENT_LAST>{};

  [&]<SVArgUnderlyingType... SVArgs>(
      std::integer_sequence<SVArgUnderlyingType, SVArgs...>) {
    (InsertSingleArgIfPresent.operator()<SVArgs>(), ...);
  }(SVArgSequence);

  return getSVASpecs(M, STI);
}
} // namespace luthier