//===-- RegValueMetadata.cpp ----------------------------------------------===//
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
#include "luthier/ToolCodeGen/RegValueMetadata.h"

#include <GCNSubtarget.h>
#include <SIRegisterInfo.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/Instruction.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>

namespace luthier {

namespace {

/// Read back a single descriptor MDNode shaped as
/// <tt>!{!"<name>", i32 BaseEnum, i32 Off, i32 N}</tt>.
bool readDescOperand(const llvm::MDNode *N, RegValueDesc &Out) {
  if (!N || N->getNumOperands() != 4)
    return false;
  auto *Base = llvm::mdconst::dyn_extract<llvm::ConstantInt>(N->getOperand(1));
  auto *Off = llvm::mdconst::dyn_extract<llvm::ConstantInt>(N->getOperand(2));
  auto *Halves =
      llvm::mdconst::dyn_extract<llvm::ConstantInt>(N->getOperand(3));
  if (!Base || !Off || !Halves)
    return false;
  Out.BaseReg = llvm::MCRegister(Base->getZExtValue());
  Out.HalfWordOffset = Off->getZExtValue();
  Out.NumHalves = Halves->getZExtValue();
  return true;
}

} // namespace

llvm::MDNode *buildRegValueDescMD(llvm::LLVMContext &Ctx,
                                  const RegValueDesc &D, llvm::StringRef Name) {
  auto *I32 = llvm::Type::getInt32Ty(Ctx);
  llvm::Metadata *Ops[4] = {
      llvm::MDString::get(Ctx, Name),
      llvm::ConstantAsMetadata::get(
          llvm::ConstantInt::get(I32, D.BaseReg.id())),
      llvm::ConstantAsMetadata::get(
          llvm::ConstantInt::get(I32, D.HalfWordOffset)),
      llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(I32, D.NumHalves)),
  };
  return llvm::MDNode::get(Ctx, Ops);
}

void attachRegValue(llvm::Instruction &I, const RegValueDesc &D,
                    llvm::StringRef Name) {
  llvm::LLVMContext &Ctx = I.getContext();
  llvm::SmallVector<llvm::Metadata *, 4> NewOps;

  if (auto *Existing = I.getMetadata(RegValueMDKindName)) {
    for (const llvm::MDOperand &Op : Existing->operands()) {
      if (auto *EntryNode = llvm::dyn_cast<llvm::MDNode>(Op.get())) {
        RegValueDesc Existing;
        if (readDescOperand(EntryNode, Existing) && Existing == D)
          return; // already tagged
      }
      NewOps.emplace_back(Op.get());
    }
  }
  NewOps.emplace_back(buildRegValueDescMD(Ctx, D, Name));
  I.setMetadata(RegValueMDKindName, llvm::MDNode::get(Ctx, NewOps));
}

void mergeRegValues(llvm::Instruction &Dst, const llvm::Instruction &Src) {
  auto *SrcMD = Src.getMetadata(RegValueMDKindName);
  if (!SrcMD)
    return;
  for (const llvm::MDOperand &Op : SrcMD->operands()) {
    auto *Entry = llvm::dyn_cast<llvm::MDNode>(Op.get());
    if (!Entry)
      continue;
    RegValueDesc D;
    if (!readDescOperand(Entry, D))
      continue;
    llvm::StringRef Name;
    if (auto *S = llvm::dyn_cast<llvm::MDString>(Entry->getOperand(0).get()))
      Name = S->getString();
    attachRegValue(Dst, D, Name);
  }
}

void getRegValues(const llvm::Instruction &I,
                  llvm::SmallVectorImpl<RegValueDesc> &Out) {
  auto *MD = I.getMetadata(RegValueMDKindName);
  if (!MD)
    return;
  for (const llvm::MDOperand &Op : MD->operands()) {
    auto *Entry = llvm::dyn_cast<llvm::MDNode>(Op.get());
    if (!Entry)
      continue;
    RegValueDesc D;
    if (readDescOperand(Entry, D))
      Out.emplace_back(D);
  }
}

void addEntryRegMapping(llvm::Function &F, llvm::Value *V,
                        const RegValueDesc &D, llvm::StringRef Name) {
  if (!V)
    return;
  llvm::LLVMContext &Ctx = F.getContext();
  auto *I32 = llvm::Type::getInt32Ty(Ctx);
  llvm::Metadata *EntryOps[5] = {
      llvm::ValueAsMetadata::get(V),
      llvm::MDString::get(Ctx, Name),
      llvm::ConstantAsMetadata::get(
          llvm::ConstantInt::get(I32, D.BaseReg.id())),
      llvm::ConstantAsMetadata::get(
          llvm::ConstantInt::get(I32, D.HalfWordOffset)),
      llvm::ConstantAsMetadata::get(llvm::ConstantInt::get(I32, D.NumHalves)),
  };
  llvm::MDNode *NewEntry = llvm::MDNode::get(Ctx, EntryOps);

  llvm::SmallVector<llvm::Metadata *, 8> NewOps;
  if (auto *Existing = F.getMetadata(EntryRegMapMDKindName)) {
    for (const llvm::MDOperand &Op : Existing->operands())
      NewOps.emplace_back(Op.get());
  }
  NewOps.emplace_back(NewEntry);
  F.setMetadata(EntryRegMapMDKindName, llvm::MDNode::get(Ctx, NewOps));
}

std::string formatRegValueDescName(const RegValueDesc &D,
                                   llvm::StringRef BaseRegName) {
  // GPR-array fast path: VGPR0 / SGPR0 / AGPR0 with DWORD-aligned slices.
  const char *Prefix = nullptr;
  switch (D.BaseReg.id()) {
  case llvm::AMDGPU::VGPR0:
    Prefix = "vgpr";
    break;
  case llvm::AMDGPU::SGPR0:
    Prefix = "sgpr";
    break;
  case llvm::AMDGPU::AGPR0:
    Prefix = "agpr";
    break;
  default:
    break;
  }
  if (Prefix && (D.HalfWordOffset % 2) == 0 && (D.NumHalves % 2) == 0 &&
      D.NumHalves > 0) {
    unsigned Idx = D.HalfWordOffset / 2;
    unsigned NDw = D.NumHalves / 2;
    if (NDw == 1)
      return (llvm::Twine(Prefix) + llvm::Twine(Idx)).str();
    return (llvm::Twine(Prefix) + "[" + llvm::Twine(Idx) + ":" +
            llvm::Twine(Idx + NDw - 1) + "]")
        .str();
  }
  // Otherwise: explicit base + half-word window.
  std::string Lower = BaseRegName.lower();
  if (D.HalfWordOffset == 0)
    return (llvm::Twine(Lower) + ":h" + llvm::Twine(D.NumHalves)).str();
  return (llvm::Twine(Lower) + "+h" + llvm::Twine(D.HalfWordOffset) + ":" +
          llvm::Twine(D.NumHalves))
      .str();
}

} // namespace luthier
