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
#include "luthier/Tooling/Metadata.h"
#include "luthier/Tooling/TargetMachineInstrMDNode.h"
#include <AMDGPUMachineFunction.h>
#include <GCNSubtarget.h>
#include <SIInstrInfo.h>
#include <SIMachineFunctionInfo.h>
#include <SIRegisterInfo.h>
#include <limits>
#include <llvm/ADT/DenseSet.h>
#include <llvm/ADT/PostOrderIterator.h>
#include <llvm/Analysis/InstSimplifyFolder.h>
#include <llvm/CodeGen/AsmPrinter.h>
#include <llvm/CodeGen/LivePhysRegs.h>
#include <llvm/CodeGen/MachineDominators.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/CodeGen/MachineInstr.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/MachineRegisterInfo.h>
#include <llvm/CodeGen/TargetSubtargetInfo.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/IntrinsicsAMDGPU.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/ValueMap.h>
#include <llvm/MC/MCAsmInfo.h>
#include <llvm/MC/MCInstPrinter.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Support/MathExtras.h>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-mir-to-ir"

namespace {
/// Friend ADL trick to allow access to the private basic block field of
/// machine basic block
/// Unlike what LLVM assumes (IR comes after MIR), we have to construct the
/// IR basic block after we have the machine basic block
struct TagBB {
  using type = const llvm::BasicBlock *llvm::MachineBasicBlock::*;

  friend type get(TagBB);
};

template <typename Tag, typename Tag::type MemPtr> struct Access {
  friend typename Tag::type get(Tag) { return MemPtr; }
};

template struct Access<TagBB, &llvm::MachineBasicBlock::BB>;

/// Friend ADL trick to allow access to the private basic block field of
/// machine basic block
/// Unlike what LLVM assumes (IR comes after MIR), we have to construct the
/// IR basic block after we have the machine basic block
struct TagMF {
  using type = llvm::MachineFunction *llvm::AsmPrinter::*;

  friend type get(TagMF);
};

template struct Access<TagMF, &llvm::AsmPrinter::MF>;

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
    llvm::Type *OutTy = Builder.getIntNTy(T->getIntegerBitWidth());
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

void MBBOperandTracker::invalidateOverlaps(MCRegValueMap &Map,
                                           llvm::MCRegister Reg,
                                           llvm::IRBuilder<> &Builder) {
  const llvm::SIRegisterInfo &TRI = getTRI();

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

llvm::Value *MBBOperandTracker::tryExtractFromSuperReg(
    MCRegValueMap &Map, llvm::MCRegister Reg, llvm::Type *RegType,
    llvm::IRBuilderBase &Builder) {
  const llvm::SIRegisterInfo &TRI = getTRI();
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

llvm::Value *MBBOperandTracker::tryComposeFromSubRegs(
    MCRegValueMap &Map, llvm::MCRegister Reg, llvm::IRBuilderBase &Builder,
    llvm::Type *RegType) {
  const llvm::SIRegisterInfo &TRI = getTRI();
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

llvm::Value *MBBOperandTracker::tryComposeFromOverlappingRegs(
    const llvm::MachineBasicBlock &MBB, MCRegValueMap &Map,
    llvm::MCRegister Reg, llvm::IRBuilderBase &Builder, llvm::Type *RegType) {
  const llvm::SIRegisterInfo &TRI = getTRI();
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
MBBOperandTracker::materializeReg(const llvm::MachineBasicBlock &MBB,
                                  llvm::MCRegister Reg, llvm::Type *RegType) {
  MCRegValueMap &Map = getMap(MBB);
  const llvm::SIRegisterInfo &TRI = getTRI();
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

  llvm::IRBuilder Builder{BB};
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
      llvm::Value *Out =
          Builder.CreateBitOrPointerCast(CastVal, RegType, RegName);
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

  // 5. Not available locally — search predecessors and emit PHI / undef.

  if (MBB.pred_empty()) {
    LLVM_DEBUG(llvm::dbgs()
               << llvm::formatv("[MIRToIRTranslator] No predecessors for "
                                "MBB {0}, returning undef for register {1}\n",
                                MBB.getNumber(), RegName));
    llvm::Value *Undef = llvm::UndefValue::get(RegType);
    Map[Reg][RegType] = Undef;
    return *Undef;
  }

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Creating PHI for "
                 "register {0} in MBB {1} with {2} predecessors\n",
                 RegName, MBB.getNumber(), MBB.pred_size()));

  llvm::PHINode *Phi = Builder.CreatePHI(RegType, MBB.pred_size(), RegName);

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Emitted phi value " << *Phi
                          << " for register " << RegName << " in basic block "
                          << MBB.getNumber() << ".\n";);
  annotateUniformIfNeeded(Phi, TRI, Reg);
  Map[Reg][RegType] = Phi;
  return *Phi;
}

/// Initialize the register tracker with the pre-loaded SGPR/VGPR values
/// for an AMDGPU kernel entry function.
///
/// At kernel launch the hardware pre-loads certain values into SGPRs and
/// VGPRs according to the kernel descriptor.  Where possible we emit the
/// corresponding AMDGCN intrinsic so that the resulting IR is idiomatic;
/// for the few pre-loaded values that lack an intrinsic we fall back to a
/// frozen poison placeholder.
static void initKernelEntryRegs(const llvm::MachineFunction &MF,
                                llvm::IRBuilderBase &Builder,
                                MBBOperandTracker &Tracker) {
  const auto &Info = *MF.getInfo<llvm::SIMachineFunctionInfo>();
  const auto &TRI = *MF.getSubtarget<llvm::GCNSubtarget>().getRegisterInfo();

  using PV = llvm::AMDGPUFunctionArgInfo::PreloadedValue;

  /// Seed a single preloaded register with \p Val.
  /// Annotates non-VGPR values with \c !amdgpu.uniform.
  auto seed = [&](PV Which, llvm::Value *Val) {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return;
    annotateUniformIfNeeded(Val, TRI, Reg);
    Tracker.seedRegValue(MF.front(), Reg, Val);
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
}

MBBOperandTracker::MBBOperandTracker(const llvm::MachineFunction &MF)
    : MF(MF), MDT(const_cast<llvm::MachineFunction &>(MF)) {
  for (const llvm::MachineBasicBlock &MBB : MF)
    VM.insert({std::ref(MBB), MCRegValueMap{}});

  const llvm::Function &F = MF.getFunction();
  /// If this is a kernel entry function, seed the register tracker with the
  /// hardware pre-loaded SGPR/VGPR values.
  if (F.getCallingConv() == llvm::CallingConv::AMDGPU_KERNEL) {
    auto *EntryBB = const_cast<llvm::BasicBlock *>(MF.front().getBasicBlock());
    assert(EntryBB && "Entry MBB has no IR basic block");
    llvm::IRBuilder Builder{EntryBB};
    initKernelEntryRegs(MF, Builder, *this);

    /// Set the initial value of the execute mask to all ones on entry
    const llvm::SIRegisterInfo *TRI =
        MF.getSubtarget<llvm::GCNSubtarget>().getRegisterInfo();
    llvm::MCRegister Exec = TRI->getExec();
    seedRegValue(MF.front(), Exec,
                 Builder.getIntN(TRI->getRegSizeInBits(Exec, MF.getRegInfo()),
                                 0xFFFFFFFF));
    /// Set the initial SCC value to zero
    seedRegValue(MF.front(), llvm::AMDGPU::SCC, Builder.getInt1(false));
  }
}

llvm::Value &
MBBOperandTracker::getRegisterOperand(const llvm::MachineBasicBlock &MBB,
                                      llvm::MCRegister Reg,
                                      llvm::Type *RegType) {
  return materializeReg(MBB, Reg, RegType);
}

llvm::Value &MBBOperandTracker::getRegisterOperand(const llvm::MachineInstr &MI,
                                                   llvm::MCRegister Reg,
                                                   llvm::Type *RegType) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI does not have a machine basic block");
  return getRegisterOperand(*MBB, Reg, RegType);
}

llvm::Value &
MBBOperandTracker::getOperandAsValue(const llvm::MachineOperand &Op,
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
MBBOperandTracker::getOperandAsBasicBlock(const llvm::MachineOperand &Op) {
  auto *BB = const_cast<llvm::BasicBlock *>(Op.getMBB()->getBasicBlock());
  assert(BB && "MBB operand has no IR BasicBlock");
  return *BB;
}

void MBBOperandTracker::setRegOperandValue(const llvm::MachineInstr &MI,
                                           llvm::MCRegister Reg,
                                           llvm::Value *Val) {
  assert(Val && "Val is nullptr");
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");
  MCRegValueMap &Map = getMap(*MBB);
  // Emit any extraction IR into the MBB's basic block.
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::IRBuilder Builder{BB};

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Setting register {0} to value {3} for"
                 "MBB {1} (type: {2})\n",
                 getTRI().getName(Reg), MBB->getNumber(),
                 *Val->getType()->getScalarType(), *Val));

  // Preserve non-overlapping portions of any partially-overwritten
  // super-registers, then erase fully-covered entries.
  invalidateOverlaps(Map, Reg, Builder);
  annotateUniformIfNeeded(Val, getTRI(), Reg);
  Map[Reg][Val->getType()] = Val;
  const llvm::MachineFunction *MF = MBB->getParent();
  assert(MF && "MBB has no parent function");
  Val->setName(MF->getSubtarget().getRegisterInfo()->getName(Reg));
}

void MBBOperandTracker::setRegOperandValue(const llvm::MachineOperand &Op,
                                           llvm::Value *Val) {
  assert(Val && "Val is nullptr");
  assert(Op.isReg() && "Operand is not a register");
  assert(Op.getReg().isPhysical() && "Operand is not a physical register");
  const llvm::MachineInstr *MI = Op.getParent();
  assert(MI && "Machine operand has no parent MI");
  setRegOperandValue(*MI, Op.getReg(), Val);
}

llvm::BasicBlock *MBBOperandTracker::getNextBB(const llvm::MachineInstr &MI) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI does not have a basic block");
  const llvm::MachineFunction *MF = MBB->getParent();
  assert(MF && "MBB has no parent function");
  const llvm::MachineBasicBlock *NextMBB = MBB->getNextNode();
  assert(NextMBB && "MI doesn't have a fall-through block");

  return const_cast<llvm::BasicBlock *>(NextMBB->getBasicBlock());
}

template <uint16_t Opcode>
void raiseMachineInstr(const llvm::MachineInstr &MI,
                       llvm::IRBuilderBase &Builder,
                       MBBOperandTracker &RegisterValueMap);

#define GET_SI_INSTR_SEMANTIC_FUNCTIONS
#include "SIInstrSemantics.inc"

#define GET_SI_INSTR_SEMANTIC_DISPATCH
#define HANDLE_INST_SEMANTIC(OPCODE)                                           \
  case llvm::AMDGPU::OPCODE:                                                   \
    return raiseMachineInstr<llvm::AMDGPU::OPCODE>(MI, Builder, Tracker);

static void raiseMachineInstr(
    const llvm::MachineInstr &MI, llvm::IRBuilderBase &Builder,
    MBBOperandTracker &Tracker,
    const std::function<std::string(const llvm::MachineInstr &MI)>
        &AsmStringPrinter,
    const std::function<std::string(llvm::MCRegister)> &AsmRegPrinter) {
  switch (MI.getOpcode()) {

#include "SIInstrSemantics.inc"

  default: {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Unmodelled instruction " << MI << "\n");

    std::string AsmStr = AsmStringPrinter(MI);

    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Obtained instruction asm string: "
               << AsmStr << "\n");

    const llvm::MachineBasicBlock *MBB = MI.getParent();
    assert(MBB && "MI doesn't have a basic block");
    const llvm::MachineFunction *MF = MBB->getParent();
    assert(MF && "MBB has no parent function");

    const llvm::SIRegisterInfo *TRI =
        MF->getSubtarget<llvm::GCNSubtarget>().getRegisterInfo();

    struct RegOperandInfo {
      const llvm::MachineOperand *Op;
      unsigned InlineAsmIdx;
      std::string Constraint;
    };

    auto GetRegConstraint = [&](llvm::MCRegister Reg) -> std::string {
      if (!TRI->isInAllocatableClass(Reg))
        return "r";
      const llvm::TargetRegisterClass *RC = TRI->getMinimalPhysRegClass(Reg);
      if (llvm::SIRegisterInfo::isAGPRClass(RC)) {
        return "a";
      } else if (llvm::SIRegisterInfo::isVGPRClass(RC)) {
        return "v";
      } else if (llvm::SIRegisterInfo::isSGPRClass(RC)) {
        return "s";
      } else
        return "r";
    };

    llvm::SmallVector<RegOperandInfo> Defs;
    llvm::SmallVector<RegOperandInfo> Uses;

    unsigned OpIdx = 0;

    for (const llvm::MachineOperand &Op : MI.all_defs()) {
      /// TODO: Support MODE register
      if (Op.getReg() == llvm::AMDGPU::MODE)
        continue;
      std::string RegConstraint = '=' + GetRegConstraint(Op.getReg().asMCReg());
      LLVM_DEBUG(llvm::StringRef RegName = TRI->getRegAsmName(Op.getReg());
                 llvm::dbgs()
                 << "[MIRToIRTranslator] Def Operand info: "
                 << "Op idx: " << OpIdx << ", "
                 << "Reg name: " << RegName << ", constraint: " << RegConstraint
                 << ", is implicit: " << Op.isImplicit() << "\n");

      Defs.push_back({&Op, OpIdx, RegConstraint});
      OpIdx++;
    }

    for (const llvm::MachineOperand &Op : MI.all_uses()) {
      /// TODO: Support MODE register
      if (Op.getReg() == llvm::AMDGPU::MODE)
        continue;
      std::string RegConstraint = GetRegConstraint(Op.getReg().asMCReg());
      LLVM_DEBUG(llvm::StringRef RegName = TRI->getRegAsmName(Op.getReg());
                 llvm::dbgs()
                 << "[MIRToIRTranslator] Use Operand info: "
                 << "Op idx: " << OpIdx << ", "
                 << "Reg name: " << RegName << ", constraint: " << RegConstraint
                 << ", is implicit: " << Op.isImplicit() << "\n");

      Uses.push_back({&Op, OpIdx, RegConstraint});
      OpIdx++;
    }

    for (const auto &RegOp : llvm::concat<RegOperandInfo>(Defs, Uses)) {
      size_t Pos = 0;
      llvm::StringRef RegAsmName = TRI->getRegAsmName(RegOp.Op->getReg());
      while ((Pos = AsmStr.find(RegAsmName, Pos)) != std::string::npos) {
        std::string AsmOpIdxAsStr = llvm::formatv("${0}", RegOp.InlineAsmIdx);
        AsmStr.replace(Pos, RegAsmName.size(), AsmOpIdxAsStr);
        Pos += AsmOpIdxAsStr.size();
      }
    }

    std::string ConstraintStr;
    for (const auto &RegOp : llvm::concat<RegOperandInfo>(Defs, Uses)) {
      if (!ConstraintStr.empty())
        ConstraintStr += ",";
      ConstraintStr += RegOp.Constraint;
    }

    llvm::SmallVector<llvm::Value *, 8> Operands;
    llvm::SmallVector<llvm::Type *, 8> ArgTys;
    for (const auto &RegOp : Uses) {
      llvm::Value &Val = Tracker.getOperandAsValue(*RegOp.Op);
      Operands.push_back(&Val);
      ArgTys.push_back(Val.getType());
    }

    llvm::Type *RetTy = [&] -> llvm::Type * {
      unsigned NumDefs = Defs.size();
      if (NumDefs == 0)
        return Builder.getVoidTy();
      else if (NumDefs == 1) {
        return Builder.getIntNTy(TRI->getRegSizeInBits(
            *TRI->getMinimalPhysRegClass(Defs[0].Op->getReg())));
      } else {
        llvm::SmallVector<llvm::Type *, 2> OutTypes;
        for (const auto &Def : Defs) {
          OutTypes.push_back(Builder.getIntNTy(TRI->getRegSizeInBits(
              *TRI->getMinimalPhysRegClass(Def.Op->getReg()))));
        }
        return llvm::StructType::get(Builder.getContext(), OutTypes);
      }
    }();

    llvm::FunctionType *FTy = llvm::FunctionType::get(RetTy, ArgTys, false);
    llvm::InlineAsm *IA =
        llvm::InlineAsm::get(FTy, AsmStr, ConstraintStr, true);

    llvm::CallInst *CI = Builder.CreateCall(IA, Operands);
    CI->addAttributeAtIndex(llvm::AttributeList::FunctionIndex,
                            llvm::Attribute::NoUnwind);

    if (Defs.size() == 1) {
      Tracker.setRegOperandValue(*Defs[0].Op, CI);
    } else if (Defs.size() > 1) {
      for (const auto &[Idx, Def] : llvm::enumerate(Defs)) {
        llvm::Value *DefVal = Builder.CreateExtractValue(CI, Idx);
        Tracker.setRegOperandValue(*Def.Op, DefVal);
      }
    }
    break;
  }
  }
}
//===----------------------------------------------------------------------===//
// translateSingleInstr — public API for the fuzzer
//===----------------------------------------------------------------------===//

llvm::Error translateSingleInstr(const llvm::MachineInstr &MI,
                                 llvm::IRBuilderBase &Builder,
                                 const PhysRegValueMap &InputRegs,
                                 PhysRegValueMap &OutputRegs) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  if (!MBB)
    return LUTHIER_MAKE_GENERIC_ERROR("MI has no parent MBB");
  const llvm::MachineFunction *MF = MBB->getParent();
  if (!MF)
    return LUTHIER_MAKE_GENERIC_ERROR("MBB has no parent MF");

  auto &TM = const_cast<llvm::TargetMachine &>(MF->getTarget());
  llvm::MCContext ExtMCCtx(TM.getTargetTriple(), TM.getMCAsmInfo(),
                           TM.getMCRegisterInfo(), TM.getMCSubtargetInfo(),
                           nullptr, &TM.Options.MCOptions, false);

  llvm::SmallString<50> AsmString;
  llvm::raw_svector_ostream OS(AsmString);

  llvm::Expected<std::unique_ptr<llvm::MCStreamer>> MCSOrErr =
      TM.createMCStreamer(OS, nullptr, llvm::CodeGenFileType::AssemblyFile,
                          ExtMCCtx);
  LUTHIER_RETURN_ON_ERROR(MCSOrErr.takeError());

  llvm::AsmPrinter *AsmPrinter =
      MF->getTarget().getTarget().createAsmPrinter(TM, std::move(*MCSOrErr));
  if (!AsmPrinter)
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Failed to create assembly printer for emitting instructions that are "
        "not modelled");

  auto AsmStrEmitter = [&](const llvm::MachineInstr &MI) {
    AsmPrinter->emitInstruction(&MI);
    std::string Out{AsmString};
    AsmString.clear();
    return Out;
  };

  std::unique_ptr<llvm::MCInstPrinter> IP(TM.getTarget().createMCInstPrinter(
      TM.getTargetTriple(), TM.getMCAsmInfo()->getAssemblerDialect(),
      *TM.getMCAsmInfo(), *TM.getMCInstrInfo(), *TM.getMCRegisterInfo()));

  auto RegNamePrinter = [&](llvm::MCRegister Reg) {
    std::string Out;
    llvm::raw_string_ostream RegOS(Out);
    IP->printRegName(RegOS, Reg);
    return Out;
  };

  LLVM_DEBUG(
      llvm::dbgs() << "[MIRToIRTranslator] Translating single instruction in '"
                   << MF->getName() << "': ";
      MI.dump(););

  // Create a tracker and seed it with the caller's input register values.
  MBBOperandTracker Tracker(*MF);
  for (const auto &[Reg, Val] : InputRegs)
    Tracker.seedRegValue(*MBB, Reg, Val);

  raiseMachineInstr(MI, Builder, Tracker, AsmStrEmitter, RegNamePrinter);

  // Extract output register values from the tracker.
  for (const llvm::MachineOperand &Def : MI.all_defs()) {
    llvm::MCRegister Reg = Def.getReg();
    llvm::Value &Val = Tracker.getRegisterOperand(*MBB, Reg);
    OutputRegs[Reg] = &Val;
  }

  LLVM_DEBUG(llvm::dbgs()
             << "[MIRToIRTranslator] Single instruction translation complete, "
             << "produced " << OutputRegs.size() << " output registers\n");

  return llvm::Error::success();
}

// llvm::SmallVector<llvm::MCRegister>
// getISAVisibleRegisters(const llvm::MachineFunction &MF) {
//   llvm::SmallVector<llvm::MCRegister> Registers;
//
//   const auto &STI = MF.getSubtarget<llvm::GCNSubtarget>();
//   const auto &TRI = *STI.getRegisterInfo();
//
//   const llvm::Function &F = MF.getFunction();
//   unsigned NumAGPRs = STI.getMaxNumAGPRs(F);
//   unsigned NumVGPRs = STI.getMaxNumVGPRs(F);
//   unsigned NumSGPRs = STI.getMaxNumSGPRs(F);
//
//   llvm::BitVector ReservedRegs = TRI.getReservedRegs(MF);
//
//   auto addRegIfNotReserved = [&](llvm::MCRegister Reg) {
//     if (!ReservedRegs.test(Reg))
//       Registers.push_back(Reg);
//   };
//
//   auto addRegClass32 = [&](const llvm::TargetRegisterClass &RC,
//                            unsigned Count) {
//     for (unsigned I = 0; I < Count; ++I) {
//       addRegIfNotReserved(RC.getRegister(I));
//     }
//   };
//
//   const auto *VGPR32RC = TRI.getVGPRClassForBitWidth(32);
//   const auto *AGPR32RC = llvm::SIRegisterInfo::getSGPRClassForBitWidth(32);
//   if (AGPR32RC) {
//     AGPR32RC = TRI.getAGPRClassForBitWidth(32);
//   }
//   const auto *SGPR32RC = llvm::SIRegisterInfo::getSGPRClassForBitWidth(32);
//
//   if (VGPR32RC && NumVGPRs != std::numeric_limits<unsigned>::max())
//     addRegClass32(*VGPR32RC, NumVGPRs);
//
//   if (AGPR32RC && NumAGPRs != std::numeric_limits<unsigned>::max())
//     addRegClass32(*AGPR32RC, NumAGPRs);
//
//   if (SGPR32RC && NumSGPRs != std::numeric_limits<unsigned>::max())
//     addRegClass32(*SGPR32RC, NumSGPRs);
//
//   addRegIfNotReserved(TRI.getVCC());
//   addRegIfNotReserved(TRI.getExec());
//   addRegIfNotReserved(llvm::AMDGPU::SCC);
//   addRegIfNotReserved(llvm::AMDGPU::M0);
//   addRegIfNotReserved(llvm::AMDGPU::MODE);
//
//   addRegIfNotReserved(llvm::AMDGPU::FLAT_SCR_LO);
//   addRegIfNotReserved(llvm::AMDGPU::FLAT_SCR_HI);
//   addRegIfNotReserved(llvm::AMDGPU::FLAT_SCR);
//
//   return Registers;
// }

llvm::Error translateMachineFunctionToIR(llvm::MachineFunction &MF) {
  llvm::Function &F = MF.getFunction();
  llvm::LLVMContext &Ctx = F.getContext();
  /// Early exit if there are no basic blocks in the machine function
  if (MF.empty())
    return llvm::Error::success();

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
  LLVM_DEBUG(llvm::dbgs() << "Before anything: "; F.dump();
             llvm::dbgs() << "\n"; MF.dump(););

  MBBOperandTracker Tracker(MF);

  auto &TM = const_cast<llvm::TargetMachine &>(MF.getTarget());
  llvm::MCContext ExtMCCtx(TM.getTargetTriple(), TM.getMCAsmInfo(),
                           TM.getMCRegisterInfo(), TM.getMCSubtargetInfo(),
                           nullptr, &TM.Options.MCOptions, false);

  llvm::SmallString<50> AsmString;
  llvm::raw_svector_ostream OS(AsmString);

  llvm::Expected<std::unique_ptr<llvm::MCStreamer>> MCSOrErr =
      TM.createMCStreamer(OS, nullptr, llvm::CodeGenFileType::AssemblyFile,
                          ExtMCCtx);
  LUTHIER_RETURN_ON_ERROR(MCSOrErr.takeError());

  llvm::AsmPrinter *AsmPrinter =
      MF.getTarget().getTarget().createAsmPrinter(TM, std::move(*MCSOrErr));
  if (!AsmPrinter)
    return LUTHIER_MAKE_GENERIC_ERROR(
        "Failed to create assembly printer for emitting instructions that are "
        "not modelled");

  AsmPrinter->*get(TagMF()) = &MF;
  auto AsmStrEmitter = [&](const llvm::MachineInstr &MI) {
    AsmPrinter->emitInstruction(&MI);
    std::string Out{AsmString};
    AsmString.clear();
    return Out;
  };

  std::unique_ptr<llvm::MCInstPrinter> IP(TM.getTarget().createMCInstPrinter(
      TM.getTargetTriple(), TM.getMCAsmInfo()->getAssemblerDialect(),
      *TM.getMCAsmInfo(), *TM.getMCInstrInfo(), *TM.getMCRegisterInfo()));
  auto RegNamePrinter = [&](llvm::MCRegister Reg) {
    std::string Out;
    llvm::raw_string_ostream RegOS(Out);
    IP->printRegName(RegOS, Reg);
    return Out;
  };

  /// Iterate over the MBBs in reverse post order (RPO) and raise the
  /// machine instructions in each MBB to LLVM IR. RPO guarantees that when
  /// we visit a block we have already visited its predecessors.
  for (llvm::MachineBasicBlock *MBB :
       llvm::ReversePostOrderTraversal(&*MF.begin())) {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Processing MBB " << MBB->getNumber()
               << " with " << MBB->size() << " instructions\n");
    auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
    for (llvm::MachineInstr &MI : *MBB) {
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
      raiseMachineInstr(MI, Builder, Tracker, AsmStrEmitter, RegNamePrinter);
    }
    /// TODO: Emit branches at the end of vector instructions to indicate
    /// they will not execute if the exec mask bit of the current thread is
    /// not zero
  }

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Translation complete for '"
                          << MF.getName() << "': " << F.size()
                          << " basic blocks\n");

  return llvm::Error::success();
}

} // namespace luthier