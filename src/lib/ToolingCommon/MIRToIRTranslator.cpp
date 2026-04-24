//===-- MIRToIRTranslator.cpp ---------------------------------------------===//
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
/// \file MIRToIRTranslator.cpp
/// Implements a set of APIs used to translate machine functions and
/// individual machine instructions to LLVM IR.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/MIRToIRTranslator.h"
#include "luthier/Common/DenseMapInfo.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/Tooling/MIInlineAsmEmitter.h"
#include "luthier/Tooling/Metadata.h"
#include "luthier/Tooling/TargetMachineInstrMDNode.h"
#include <AMDGPUMachineFunction.h>
#include <GCNSubtarget.h>
#include <SIDefines.h>
#include <SIInstrInfo.h>
#include <SIMachineFunctionInfo.h>
#include <SIModeRegisterDefaults.h>
#include <SIRegisterInfo.h>
#include <Utils/AMDGPUBaseInfo.h>
#include <llvm/ADT/PostOrderIterator.h>
#include <llvm/Analysis/InstSimplifyFolder.h>
#include <llvm/CodeGen/AsmPrinter.h>
#include <llvm/CodeGen/LivePhysRegs.h>
#include <llvm/CodeGen/MachineDominators.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineInstr.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/IntrinsicsAMDGPU.h>
#include <llvm/IR/ValueMap.h>
#include <llvm/MC/TargetRegistry.h>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-mir-to-ir"

namespace {
template <typename Tag, typename Tag::type MemPtr> struct Access {
  friend typename Tag::type get(Tag) { return MemPtr; }
};

/// Friend ADL trick to allow access to the private basic block field of
/// machine basic block
/// Unlike what LLVM assumes (IR comes after MIR), we have to construct the
/// IR basic block after we have the machine basic block
struct TagBB {
  using type = const llvm::BasicBlock *llvm::MachineBasicBlock::*;

  friend type get(TagBB);
};

template struct Access<TagBB, &llvm::MachineBasicBlock::BB>;

} // namespace

namespace luthier {

/// If \p Reg is not a VGPR (i.e. SGPR, SCC, etc.) and \p V is an
/// Instruction, attach \c !amdgpu.uniform metadata to mark it as uniform.
static void annotateUniformIfNeeded(llvm::Value *V,
                                    const llvm::SIRegisterInfo &TRI,
                                    llvm::MCRegister Reg) {
  if (auto *I = llvm::dyn_cast<llvm::Instruction>(V)) {
    if (!TRI.isVGPRPhysReg(Reg))
      I->setMetadata("amdgpu.uniform", llvm::MDNode::get(I->getContext(), {}));
  }
}

static llvm::Value *getOrCreateIntOrPtrTypeForReg(
    llvm::DenseMap<llvm::Type *, llvm::Value *> &ValueEntries,
    llvm::IRBuilderBase &Builder, const llvm::SIRegisterInfo &TRI,
    llvm::MCRegister Reg) {
  assert(!ValueEntries.empty() && "Value entry map is empty");
  llvm::Value *VecIntOrPtrVal{nullptr};
  for (auto &[T, V] : ValueEntries) {
    if (T->isScalableTy() && T->isIntOrPtrTy())
      return V;
    if (T->isIntOrIntVectorTy() || T->isPtrOrPtrVectorTy())
      VecIntOrPtrVal = V;
  }
  /// If we couldn't find a pointer or an int type, do a bitcast on the first
  /// value in the map
  if (!VecIntOrPtrVal) {
    llvm::StringRef RegName = TRI.getName(Reg);
    auto &[T, V] = *ValueEntries.begin();
    llvm::Type *OutTy = Builder.getIntNTy(T->getPrimitiveSizeInBits());
    VecIntOrPtrVal = Builder.CreateBitOrPointerCast(V, OutTy, RegName);
    annotateUniformIfNeeded(VecIntOrPtrVal, TRI, Reg);
    ValueEntries[OutTy] = VecIntOrPtrVal;
  }
  return VecIntOrPtrVal;
}

static llvm::Value *getOrCreateIntTypeForReg(
    llvm::DenseMap<llvm::Type *, llvm::Value *> &ValueEntries,
    llvm::IRBuilderBase &Builder, const llvm::SIRegisterInfo &TRI,
    llvm::MCRegister Reg) {
  assert(!ValueEntries.empty() && "Value entry map is empty");
  llvm::Value *VecIntVal{nullptr};
  for (auto &[T, V] : ValueEntries) {
    if (T->isScalableTy() && T->isIntegerTy())
      return V;
    if (T->isIntOrIntVectorTy())
      VecIntVal = V;
  }
  /// If we couldn't find a pointer or an int type, do a bitcast on the first
  /// value in the map
  if (!VecIntVal) {
    llvm::StringRef RegName = TRI.getName(Reg);
    auto &[T, V] = *ValueEntries.begin();
    llvm::Type *OutTy = Builder.getIntNTy(T->getIntegerBitWidth());
    VecIntVal = Builder.CreateBitOrPointerCast(V, OutTy, RegName);
    annotateUniformIfNeeded(VecIntVal, TRI, Reg);
    ValueEntries[OutTy] = VecIntVal;
  }
  return VecIntVal;
}

static llvm::Value *getorCreateIntOrFloatTypeForReg(
    llvm::DenseMap<llvm::Type *, llvm::Value *> &ValueEntries,
    llvm::IRBuilderBase &Builder, const llvm::SIRegisterInfo &TRI,
    llvm::MCRegister Reg) {
  assert(!ValueEntries.empty() && "Value entry map is empty");
  llvm::Value *IntOrFloatVecVal{nullptr};
  for (auto &[T, V] : ValueEntries) {
    if (T->isIntOrIntVectorTy() || T->isFPOrFPVectorTy())
      return V;
  }
  /// If we couldn't find a pointer or an int type, do a bitcast on the first
  /// value in the map
  if (!IntOrFloatVecVal) {
    llvm::StringRef RegName = TRI.getName(Reg);
    auto &[T, V] = *ValueEntries.begin();
    llvm::Type *OutTy = Builder.getIntNTy(T->getIntegerBitWidth());
    IntOrFloatVecVal = Builder.CreateBitOrPointerCast(V, OutTy, RegName);
    annotateUniformIfNeeded(IntOrFloatVecVal, TRI, Reg);
    ValueEntries[OutTy] = IntOrFloatVecVal;
  }
  return IntOrFloatVecVal;
}

/// Given a non-empty set of values mapped to the same register and their
/// types, manifests a vector type that breaks down the register into
/// scalar integer elements with \p ElemWidth as their width
/// Useful for 'extractelement'/'insertelement' indexing
static llvm::Value *breakdownToVecTyFromAvailableValues(
    llvm::DenseMap<llvm::Type *, llvm::Value *> &ValueEntries,
    unsigned ElemWidth, llvm::IRBuilderBase &Builder,
    const llvm::SIRegisterInfo &TRI, llvm::MCRegister Reg) {
  assert(!ValueEntries.empty() && "Empty value entry map");
  unsigned TotalWidth =
      ValueEntries.begin()->getFirst()->getPrimitiveSizeInBits();
  assert(TotalWidth % ElemWidth == 0);
  unsigned NumElems = TotalWidth / ElemWidth;
  auto *VecTy =
      llvm::FixedVectorType::get(Builder.getIntNTy(ElemWidth), NumElems);
  if (auto ValueEntryIt = ValueEntries.find(VecTy);
      ValueEntryIt != ValueEntries.end()) {
    return ValueEntryIt->second;
  } else {
    llvm::StringRef RegName = TRI.getName(Reg);
    llvm::Value *IntVal =
        getorCreateIntOrFloatTypeForReg(ValueEntries, Builder, TRI, Reg);
    llvm::Value *Out = Builder.CreateBitOrPointerCast(IntVal, VecTy, RegName);

    annotateUniformIfNeeded(Out, TRI, Reg);
    ValueEntries[VecTy] = Out;
    return Out;
  }
}

static llvm::SmallVector<llvm::MCRegister>
getOverlappingRegUnits(const llvm::TargetRegisterInfo &TRI,
                       llvm::MCRegister RegA, llvm::MCRegister RegB) {
  /// This is similar to regsOverlap method in TRI; It's modified to
  /// obtain all common reg units
  auto RangeA = TRI.regunits(RegA);
  llvm::MCRegUnitIterator IA = RangeA.begin(), EA = RangeA.end();
  auto RangeB = TRI.regunits(RegB);
  llvm::MCRegUnitIterator IB = RangeB.begin(), EB = RangeB.end();
  llvm::SmallVector<llvm::MCRegister> OverlappingRegUnits{};
  do {
    if (*IA == *IB) {
      for (llvm::MCRegUnitRootIterator RI(*IA, &TRI); RI.isValid(); ++RI)
        OverlappingRegUnits.push_back(*RI);
    }
  } while (*IA < *IB ? ++IA != EA : ++IB != EB);
  return OverlappingRegUnits;
}

/// Given two registers \p RegA and \p RegB finds the common
/// \c llvm::MCRegister that is common between both registers. Returns the
/// empty \c llvm::MCRegister if no common sub register is found
static llvm::MCRegister
getOverlappingSubReg(const llvm::TargetRegisterInfo &TRI, llvm::MCRegister RegA,
                     llvm::MCRegister RegB) {
  llvm::SmallVector<llvm::MCRegister> OverlappingRegUnits =
      getOverlappingRegUnits(TRI, RegA, RegB);

  switch (OverlappingRegUnits.size()) {
  case 0:
    return {};
  case 1:
    return OverlappingRegUnits[0];
  default: {
    llvm::MCRegister FirstReg = OverlappingRegUnits[0];
    auto OtherOverlappingRegs =
        llvm::ArrayRef<llvm::MCRegister>{OverlappingRegUnits}.drop_front();
    llvm::MCRegister Out{};
    for (auto FirstSupReg = llvm::MCSuperRegIterator(FirstReg, &TRI);
         FirstSupReg.isValid(); ++FirstSupReg) {
      bool DoAllOverlap{true};
      for (llvm::MCRegister OtherRegUnit : OtherOverlappingRegs) {
        DoAllOverlap |= TRI.regsOverlap(*FirstSupReg, OtherRegUnit);
      }

      if (DoAllOverlap &&
          (Out == 0 || TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Out)) >
                           TRI.getRegSizeInBits(
                               *TRI.getMinimalPhysRegClass(*FirstSupReg)))) {
        Out = *FirstSupReg;
      }
    }
    return Out;
  }
  }
}

void MIRToIRTranslator::invalidateOverlaps(MCRegValueMap &Map,
                                           llvm::MCRegister Reg,
                                           llvm::IRBuilderBase &Builder) {

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] invalidateOverlaps: "
                          << TRI.getName(Reg) << "\n");

  struct Preserve {
    llvm::MCRegister SubReg;
    llvm::Value *Val;
  };
  llvm::SmallVector<llvm::MCRegister, 8> ToErase;
  llvm::SmallVector<Preserve, 4> ToPreserve;

  for (auto &[StoredReg, Entry] : Map) {
    if (StoredReg == Reg)
      continue;
    if (!TRI.regsOverlap(StoredReg, Reg))
      continue;

    // Case 1: StoredReg ⊂ Reg — fully covered, just erase.
    if (unsigned SubIdx = TRI.getSubRegIndex(Reg, StoredReg); SubIdx != 0) {
      LLVM_DEBUG(llvm::dbgs() << "  Case 1: " << TRI.getName(StoredReg)
                              << " is sub-register of " << TRI.getName(Reg)
                              << ", erasing\n");
      ToErase.push_back(StoredReg);
      continue;
    }

    // Case 2: Reg ⊂ StoredReg — partial overwrite of a super-register.
    // Bitcast super-reg value to a vector of sub-reg-sized elements and
    // extract the non-overlapping parts.
    if (unsigned SubIdx = TRI.getSubRegIndex(StoredReg, Reg); SubIdx != 0) {
      LLVM_DEBUG(llvm::dbgs()
                 << "  Case 2: " << TRI.getName(Reg) << " is sub-register of "
                 << TRI.getName(StoredReg) << ", extracting preserved parts\n");
      unsigned RegSize = TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Reg));
      for (llvm::MCSubRegIndexIterator SRII(StoredReg, &TRI); SRII.isValid();
           ++SRII) {
        llvm::MCRegister Sub = SRII.getSubReg();
        unsigned SubSubIdx = SRII.getSubRegIndex();
        if (TRI.regsOverlap(Sub, Reg))
          continue; // Being overwritten.

        const llvm::TargetRegisterClass *SubRC =
            TRI.getMinimalPhysRegClass(Sub);
        unsigned SubSize = TRI.getRegSizeInBits(*SubRC);
        if (SubSize != RegSize)
          continue;
        unsigned Offset = TRI.getSubRegIdxOffset(SubSubIdx);
        unsigned ElemIdx = Offset / SubSize;

        llvm::Value *Vec = breakdownToVecTyFromAvailableValues(
            Entry, SubSize, Builder, TRI, Reg);
        llvm::Value *Extracted =
            Builder.CreateExtractElement(Vec, ElemIdx, TRI.getName(Sub));
        ToPreserve.push_back({Sub, Extracted});
      }
      ToErase.push_back(StoredReg);
      continue;
    }

    // Case 3: Partial overlap, neither sub nor super - recursively erase
    // overlapping sub-regs
    LLVM_DEBUG(llvm::dbgs()
               << "  Case 3: partial overlap between " << TRI.getName(StoredReg)
               << " and " << TRI.getName(Reg) << ", recursing\n");
    invalidateOverlaps(Map, getOverlappingSubReg(TRI, StoredReg, Reg), Builder);
  }

  LLVM_DEBUG({
    if (!ToErase.empty()) {
      llvm::dbgs() << "  Erasing registers: ";
      for (llvm::MCRegister R : ToErase)
        llvm::dbgs() << TRI.getName(R) << " ";
      llvm::dbgs() << "\n";
    }
    if (!ToPreserve.empty()) {
      llvm::dbgs() << "  Preserving: ";
      for (const Preserve &P : ToPreserve)
        llvm::dbgs() << TRI.getName(P.SubReg) << " ";
      llvm::dbgs() << "\n";
    }
  });

  for (llvm::MCRegister R : ToErase)
    Map.erase(R);
  for (const Preserve &P : ToPreserve) {
    annotateUniformIfNeeded(P.Val, TRI, P.SubReg);
    Map[P.SubReg][P.Val->getType()] = P.Val;
  }
}

llvm::Value *MIRToIRTranslator::tryExtractFromSuperReg(
    MCRegValueMap &Map, llvm::MCRegister Reg, llvm::Type *RegType,
    llvm::IRBuilderBase &Builder) {
  unsigned RegSize = TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Reg));

  LLVM_DEBUG(llvm::StringRef RegName = TRI.getName(Reg);
             llvm::dbgs() << "[MIRToIRTranslator] attempting to find a super "
                             "register that contains "
                          << RegName << " in the current basic block.\n";);

  for (auto &[StoredReg, Entry] : Map) {
    unsigned StoredSize =
        TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(StoredReg));
    if (StoredSize <= RegSize)
      continue;
    unsigned SubIdx = TRI.getSubRegIndex(StoredReg, Reg);
    if (SubIdx == 0)
      continue;
    unsigned Offset = TRI.getSubRegIdxOffset(SubIdx);
    unsigned ElemIdx = Offset / RegSize;

    auto RegValIt = Entry.find(RegType);
    if (RegValIt == Entry.end()) {
      LLVM_DEBUG(llvm::StringRef SuperRegName = TRI.getName(StoredReg);
                 llvm::dbgs()
                 << "[MIRToIRTranslator] found super register " << SuperRegName
                 << " with sub idx " << SubIdx << "\n";);
      /// No entry was found; Create a bitcast
      llvm::Value *Vec = breakdownToVecTyFromAvailableValues(Entry, RegSize,
                                                             Builder, TRI, Reg);
      return Builder.CreateExtractElement(Vec, ElemIdx, TRI.getName(Reg));
    } else {
      return RegValIt->getSecond();
    }
  }
  return nullptr;
}

llvm::Value *MIRToIRTranslator::tryComposeFromSubRegs(
    MCRegValueMap &Map, llvm::MCRegister Reg, llvm::IRBuilderBase &Builder,
    llvm::Type *RegType) {
  unsigned RegSize = TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Reg));
  llvm::StringRef RegName = TRI.getName(Reg);

  struct SubPart {
    unsigned ElemIdx;
    unsigned Width;
    llvm::DenseMap<llvm::Type *, llvm::Value *> &Vals;
  };
  llvm::SmallVector<SubPart, 8> Parts;
  unsigned CoveredBits = 0;

  for (auto &[StoredReg, Entry] : Map) {
    unsigned StoredSize =
        TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(StoredReg));
    if (StoredSize >= RegSize)
      continue;
    unsigned SubIdx = TRI.getSubRegIndex(Reg, StoredReg);
    if (SubIdx == 0)
      continue;
    unsigned Offset = TRI.getSubRegIdxOffset(SubIdx);
    unsigned ElemIdx = Offset / StoredSize;
    Parts.push_back({ElemIdx, StoredSize, Entry});
    CoveredBits += StoredSize;
  }

  if (CoveredBits < RegSize)
    return nullptr;

  if (!RegType)
    RegType = Builder.getIntNTy(RegSize);

  unsigned ElemWidth = Parts[0].Width;
  for (const SubPart &P : Parts)
    ElemWidth = std::gcd(ElemWidth, P.Width);

  unsigned NumElems = RegSize / ElemWidth;
  auto *VecTy =
      llvm::FixedVectorType::get(Builder.getIntNTy(ElemWidth), NumElems);

  llvm::Value *Vec = llvm::PoisonValue::get(VecTy);
  for (const SubPart &P : Parts) {
    llvm::Value *PartVec = breakdownToVecTyFromAvailableValues(
        P.Vals, ElemWidth, Builder, TRI, Reg);
    unsigned NumSubElems = P.Width / ElemWidth;
    for (unsigned I = 0; I < NumSubElems; ++I) {
      llvm::MCRegister SubReg =
          TRI.getSubReg(Reg, TRI.getSubRegFromChannel(I, NumSubElems));
      llvm::StringRef SubRegName = TRI.getName(SubReg);
      llvm::Value *SubVal =
          Builder.CreateExtractElement(PartVec, I, SubRegName);
      Map[SubReg][SubVal->getType()] = SubVal;
      Vec = Builder.CreateInsertElement(Vec, SubVal, P.ElemIdx + I, RegName);
    }
  }
  Map[Reg][VecTy] = Vec;
  annotateUniformIfNeeded(Vec, TRI, Reg);
  return Builder.CreateBitOrPointerCast(Vec, RegType, RegName);
}

llvm::Value *MIRToIRTranslator::tryComposeFromOverlappingRegs(
    const llvm::MachineBasicBlock &MBB, MCRegValueMap &Map,
    llvm::MCRegister Reg, llvm::IRBuilderBase &Builder, llvm::Type *RegType) {
  unsigned RegSize = TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Reg));
  if (!RegType)
    RegType = Builder.getIntNTy(RegSize);

  for (llvm::MCRegUnit IA : TRI.regunits(Reg)) {
    for (llvm::MCRegUnitRootIterator RI(IA, &TRI); RI.isValid(); ++RI) {
      unsigned RegRootSize =
          TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(*RI));
      (void)materializeReg(MBB, *RI, Builder.getIntNTy(RegRootSize));
    }
  }
  /// Registers should have been materialized by now; Simply ask for it again
  return &materializeReg(MBB, Reg, RegType);
}

llvm::Value &
MIRToIRTranslator::materializeReg(const llvm::MachineBasicBlock &MBB,
                                  llvm::MCRegister Reg, llvm::Type *RegType) {
  BlockRegState &State = VM[MBB];
  MCRegValueMap &Map = State.RegCache;
  unsigned RegSize =
      Reg == llvm::AMDGPU::MODE
          ? 32
          : TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Reg));
  llvm::StringRef RegName = TRI.getName(Reg);

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Materializing register {0} "
                 "in MBB {1}\n",
                 RegName, MBB.getNumber()));

  auto *BB = const_cast<llvm::BasicBlock *>(MBB.getBasicBlock());
  assert(BB && "MBB does not have an IR basic block");

  llvm::Instruction *TermInst = BB->getTerminator();
  llvm::IRBuilder Builder =
      TermInst ? llvm::IRBuilder{TermInst} : llvm::IRBuilder{BB};
  /// If the type of the register is not specified, we are going to assume
  /// integer type
  if (!RegType) {
    RegType = Builder.getIntNTy(RegSize);
  }
  assert(RegType->getPrimitiveSizeInBits() == RegSize &&
         "Requested type's size is not the same as the type of the register");

  // 1. Exact match — the common / fast path.
  auto ExactIt = Map.find(Reg);
  if (ExactIt != Map.end()) {
    auto RegValueMap = ExactIt->second;
    auto ExactRegType = RegValueMap.find(RegType);
    if (ExactRegType != RegValueMap.end()) {
      /// We found the exact reg with the exact type already materialized
      LLVM_DEBUG(llvm::dbgs()
                 << llvm::formatv("[MIRToIRTranslator] Found cached value for "
                                  "register {0} in MBB {1}\n",
                                  RegName, MBB.getNumber()));
      return *ExactRegType->second;
    } else {
      /// We have the value but we don't have the exact type; Create a cast
      /// from the first available integer or pointer value
      assert(!RegValueMap.empty() && "The value map for the register is empty");
      LLVM_DEBUG(llvm::dbgs()
                 << llvm::formatv("[MIRToIRTranslator] Creating type cast for "
                                  "register {0} in MBB {1}\n",
                                  RegName, MBB.getNumber()));
      llvm::Value *CastVal =
          getOrCreateIntOrPtrTypeForReg(RegValueMap, Builder, TRI, Reg);
      CastVal->setName(getRegValueName(Reg));
      llvm::Value *Out = Builder.CreateBitOrPointerCast(CastVal, RegType,
                                                        getRegValueName(Reg));
      annotateUniformIfNeeded(Out, TRI, Reg);
      Map[Reg][RegType] = Out;
      return *Out;
    }
  }

  // 2. Try to extract from a stored super-register.
  if (llvm::Value *V = tryExtractFromSuperReg(Map, Reg, RegType, Builder)) {
    LLVM_DEBUG(llvm::dbgs()
               << llvm::formatv("[MIRToIRTranslator] Extracted register {0} "
                                "from super-register in MBB {1}\n",
                                RegName, MBB.getNumber()));
    annotateUniformIfNeeded(V, TRI, Reg);
    V->setName(getRegValueName(Reg));
    Map[Reg][RegType] = V;
    return *V;
  }

  // 3. Try to compose from stored sub-registers.
  if (llvm::Value *V = tryComposeFromSubRegs(Map, Reg, Builder, RegType)) {
    LLVM_DEBUG(llvm::dbgs()
               << llvm::formatv("[MIRToIRTranslator] Composed register {0} "
                                "from sub-registers in MBB {1}\n",
                                RegName, MBB.getNumber()));
    annotateUniformIfNeeded(V, TRI, Reg);
    V->setName(getRegValueName(Reg));
    Map[Reg][RegType] = V;
    return *V;
  }

  /// TODO: Fix this part
  // 4. Try to see if there are multiple overlapping registers that contain
  // the requested register that are not completely sub or super regs
  // if (llvm::Value *V =
  //         tryComposeFromOverlappingRegs(MBB, Map, Reg, Builder, RegType)) {
  //   LLVM_DEBUG(llvm::dbgs()
  //              << llvm::formatv("[MIRToIRTranslator] Composed register {0} "
  //                               "from overlapping registers in MBB {1}\n",
  //                               RegName, MBB.getNumber()));
  //   annotateUniformIfNeeded(V, TRI, Reg);
  //   Map[Reg][RegType] = V;
  //   return *V;
  // }

  // 5. If a register file covering this reg is already live in the block
  // (typically because a dynamic-index file write invalidated all per-reg
  // entries), extract the reg's lanes directly from the cached file value
  // instead of falling through to a cross-block PHI.
  {
    const llvm::TargetRegisterClass *RC = TRI.getPhysRegBaseClass(Reg);
    bool MaybeInFile =
        (RC && (llvm::SIRegisterInfo::hasSGPRs(RC) ||
                llvm::SIRegisterInfo::isVGPRClass(RC) ||
                llvm::SIRegisterInfo::isAGPRClass(RC))) ||
        Reg == llvm::AMDGPU::VCC || Reg == llvm::AMDGPU::VCC_LO ||
        Reg == llvm::AMDGPU::VCC_HI || Reg == llvm::AMDGPU::XNACK_MASK ||
        Reg == llvm::AMDGPU::XNACK_MASK_LO ||
        Reg == llvm::AMDGPU::XNACK_MASK_HI || Reg == llvm::AMDGPU::FLAT_SCR ||
        Reg == llvm::AMDGPU::FLAT_SCR_LO || Reg == llvm::AMDGPU::FLAT_SCR_HI ||
        llvm::StringRef(TRI.getName(Reg)).starts_with("TTMP");
    if (MaybeInFile) {
      RegFileSlot Slot = getRegFileSlot(Reg);
      if (llvm::Value *FileVal =
              State.FileCache[static_cast<size_t>(Slot.File)]) {
        llvm::Value *V = nullptr;
        if (Slot.BitWidth != 0) {
          /// Sub-lane read (16-bit VGPR_LO16 / VGPR_HI16 etc.): pull the
          /// parent 32-bit lane, shift the requested window into the low
          /// bits, and truncate.
          assert(Slot.NumLanes == 1 && "sub-lane slot spans multiple lanes");
          llvm::Value *Lane =
              Builder.CreateExtractElement(FileVal, Slot.LaneIdx, RegName);
          if (Slot.BitOffset != 0)
            Lane = Builder.CreateLShr(Lane, Slot.BitOffset, RegName);
          V = Builder.CreateTrunc(Lane, Builder.getIntNTy(Slot.BitWidth),
                                  RegName);
        } else if (Slot.NumLanes == 1) {
          V = Builder.CreateExtractElement(FileVal, Slot.LaneIdx, RegName);
        } else {
          auto *SubVecTy =
              llvm::FixedVectorType::get(Builder.getInt32Ty(), Slot.NumLanes);
          V = llvm::PoisonValue::get(SubVecTy);
          for (unsigned L = 0; L < Slot.NumLanes; ++L) {
            llvm::Value *Lane = Builder.CreateExtractElement(
                FileVal, Slot.LaneIdx + L, RegName);
            V = Builder.CreateInsertElement(V, Lane, L, RegName);
          }
        }
        if (V->getType() != RegType)
          V = Builder.CreateBitOrPointerCast(V, RegType, RegName);
        annotateUniformIfNeeded(V, TRI, Reg);
        V->setName(getRegValueName(Reg));
        Map[Reg][RegType] = V;
        return *V;
      }
    }
  }

  // 6. Not available locally — search predecessors and emit PHI / undef.

  if (MBB.pred_empty()) {
    LLVM_DEBUG(llvm::dbgs()
               << llvm::formatv("[MIRToIRTranslator] No predecessors for "
                                "MBB {0}, returning undef for register {1}\n",
                                MBB.getNumber(), RegName));
    llvm::Value *InitVal =
        Builder.CreateFreeze(llvm::PoisonValue::get(RegType));
    InitVal->setName(getRegValueName(Reg));
    Map[Reg][RegType] = InitVal;
    return *InitVal;
  }

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Creating PHI for "
                 "register {0} in MBB {1} with {2} predecessors\n",
                 RegName, MBB.getNumber(), MBB.pred_size()));

  if (!BB->empty())
    Builder.SetInsertPoint(&BB->front());
  llvm::PHINode *Phi =
      Builder.CreatePHI(RegType, MBB.pred_size(), getRegValueName(Reg));

  ToBeFixedPhis.emplace_back(&MBB, Reg, Phi);

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Emitted phi value " << *Phi
                          << " for register " << RegName << " in basic block "
                          << MBB.getNumber() << ".\n";);
  annotateUniformIfNeeded(Phi, TRI, Reg);
  Map[Reg][RegType] = Phi;
  return *Phi;
}

/// Decode the "denormal-fp-math[-f32]" attribute value (e.g.
/// "preserve-sign," or ",preserve-sign") into the AMDGPU \c FP_DENORM_*
/// encoding used by the MODE register.
static uint32_t decodeDenormAttr(llvm::StringRef AttrVal) {
  auto [In, Out] = AttrVal.split(',');
  In = In.trim();
  Out = Out.trim();
  bool InFlush = (In == "preserve-sign");
  bool OutFlush = (Out == "preserve-sign");
  if (InFlush && OutFlush)
    return llvm::AMDGPU::FP_DENORM_FLUSH_IN_FLUSH_OUT;
  if (OutFlush)
    return llvm::AMDGPU::FP_DENORM_FLUSH_OUT;
  if (InFlush)
    return llvm::AMDGPU::FP_DENORM_FLUSH_IN;
  return llvm::AMDGPU::FP_DENORM_FLUSH_NONE;
}

/// Build the i32 MODE register value that mirrors the kernel-entry state
/// implied by the function's FP attributes (lifted from the kernel
/// descriptor by \c CodeDiscoveryPass). Fields whose attribute is missing
/// fall back to \c SIModeRegisterDefaults so the subtarget-specific
/// defaults stay authoritative. Target-divergent bits (IEEE, DX10_CLAMP)
/// are guarded with subtarget predicates.
static llvm::Value *
buildInitialModeValue(const llvm::Function &F,
                                          const llvm::GCNSubtarget &ST,
                                          llvm::IRBuilderBase &Builder) {
  llvm::SIModeRegisterDefaults Defaults(F, ST);

  uint32_t Mode = 0;

  /// FP_ROUND (bits 0..3): the backend emits round-to-nearest at kernel
  /// entry on every supported target and there is no function attribute
  /// that overrides this, so both halves stay zero.

  /// FP_DENORM_F32 (bits 4..5).
  uint32_t Denorm32 =
      F.hasFnAttribute("denormal-fp-math-f32")
          ? decodeDenormAttr(
                F.getFnAttribute("denormal-fp-math-f32").getValueAsString())
          : Defaults.fpDenormModeSPValue();
  Mode |= (Denorm32 & 0x3u) << 4;

  /// FP_DENORM_F64/F16 (bits 6..7).
  uint32_t Denorm1664 =
      F.hasFnAttribute("denormal-fp-math")
          ? decodeDenormAttr(
                F.getFnAttribute("denormal-fp-math").getValueAsString())
          : Defaults.fpDenormModeDPValue();
  Mode |= (Denorm1664 & 0x3u) << 6;

  /// DX10_CLAMP (bit 8) — pre-GFX12 only. On GFX12 the bit moved out of
  /// WAVE_MODE; we leave it cleared here.
  if (!llvm::AMDGPU::isGFX12Plus(ST)) {
    bool DX10Clamp =
        F.hasFnAttribute("amdgpu-dx10-clamp")
            ? F.getFnAttribute("amdgpu-dx10-clamp").getValueAsString() == "true"
            : Defaults.DX10Clamp;
    if (DX10Clamp)
      Mode |= llvm::AMDGPU::DX10_CLAMP_MASK;
  }

  /// IEEE (bit 9) — pre-GFX12 only. Moved out of WAVE_MODE on GFX12.
  if (!llvm::AMDGPU::isGFX12Plus(ST)) {
    bool IEEE =
        F.hasFnAttribute("amdgpu-ieee")
            ? F.getFnAttribute("amdgpu-ieee").getValueAsString() == "true"
            : Defaults.IEEE;
    if (IEEE)
      Mode |= (1u << 9);
  }

  /// GPR_IDX_EN, VSKIP, CSP — GFX9-and-earlier only. These MODE bits were
  /// removed / repurposed on GFX10+. On the targets that do have them,
  /// they are guaranteed zero on kernel entry; the masked AND-NOT keeps
  /// the invariant tied to the canonical SIDefines names.
  if (!llvm::AMDGPU::isGFX10Plus(ST)) {
    Mode &= ~llvm::AMDGPU::GPR_IDX_EN_MASK;
    Mode &= ~llvm::AMDGPU::VSKIP_MASK;
    Mode &= ~llvm::AMDGPU::CSP_MASK;
  }

  return Builder.getInt32(Mode);
}

/// Initialize the register tracker with the pre-loaded SGPR/VGPR values
/// for an AMDGPU kernel entry function.
///
/// At kernel launch the hardware pre-loads certain values into SGPRs and
/// VGPRs according to the kernel descriptor.  Where possible we emit the
/// corresponding AMDGCN intrinsic so that the resulting IR is idiomatic;
/// for the few pre-loaded values that lack an intrinsic we fall back to a
/// frozen poison placeholder.
void MIRToIRTranslator::initKernelEntryRegs(llvm::IRBuilderBase &Builder) {
  const auto &Info = *MF.getInfo<llvm::SIMachineFunctionInfo>();

  using PV = llvm::AMDGPUFunctionArgInfo::PreloadedValue;

  auto seedRegValue = [&](const llvm::MachineBasicBlock &MBB,
                          llvm::MCRegister Reg, llvm::Value *Val) {
    VM[MBB].RegCache[Reg][Val->getType()] = Val;
  };

  /// Seed a single preloaded register with \p Val.
  /// Annotates non-VGPR values with \c !amdgpu.uniform.
  auto seed = [&](PV Which, llvm::Value *Val) {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return;
    annotateUniformIfNeeded(Val, TRI, Reg);
    seedRegValue(MF.front(), Reg, Val);
  };

  /// Create a frozen-poison placeholder for values with no intrinsic.
  auto makePlaceholder = [&](PV Which) -> llvm::Value * {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return nullptr;
    const llvm::TargetRegisterClass *RC = TRI.getMinimalPhysRegClass(Reg);
    unsigned BitWidth = TRI.getRegSizeInBits(*RC);
    return Builder.CreateFreeze(
        llvm::PoisonValue::get(Builder.getIntNTy(BitWidth)), TRI.getName(Reg));
  };

  /// Emit a void-returning intrinsic whose result is a pointer, then
  /// ptrtoint it to match the register's integer type.
  auto ptrIntrinsic = [&](PV Which, llvm::Intrinsic::ID IID) {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return;
    const llvm::TargetRegisterClass *RC = TRI.getMinimalPhysRegClass(Reg);
    llvm::Value *Ptr = Builder.CreateIntrinsic(Builder.getPtrTy(4), IID, {},
                                               nullptr, TRI.getName(Reg));

    seed(Which, Ptr);
  };

  /// Emit a scalar-returning intrinsic (i32 or i64).
  auto scalarIntrinsic = [&](PV Which, llvm::Intrinsic::ID IID,
                             llvm::Type *RetTy) {
    const llvm::ArgDescriptor *ArgDesc =
        std::get<0>(Info.getArgInfo().getPreloadedValue(Which));
    if (!ArgDesc)
      return;
    llvm::MCRegister Reg = ArgDesc->getRegister();
    if (!Reg)
      return;
    unsigned Mask = ArgDesc->getMask();
    llvm::Value *Val =
        Builder.CreateIntrinsic(RetTy, IID, {}, nullptr, TRI.getName(Reg));
    if (Mask != ~0u)
      Val = Builder.CreateAnd(Val, Builder.getInt32(Mask), TRI.getName(Reg));
    seed(Which, Val);
  };

  // ---- User SGPRs (allocated in HSA ABI order) ----

  // PrivateSegmentBuffer: no intrinsic — use placeholder.
  if (llvm::Value *V = makePlaceholder(PV::PRIVATE_SEGMENT_BUFFER))
    seed(PV::PRIVATE_SEGMENT_BUFFER, V);

  // DispatchPtr → llvm.amdgcn.dispatch.ptr() : ptr addrspace(4)
  ptrIntrinsic(PV::DISPATCH_PTR, llvm::Intrinsic::amdgcn_dispatch_ptr);

  // QueuePtr → llvm.amdgcn.queue.ptr() : ptr addrspace(4)
  ptrIntrinsic(PV::QUEUE_PTR, llvm::Intrinsic::amdgcn_queue_ptr);

  // KernargSegmentPtr → llvm.amdgcn.kernarg.segment.ptr() : ptr addrspace(4)
  ptrIntrinsic(PV::KERNARG_SEGMENT_PTR,
               llvm::Intrinsic::amdgcn_kernarg_segment_ptr);

  // DispatchID → llvm.amdgcn.dispatch.id() : i64
  scalarIntrinsic(PV::DISPATCH_ID, llvm::Intrinsic::amdgcn_dispatch_id,
                  Builder.getInt64Ty());

  // FlatScratchInit: no intrinsic — use placeholder.
  if (llvm::Value *V = makePlaceholder(PV::FLAT_SCRATCH_INIT))
    seed(PV::FLAT_SCRATCH_INIT, V);

  // PrivateSegmentSize: no intrinsic — use placeholder.
  if (llvm::Value *V = makePlaceholder(PV::PRIVATE_SEGMENT_SIZE))
    seed(PV::PRIVATE_SEGMENT_SIZE, V);

  // ---- System SGPRs ----

  // WorkgroupID X/Y/Z → llvm.amdgcn.workgroup.id.{x,y,z}() : i32
  scalarIntrinsic(PV::WORKGROUP_ID_X, llvm::Intrinsic::amdgcn_workgroup_id_x,
                  Builder.getInt32Ty());
  scalarIntrinsic(PV::WORKGROUP_ID_Y, llvm::Intrinsic::amdgcn_workgroup_id_y,
                  Builder.getInt32Ty());
  scalarIntrinsic(PV::WORKGROUP_ID_Z, llvm::Intrinsic::amdgcn_workgroup_id_z,
                  Builder.getInt32Ty());

  // PrivateSegmentWaveByteOffset: no intrinsic — use placeholder.
  if (llvm::Value *V = makePlaceholder(PV::PRIVATE_SEGMENT_WAVE_BYTE_OFFSET))
    seed(PV::PRIVATE_SEGMENT_WAVE_BYTE_OFFSET, V);

  // ---- VGPRs (work-item IDs) ----

  // WorkitemID X/Y/Z → llvm.amdgcn.workitem.id.{x,y,z}() : i32
  scalarIntrinsic(PV::WORKITEM_ID_X, llvm::Intrinsic::amdgcn_workitem_id_x,
                  Builder.getInt32Ty());
  scalarIntrinsic(PV::WORKITEM_ID_Y, llvm::Intrinsic::amdgcn_workitem_id_y,
                  Builder.getInt32Ty());
  scalarIntrinsic(PV::WORKITEM_ID_Z, llvm::Intrinsic::amdgcn_workitem_id_z,
                  Builder.getInt32Ty());

  // ---- Writable specials ----

  const auto &ST = MF.getSubtarget<llvm::GCNSubtarget>();

  /// EXEC is all-ones on kernel entry (every lane active). Width matches
  /// the wavefront size — use ~0ULL so wave64 sets all 64 bits, not just
  /// the low 32.
  llvm::MCRegister Exec = TRI.getExec();
  unsigned ExecWidth = TRI.getRegSizeInBits(Exec, MF.getRegInfo());
  llvm::Value *ExecInit = Builder.getIntN(ExecWidth, ~0ULL);
  annotateUniformIfNeeded(ExecInit, TRI, Exec);
  seedRegValue(MF.front(), Exec, ExecInit);

  /// SCC is zero on kernel entry.
  seedRegValue(MF.front(), llvm::AMDGPU::SCC, Builder.getInt1(false));

  /// MODE: constant assembled from the kernel-descriptor-derived attrs.
  llvm::Value *ModeInit = buildInitialModeValue(MF.getFunction(), ST, Builder);
  annotateUniformIfNeeded(ModeInit, TRI, llvm::AMDGPU::MODE);
  seedRegValue(MF.front(), llvm::AMDGPU::MODE, ModeInit);

  /// VCC is zero on kernel entry. \c TRI.getVCC() returns VCC_LO on
  /// wave32 and the full VCC pair on wave64.
  if (llvm::MCRegister VccReg = TRI.getVCC()) {
    unsigned VccWidth = TRI.getRegSizeInBits(VccReg, MF.getRegInfo());
    llvm::Value *VccInit = Builder.getIntN(VccWidth, 0);
    annotateUniformIfNeeded(VccInit, TRI, VccReg);
    seedRegValue(MF.front(), VccReg, VccInit);
  }
}

MIRToIRTranslator::MIRToIRTranslator(llvm::MachineFunction &MF,
                                     llvm::Error &Err)
    : MF(MF), TRI(*MF.getSubtarget<llvm::GCNSubtarget>().getRegisterInfo()),
      TII(*MF.getSubtarget<llvm::GCNSubtarget>().getInstrInfo()) {
  llvm::ErrorAsOutParameter EAO(Err);
  for (const llvm::MachineBasicBlock &MBB : MF)
    VM.insert({std::ref(MBB), BlockRegState{}});

  buildRegFileLayout();

  Err =
      MIInlineAsmEmitter::get(const_cast<llvm::TargetMachine &>(MF.getTarget()))
          .moveInto(InlineAsmEmitter);
  if (Err) {
    return;
  }
}

void MIRToIRTranslator::buildRegFileLayout() {
  const llvm::Function &F = MF.getFunction();
  const auto &ST = MF.getSubtarget<llvm::GCNSubtarget>();
  llvm::LLVMContext &Ctx = F.getContext();

  unsigned NumSGPRs = F.getFnAttributeAsParsedInteger("amdgpu-num-sgpr", 0);
  unsigned NumVGPRs = F.getFnAttributeAsParsedInteger("amdgpu-num-vgpr", 0);

  /// The kernel descriptor's granulated counts must be non-zero and a
  /// multiple of the subtarget's allocation granule — otherwise the file
  /// sizing won't line up with the hardware allocation units.
  assert(NumSGPRs != 0 && NumSGPRs % ST.getSGPREncodingGranule() == 0 &&
         "amdgpu-num-sgpr must be a non-zero multiple of the SGPR granule");
  assert(NumVGPRs != 0 && NumVGPRs % ST.getVGPREncodingGranule() == 0 &&
         "amdgpu-num-vgpr must be a non-zero multiple of the VGPR granule");

  FileWidths[static_cast<size_t>(RegFileID::SGPR)] = NumSGPRs;
  FileWidths[static_cast<size_t>(RegFileID::VGPR)] = NumVGPRs;
  FileWidths[static_cast<size_t>(RegFileID::AGPR)] =
      ST.hasMAIInsts() ? NumVGPRs : 0u;
  /// TTMP0..TTMP15 on every GCN/RDNA target we support — 16 32-bit lanes.
  FileWidths[static_cast<size_t>(RegFileID::TTMP)] = 16u;

  auto *I32 = llvm::Type::getInt32Ty(Ctx);
  for (size_t I = 0; I < static_cast<size_t>(RegFileID::NumFiles); ++I) {
    if (FileWidths[I])
      FileTypes[I] = llvm::FixedVectorType::get(I32, FileWidths[I]);
  }

  /// Reserve two SGPR slots at the top of the file for each SGPR-aliased
  /// special, in the same order the AMDGPU backend allocates them: VCC,
  /// then XNACK_MASK, then FLAT_SCR. VCC always reserves two slots
  /// (VCC_HI is allocated even on wave32 where the shader only uses
  /// VCC_LO). We store only the LO-half SGPR MCRegister; HI-half is
  /// \c LO + 1 because the SGPR enum is contiguous.
  /// The kernel is guaranteed to carry at least enough SGPRs for the
  /// hardware to reserve two for VCC (the SGPR granule on every
  /// supported target is >= 8), so VCC always fits.
  assert(NumSGPRs >= 2 && "kernel must have at least two SGPRs for VCC");
  unsigned NextSlot = NumSGPRs;
  auto reserveLoPair = [&]() -> llvm::MCRegister {
    if (NextSlot < 2)
      return llvm::MCRegister{};
    NextSlot -= 2;
    return llvm::MCRegister(llvm::AMDGPU::SGPR0 + NextSlot);
  };
  NextSlot -= 2;
  VccLoSgpr = llvm::MCRegister(llvm::AMDGPU::SGPR0 + NextSlot);
  if (ST.getTargetID().isXnackSupported())
    XnackMaskLoSgpr = reserveLoPair();
  if (ST.hasFlatScratchInsts() && !llvm::AMDGPU::isGFX10Plus(ST))
    FlatScrLoSgpr = reserveLoPair();
}

MIRToIRTranslator::RegFileID
MIRToIRTranslator::getRegFileForReg(llvm::MCRegister Reg) const {
  return getRegFileSlot(Reg).File;
}

MIRToIRTranslator::RegFileSlot
MIRToIRTranslator::getRegFileSlot(llvm::MCRegister Reg) const {
  /// SGPR-aliased specials first. For each special, the LO-half SGPR
  /// MCRegister was recorded in \c buildRegFileLayout; the HI-half is at
  /// \c LO + 1.
  auto checkSpecial =
      [&](llvm::MCRegister Full, llvm::MCRegister Lo, llvm::MCRegister Hi,
          llvm::MCRegister LoSgpr) -> std::optional<RegFileSlot> {
    if (!LoSgpr)
      return std::nullopt;
    unsigned Base = TRI.getHWRegIndex(LoSgpr);
    if (Reg == Full)
      return RegFileSlot{RegFileID::SGPR, static_cast<uint16_t>(Base), 2};
    if (Reg == Lo)
      return RegFileSlot{RegFileID::SGPR, static_cast<uint16_t>(Base), 1};
    if (Reg == Hi)
      return RegFileSlot{RegFileID::SGPR, static_cast<uint16_t>(Base + 1), 1};
    return std::nullopt;
  };
  if (auto S = checkSpecial(llvm::AMDGPU::VCC, llvm::AMDGPU::VCC_LO,
                            llvm::AMDGPU::VCC_HI, VccLoSgpr))
    return *S;
  if (auto S =
          checkSpecial(llvm::AMDGPU::XNACK_MASK, llvm::AMDGPU::XNACK_MASK_LO,
                       llvm::AMDGPU::XNACK_MASK_HI, XnackMaskLoSgpr))
    return *S;
  if (auto S = checkSpecial(llvm::AMDGPU::FLAT_SCR, llvm::AMDGPU::FLAT_SCR_LO,
                            llvm::AMDGPU::FLAT_SCR_HI, FlatScrLoSgpr))
    return *S;

  /// 16-bit sub-registers (e.g. VGPR0_LO16 / VGPR0_HI16 on GFX11+, and
  /// TTMP0_LO16..TTMP15_LO16) share storage with a 32-bit super-register.
  /// Locate that super-register, resolve its lane index recursively, and
  /// attach the sub-lane window (low or high 16 bits) to the returned
  /// slot. This must run before the TTMP-name classification below,
  /// because TTMP*_LO16 also names-match "TTMP" but lives in a 16-bit
  /// class.
  const llvm::TargetRegisterClass *RC = TRI.getPhysRegBaseClass(Reg);
  unsigned SizeBits = TRI.getRegSizeInBits(*RC);
  if (SizeBits == 16) {
    for (llvm::MCSuperRegIterator Super(Reg, &TRI, /*IncludeSelf=*/false);
         Super.isValid(); ++Super) {
      const llvm::TargetRegisterClass *SuperRC =
          TRI.getPhysRegBaseClass(*Super);
      if (!SuperRC || TRI.getRegSizeInBits(*SuperRC) != 32)
        continue;
      unsigned SubIdx = TRI.getSubRegIndex(*Super, Reg);
      if (SubIdx != llvm::AMDGPU::lo16 && SubIdx != llvm::AMDGPU::hi16)
        continue;
      RegFileSlot Parent = getRegFileSlot(*Super);
      assert(Parent.NumLanes == 1 && Parent.BitWidth == 0 &&
             "16-bit sub-register's parent must be a single full-lane reg");
      return RegFileSlot{
          Parent.File, Parent.LaneIdx, 1,
          static_cast<uint8_t>(SubIdx == llvm::AMDGPU::hi16 ? 16 : 0), 16};
    }
    llvm_unreachable("16-bit register without a 32-bit phys super-register");
  }

  assert(SizeBits != 0 && SizeBits % 32 == 0 &&
         "file-backed register must have a 32-bit-multiple size");
  unsigned NumLanes = SizeBits / 32;

  /// TTMPs are classified by name (their register class is SGPR-like at
  /// the hardware level, but LLVM keeps them in separate TTMP classes).
  /// The TTMP MCRegisters are pseudos whose direct HW encoding is 0 — we
  /// must first lower to the target-physical MCRegister via
  /// \c AMDGPU::getMCReg so that \c TRI.getHWRegIndex returns the actual
  /// TTMP bank index (0..15).
  if (llvm::StringRef(TRI.getName(Reg)).starts_with("TTMP")) {
    llvm::MCRegister PhysReg = llvm::AMDGPU::getMCReg(Reg, ST);
    unsigned Idx = TRI.getHWRegIndex(PhysReg);
    return RegFileSlot{RegFileID::TTMP, static_cast<uint16_t>(Idx),
                       static_cast<uint16_t>(NumLanes)};
  }

  RegFileID File;
  if (llvm::SIRegisterInfo::hasSGPRs(RC) &&
      !llvm::SIRegisterInfo::hasVGPRs(RC) &&
      !llvm::SIRegisterInfo::hasAGPRs(RC))
    File = RegFileID::SGPR;
  else if (llvm::SIRegisterInfo::isVGPRClass(RC))
    File = RegFileID::VGPR;
  else if (llvm::SIRegisterInfo::isAGPRClass(RC))
    File = RegFileID::AGPR;
  else
    llvm_unreachable("register does not belong to a modeled register file");

  unsigned Idx = TRI.getHWRegIndex(Reg);
  return RegFileSlot{File, static_cast<uint16_t>(Idx),
                     static_cast<uint16_t>(NumLanes)};
}

static llvm::StringRef getFileDebugName(MIRToIRTranslator::RegFileID File) {
  switch (File) {
  case MIRToIRTranslator::RegFileID::SGPR:
    return "sgpr_file";
  case MIRToIRTranslator::RegFileID::VGPR:
    return "vgpr_file";
  case MIRToIRTranslator::RegFileID::AGPR:
    return "agpr_file";
  case MIRToIRTranslator::RegFileID::TTMP:
    return "ttmp_file";
  default:
    break;
  }
  return "reg_file";
}

llvm::Value *
MIRToIRTranslator::getRegisterFileValue(const llvm::MachineBasicBlock &MBB,
                                        RegFileID File,
                                        llvm::IRBuilderBase &Builder) {
  size_t Idx = static_cast<size_t>(File);
  BlockRegState &State = VM[MBB];
  if (State.FileCache[Idx])
    return State.FileCache[Idx];

  llvm::FixedVectorType *FT = FileTypes[Idx];
  assert(FT && "register file is not modeled for the current target");

  auto *BB = const_cast<llvm::BasicBlock *>(MBB.getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::StringRef Name = getFileDebugName(File);

  if (!MBB.pred_empty()) {
    /// Defer to the PHI-fixup pass: emit an empty \c <N x i32> PHI at the
    /// top of the block and record it for later stitching against the
    /// predecessors' file values.
    llvm::IRBuilder PhiBuilder =
        BB->empty() ? llvm::IRBuilder{BB} : llvm::IRBuilder{&BB->front()};
    llvm::PHINode *Phi = PhiBuilder.CreatePHI(FT, MBB.pred_size(), Name);
    ToBeFixedFilePhis.push_back({&MBB, File, Phi});
    State.FileCache[Idx] = Phi;
    return Phi;
  }

  /// Predecessor-less block (typically the kernel entry): build the file
  /// from a frozen-poison base and \c insertelement every currently
  /// cached register that belongs to this file.
  llvm::Value *FileVal = Builder.CreateFreeze(llvm::PoisonValue::get(FT), Name);
  for (auto &[Reg, ValMap] : State.RegCache) {
    if (ValMap.empty())
      continue;
    if (getRegFileForReg(Reg) != File)
      continue;
    RegFileSlot Slot = getRegFileSlot(Reg);
    /// Skip sub-lane registers (e.g. VGPR_LO16 / VGPR_HI16) in the
    /// build-from-cache path. They would require a read-modify-write
    /// against the file's lane value, but the parent 32-bit lane is
    /// currently frozen poison — writing a 16-bit value into one half
    /// of it would destroy the other half. If the parent 32-bit reg is
    /// also cached, it is processed here and carries the right value;
    /// otherwise the sub-lane value will be recovered via the regular
    /// super/sub-reg composition on the next read of either half.
    if (Slot.BitWidth != 0)
      continue;
    /// Prefer an already-cached i32 / <NumLanes x i32> view; fall back to
    /// bitcasting the first cached value of the register.
    llvm::Value *V = nullptr;
    llvm::Type *PreferredTy =
        Slot.NumLanes == 1
            ? static_cast<llvm::Type *>(Builder.getInt32Ty())
            : static_cast<llvm::Type *>(llvm::FixedVectorType::get(
                  Builder.getInt32Ty(), Slot.NumLanes));
    if (auto It = ValMap.find(PreferredTy); It != ValMap.end()) {
      V = It->second;
    } else {
      auto First = ValMap.begin();
      V = Builder.CreateBitOrPointerCast(First->second, PreferredTy,
                                         TRI.getName(Reg));
    }
    if (Slot.NumLanes == 1) {
      FileVal = Builder.CreateInsertElement(FileVal, V, Slot.LaneIdx, Name);
    } else {
      for (unsigned L = 0; L < Slot.NumLanes; ++L) {
        llvm::Value *Lane = Builder.CreateExtractElement(V, L);
        FileVal =
            Builder.CreateInsertElement(FileVal, Lane, Slot.LaneIdx + L, Name);
      }
    }
  }
  State.FileCache[Idx] = FileVal;
  return FileVal;
}

llvm::Value *
MIRToIRTranslator::getRegisterFileValue(const llvm::MachineInstr &MI,
                                        llvm::MCRegister Reg) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::Instruction *TermInst = BB->getTerminator();
  llvm::IRBuilder Builder =
      TermInst ? llvm::IRBuilder{TermInst} : llvm::IRBuilder{BB};
  return getRegisterFileValue(*MBB, getRegFileForReg(Reg), Builder);
}

void MIRToIRTranslator::wipeFileRegsFromCache(BlockRegState &State,
                                              RegFileID File) {
  llvm::SmallVector<llvm::MCRegister, 8> ToErase;
  for (auto &[Reg, ValMap] : State.RegCache) {
    /// \c getRegFileForReg asserts on non-file-backed regs; filter those
    /// out first by checking the base class / name without tripping the
    /// assertion.
    const llvm::TargetRegisterClass *RC = TRI.getPhysRegBaseClass(Reg);
    bool MightBeInFile =
        (RC && (llvm::SIRegisterInfo::hasSGPRs(RC) ||
                llvm::SIRegisterInfo::isVGPRClass(RC) ||
                llvm::SIRegisterInfo::isAGPRClass(RC))) ||
        Reg == llvm::AMDGPU::VCC || Reg == llvm::AMDGPU::VCC_LO ||
        Reg == llvm::AMDGPU::VCC_HI || Reg == llvm::AMDGPU::XNACK_MASK ||
        Reg == llvm::AMDGPU::XNACK_MASK_LO ||
        Reg == llvm::AMDGPU::XNACK_MASK_HI || Reg == llvm::AMDGPU::FLAT_SCR ||
        Reg == llvm::AMDGPU::FLAT_SCR_LO || Reg == llvm::AMDGPU::FLAT_SCR_HI ||
        llvm::StringRef(TRI.getName(Reg)).starts_with("TTMP");
    if (!MightBeInFile)
      continue;
    if (getRegFileForReg(Reg) == File)
      ToErase.push_back(Reg);
  }
  for (llvm::MCRegister R : ToErase)
    State.RegCache.erase(R);
}

void MIRToIRTranslator::writeRegisterFile(const llvm::MachineInstr &MI,
                                          llvm::MCRegister Reg,
                                          llvm::Value *Index,
                                          llvm::Value *Val) {
  RegFileID File = getRegFileForReg(Reg);

  /// TTMP writes are silently ignored — unprivileged shader code is not
  /// allowed to modify them and we don't yet model the SPI-initialized
  /// view the TTMP file will eventually expose on reads.
  if (File == RegFileID::TTMP)
    return;

  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");

  /// `writeRegisterFile` is only meant to be called with a 32-bit-aligned
  /// \c Reg (the file's element-width identity). Sub-lane regs like
  /// VGPR0_LO16 / VGPR0_HI16 don't compose with the lane-indexed file
  /// write semantics and are expected to go through
  /// \c setRegOperandValue instead.
  {
    RegFileSlot SlotForReg = getRegFileSlot(Reg);
    assert(SlotForReg.BitWidth == 0 &&
           "writeRegisterFile does not support 16-bit sub-lane registers");
    (void)SlotForReg;
  }

  /// Constant-index writes degrade to a normal register write on the
  /// addressed sub-register.
  if (auto *CI = llvm::dyn_cast<llvm::ConstantInt>(Index)) {
    unsigned BaseLane = TRI.getHWRegIndex(Reg);
    unsigned TargetLane = BaseLane + CI->getZExtValue();
    llvm::MCRegister Base;
    switch (File) {
    case RegFileID::SGPR:
      Base = llvm::AMDGPU::SGPR0;
      break;
    case RegFileID::VGPR:
      Base = llvm::AMDGPU::VGPR0;
      break;
    case RegFileID::AGPR:
      Base = llvm::AMDGPU::AGPR0;
      break;
    default:
      llvm_unreachable("unexpected file for constant-index file write");
    }
    setRegOperandValue(MI, llvm::MCRegister(Base + TargetLane), Val);
    return;
  }

  /// Dynamic index: emit the full-file \c insertelement, make the file
  /// the sole source of truth, and invalidate every per-register cache
  /// entry that belongs to this file.
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::Instruction *TermInst = BB->getTerminator();
  llvm::IRBuilder Builder =
      TermInst ? llvm::IRBuilder{TermInst} : llvm::IRBuilder{BB};

  llvm::Value *OldFile = getRegisterFileValue(*MBB, File, Builder);
  llvm::Type *LaneTy = Builder.getInt32Ty();
  llvm::Value *V = Val;
  if (V->getType() != LaneTy)
    V = Builder.CreateBitOrPointerCast(V, LaneTy);
  llvm::Value *NewFile =
      Builder.CreateInsertElement(OldFile, V, Index, getFileDebugName(File));

  BlockRegState &State = VM[*MBB];
  State.FileCache[static_cast<size_t>(File)] = NewFile;
  wipeFileRegsFromCache(State, File);
}

llvm::Value &MIRToIRTranslator::getOperandAsValue(const llvm::MachineInstr &MI,
                                                  llvm::AMDGPU::OpName OpName,
                                                  llvm::Type *RegType) {
  return getOperandAsValue(*TII.getNamedOperand(MI, OpName), RegType);
}

llvm::Value &
MIRToIRTranslator::getRegisterOperand(const llvm::MachineBasicBlock &MBB,
                                      llvm::MCRegister Reg,
                                      llvm::Type *RegType) {
  return materializeReg(MBB, Reg, RegType);
}

llvm::Value &MIRToIRTranslator::getRegisterOperand(const llvm::MachineInstr &MI,
                                                   llvm::MCRegister Reg,
                                                   llvm::Type *RegType) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI does not have a machine basic block");
  return getRegisterOperand(*MBB, Reg, RegType);
}

llvm::Value &
MIRToIRTranslator::getOperandAsValue(const llvm::MachineOperand &Op,
                                     llvm::Type *RegType) {
  switch (Op.getType()) {
  case llvm::MachineOperand::MO_Register: {
    const llvm::MachineInstr *MI = Op.getParent();
    assert(MI && "Operand does not have a machine instruction");
    return getRegisterOperand(*MI, Op.getReg(), RegType);
  }
  case llvm::MachineOperand::MO_Immediate: {
    const llvm::MachineInstr *MI = Op.getParent();
    assert(MI && "Operand does not have a machine instruction");
    llvm::LLVMContext &Ctx = MF.getFunction().getContext();
    return *llvm::ConstantInt::getSigned(
        RegType ? RegType : llvm::IntegerType::getInt64Ty(Ctx), Op.getImm());
  }
  case llvm::MachineOperand::MO_MachineBasicBlock: {
    auto *BB = const_cast<llvm::BasicBlock *>(Op.getMBB()->getBasicBlock());
    assert(BB && "MBB operand has no IR BasicBlock");
    return *BB;
  }
  case llvm::MachineOperand::MO_GlobalAddress:
    return *const_cast<llvm::GlobalValue *>(Op.getGlobal());
  default:
    llvm_unreachable("Unhandled operand type");
  }
}

llvm::BasicBlock &
MIRToIRTranslator::getOperandAsBasicBlock(const llvm::MachineInstr &MI,
                                          llvm::AMDGPU::OpName OpName) {
  return getOperandAsBasicBlock(*TII.getNamedOperand(MI, OpName));
}

llvm::BasicBlock &
MIRToIRTranslator::getOperandAsBasicBlock(const llvm::MachineOperand &Op) {
  auto *BB = const_cast<llvm::BasicBlock *>(Op.getMBB()->getBasicBlock());
  assert(BB && "MBB operand has no IR BasicBlock");
  return *BB;
}

void MIRToIRTranslator::setRegOperandValue(const llvm::MachineInstr &MI,
                                           llvm::MCRegister Reg,
                                           llvm::Value *Val) {
  assert(Val && "Val is nullptr");
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");
  BlockRegState &State = VM[*MBB];
  MCRegValueMap &Map = State.RegCache;
  // Emit any extraction IR into the MBB's basic block.
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::Instruction *TermInst = BB->getTerminator();
  llvm::IRBuilder Builder =
      TermInst ? llvm::IRBuilder{TermInst} : llvm::IRBuilder{BB};
  unsigned RegSize =
      Reg == llvm::AMDGPU::MODE
          ? 32
          : TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(Reg));

  assert(Val->getType()->getPrimitiveSizeInBits() == RegSize &&
         "Value type's size is not the same as the type of the register");

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Setting register {0} to value {3} for"
                 "MBB {1} (type: {2})\n",
                 TRI.getName(Reg), MBB->getNumber(),
                 *Val->getType()->getScalarType(), *Val));

  // Preserve non-overlapping portions of any partially-overwritten
  // super-registers, then erase fully-covered entries.
  invalidateOverlaps(Map, Reg, Builder);
  annotateUniformIfNeeded(Val, TRI, Reg);
  Map[Reg][Val->getType()] = Val;
  const llvm::MachineFunction *MF = MBB->getParent();
  assert(MF && "MBB has no parent function");
  Val->setName(getRegValueName(Reg));

  /// If \p Reg belongs to a modeled register file, the cached file value
  /// (if any) is now stale — it was built before this write, so drop it
  /// and let the next \c getRegisterFileValue call rebuild from the
  /// updated cache.
  {
    const llvm::TargetRegisterClass *RC = TRI.getPhysRegBaseClass(Reg);
    bool MaybeInFile =
        (RC && (llvm::SIRegisterInfo::hasSGPRs(RC) ||
                llvm::SIRegisterInfo::isVGPRClass(RC) ||
                llvm::SIRegisterInfo::isAGPRClass(RC))) ||
        Reg == llvm::AMDGPU::VCC || Reg == llvm::AMDGPU::VCC_LO ||
        Reg == llvm::AMDGPU::VCC_HI || Reg == llvm::AMDGPU::XNACK_MASK ||
        Reg == llvm::AMDGPU::XNACK_MASK_LO ||
        Reg == llvm::AMDGPU::XNACK_MASK_HI || Reg == llvm::AMDGPU::FLAT_SCR ||
        Reg == llvm::AMDGPU::FLAT_SCR_LO || Reg == llvm::AMDGPU::FLAT_SCR_HI ||
        llvm::StringRef(TRI.getName(Reg)).starts_with("TTMP");
    if (MaybeInFile) {
      RegFileID File = getRegFileForReg(Reg);
      State.FileCache[static_cast<size_t>(File)] = nullptr;
    }
  }
}

void MIRToIRTranslator::setRegOperandValue(const llvm::MachineOperand &Op,
                                           llvm::Value *Val) {
  assert(Val && "Val is nullptr");
  assert(Op.isReg() && "Operand is not a register");
  assert(Op.getReg().isPhysical() && "Operand is not a physical register");
  const llvm::MachineInstr *MI = Op.getParent();
  assert(MI && "Machine operand has no parent MI");
  setRegOperandValue(*MI, Op.getReg(), Val);
}

void MIRToIRTranslator::setRegOperandValue(const llvm::MachineInstr &MI,
                                           llvm::AMDGPU::OpName OpName,
                                           llvm::Value *Val) {
  setRegOperandValue(*TII.getNamedOperand(MI, OpName), Val);
}

llvm::BasicBlock *MIRToIRTranslator::getNextBB(const llvm::MachineInstr &MI) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI does not have a basic block");
  const llvm::MachineBasicBlock *NextMBB = MBB->getNextNode();
  assert(NextMBB && "MI doesn't have a fall-through block");

  return const_cast<llvm::BasicBlock *>(NextMBB->getBasicBlock());
}

void MIRToIRTranslator::fixupPhis() {
  llvm::SmallVector<llvm::PHINode *> SingleValuePhis{};

  /// Resolving a per-register PHI may cause \c materializeReg on a
  /// predecessor to emit a new placeholder PHI (there, or in one of its
  /// own predecessors). Those get appended to \c ToBeFixedPhis while we
  /// iterate, so keep draining until the list is empty.
  while (!ToBeFixedPhis.empty()) {
    auto It = ToBeFixedPhis.begin();
    for (const llvm::MachineBasicBlock *PredMBB : It->MBB->predecessors()) {
      auto *PredBB = const_cast<llvm::BasicBlock *>(PredMBB->getBasicBlock());
      if (!llvm::is_contained(It->Phi->blocks(), PredBB)) {
        It->Phi->addIncoming(
            &materializeReg(*PredMBB, It->Reg, It->Phi->getType()), PredBB);
      }
    }
    if (It->Phi->getNumIncomingValues() == 1)
      SingleValuePhis.push_back(It->Phi);
    ToBeFixedPhis.erase(It);
  }

  /// File-level PHIs have to be wired up *after* the per-register pass,
  /// because \c getRegisterFileValue on a predecessor may in turn build a
  /// file from that predecessor's \c RegCache, which needs its per-reg
  /// PHIs to be settled first. As with per-reg PHIs, resolving one can
  /// cause additional file PHIs to be queued in predecessor blocks — keep
  /// draining until the list is empty.
  while (!ToBeFixedFilePhis.empty()) {
    auto It = ToBeFixedFilePhis.begin();
    for (const llvm::MachineBasicBlock *PredMBB : It->MBB->predecessors()) {
      auto *PredBB = const_cast<llvm::BasicBlock *>(PredMBB->getBasicBlock());
      if (llvm::is_contained(It->Phi->blocks(), PredBB))
        continue;
      llvm::Instruction *TermInst = PredBB->getTerminator();
      llvm::IRBuilder Builder =
          TermInst ? llvm::IRBuilder{TermInst} : llvm::IRBuilder{PredBB};
      llvm::Value *PredFile = getRegisterFileValue(*PredMBB, It->File, Builder);
      It->Phi->addIncoming(PredFile, PredBB);
    }
    if (It->Phi->getNumIncomingValues() == 1)
      SingleValuePhis.push_back(It->Phi);
    ToBeFixedFilePhis.erase(It);
  }

  for (llvm::PHINode *P : SingleValuePhis) {
    llvm::Value *V = P->getIncomingValue(0);
    P->replaceAllUsesWith(V);
    P->eraseFromParent();
  }
}

#define GET_SI_INSTR_SEMANTIC_FUNCTIONS
#include "SIInstrSemantics.inc"

#define GET_SI_INSTR_SEMANTIC_DISPATCH
#define HANDLE_INST_SEMANTIC(OPCODE)                                           \
  case llvm::AMDGPU::OPCODE:                                                   \
    return luthier::raiseMachineInstr<llvm::AMDGPU::OPCODE>(MI, Builder, *this);

void MIRToIRTranslator::raiseMachineInstr(const llvm::MachineInstr &MI,
                                          llvm::IRBuilderBase &Builder) {
  switch (MI.getOpcode()) {

#include "SIInstrSemantics.inc"

  default: {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Unmodelled instruction " << MI << "\n");

    InlineAsmEmitter->emitInlineAsm(
        Builder, MI,
        [&](llvm::MCRegister Reg) -> llvm::Value & {
          return getRegisterOperand(MI, Reg);
        },
        [&](llvm::MCRegister Reg, llvm::Value &Val) {
          setRegOperandValue(MI, Reg, &Val);
        });
  }
  }
}

void MIRToIRTranslator::translate() {
  auto &F = const_cast<llvm::Function &>(MF.getFunction());
  llvm::LLVMContext &Ctx = F.getContext();
  /// Early exit if there are no basic blocks in the machine function
  if (MF.empty())
    return;

  LLVM_DEBUG(
      llvm::dbgs() << "[MIRToIRTranslator] Translating machine function '"
                   << MF.getName() << "' with " << MF.size() << " MBBs\n");

  /// Delete any basic blocks already present in the IR Function
  if (!F.empty())
    (void)F.erase(F.begin(), F.end());

  /// Create BBs associated with every MBB in the MF
  for (llvm::MachineBasicBlock &MBB : MF) {
    MBB.*get(TagBB()) = llvm::BasicBlock::Create(Ctx, "", &F);
  }

  /// If this is a kernel entry function, seed the register tracker with the
  /// hardware pre-loaded SGPR/VGPR values.
  if (F.getCallingConv() == llvm::CallingConv::AMDGPU_KERNEL) {
    auto *EntryBB = const_cast<llvm::BasicBlock *>(MF.front().getBasicBlock());
    assert(EntryBB && "Entry MBB has no IR basic block");
    llvm::IRBuilder Builder{EntryBB};
    initKernelEntryRegs(Builder);
  }

  /// Iterate over the MBBs and raise the machine instructions in each MBB to
  /// LLVM IR
  for (llvm::MachineBasicBlock &MBB : MF) {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Processing MBB " << MBB.getNumber()
               << " with " << MBB.size() << " instructions\n");
    auto *BB = const_cast<llvm::BasicBlock *>(MBB.getBasicBlock());
    for (llvm::MachineInstr &MI : MBB) {
      LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Translating MI: ";
                 MI.print(llvm::dbgs()); llvm::dbgs() << "\n");
      llvm::InstSimplifyFolder CF{MF.getDataLayout()};
      llvm::IRBuilderCallbackInserter Inserter([&](llvm::Instruction *I) {
        LLVM_DEBUG(llvm::dbgs()
                   << "[MIRToIRTranslator] Inserting translated instruction "
                   << *I << "\n");
        if (MI.getPCSections())
          I->setMetadata(llvm::LLVMContext::MD_pcsections, MI.getPCSections());
      });
      llvm::IRBuilderBase Builder(Ctx, CF, Inserter, {}, {});
      Builder.SetInsertPoint(BB);
      raiseMachineInstr(MI, Builder);
    }
    if (MBB.canFallThrough()) {
      /// Call instructions are not intended to fall through; Instead, we create
      /// a new function for it. Hence, at the IR level, the instruction
      /// after call instructions are unreachable in the current function
      if (MBB.back().isCall()) {
        llvm::IRBuilder Builder(
            const_cast<llvm::BasicBlock *>(MBB.getBasicBlock()));
        Builder.CreateUnreachable();
      } else if (!MBB.back().isBranch()) {
        auto NextBB =
            const_cast<llvm::BasicBlock *>(MBB.getNextNode()->getBasicBlock());
        llvm::IRBuilder{BB}.CreateBr(NextBB);
      }
    }

    /// TODO: Emit branches at the end of vector instructions to indicate
    /// they will not execute if the exec mask bit of the current thread is
    /// not zero
  }
  /// Fixup all dangeling PHIs
  fixupPhis();

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Translation complete for '"
                          << F.getName() << "': " << F.size()
                          << " basic blocks\n");
}

} // namespace luthier