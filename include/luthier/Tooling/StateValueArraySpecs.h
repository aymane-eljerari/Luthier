//===-- StateValueArraySpecs.h ----------------------------------*- C++ -*-===//
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
/// \file StateValueArraySpecs.h
/// Defines the \c StateValueArraySpecs class used to set up and read named
/// metadata used in a \c llvm::Module to express the specifications of the
/// state value array used across all functions.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_STATE_VALUE_ARRAY_SPECS_H
#define LUTHIER_TOOLING_STATE_VALUE_ARRAY_SPECS_H
#include "luthier/Intrinsic/IntrinsicProcessor.h"

namespace llvm {
class GCNSubtarget;
}

namespace luthier {

class StateValueArraySpecs {
  llvm::DenseMap<llvm::Register, uint8_t> FrameSpillLanes{};

  llvm::DenseMap<llvm::Register, uint8_t> InstrumentationFrameLanes{};

  llvm::DenseMap<ScalarValueArgument, uint8_t> ScalarArguments{};

  StateValueArraySpecs() = default;

public:
  static std::unique_ptr<StateValueArraySpecs>
  getSVASpecs(const llvm::Module &M, const llvm::GCNSubtarget &STI);

  static std::unique_ptr<StateValueArraySpecs> setModuleSVASpec(
      llvm::Module &M, const llvm::GCNSubtarget &STI,
      const llvm::SmallDenseSet<ScalarValueArgument> &RequestedSVArgs);
};

} // namespace luthier

#endif