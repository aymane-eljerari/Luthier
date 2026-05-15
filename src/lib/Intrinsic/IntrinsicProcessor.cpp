//===-- IntrinsicProcessor.cpp ----------------------------------*- C++ -*-===//
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
/// \file
/// Minimal out-of-line definitions for the helpers declared in
/// IntrinsicProcessor.h. The previous IntrinsicProcessor.cpp was lost; this
/// stub restores the bits the rest of the codegen pipeline links against.
//===----------------------------------------------------------------------===//
#include "luthier/Intrinsic/IntrinsicProcessor.h"

#include <llvm/IR/Constants.h>
#include <llvm/IR/Metadata.h>

namespace luthier {

namespace {

/// Extract `unsigned`-castable integer values from an MDNode whose operands
/// are `ConstantAsMetadata`-wrapped i32 constants. Silently skips
/// non-conforming operands so a partially-malformed effects node still
/// decodes to whatever subset is well-formed.
template <typename Out, typename CastFn>
void readUnsignedListMDNode(const llvm::MDNode *Node, Out &Sink,
                            CastFn &&Cast) {
  if (!Node)
    return;
  for (const llvm::MDOperand &Op : Node->operands()) {
    auto *CAM = llvm::dyn_cast_or_null<llvm::ConstantAsMetadata>(Op.get());
    if (!CAM)
      continue;
    auto *CI = llvm::dyn_cast<llvm::ConstantInt>(CAM->getValue());
    if (!CI)
      continue;
    Sink.push_back(Cast(CI->getZExtValue()));
  }
}

} // namespace

IntrinsicISAStateEffects
decodeIntrinsicISAStateEffects(const llvm::MDNode *EffNode) {
  IntrinsicISAStateEffects Out;
  // Empty / malformed node → "no callee-visible ISA-state effects".
  if (!EffNode || EffNode->getNumOperands() < 3)
    return Out;
  auto *SVANode = llvm::dyn_cast_or_null<llvm::MDNode>(EffNode->getOperand(0));
  auto *ReadNode = llvm::dyn_cast_or_null<llvm::MDNode>(EffNode->getOperand(1));
  auto *WrittenNode =
      llvm::dyn_cast_or_null<llvm::MDNode>(EffNode->getOperand(2));

  readUnsignedListMDNode(SVANode, Out.ReadSVAs, [](uint64_t V) {
    return static_cast<ScalarValueArgument>(V);
  });
  readUnsignedListMDNode(ReadNode, Out.ReadPhysRegs, [](uint64_t V) {
    return llvm::MCRegister(static_cast<unsigned>(V));
  });
  readUnsignedListMDNode(WrittenNode, Out.WrittenPhysRegs, [](uint64_t V) {
    return llvm::MCRegister(static_cast<unsigned>(V));
  });
  return Out;
}

} // namespace luthier
