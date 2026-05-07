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
#include <llvm/Analysis/CallGraph.h>
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

/// If \p Reg is not a VGPR/AGPR (i.e. SGPR, SCC, etc.)
/// attach \c !amdgpu.uniform metadata to \p I to mark it as uniform.
void inline annotateUniformIfNeeded(llvm::Instruction *I,
                                    const llvm::SIRegisterInfo &TRI,
                                    llvm::MCRegister Reg) {
  if (const llvm::TargetRegisterClass *RC = TRI.getPhysRegBaseClass(Reg);
      RC && !llvm::SIRegisterInfo::isAGPRClass(RC) &&
      !llvm::SIRegisterInfo::isVGPRClass(RC))
    I->setMetadata("amdgpu.uniform", llvm::MDNode::get(I->getContext(), {}));
}

static void
getRegisterFileArgOrder(const llvm::GCNSubtarget &ST,
                        llvm::SmallVector<llvm::MCRegister> &ABIRegFileIdx) {
  ABIRegFileIdx.push_back(llvm::AMDGPU::SGPR0);
  ABIRegFileIdx.push_back(llvm::AMDGPU::isGFX9Plus(ST) ? llvm::AMDGPU::TTMP0
                                                       : llvm::AMDGPU::TBA_LO);
  ABIRegFileIdx.push_back(llvm::AMDGPU::isNotGFX10Plus(ST)
                              ? llvm::AMDGPU::M0
                              : llvm::AMDGPU::SGPR_NULL);
  if (llvm::AMDGPU::isNotGFX9Plus(ST))
    ABIRegFileIdx.push_back(llvm::AMDGPU::SRC_SHARED_BASE);
  ABIRegFileIdx.push_back(llvm::AMDGPU::SRC_VCCZ);
  ABIRegFileIdx.push_back(llvm::AMDGPU::VGPR0);
  if (ST.hasMAIInsts())
    ABIRegFileIdx.push_back(llvm::AMDGPU::AGPR0);
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
    return FP_DENORM_FLUSH_IN_FLUSH_OUT;
  if (OutFlush)
    return FP_DENORM_FLUSH_OUT;
  if (InFlush)
    return FP_DENORM_FLUSH_IN;
  return FP_DENORM_FLUSH_NONE;
}

static llvm::Value *getOrCreateIntOrPtrTypeForReg(
    llvm::DenseMap<llvm::Type *, llvm::Value *> &ValueEntries,
    llvm::IRBuilderBase &Builder) {
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
    auto &[T, V] = *ValueEntries.begin();
    llvm::Type *OutTy = Builder.getIntNTy(T->getPrimitiveSizeInBits());
    VecIntOrPtrVal = Builder.CreateBitOrPointerCast(V, OutTy);
    if (ValueEntries[OutTy] != VecIntOrPtrVal)
      ValueEntries[OutTy] = VecIntOrPtrVal;
  }
  return VecIntOrPtrVal;
}

static llvm::Value *getOrCreateIntOrFloatTypeForReg(
    llvm::DenseMap<llvm::Type *, llvm::Value *> &ValueEntries,
    llvm::IRBuilderBase &Builder) {
  assert(!ValueEntries.empty() && "Value entry map is empty");
  llvm::Value *IntOrFloatVecVal{nullptr};
  for (auto &[T, V] : ValueEntries) {
    if (T->isIntOrIntVectorTy() || T->isFPOrFPVectorTy())
      return V;
  }
  /// If we couldn't find a pointer or an int type, do a bitcast on the first
  /// value in the map
  if (!IntOrFloatVecVal) {
    auto &[T, V] = *ValueEntries.begin();
    llvm::Type *OutTy = Builder.getIntNTy(T->getIntegerBitWidth());
    IntOrFloatVecVal = Builder.CreateBitOrPointerCast(V, OutTy);
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
    unsigned ElemWidth, llvm::IRBuilderBase &Builder) {
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
    llvm::Value *IntVal =
        getOrCreateIntOrFloatTypeForReg(ValueEntries, Builder);
    llvm::Value *Out = Builder.CreateBitOrPointerCast(IntVal, VecTy);
    ValueEntries[VecTy] = Out;
    return Out;
  }
}

void MIRToIRTranslator::invalidateOverlaps(RegValueMap &State,
                                           const RegFileKey &WrittenRegKey,
                                           llvm::IRBuilderBase &Builder) {
  llvm::MCRegister BaseReg = std::get<0>(WrittenRegKey);
  const unsigned WStart = std::get<1>(WrittenRegKey);
  const unsigned WNumHalves = std::get<2>(WrittenRegKey);
  const unsigned WEnd = WStart + WNumHalves;
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] invalidateOverlaps: "
                          << "base=" << TRI.getName(BaseReg)
                          << " offset=" << WStart << " halves=" << WNumHalves
                          << " end=" << WEnd << "\n");

  struct Preserve {
    uint32_t Offset;
    uint32_t NumHalves;
    llvm::Value *Val;
  };
  llvm::SmallVector<RegFileKey, 8> ToErase;
  llvm::SmallVector<Preserve, 4> ToPreserve;

  for (auto &[StoredKey, Entry] : State) {
    if (std::get<0>(StoredKey) != BaseReg)
      continue;
    const uint32_t SStart = std::get<1>(StoredKey);
    const uint32_t SNumHalves = std::get<2>(StoredKey);
    const uint32_t SEnd = SStart + SNumHalves;

    /// No overlap.
    if (SEnd <= WStart || SStart >= WEnd)
      continue;

    /// Skip the exact slot we're about to write — \c setRegOperandValue
    /// will overwrite it.
    if (SStart == WStart && SNumHalves == WNumHalves)
      continue;

    /// Stored ⊂ Written: fully covered, drop it.
    if (SStart >= WStart && SEnd <= WEnd) {
      LLVM_DEBUG(
          llvm::dbgs()
          << "  Fully covered (Stored ⊂ Written), erasing stored key: base="
          << TRI.getName(std::get<0>(StoredKey)) << " offset=" << SStart
          << " halves=" << SNumHalves << "\n");
      ToErase.push_back(StoredKey);
      continue;
    }

    /// Written ⊂ Stored: partial overwrite of a super-register. Preserve
    /// the non-overlapping regions as the largest uniform chunk size that
    /// divides both regions, so a later read can re-compose.
    if (SStart <= WStart && SEnd >= WEnd) {
      LLVM_DEBUG(llvm::dbgs()
                 << "  Partial overwrite (written ⊂ stored), preserving "
                    "non-overlapping parts of stored key: base="
                 << TRI.getName(std::get<0>(StoredKey)) << " offset=" << SStart
                 << " halves=" << SNumHalves << "\n");

      // Compute optimal chunk size as GCD of the two preserved region sizes,
      // the same approach used in \c materializeFromOverlapping
      const uint32_t LeftSize = WStart - SStart; // may be 0
      const uint32_t RightSize = SEnd - WEnd;    // may be 0
      uint32_t OptHalves = LeftSize ? LeftSize : RightSize;
      if (LeftSize && RightSize)
        OptHalves = std::gcd(LeftSize, RightSize);

      const unsigned ElemWidth = OptHalves * RegGranule;
      llvm::Value *Vec =
          breakdownToVecTyFromAvailableValues(Entry, ElemWidth, Builder);

      auto preserveRegion = [&](uint32_t RegionStart, uint32_t RegionEnd) {
        const uint32_t NumChunks = (RegionEnd - RegionStart) / OptHalves;
        for (uint32_t CI = 0; CI < NumChunks; ++CI) {
          uint32_t AbsOffset = RegionStart + CI * OptHalves;
          uint32_t SrcIdx = (AbsOffset - SStart) / OptHalves;
          LLVM_DEBUG(llvm::dbgs() << "  Preserving " << OptHalves
                                  << " halves at offset " << AbsOffset << "\n");
          llvm::Value *Elem = Builder.CreateExtractElement(Vec, SrcIdx);
          ToPreserve.push_back({AbsOffset, OptHalves, Elem});
        }
      };
      if (LeftSize)
        preserveRegion(SStart, WStart);
      if (RightSize)
        preserveRegion(WEnd, SEnd);
      ToErase.push_back(StoredKey);
      continue;
    }
    LLVM_DEBUG(llvm::dbgs() << "  Partial overlap, erasing stored key: base="
                            << TRI.getName(std::get<0>(StoredKey)) << " offset="
                            << SStart << " halves=" << SNumHalves << "\n");
    ToErase.push_back(StoredKey);
  }

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] invalidateOverlaps: Erasing "
                          << ToErase.size() << " entries, preserving "
                          << ToPreserve.size() << " partial entries\n");

  for (auto &K : ToErase) {
    LLVM_DEBUG(llvm::dbgs()
               << "  Deleting entry: [" << TRI.getName(std::get<0>(K)) << ", "
               << std::get<1>(K) << ", " << std::get<2>(K) << "]\n");
    State.erase(K);
  }
  for (const Preserve &P : ToPreserve) {
    LLVM_DEBUG(llvm::dbgs() << "  Restoring preserved entry at offset "
                            << P.Offset << ", halves: " << P.NumHalves << "\n");
    State[std::make_tuple(BaseReg, P.Offset, P.NumHalves)][P.Val->getType()] =
        P.Val;
  }
}

llvm::Value *MIRToIRTranslator::extractChunkFromSource(
    RegValueMap &State, const RegFileKey &RegKey, unsigned VecChunkSize,
    unsigned Idx, unsigned NumChunks, llvm::IRBuilderBase &Builder) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] extractChunkFromSource: "
                             "base="
                          << TRI.getName(std::get<0>(RegKey))
                          << " offset=" << std::get<1>(RegKey) << " Idx=" << Idx
                          << " NumChunks=" << NumChunks
                          << " chunkSize=" << VecChunkSize << "\n";);
  auto &RegValueMap = State[RegKey];
  // Breakdown the value to the requested chunk size
  llvm::Value *TheVec =
      breakdownToVecTyFromAvailableValues(RegValueMap, VecChunkSize, Builder);

  if (NumChunks == 1) {
    llvm::Value *Val = Builder.CreateExtractElement(TheVec, Idx);
    return Val;
  }

  // Build <NumChunks x ChunkSize> from the source
  auto *ChunkTy =
      llvm::FixedVectorType::get(Builder.getIntNTy(VecChunkSize), NumChunks);
  llvm::Value *Chunk = llvm::PoisonValue::get(ChunkTy);
  unsigned VecChunkRegGranMul = VecChunkSize / RegGranule;
  unsigned ChunkSizeInRegGran = NumChunks * VecChunkRegGranMul;
  for (uint32_t I = 0; I < NumChunks; ++I) {
    llvm::Value *E = Builder.CreateExtractElement(TheVec, Idx + I);
    State[std::make_tuple(std::get<0>(RegKey), I * VecChunkRegGranMul,
                          ChunkSizeInRegGran)][E->getType()] = E;
    Chunk = Builder.CreateInsertElement(Chunk, E, I);
  }
  return Chunk;
}

llvm::Value *MIRToIRTranslator::materializeFromOverlapping(
    RegValueMap &State, const llvm::MachineBasicBlock &MBB,
    const RegFileKey &ReadKeyReg, llvm::IRBuilderBase &Builder,
    llvm::Type &RegType) {
  LLVM_DEBUG(
      llvm::dbgs() << "[MIRToIRTranslator] materializeFromOverlapping\n");

  llvm::MCRegister BaseReg = std::get<0>(ReadKeyReg);
  const uint32_t RStart = std::get<1>(ReadKeyReg);
  const uint32_t RNumHalves = std::get<2>(ReadKeyReg);
  /// Note: End is exclusive
  const uint32_t REnd = RStart + RNumHalves;

  // Step 1: Collect all overlapping entries
  struct OverlapInfo {
    uint32_t SrcOffset;
    uint32_t SrcNumHalves;
    RegFileKey RegKey;
    uint32_t OverlapStart;
    uint32_t OverlapEnd;
  };

  llvm::SmallVector<OverlapInfo, 8> Overlaps;
  for (auto &[Key, Entry] : State) {
    if (std::get<0>(Key) != BaseReg)
      continue;
    const uint32_t SOffset = std::get<1>(Key);
    const uint32_t SEnd = SOffset + std::get<2>(Key);
    const uint32_t OStart = std::max(SOffset, RStart);
    const uint32_t OEnd = std::min(SEnd, REnd);
    if (OStart < OEnd) {
      Overlaps.push_back({SOffset, SEnd - SOffset, Key, OStart, OEnd});
    }
  }

  // Step 2: Handle no overlaps case
  if (Overlaps.empty()) {
    if (!MBB.pred_empty()) {
      // Create PHI for entire register
      llvm::PHINode *Phi = Builder.CreatePHI(&RegType, MBB.pred_size());
      ToBeFixedPhis.emplace_back(&MBB, ReadKeyReg, Phi);
      State[ReadKeyReg][&RegType] = Phi;
      return Phi;
    } else {
      // Entry block - freeze(poison)
      llvm::Value *InitVal =
          Builder.CreateFreeze(llvm::PoisonValue::get(&RegType));
      State[ReadKeyReg][&RegType] = InitVal;
      return InitVal;
    }
  }

  // Step 3: Sort overlaps by the size of overlap with the target register
  llvm::sort(Overlaps, [](const OverlapInfo &A, const OverlapInfo &B) {
    return (A.OverlapEnd - A.OverlapStart) > (B.OverlapEnd - B.OverlapStart);
  });

  // Step 4: Build coverage map and identify overlapping chunks
  llvm::BitVector Covered(REnd - RStart, false);

  struct OverlapChunkInfo {
    OverlapInfo *Src;
    uint32_t SrcChunkStart; // Position in source (in halves)
    uint32_t ChunkStart; // Position in result (in halves, relative to WStart)
    uint32_t ChunkEnd;   // End position in result (exclusive)
  };
  llvm::SmallVector<OverlapChunkInfo, 8> OverlapChunks;

  for (OverlapInfo &Overlap : Overlaps) {
    for (uint32_t H = Overlap.OverlapStart; H < Overlap.OverlapEnd;) {
      if (Covered[H - RStart]) {
        H++;
        continue;
      }
      uint32_t ChunkStart = H;
      while (H < Overlap.OverlapEnd && !Covered[H - RStart]) {
        Covered[H - RStart] = true;
        H++;
      }
      uint32_t ChunkEnd = H;
      OverlapChunks.push_back({&Overlap, ChunkStart - Overlap.SrcOffset,
                               ChunkStart - RStart, ChunkEnd - RStart});
    }
  }

  // Step 5: Handle uncovered chunks and add them to the coverage map
  struct NonOverlapChunkInfo {
    RegFileKey KeyReg;
    unsigned ChunkStart;
    uint32_t ChunkEnd;
  };
  llvm::SmallVector<NonOverlapChunkInfo, 8> NonOverlapChunks;

  for (uint32_t H = RStart; H < REnd;) {
    if (Covered[H - RStart]) {
      H++;
      continue;
    }
    uint32_t RangeStart = H;
    while (H < REnd && !Covered[H - RStart]) {
      H++;
    }
    uint32_t RangeEnd = H;
    uint32_t RangeNumHalves = RangeEnd - RangeStart;

    llvm::Type *ValTy = Builder.getIntNTy(RangeNumHalves * 16u);
    llvm::Value *DefaultVal = nullptr;
    RegFileKey NonOverlappingSubKey =
        std::make_tuple(BaseReg, RangeStart, RangeNumHalves);
    if (MBB.pred_empty()) {
      // Entry block - freeze(poison) for the missing value
      DefaultVal = Builder.CreateFreeze(llvm::PoisonValue::get(ValTy));
    } else {
      // Has predecessors - create PHI for the missing value
      llvm::PHINode *Phi = Builder.CreatePHI(ValTy, MBB.pred_size());
      ToBeFixedPhis.emplace_back(&MBB, NonOverlappingSubKey, Phi);
      DefaultVal = Phi;
    }
    State[NonOverlappingSubKey][ValTy] = DefaultVal;
    NonOverlapChunks.push_back({NonOverlappingSubKey, RangeStart, RangeEnd});
  }

  unsigned OptimalNumHalves =
      std::accumulate(OverlapChunks.begin(), OverlapChunks.end(),
                      OverlapChunks[0].ChunkEnd - OverlapChunks[0].ChunkStart,
                      [](unsigned A, OverlapChunkInfo &B) {
                        return std::gcd(A, B.ChunkEnd - B.ChunkStart);
                      });
  OptimalNumHalves =
      std::accumulate(NonOverlapChunks.begin(), NonOverlapChunks.end(),
                      OptimalNumHalves, [](unsigned A, NonOverlapChunkInfo &B) {
                        return std::gcd(A, B.ChunkEnd - B.ChunkStart);
                      });

  // Step 5: Construct a vector type to materialize chunks
  auto *WorkingTy = llvm::FixedVectorType::get(
      Builder.getIntNTy(OptimalNumHalves * RegGranule),
      RNumHalves / OptimalNumHalves);
  llvm::Value *Result = llvm::PoisonValue::get(WorkingTy);

  unsigned OptimalChunkSizeInBits = RegGranule * OptimalNumHalves;

  // InsertChunkFn inserts chunks into Result.
  // SrcChunkStart: source-relative start offset (in halves) within K.
  // ChunkStart / ChunkEnd: RStart-relative offsets (in halves) in the result.
  auto InsertChunkFn = [&](unsigned SrcChunkStart, unsigned ChunkStart,
                           unsigned ChunkEnd, const RegFileKey &K) {
    unsigned NumChunks = ChunkEnd - ChunkStart;
    for (unsigned CI = 0; CI < NumChunks; CI += OptimalNumHalves) {
      // Cache key must use the absolute position in the register file.
      RegFileKey SubRegKey =
          std::make_tuple(BaseReg, RStart + ChunkStart + CI, OptimalNumHalves);
      unsigned SrcElIdx = (SrcChunkStart + CI) / OptimalNumHalves;
      // DestElIdx indexes into WorkingTy which starts at RStart.
      unsigned DestElIdx = (ChunkStart + CI) / OptimalNumHalves;
      llvm::Value *ChunkVal = extractChunkFromSource(
          State, K, OptimalChunkSizeInBits, SrcElIdx, 1, Builder);
      State[SubRegKey][ChunkVal->getType()] = ChunkVal;
      ChunkVal = Builder.CreateBitOrPointerCast(
          ChunkVal, Builder.getIntNTy(OptimalChunkSizeInBits));
      State[SubRegKey][ChunkVal->getType()] = ChunkVal;
      Result = Builder.CreateInsertElement(Result, ChunkVal, DestElIdx);
    }
  };

  // Step 6: Extract and insert chunks.
  // NonOverlapChunks store absolute offsets; normalize to RStart-relative
  // before calling InsertChunkFn (which expects RStart-relative ChunkStart).
  for (auto &C : NonOverlapChunks) {
    InsertChunkFn(0, C.ChunkStart - RStart, C.ChunkEnd - RStart, C.KeyReg);
  }

  for (auto &C : OverlapChunks) {
    InsertChunkFn(C.SrcChunkStart, C.ChunkStart, C.ChunkEnd, C.Src->RegKey);
  }

  // Step 7: Final bitcast to requested type
  return Builder.CreateBitOrPointerCast(Result, &RegType);
}

llvm::Value &
MIRToIRTranslator::getOperandAsValue(const llvm::MachineBasicBlock &MBB,
                                     llvm::MCRegister Reg,
                                     llvm::Type *OutRegType) {
  llvm::StringRef RegName = TRI.getName(Reg);
  std::string RegValName = getRegValueName(Reg);

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Materializing register {0} "
                 "in MBB {1}\n",
                 RegName, MBB.getNumber()));
  (void)RegName;

  auto *BB = const_cast<llvm::BasicBlock *>(MBB.getBasicBlock());
  assert(BB && "MBB does not have an IR basic block");

  llvm::Instruction *TermInst = BB->getTerminator();

  llvm::IRBuilder<llvm::InstSimplifyFolder, llvm::IRBuilderCallbackInserter>
      Builder(BB->getContext(), llvm::InstSimplifyFolder{MF.getDataLayout()},
              llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                annotateUniformIfNeeded(I, TRI, Reg);
                LLVM_DEBUG(
                    llvm::dbgs()
                    << "[MIRToIRTranslator] Inserting reg read instruction "
                    << *I << "\n");
              }});
  TermInst ? Builder.SetInsertPoint(TermInst) : Builder.SetInsertPoint(BB);

  return getOperandAsValue(MBB, getRegFileKey(Reg), Builder, OutRegType);
}

llvm::Value &MIRToIRTranslator::getOperandAsValue(
    const llvm::MachineBasicBlock &MBB, const RegFileKey &Key,
    llvm::IRBuilderBase &Builder, llvm::Type *OutRegType) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] getOperandAsValue: MBB "
                          << MBB.getNumber()
                          << " base=" << TRI.getName(std::get<0>(Key))
                          << " offset=" << std::get<1>(Key)
                          << " halves=" << std::get<2>(Key) << "\n");
  RegValueMap &State = VM[MBB];
  /// ---- Bounds check -------------------------------------------------
  /// Out-of-range access returns the file's base register value (s0/v0/
  /// a0). Hardware semantics: each 32-bit slot of an OOR multi-slot read
  /// returns base-reg's value; writes are dropped.
  llvm::MCRegister BaseReg = std::get<0>(Key);
  unsigned Offset = std::get<1>(Key);
  unsigned NumHalves = std::get<2>(Key);
  unsigned Allocated = RegFileSize[BaseReg];
  if (Offset + NumHalves > Allocated) {
    assert(Offset != 0 &&
           "offset 0 is not in range of the register file allocation");
    Offset = 0;
  }

  if (!OutRegType)
    OutRegType = Builder.getIntNTy(std::get<2>(Key) * RegGranule);

  /// ---- Normal file-keyed lookup -------------------------------------

  // Exact match.
  if (auto It = State.find(Key); It != State.end()) {
    auto &VTM = It->second;
    if (auto V = VTM.find(OutRegType); V != VTM.end())
      return *V->getSecond();
    llvm::Value *CastVal = getOrCreateIntOrPtrTypeForReg(VTM, Builder);
    llvm::Value *Out = Builder.CreateBitOrPointerCast(CastVal, OutRegType);
    VTM[OutRegType] = Out;
    return *Out;
  }

  // Materialize from overlapping registers
  llvm::Value *V =
      materializeFromOverlapping(State, MBB, Key, Builder, *OutRegType);
  State[Key][OutRegType] = V;
  return *V;
}

/// Build the i32 MODE register value that mirrors the kernel-entry state
/// implied by the function's FP attributes (lifted from the kernel
/// descriptor by \c CodeDiscoveryPass). Fields whose attribute is missing
/// fall back to \c SIModeRegisterDefaults so the subtarget-specific
/// defaults stay authoritative. Target-divergent bits (IEEE, DX10_CLAMP)
/// are guarded with subtarget predicates.
static llvm::Value *buildInitialModeValue(const llvm::Function &F,
                                          const llvm::GCNSubtarget &ST,
                                          llvm::IRBuilderBase &Builder) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Building initial MODE "
                             "register value\n");
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
      Mode |= llvm::AMDGPU::Hwreg::DX10_CLAMP_MASK;
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
    Mode &= ~llvm::AMDGPU::Hwreg::GPR_IDX_EN_MASK;
    Mode &= ~llvm::AMDGPU::Hwreg::VSKIP_MASK;
    Mode &= ~llvm::AMDGPU::Hwreg::CSP_MASK;
  }

  return Builder.getInt32(Mode);
}

void MIRToIRTranslator::initKernelEntryRegs(llvm::IRBuilderBase &Builder) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Initializing kernel entry "
                             "registers for '"
                          << MF.getName() << "'\n");
  /// TODO: preload kernel argument values
  const auto &Info = *MF.getInfo<llvm::SIMachineFunctionInfo>();

  using PV = llvm::AMDGPUFunctionArgInfo::PreloadedValue;

  auto seedRegValue = [&](const llvm::MachineBasicBlock &MBB,
                          llvm::MCRegister Reg, llvm::Value *Val) {
    RegValueMap &State = VM[MBB];
    State[getRegFileKey(Reg)][Val->getType()] = Val;
  };

  /// Seed a single preloaded register with \p Val.
  /// Annotates non-VGPR values with \c !amdgpu.uniform.
  auto seed = [&](PV Which, llvm::Value *Val) {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return;
    seedRegValue(MF.front(), Reg, Val);
  };

  /// Create a frozen-poison placeholder for values with no intrinsic.
  auto makePlaceholder = [&](PV Which) -> llvm::Value * {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return nullptr;
    unsigned BitWidth = getPhysRegisterSize(Reg);
    return Builder.CreateFreeze(
        llvm::PoisonValue::get(Builder.getIntNTy(BitWidth)));
  };

  /// Emit a void-returning intrinsic whose result is a pointer, then
  /// ptrtoint it to match the register's integer type.
  auto ptrIntrinsic = [&](PV Which, llvm::Intrinsic::ID IID) {
    llvm::MCRegister Reg = Info.getPreloadedReg(Which);
    if (!Reg)
      return;
    llvm::Value *Ptr =
        Builder.CreateIntrinsic(Builder.getPtrTy(4), IID, {}, nullptr);
    // Store the pointer form for consumers that address through this register.
    seed(Which, Ptr);
    // Also store the integer form: getPrimitiveSizeInBits() returns 0 for
    // pointer types, which causes breakdownToVecTyFromAvailableValues to
    // produce a zero-element vector if this register is later split.
    unsigned BitWidth = getPhysRegisterSize(Reg);
    seed(Which, Builder.CreatePtrToInt(Ptr, Builder.getIntNTy(BitWidth)));
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
    llvm::Value *Val = Builder.CreateIntrinsic(RetTy, IID, {}, nullptr);
    /// If the input argument has a mask (e.g. in case of packed workitem ID),
    /// construct the value from the mask first before materializing the final
    /// register value; Otherwise, just assign the register name to the
    /// intrinsic value
    if (Mask != ~0u) {
      unsigned NumRZeros = std::countr_zero(Mask);
      unsigned MaskNoRZeros = Mask >> NumRZeros;
      Val = Builder.CreateAnd(Val, Builder.getInt32(MaskNoRZeros));
      if (NumRZeros)
        Val = Builder.CreateShl(Val, Builder.getInt32(NumRZeros));
    }

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
  seedRegValue(MF.front(), Exec, ExecInit);

  /// SCC is zero on kernel entry.
  seedRegValue(MF.front(), llvm::AMDGPU::SRC_SCC, Builder.getInt32(false));

  /// MODE: constant assembled from the kernel-descriptor-derived attrs.
  llvm::Value *ModeInit = buildInitialModeValue(MF.getFunction(), ST, Builder);
  seedRegValue(MF.front(), llvm::AMDGPU::MODE, ModeInit);

  /// VCC is zero on kernel entry. \c TRI.getVCC() returns VCC_LO on
  /// wave32 and the full VCC pair on wave64.
  if (llvm::MCRegister VccReg = TRI.getVCC()) {
    unsigned VccWidth = TRI.getRegSizeInBits(VccReg, MF.getRegInfo());
    llvm::Value *VccInit = Builder.getIntN(VccWidth, 0);
    seedRegValue(MF.front(), VccReg, VccInit);
  }
}

MIRToIRTranslator::MIRToIRTranslator(llvm::MachineFunction &MF,
                                     llvm::Error &Err)
    : MF(MF), TRI(*MF.getSubtarget<llvm::GCNSubtarget>().getRegisterInfo()),
      TII(*MF.getSubtarget<llvm::GCNSubtarget>().getInstrInfo()),
      ST(MF.getSubtarget<llvm::GCNSubtarget>()) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Creating translator for '"
                          << MF.getName() << "' with " << MF.size()
                          << " MBBs\n");
  llvm::ErrorAsOutParameter EAO(Err);
  for (const llvm::MachineBasicBlock &MBB : MF)
    VM.try_emplace(std::ref(MBB));

  Err = initRegFileLayouts();
  if (Err)
    return;

  Err =
      MIInlineAsmEmitter::get(const_cast<llvm::TargetMachine &>(MF.getTarget()))
          .moveInto(InlineAsmEmitter);
  if (Err) {
    return;
  }
}

llvm::MCRegister MIRToIRTranslator::getPhysReg(llvm::MCRegister Reg) const {
  switch (Reg) {
  case llvm::AMDGPU::SCC:
    return llvm::AMDGPU::SRC_SCC;
  default:
    return llvm::AMDGPU::getMCReg(Reg, ST);
  }
}

unsigned MIRToIRTranslator::getPhysRegisterSize(llvm::MCRegister Reg) const {
  if (Reg == llvm::AMDGPU::MODE)
    return 32;
  else if (Reg == llvm::AMDGPU::SCC)
    return 32; /// Return SRC_SCC's size instead
  const llvm::TargetRegisterClass *RC = TRI.getMinimalPhysRegClass(Reg);
  if (RC) {
    return TRI.getRegSizeInBits(*RC);
  }
  llvm_unreachable(
      llvm::formatv("Register {0} does not have any register class and its "
                    "size must be explicitly provided",
                    TRI.getName(Reg))
          .str()
          .c_str());
}

llvm::Error MIRToIRTranslator::initRegFileLayouts() {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Initializing register file "
                             "layouts for '"
                          << MF.getName() << "'\n");
  const llvm::Function &F = MF.getFunction();
  const auto &ST = MF.getSubtarget<llvm::GCNSubtarget>();

  unsigned NumSGPRs = F.getFnAttributeAsParsedInteger("amdgpu-num-sgpr");
  unsigned NumVGPRs = F.getFnAttributeAsParsedInteger("amdgpu-num-vgpr");

  if (NumSGPRs == 0) {
    return LUTHIER_MAKE_GENERIC_ERROR("amdgpu-num-sgpr must be non-zero.");
  }
  if (NumVGPRs == 0) {
    return LUTHIER_MAKE_GENERIC_ERROR("amdgpu-num-vgpr must be a non-zero.");
  }

  TTMPBaseReg =
      llvm::AMDGPU::isGFX9Plus(ST) ? llvm::AMDGPU::TTMP0 : llvm::AMDGPU::TBA_LO;

  ExecBaseReg = llvm::AMDGPU::isNotGFX10Plus(ST) ? llvm::AMDGPU::M0
                                                 : llvm::AMDGPU::SGPR_NULL;

  unsigned NumApertureSregs = llvm::AMDGPU::isGFX9_GFX10(ST)  ? 10
                              : llvm::AMDGPU::isGFX11Plus(ST) ? 8
                                                              : 0;
  getRegisterFileArgOrder(ST, FunctionCallArgOrder);

  RegFileSize[llvm::AMDGPU::SGPR0] = 2u * NumSGPRs;
  /// TTMP region has 16 register across all targets; If a new generation
  /// comes with a different encoding, this must be updated
  RegFileSize[TTMPBaseReg] = 2u * 16;
  /// There are 4 slots in the exec mask reg file; We keep the SGPR null even
  /// on targets that don't support it
  RegFileSize[ExecBaseReg] = 2u * 4;
  RegFileSize[llvm::AMDGPU::SRC_VCCZ] = 6;
  RegFileSize[llvm::AMDGPU::SRC_SHARED_BASE] = NumApertureSregs;
  RegFileSize[llvm::AMDGPU::VGPR0] = 2u * NumVGPRs;
  RegFileSize[llvm::AMDGPU::AGPR0] = ST.hasMAIInsts() ? 2u * NumVGPRs : 0u;
  RegFileSize[llvm::AMDGPU::MODE] = 1 << 7;

  /// Reserve two SGPR slots at the top of the kernel SGPR allocation for each
  /// SGPR-aliased special on pre-GFX10, in the order the GPU allocates them:
  /// VCC, then XNACK_MASK, then FLAT_SCR. We store only
  /// the LO-half SGPR MCRegister; HI-half is \c LO + 1 because the SGPR
  /// enum is contiguous. The kernel is guaranteed to carry at least
  /// enough SGPRs for VCC (the SGPR granule on every supported target is
  /// >= 8), so VCC always fits.
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
  if (llvm::AMDGPU::isNotGFX10Plus(ST)) {
    if (ST.getTargetID().isXnackSupported())
      XnackMaskLoSgpr = reserveLoPair();
    if (ST.hasFlatScratchInsts())
      FlatScrLoSgpr = reserveLoPair();
  }
  return llvm::Error::success();
}

std::string MIRToIRTranslator::getSubValueSuffixName(unsigned SubValueStart,
                                                     unsigned NumSubVals) {
  llvm::Twine T(".sub");
  for (unsigned I = SubValueStart; I < SubValueStart + NumSubVals; ++I) {
    T.concat("_" + llvm::Twine(std::to_string(I)));
  }
  return T.concat(".").str();
}

MIRToIRTranslator::RegFileKey
MIRToIRTranslator::getRegFileKey(llvm::MCRegister Reg) const {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] getRegFileKey for reg "
                          << TRI.getName(Reg) << "\n");
  llvm::MCRegister MCReg = getPhysReg(Reg);
  if (MCReg == llvm::AMDGPU::MODE)
    return std::make_tuple(Reg, 0, 2);

  unsigned Enc = TRI.getEncodingValue(MCReg);
  unsigned HwIdx = Enc & llvm::AMDGPU::HWEncoding::REG_IDX_MASK;
  unsigned IsHi16 = (Enc & llvm::AMDGPU::HWEncoding::IS_HI16) ? 1u : 0u;

  llvm::MCRegister BaseReg;
  if (Enc & llvm::AMDGPU::HWEncoding::IS_AGPR)
    BaseReg = llvm::AMDGPU::AGPR0;
  else if (Enc & llvm::AMDGPU::HWEncoding::IS_VGPR)
    BaseReg = llvm::AMDGPU::VGPR0;
  else
    BaseReg = llvm::AMDGPU::SGPR0;

  if (BaseReg == llvm::AMDGPU::SGPR0) {
    /// Pre-GFX10 alias translation: VCC / XNACK_MASK / FLAT_SCR are
    /// reserved at the top of the kernel SGPR allocation, so route them to
    /// the logical SGPR they alias before the encoding lookup. The cache
    /// then naturally shares the slot between VCC-named and SGPR-named
    /// access to the same physical pair.
    if (llvm::AMDGPU::isNotGFX10Plus(ST)) {
      auto rewriteAlias = [&](llvm::MCRegister AliasReg,
                              llvm::MCRegister LogicalBase) -> bool {
        if (!TRI.regsOverlap(Reg, AliasReg))
          return false;
        HwIdx = TRI.getEncodingValue(LogicalBase) &
                llvm::AMDGPU::HWEncoding::REG_IDX_MASK;
        return true;
      };
      for (auto [AliasReg, LogicalBase] :
           std::initializer_list<std::pair<llvm::MCRegister, llvm::MCRegister>>{
               {llvm::AMDGPU::VCC, VccLoSgpr},
               {llvm::AMDGPU::XNACK_MASK, XnackMaskLoSgpr},
               {llvm::AMDGPU::FLAT_SCR, FlatScrLoSgpr}}) {
        if (rewriteAlias(AliasReg, LogicalBase))
          break;
      }
    }
    /// Take care of special SGPR registers
    if (HwIdx >= RegFileSize.at(llvm::AMDGPU::SGPR0) / 2) {
      /// We sort the checks based on the frequency of the register files
      /// accessed

      unsigned VCCZBaseIdx =
          TRI.getEncodingValue(getPhysReg(llvm::AMDGPU::SRC_VCCZ)) &
          llvm::AMDGPU::HWEncoding::REG_IDX_MASK;
      unsigned ExecBaseIdx = TRI.getEncodingValue(getPhysReg(ExecBaseReg)) &
                             llvm::AMDGPU::HWEncoding::REG_IDX_MASK;
      unsigned TTmpBaseIdx = TRI.getEncodingValue(getPhysReg(TTMPBaseReg)) &
                             llvm::AMDGPU::HWEncoding::REG_IDX_MASK;
      unsigned SharedBaseIdx =
          TRI.getEncodingValue(getPhysReg(llvm::AMDGPU::SRC_SHARED_BASE)) &
          llvm::AMDGPU::HWEncoding::REG_IDX_MASK;

      if (HwIdx >= VCCZBaseIdx && HwIdx < VCCZBaseIdx + 6) {
        BaseReg = llvm::AMDGPU::SRC_VCCZ;
      } else if (HwIdx >= ExecBaseIdx && HwIdx < ExecBaseIdx + 4) {
        BaseReg = ExecBaseReg;
      } else if (HwIdx >= TTmpBaseIdx && HwIdx < TTmpBaseIdx + 16) {
        BaseReg = TTMPBaseReg;
      } else if (llvm::AMDGPU::isGFX9Plus(ST) && HwIdx >= SharedBaseIdx &&
                 SharedBaseIdx < RegFileSize.at(getPhysReg(
                                     llvm::AMDGPU::SRC_SHARED_BASE))) {
        BaseReg = getPhysReg(llvm::AMDGPU::SRC_SHARED_BASE);
      } else
        llvm_unreachable("SGPR is not contained in any register file");
    }
  }

  unsigned BaseHwIdx =
      TRI.getEncodingValue(BaseReg) & llvm::AMDGPU::HWEncoding::REG_IDX_MASK;

  unsigned Offset = (HwIdx - BaseHwIdx) * 2 + IsHi16;

  unsigned RegSizeBits = getPhysRegisterSize(Reg);

  auto Key = std::make_tuple(BaseReg, Offset, RegSizeBits / RegGranule);
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] -> Key: base="
                          << TRI.getName(BaseReg) << " offset=" << Offset
                          << " halves=" << std::get<2>(Key) << "\n");
  return Key;
}

std::string MIRToIRTranslator::getRegfileValueName(llvm::MCRegister BaseReg) {
  switch (BaseReg) {
  case llvm::AMDGPU::SGPR0:
    return "sgpr_file";
  case llvm::AMDGPU::VGPR0:
    return "vgpr_file";
  case llvm::AMDGPU::AGPR0:
    return "agpr_file";
  default:
    if (BaseReg == TTMPBaseReg)
      return "ttmp_file";
    else if (BaseReg == ExecBaseReg)
      return "exec_file";
    else if (BaseReg == llvm::AMDGPU::SRC_SHARED_BASE)
      return "apreture_file";
    else if (BaseReg == llvm::AMDGPU::SRC_VCCZ)
      return "vccz_file";
    else
      assert(BaseReg == llvm::AMDGPU::MODE && "Invalid register file base");
    return "hw_reg_file";
  }
}

llvm::Value *MIRToIRTranslator::getRegisterFile(
    const llvm::MachineBasicBlock &MBB, llvm::MCRegister Reg,
    llvm::IRBuilderBase &Builder, llvm::Type *LaneTy) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] getRegisterFile: MBB "
                          << MBB.getNumber() << " reg=" << TRI.getName(Reg)
                          << "\n");
  llvm::MCRegister RegFileBaseReg = std::get<0>(getRegFileKey(Reg));
  unsigned NumLanes16 = RegFileSize[RegFileBaseReg];
  RegFileKey MegaKey = std::make_tuple(RegFileBaseReg, 0, NumLanes16);

  if (!LaneTy)
    LaneTy = Builder.getInt32Ty();
  assert(LaneTy->isIntegerTy() && !LaneTy->isVectorTy() &&
         "Lane type is not a scalar integer type");

  unsigned LaneSize = LaneTy->getPrimitiveSizeInBits();
  assert(LaneSize % RegGranule == 0 && "Lane size is not divisible by 16");
  assert(NumLanes16 != 0 &&
         "register file is not modeled for the current target");

  unsigned NumRegFileLanes = NumLanes16 * RegGranule / LaneSize;

  auto *VecTy = llvm::FixedVectorType::get(LaneTy, NumRegFileLanes);

  return &getOperandAsValue(MBB, MegaKey, Builder, VecTy);
}

llvm::Value *MIRToIRTranslator::getRegisterFile(const llvm::MachineInstr &MI,
                                                llvm::MCRegister Register,
                                                llvm::Type *LaneTy) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::Instruction *TermInst = BB->getTerminator();

  llvm::MCRegister BaseReg = std::get<0>(getRegFileKey(Register));

  std::string ValueName = getRegfileValueName(BaseReg);
  llvm::IRBuilder<llvm::InstSimplifyFolder, llvm::IRBuilderCallbackInserter>
      Builder(BB->getContext(), llvm::InstSimplifyFolder{MF.getDataLayout()},
              llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                annotateUniformIfNeeded(I, TRI, Register);
                LLVM_DEBUG(
                    llvm::dbgs()
                    << "[MIRToIRTranslator] Inserting read reg instruction "
                    << *I << "\n");
              }});
  TermInst ? Builder.SetInsertPoint(TermInst) : Builder.SetInsertPoint(BB);

  return getRegisterFile(*MBB, Register, Builder, LaneTy);
}

void MIRToIRTranslator::setRegisterFile(const llvm::MachineInstr &MI,
                                        llvm::MCRegister Reg,
                                        llvm::Value *NewVec) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");
  llvm::Instruction *TermInst = BB->getTerminator();

  llvm::MCRegister BaseReg = std::get<0>(getRegFileKey(Reg));

  std::string ValueName = getRegfileValueName(BaseReg);
  llvm::IRBuilder<llvm::InstSimplifyFolder, llvm::IRBuilderCallbackInserter>
      Builder(BB->getContext(), llvm::InstSimplifyFolder{MF.getDataLayout()},
              llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                annotateUniformIfNeeded(I, TRI, Reg);
                LLVM_DEBUG(
                    llvm::dbgs()
                    << "[MIRToIRTranslator] Inserting read reg instruction "
                    << *I << "\n");
              }});
  TermInst ? Builder.SetInsertPoint(TermInst) : Builder.SetInsertPoint(BB);

  setRegisterFile(*MBB, Reg, Builder, NewVec);
}

void MIRToIRTranslator::setRegisterFile(const llvm::MachineBasicBlock &MBB,
                                        llvm::MCRegister Reg,
                                        llvm::IRBuilderBase &Builder,
                                        llvm::Value *Val) {
  llvm::MCRegister RegFileBaseReg = std::get<0>(getRegFileKey(Reg));
  unsigned NumLanes16 = RegFileSize[RegFileBaseReg];
  RegFileKey MegaKey = std::make_tuple(RegFileBaseReg, 0, NumLanes16);

  setRegOperandValue(MBB, MegaKey, Builder, Val);
}

llvm::FunctionType *MIRToIRTranslator::getStandardDeviceFunctionType() const {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Getting standard device "
                             "function type for '"
                          << MF.getName() << "'\n");
  llvm::Function &F = MF.getFunction();
  if (F.getCallingConv() != llvm::CallingConv::AMDGPU_KERNEL)
    return F.getFunctionType();
  llvm::LLVMContext &Ctx = F.getContext();
  std::vector<llvm::Type *> Fields;
  unsigned TotalNumArgs = 0;
  for (llvm::MCRegister RegFileBase : FunctionCallArgOrder) {
    TotalNumArgs += RegFileSize.at(RegFileBase) / 2;
  }

  Fields.reserve(TotalNumArgs);
  auto *I32 = llvm::Type::getInt32Ty(Ctx);
  for (unsigned I = 0; I < TotalNumArgs; ++I) {
    Fields.push_back(I32);
  }

  llvm::FunctionType *FuncTy =
      llvm::FunctionType::get(llvm::Type::getVoidTy(Ctx), Fields,
                              /*isVarArg=*/false);

  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] device "
                             "function type: "
                          << *FuncTy << "\n");

  return FuncTy;
}

void MIRToIRTranslator::initDeviceFunctionEntryRegs(
    llvm::IRBuilderBase &Builder) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Initializing device function "
                             "entry registers for '"
                          << MF.getName() << "' with "
                          << MF.getFunction().arg_size() << " arguments\n");
  llvm::Function &F = const_cast<llvm::Function &>(MF.getFunction());

  const llvm::MachineBasicBlock &EntryMBB = MF.front();
  RegValueMap &State = VM[EntryMBB];

  unsigned CurrentArgPos = 0;
  llvm::Type *I32 = Builder.getInt32Ty();
  for (llvm::MCRegister RegFileBase : FunctionCallArgOrder) {
    /// store register file entries
    unsigned NumLanes32 = RegFileSize[RegFileBase] / 2u;
    for (unsigned I = 0; I < NumLanes32; ++I) {
      // Each 32-bit GPR spans 2 halves (RegGranule = 16 bits), so SGPR_N lives
      // at offset 2*N in the half-indexed register file.
      State[std::make_tuple(RegFileBase, I * 2, 2)][I32] =
          F.getArg(CurrentArgPos + I);
    }
    CurrentArgPos += NumLanes32;
  }
}

void MIRToIRTranslator::emitIndirectTailCall(const llvm::MachineInstr &MI,
                                             llvm::Value *Target) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Emitting indirect tail call "
                             "in MBB "
                          << MI.getParent()->getNumber()
                          << " target=" << *Target << "\n");
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI has no parent MBB");
  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());

  llvm::IRBuilder Builder{BB};
  llvm::Value *FuncPtr =
      Builder.CreateBitOrPointerCast(Target, Builder.getPtrTy());

  llvm::FunctionType *FTy = getStandardDeviceFunctionType();
  std::vector<llvm::Value *> CallArgs;
  CallArgs.reserve(FTy->getNumParams());

  unsigned CurrentParamIdx = 0;
  for (llvm::MCRegister RegFileBase : FunctionCallArgOrder) {
    unsigned NumLanes32 = RegFileSize[RegFileBase] / 2;
    std::string ValueName = getRegValueName(RegFileBase);
    for (unsigned PI = 0; PI < NumLanes32; ++PI) {
      llvm::IRBuilder<llvm::InstSimplifyFolder, llvm::IRBuilderCallbackInserter>
          RegBuilder(BB->getContext(),
                     llvm::InstSimplifyFolder{MF.getDataLayout()},
                     llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                       LLVM_DEBUG(llvm::dbgs()
                                  << "[MIRToIRTranslator] Inserting reg read "
                                     "instruction "
                                  << *I << "\n");
                     }});
      // Must set an insert point so any materialized instructions are
      // anchored in BB rather than being orphaned (no-parent) instructions.
      RegBuilder.SetInsertPoint(BB);
      // Each 32-bit GPR spans 2 halves, so SGPR_N lives at offset 2*N.
      CallArgs.push_back(&getOperandAsValue(
          *MBB, std::make_tuple(RegFileBase, PI * 2, 2), RegBuilder));
    }
    CurrentParamIdx += NumLanes32;
  }

  llvm::CallInst *Call = Builder.CreateCall(FTy, FuncPtr, CallArgs);
  Call->setTailCallKind(llvm::CallInst::TCK_Tail);

  /// Create an unreachable instruction to end the control flow graph
  Builder.CreateUnreachable();
}

llvm::Value &MIRToIRTranslator::getOperandAsValue(const llvm::MachineInstr &MI,
                                                  llvm::AMDGPU::OpName OpName,
                                                  llvm::Type *OutType) {
  return getOperandAsValue(*TII.getNamedOperand(MI, OpName), OutType);
}

llvm::Value &MIRToIRTranslator::getOperandAsValue(const llvm::MachineInstr &MI,
                                                  llvm::MCRegister Reg,
                                                  llvm::Type *RegType) {
  const llvm::MachineBasicBlock *MBB = MI.getParent();
  assert(MBB && "MI does not have a machine basic block");
  return getOperandAsValue(*MBB, Reg, RegType);
}

llvm::Value &
MIRToIRTranslator::getOperandAsValue(const llvm::MachineOperand &Op,
                                     llvm::Type *OutType) {
  switch (Op.getType()) {
  case llvm::MachineOperand::MO_Register: {
    const llvm::MachineInstr *MI = Op.getParent();
    assert(MI && "Operand does not have a machine instruction");
    return getOperandAsValue(*MI, Op.getReg(), OutType);
  }
  case llvm::MachineOperand::MO_Immediate: {
    const llvm::MachineInstr *MI = Op.getParent();
    assert(MI && "Operand does not have a machine instruction");
    llvm::LLVMContext &Ctx = MF.getFunction().getContext();
    return *llvm::ConstantInt::getSigned(
        OutType ? OutType : llvm::IntegerType::getInt64Ty(Ctx), Op.getImm());
  }
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

  auto *BB = const_cast<llvm::BasicBlock *>(MBB->getBasicBlock());
  assert(BB && "MBB has no IR basic block");

  llvm::Instruction *TermInst = BB->getTerminator();
  std::string ValueName = getRegValueName(Reg);
  llvm::IRBuilder<llvm::InstSimplifyFolder, llvm::IRBuilderCallbackInserter>
      Builder(BB->getContext(), llvm::InstSimplifyFolder{MF.getDataLayout()},
              llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                annotateUniformIfNeeded(I, TRI, Reg);
                LLVM_DEBUG(
                    llvm::dbgs()
                    << "[MIRToIRTranslator] Inserting reg write instruction "
                    << *I << "\n");
              }});
  TermInst ? Builder.SetInsertPoint(TermInst) : Builder.SetInsertPoint(BB);

  unsigned RegSize = getPhysRegisterSize(Reg);
  assert(Val->getType()->getPrimitiveSizeInBits() == RegSize &&
         "Value type's size is not the same as the type of the register");
  (void)RegSize;

  LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                 "[MIRToIRTranslator] Setting register {0} to value {3} for "
                 "MBB {1} (type: {2})\n",
                 TRI.getName(Reg), MBB->getNumber(),
                 *Val->getType()->getScalarType(), *Val));

  setRegOperandValue(*MBB, getRegFileKey(Reg), Builder, Val);
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

void MIRToIRTranslator::setRegOperandValue(const llvm::MachineBasicBlock &MBB,
                                           const RegFileKey &Key,
                                           llvm::IRBuilderBase &Builder,
                                           llvm::Value *Val) {
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] setRegOperandValue: MBB "
                          << MBB.getNumber()
                          << " base=" << TRI.getName(std::get<0>(Key))
                          << " offset=" << std::get<1>(Key)
                          << " halves=" << std::get<2>(Key) << " val=" << *Val
                          << " (type=" << *Val->getType() << ")\n");
  RegValueMap &State = VM[MBB];
  llvm::MCRegister BaseReg = std::get<0>(Key);
  unsigned Offset = std::get<1>(Key);
  unsigned Size = std::get<2>(Key);

  /// Bounds check: silently drop writes that target an unallocated plain
  /// GPR slot. Specials (TTMP/M0/EXEC/NULL/VCC-on-GFX10+) bypass the
  /// check and are always written through.
  unsigned Allocated = RegFileSize[BaseReg];
  if (Offset + Size > Allocated) {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Dropping out-of-range write to "
               << " (offset=" << Offset << " halves=" << Size
               << " allocated=" << Allocated << ")\n");
    return;
  }

  /// Preserve non-overlapping portions of partially-overwritten
  /// super-registers, then erase fully-covered entries.
  invalidateOverlaps(State, Key, Builder);
  State[Key][Val->getType()] = Val;
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
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Fixing up "
                          << ToBeFixedPhis.size() << " PHI nodes\n");
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
        llvm::IRBuilder<llvm::InstSimplifyFolder,
                        llvm::IRBuilderCallbackInserter>
            Builder(It->Phi->getContext(),
                    llvm::InstSimplifyFolder{MF.getDataLayout()},
                    llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                      if (It->Phi->hasMetadata("amdgpu.uniform"))
                        I->setMetadata("amdgpu.uniform",
                                       llvm::MDNode::get(I->getContext(), {}));
                      LLVM_DEBUG(
                          llvm::dbgs()
                          << "[MIRToIRTranslator] Inserting instruction to "
                             "resolve phi: "
                          << *I << "\n");
                    }});
        // Insert just before the predecessor's terminator so all value-defining
        // instructions (asm calls, loads, etc.) already appear above this
        // point
        Builder.SetInsertPoint(PredBB->getTerminator());
        It->Phi->addIncoming(&getOperandAsValue(*PredMBB, It->RegKey, Builder,
                                                It->Phi->getType()),
                             PredBB);
      }
    }
    if (It->Phi->getNumIncomingValues() == 1)
      SingleValuePhis.push_back(It->Phi);
    ToBeFixedPhis.erase(It);
  }

  /// Remove single edge
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
  LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] raiseMachineInstr: " << MI);

  switch (MI.getOpcode()) {

#include "SIInstrSemantics.inc"

  default: {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Unmodelled instruction " << MI << "\n");

    InlineAsmEmitter->emitInlineAsm(
        Builder, MI,
        [&](llvm::MCRegister Reg) -> llvm::Value & {
          return getOperandAsValue(MI, Reg);
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
  /// hardware pre-loaded SGPR/VGPR values. Otherwise the function is a
  /// device function with the standard prototype — seed from its arguments.

  auto *EntryBB = const_cast<llvm::BasicBlock *>(MF.front().getBasicBlock());
  assert(EntryBB && "Entry MBB has no IR basic block");

  llvm::IRBuilder EntryBuilder{EntryBB};
  if (F.getCallingConv() == llvm::CallingConv::AMDGPU_KERNEL)
    initKernelEntryRegs(EntryBuilder);
  else
    initDeviceFunctionEntryRegs(EntryBuilder);

  /// Iterate over the MBBs and raise the machine instructions in each MBB to
  /// LLVM IR
  for (llvm::MachineBasicBlock &MBB : MF) {
    LLVM_DEBUG(llvm::dbgs()
               << "[MIRToIRTranslator] Processing MBB " << MBB.getNumber()
               << " with " << MBB.size() << " instructions\n");
    auto *BB = const_cast<llvm::BasicBlock *>(MBB.getBasicBlock());
    for (llvm::MachineInstr &MI : MBB) {
      LLVM_DEBUG(llvm::dbgs() << "[MIRToIRTranslator] Translating MI: ";
                 MI.print(llvm::dbgs()););
      llvm::IRBuilder<llvm::InstSimplifyFolder, llvm::IRBuilderCallbackInserter>
          Builder(Ctx, llvm::InstSimplifyFolder{MF.getDataLayout()},
                  llvm::IRBuilderCallbackInserter{[&](llvm::Instruction *I) {
                    if (MI.getPCSections())
                      I->setMetadata(llvm::LLVMContext::MD_pcsections,
                                     MI.getPCSections());
                    LLVM_DEBUG(llvm::dbgs()
                               << "[MIRToIRTranslator] Inserting translated "
                                  "instruction "
                               << *I << "\n");
                  }});
      Builder.SetInsertPoint(BB);
      raiseMachineInstr(MI, Builder);
    }
    if (MBB.canFallThrough() && !MBB.back().isBranch() &&
        !BB->getTerminator()) {
      auto NextBB =
          const_cast<llvm::BasicBlock *>(MBB.getNextNode()->getBasicBlock());
      llvm::IRBuilder{BB}.CreateBr(NextBB);
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
