//===-- TargetModulePatcherPass.cpp -----------------------------*- C++ -*-===//
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
/// \file TargetModulePatcherPass.cpp
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/TargetModulePatcherPass.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/LLVM/Cloning.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include "luthier/ToolCodeGen/IPPredicatedLivenessIModulePass.h"
#include "luthier/ToolCodeGen/InjectedPayloadAndInstPointAnalysis.h"
#include "luthier/ToolCodeGen/MMISlotIndexesAnalysis.h"
#include "luthier/ToolCodeGen/PrePostAmbleEmitter.h"
#include "luthier/ToolCodeGen/SVStorageAndLoadLocations.h"
#include "luthier/ToolCodeGen/StateValueArraySpecs.h"
#include "luthier/ToolCodeGen/StateValueArrayStorage.h"
#include "luthier/ToolCodeGen/WrapperAnalysisPasses.h"

#include <AMDGPU.h>
#include <AMDGPUTargetMachine.h>
#include <GCNSubtarget.h>
#include <SIInstrInfo.h>
#include <SIMachineFunctionInfo.h>
#include <llvm/CodeGen/BranchRelaxation.h>
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineFrameInfo.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/MachinePassManager.h>
#include <llvm/CodeGen/TargetInstrInfo.h>
#include <llvm/CodeGen/TargetRegisterInfo.h>
#include <llvm/CodeGen/TargetSubtargetInfo.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/GlobalAlias.h>
#include <llvm/IR/GlobalIFunc.h>
#include <llvm/IR/GlobalVariable.h>
#include <llvm/IR/Module.h>
#include <llvm/Linker/Linker.h>
#include <llvm/Support/Debug.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Transforms/Utils/Cloning.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-target-module-patcher"

namespace luthier {

char TargetModulePatcherPass::ID = 0;

LUTHIER_INITIALIZE_LEGACY_PASS_BODY(TargetModulePatcherPass,
                                    "target-module-patcher",
                                    "Luthier Target Module Patcher Pass",
                                    /*CFGOnly=*/false,
                                    /*IsAnalysis=*/false)

void TargetModulePatcherPass::getAnalysisUsage(llvm::AnalysisUsage &AU) const {
  AU.addRequired<IModuleMAMWrapperPass>();
  AU.addRequired<LRStateValueStorageAndLoadLocationsAnalysis>();
  AU.addRequired<IModuleIPPredicatedLivenessAnalysis>();
  AU.addRequired<llvm::MachineModuleInfoWrapperPass>();
  llvm::ModulePass::getAnalysisUsage(AU);
}

namespace {

/// Walk the target MF's per-MBB storage intervals from
/// \c SVStorageAndLoadLocations and emit
/// \c currentSVS.emitCodeToSwitchSVS(MI, nextSVS) at every boundary. This
/// makes the SVA actually migrate between storage schemes across the
/// target's control flow — without this, the load plan exists but the
/// runtime state never matches it.
void emitSVSSwitchesForMF(llvm::MachineFunction &MF,
                          const SVStorageAndLoadLocations &SVLocations,
                          const llvm::SlotIndexes &SI) {
  for (llvm::MachineBasicBlock &MBB : MF) {
    llvm::ArrayRef<StateValueStorageSegment> Segments =
        SVLocations.getStorageIntervals(MBB);
    if (Segments.size() < 2)
      continue;
    for (unsigned I = 0, E = Segments.size() - 1; I < E; ++I) {
      const StateValueArrayStorage &Curr = Segments[I].getSVS();
      const StateValueArrayStorage &Next = Segments[I + 1].getSVS();
      if (Curr == Next)
        continue;
      // Resolve the boundary slot index → MI inside MBB. The switch
      // must be emitted before the MI at Segments[I+1].begin(); that's
      // where the runtime location of the SVA changes. SlotIndexes maps
      // a slot to its owning MI (or returns null at non-MI slots like
      // block-end), so we use getInstructionFromIndex and fall back to
      // walking forward to the next instruction within MBB.
      llvm::SlotIndex Boundary = Segments[I + 1].begin();
      llvm::MachineInstr *MI = SI.getInstructionFromIndex(Boundary);
      llvm::MachineBasicBlock::iterator InsertPt;
      if (MI && MI->getParent() == &MBB) {
        InsertPt = MI->getIterator();
      } else {
        // No MI is directly anchored at this slot (e.g., the slot
        // corresponds to a block boundary / deleted MI). Fall back to
        // the first terminator so the switch still happens before any
        // control-flow leaves MBB.
        InsertPt = MBB.getFirstTerminator();
        if (InsertPt == MBB.end())
          InsertPt = MBB.end();
      }
      Curr.emitCodeToSwitchSVS(InsertPt, Next);
    }
  }
}

/// Map a Luthier \c ScalarValueArgument to the AMDGPU
/// \c PreloadedValue that supplies its bits from the HSA kernarg preload.
/// Returns \c std::nullopt for SVA entries that have no kernarg source
/// (e.g., USER_ARG_PTR / IMPLICIT_ARG_OFFSET, which are filled in
/// elsewhere). Used by the initial-entry-kernel setup to find the source
/// SGPR for each requested kernarg spill.
static std::optional<llvm::AMDGPUFunctionArgInfo::PreloadedValue>
preloadedValueForSVA(ScalarValueArgument SA) {
  switch (SA) {
  case WAVEFRONT_PRIVATE_SEGMENT_BUFFER:
    return llvm::AMDGPUFunctionArgInfo::PRIVATE_SEGMENT_BUFFER;
  case KERNEL_ARG_PTR:
    return llvm::AMDGPUFunctionArgInfo::KERNARG_SEGMENT_PTR;
  case DISPATCH_ID:
    return llvm::AMDGPUFunctionArgInfo::DISPATCH_ID;
  case FLAT_SCRATCH:
    return llvm::AMDGPUFunctionArgInfo::FLAT_SCRATCH_INIT;
  case PRIVATE_SEGMENT_WAVE_BYTE_OFFSET:
    return llvm::AMDGPUFunctionArgInfo::PRIVATE_SEGMENT_WAVE_BYTE_OFFSET;
  case DISPATCH_PTR:
    return llvm::AMDGPUFunctionArgInfo::DISPATCH_PTR;
  case QUEUE_PTR:
    return llvm::AMDGPUFunctionArgInfo::QUEUE_PTR;
  case WORK_ITEM_PRIVATE_SEGMENT_SIZE:
    return llvm::AMDGPUFunctionArgInfo::PRIVATE_SEGMENT_SIZE;
  case USER_ARG_PTR:
  case IMPLICIT_ARG_OFFSET:
    return std::nullopt;
  }
  return std::nullopt;
}

/// Emit, at every initial-entry kernel's first instruction, the SVA
/// kernarg-preload setup: scratch/stack setup (when requested) plus an
/// \c emitCodeToStoreSGPRKernelArg for each \c ScalarValueArgument in
/// \c KernelInfo.RequestedKernelArguments. The SVA storage register for
/// the entry MBB comes from \c SVLocations.
llvm::Error emitInitialEntryKernelSetup(
    llvm::MachineModuleInfo &TargetMMI, llvm::Module &TargetModule,
    const FunctionPreambleDescriptor &FPD,
    const SVStorageAndLoadLocations &SVLocations,
    const StateValueArraySpecs &Specs) {
  for (const auto &[KernelMF, KernelInfo] : FPD.Kernels) {
    if (!KernelInfo.usesSVA())
      continue;
    llvm::MachineFunction *MF =
        const_cast<llvm::MachineFunction *>(KernelMF);
    if (!MF || MF->empty())
      continue;
    llvm::MachineBasicBlock &EntryMBB = MF->front();
    if (EntryMBB.empty())
      return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
          "TargetModulePatcherPass: kernel '{0}' has an empty entry MBB; "
          "cannot insert SVA setup",
          MF->getName()));
    llvm::MachineInstr &EntryInstr = EntryMBB.front();

    llvm::ArrayRef<StateValueStorageSegment> EntrySegments =
        SVLocations.getStorageIntervals(EntryMBB);
    if (EntrySegments.empty())
      return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
          "TargetModulePatcherPass: kernel '{0}' has no SVA storage "
          "segment at entry; SV-load-locations analysis is inconsistent",
          MF->getName()));
    llvm::MCRegister SVSStorageReg =
        EntrySegments.front().getSVS().getStateValueStorageReg();

    if (KernelInfo.RequiresScratchAndStackSetup) {
      const llvm::MachineFrameInfo &MFI = MF->getFrameInfo();
      bool UsesDynamicStack = MFI.hasVarSizedObjects();
      unsigned PrivateSegmentFixedSize =
          static_cast<unsigned>(MFI.getStackSize());
      if (auto Err = emitCodeToSetupScratch(EntryInstr, SVSStorageReg,
                                            UsesDynamicStack,
                                            PrivateSegmentFixedSize, Specs))
        return Err;
    }

    const auto &SIMFI = *MF->getInfo<llvm::SIMachineFunctionInfo>();
    for (ScalarValueArgument SA : KernelInfo.RequestedKernelArguments) {
      auto LaneIt = Specs.findArgumentLane(SA);
      if (LaneIt == Specs.argument_lane_end())
        return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
            "TargetModulePatcherPass: kernel '{0}' requests SVA arg {1} "
            "but the SVA specs do not assign it a lane",
            MF->getName(), static_cast<unsigned>(SA)));
      std::optional<llvm::AMDGPUFunctionArgInfo::PreloadedValue> PV =
          preloadedValueForSVA(SA);
      if (!PV)
        continue; // USER_ARG_PTR / IMPLICIT_ARG_OFFSET: filled in elsewhere.
      llvm::MCRegister SrcSGPR = SIMFI.getPreloadedReg(*PV);
      if (!SrcSGPR)
        return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
            "TargetModulePatcherPass: kernel '{0}' requests SVA arg {1} "
            "but the source preloaded SGPR is not enabled on the MF",
            MF->getName(), static_cast<unsigned>(SA)));
      int NumSlots =
          static_cast<int>(StateValueArraySpecs::getArgumentLaneSize(SA));
      if (auto Err = emitCodeToStoreSGPRKernelArg(
              EntryInstr, SrcSGPR, SVSStorageReg, /*SpillSlotStart=*/LaneIt->second,
              NumSlots, /*KillAfterUse=*/false))
        return Err;
    }
  }
  (void)TargetMMI;
  (void)TargetModule;
  return llvm::Error::success();
}

/// Clone an IModule \c MachineFunction's frame layout into the target
/// host \c MachineFunction. Frame indices in the cloned payload MIs will
/// continue to be valid because we add equivalent slots to the host MF
/// in the same index order (with the same offset & alignment). This is
/// a verbatim port of the prior \c PatchLiftedRepresentationPass helper.
void patchFrameInfo(const llvm::MachineFunction &InjectedPayloadMF,
                    llvm::MachineFunction &ToBeInstrumentedMF) {
  auto &SrcMFI = InjectedPayloadMF.getFrameInfo();
  if (!SrcMFI.hasStackObjects())
    return;
  auto &DstMFI = ToBeInstrumentedMF.getFrameInfo();
  DstMFI.setStackSize(DstMFI.getStackSize() + SrcMFI.getStackSize());

  auto CopyObjectProperties = [](llvm::MachineFrameInfo &DstMFI,
                                 const llvm::MachineFrameInfo &SrcMFI,
                                 int SrcFI, int DestFI) {
    if (SrcMFI.isStatepointSpillSlotObjectIndex(SrcFI))
      DstMFI.markAsStatepointSpillSlotObjectIndex(DestFI);
    DstMFI.setObjectSSPLayout(DestFI, SrcMFI.getObjectSSPLayout(SrcFI));
    DstMFI.setObjectZExt(DestFI, SrcMFI.isObjectZExt(SrcFI));
    DstMFI.setObjectSExt(DestFI, SrcMFI.isObjectSExt(SrcFI));
  };
  for (int I = 0, E = SrcMFI.getNumObjects() - SrcMFI.getNumFixedObjects();
       I != E; ++I) {
    if (SrcMFI.isDeadObjectIndex(I))
      continue;
    int NewFI;
    if (SrcMFI.isVariableSizedObjectIndex(I)) {
      NewFI = DstMFI.CreateVariableSizedObject(SrcMFI.getObjectAlign(I),
                                               SrcMFI.getObjectAllocation(I));
    } else {
      NewFI = DstMFI.CreateStackObject(
          SrcMFI.getObjectSize(I), SrcMFI.getObjectAlign(I),
          SrcMFI.isSpillSlotObjectIndex(I), SrcMFI.getObjectAllocation(I),
          SrcMFI.getStackID(I));
      DstMFI.setObjectOffset(NewFI, SrcMFI.getObjectOffset(I));
    }
    CopyObjectProperties(DstMFI, SrcMFI, I, NewFI);
  }
  for (int I = -1; I >= (int)-SrcMFI.getNumFixedObjects(); --I) {
    if (SrcMFI.isDeadObjectIndex(I))
      continue;
    int NewFI = DstMFI.CreateFixedObject(
        SrcMFI.getObjectSize(I), SrcMFI.getObjectOffset(I),
        SrcMFI.isImmutableObjectIndex(I), SrcMFI.isAliasedObjectIndex(I));
    CopyObjectProperties(DstMFI, SrcMFI, I, NewFI);
  }
}

/// Inline-clone the body of \p InjectedPayloadMF directly before
/// \p InsertionPointMI in the host MF, splitting the host MBB at the
/// insertion point so that the payload's return blocks branch through
/// to the continuation. \p VMap maps GVs in the IModule to their
/// counterparts in the target module so cross-module operands
/// resolve. Verbatim port of the prior PatchLiftedRepresentationPass
/// helper, scoped down to the inline path (per the new design
/// decision to always inline payloads at their IP).
void inlineInjectedPayload(
    const llvm::MachineFunction &InjectedPayloadMF,
    llvm::MachineInstr &InsertionPointMI,
    llvm::DenseMap<const llvm::MachineBasicBlock *,
                   llvm::MachineBasicBlock *> &MBBMap,
    const llvm::ValueToValueMapTy &VMap) {
  auto &InsertionPointMBB = *InsertionPointMI.getParent();
  auto &ToBeInstrumentedMF = *InsertionPointMI.getMF();
  unsigned NumReturnBlocksInHook = 0;
  const llvm::MachineBasicBlock *HookLastReturnMBB = nullptr;
  llvm::MachineBasicBlock *HookLastReturnMBBDest = nullptr;

  for (auto It = InjectedPayloadMF.rbegin(), End = InjectedPayloadMF.rend();
       It != End; ++It) {
    if (It->isReturnBlock() && HookLastReturnMBB == nullptr) {
      HookLastReturnMBB = &*It;
      NumReturnBlocksInHook++;
    }
  }
  if (!HookLastReturnMBB) {
    llvm::report_fatal_error(
        "TargetModulePatcherPass: payload MF has no return block");
  }

  if (InjectedPayloadMF.size() > 1) {
    if (InsertionPointMI.getIterator() != InsertionPointMBB.begin())
      HookLastReturnMBBDest =
          InsertionPointMBB.splitAt(*InsertionPointMI.getPrevNode());
    else
      HookLastReturnMBBDest = &InsertionPointMBB;
    if (NumReturnBlocksInHook == 1)
      MBBMap.insert({HookLastReturnMBB, HookLastReturnMBBDest});
  }

  for (const auto &HookMBB : InjectedPayloadMF) {
    if (HookMBB.isEntryBlock()) {
      if (InsertionPointMI.getIterator() != InsertionPointMBB.begin()) {
        MBBMap.insert({&HookMBB, &InsertionPointMBB});
      } else if (InjectedPayloadMF.size() == 1) {
        MBBMap.insert({&InjectedPayloadMF.front(), &InsertionPointMBB});
      } else {
        auto *NewEntryBlock = ToBeInstrumentedMF.CreateMachineBasicBlock();
        ToBeInstrumentedMF.insert(HookLastReturnMBBDest->getIterator(),
                                  NewEntryBlock);
        llvm::SmallVector<llvm::MachineBasicBlock *, 2> PredMBBs;
        for (auto It = InsertionPointMBB.pred_begin();
             It != InsertionPointMBB.pred_end(); ++It) {
          auto *PredMBB = *It;
          PredMBB->addSuccessor(NewEntryBlock);
          PredMBBs.push_back(PredMBB);
        }
        for (auto *PredMBB : PredMBBs)
          PredMBB->removeSuccessor(&InsertionPointMBB);
        NewEntryBlock->addSuccessor(&InsertionPointMBB);
        MBBMap.insert({&InjectedPayloadMF.front(), NewEntryBlock});
      }
    } else if (HookMBB.isReturnBlock()) {
      if (NumReturnBlocksInHook > 1 || &HookMBB != HookLastReturnMBB) {
        auto *TargetReturnBlock = ToBeInstrumentedMF.CreateMachineBasicBlock();
        ToBeInstrumentedMF.insert(HookLastReturnMBBDest->getIterator(),
                                  TargetReturnBlock);
        MBBMap.insert({&HookMBB, TargetReturnBlock});
      }
    } else {
      auto *NewHookMBB = ToBeInstrumentedMF.CreateMachineBasicBlock();
      ToBeInstrumentedMF.insert(HookLastReturnMBBDest->getIterator(),
                                NewHookMBB);
      MBBMap.insert({&HookMBB, NewHookMBB});
    }
  }

  for (auto &MBB : InjectedPayloadMF) {
    auto *DstMBB = MBBMap[&MBB];
    for (auto It = MBB.succ_begin(), IterEnd = MBB.succ_end(); It != IterEnd;
         ++It) {
      auto *DstSuccMBB = MBBMap[*It];
      if (!DstMBB->isSuccessor(DstSuccMBB))
        DstMBB->addSuccessor(DstSuccMBB, MBB.getSuccProbability(It));
    }
    if (MBB.isReturnBlock() && NumReturnBlocksInHook > 1) {
      if (!DstMBB->isSuccessor(HookLastReturnMBBDest))
        DstMBB->addSuccessor(HookLastReturnMBBDest);
    }
  }

  const llvm::TargetSubtargetInfo &STI = ToBeInstrumentedMF.getSubtarget();
  const llvm::TargetInstrInfo *TII = STI.getInstrInfo();
  const llvm::TargetRegisterInfo *TRI = STI.getRegisterInfo();
  auto &TargetMFMRI = ToBeInstrumentedMF.getRegInfo();
  (void)TargetMFMRI;

  llvm::DenseSet<const uint32_t *> ConstRegisterMasks;
  for (const uint32_t *Mask : TRI->getRegMasks())
    ConstRegisterMasks.insert(Mask);

  for (const auto &MBB : InjectedPayloadMF) {
    auto *DstMBB = MBBMap[&MBB];
    llvm::MachineBasicBlock::iterator InsertionPoint;
    if (MBB.isReturnBlock() && NumReturnBlocksInHook == 1)
      InsertionPoint = DstMBB->begin();
    else if (MBB.isEntryBlock() && InjectedPayloadMF.size() == 1)
      InsertionPoint = InsertionPointMI.getIterator();
    else
      InsertionPoint = DstMBB->end();

    for (auto &SrcMI : MBB.instrs()) {
      // Drop the payload's return-edge terminators — the inlined body
      // falls through (or branches) to the host's continuation MBB
      // instead of "returning" to the runtime caller.
      if (MBB.isReturnBlock() && SrcMI.isTerminator())
        break;
      if (SrcMI.isBundle())
        continue;
      const auto &MCID = TII->get(SrcMI.getOpcode());
      auto *DstMI = ToBeInstrumentedMF.CreateMachineInstr(MCID, llvm::DebugLoc(),
                                                          /*NoImplicit=*/true);
      DstMI->setFlags(SrcMI.getFlags());
      DstMI->setAsmPrinterFlag(SrcMI.getAsmPrinterFlags());
      DstMBB->insert(InsertionPoint, DstMI);
      for (auto &SrcMO : SrcMI.operands()) {
        llvm::MachineOperand DstMO(SrcMO);
        DstMO.clearParent();
        if (DstMO.isMBB()) {
          DstMO.setMBB(MBBMap[DstMO.getMBB()]);
        } else if (DstMO.isRegMask()) {
          if (!ConstRegisterMasks.count(DstMO.getRegMask())) {
            uint32_t *DstMask = ToBeInstrumentedMF.allocateRegMask();
            std::memcpy(DstMask, SrcMO.getRegMask(),
                        sizeof(*DstMask) * llvm::MachineOperand::getRegMaskSize(
                                               TRI->getNumRegs()));
            DstMO.setRegMask(DstMask);
          }
        } else if (DstMO.isGlobal()) {
          auto GVEntry = VMap.find(DstMO.getGlobal());
          if (GVEntry == VMap.end()) {
            ToBeInstrumentedMF.getFunction().getContext().emitError(
                llvm::formatv("TargetModulePatcherPass: GV {0} referenced "
                              "by payload MI was not cloned into the "
                              "target module",
                              DstMO.getGlobal()->getName()));
          } else {
            auto *DestGV = llvm::cast<llvm::GlobalValue>(GVEntry->second);
            DstMO.ChangeToGA(DestGV, DstMO.getOffset(), DstMO.getTargetFlags());
          }
        }
        DstMI->addOperand(DstMO);
      }
    }
  }
}

/// Build a VMap that maps each IModule global object (GVs, non-payload
/// non-hook Functions) to a fresh handle created in the target module,
/// and for every IModule function that owns a MachineFunction *and* is
/// neither a payload nor a hook, deep-clone its MIR into the target MMI
/// keyed on the new target-module Function. Returns the VMap so the
/// per-payload inliner can resolve cross-module operands. This subsumes
/// the previous Linker-based approach: we need explicit MF cloning for
/// the non-payload functions, not just IR handles.
llvm::Error
cloneIModuleIntoTarget(llvm::Module &IModule, llvm::Module &TargetModule,
                       const llvm::MachineModuleInfo &IMMI,
                       llvm::MachineModuleInfo &TargetMMI,
                       llvm::ValueToValueMapTy &VMap) {
  for (auto &GV : IModule.globals()) {
    auto *NewGV = new llvm::GlobalVariable(
        TargetModule, GV.getValueType(), GV.isConstant(), GV.getLinkage(),
        /*Initializer=*/nullptr, GV.getName(), /*InsertBefore=*/nullptr,
        GV.getThreadLocalMode(), GV.getType()->getAddressSpace());
    NewGV->copyAttributesFrom(&GV);
    VMap[&GV] = NewGV;
  }

  for (auto &F : IModule.functions()) {
    if (IMMI.getMachineFunction(F) == nullptr)
      continue;
    if (F.hasFnAttribute(HookAttribute) ||
        F.hasFnAttribute(InjectedPayloadAttribute))
      continue;
    auto *NewF = llvm::Function::Create(
        llvm::cast<llvm::FunctionType>(F.getValueType()), F.getLinkage(),
        F.getAddressSpace(), F.getName(), &TargetModule);
    // Empty entry block + unreachable so the IR is well-formed; the
    // real behavior lives in the cloned MF.
    auto *BB = llvm::BasicBlock::Create(TargetModule.getContext(), "", NewF);
    new llvm::UnreachableInst(TargetModule.getContext(), BB);
    VMap[&F] = NewF;

    auto NewMF = cloneMF(IMMI.getMachineFunction(F), VMap, TargetMMI);
    if (!NewMF)
      return NewMF.takeError();
    TargetMMI.insertFunction(*NewF, std::move(*NewMF));
  }

  return llvm::Error::success();
}

/// Strip the `amdgpu-num-vgpr` and `amdgpu-num-sgpr` attributes from every
/// function in \p TargetModule. These were set by CodeDiscoveryPass based
/// on the original (pre-instrumentation) code-object's register usage,
/// but are no longer accurate after our instrumentation extends the
/// register footprint. Leaving them present would mislead the LLVM
/// AMDGPU backend's register-pressure heuristics on the next codegen
/// pass over the target.
void stripStaleNumRegsAttrs(llvm::Module &TargetModule) {
  for (llvm::Function &F : TargetModule.functions()) {
    F.removeFnAttr("amdgpu-num-vgpr");
    F.removeFnAttr("amdgpu-num-sgpr");
  }
}

/// Walk every non-indirect branch in \p MF, sum byte sizes via
/// \c TII.getInstSizeInBytes to estimate per-MBB layout offsets, and
/// report any branch whose target lies beyond \c s_branch's signed
/// 16-bit-word range (±131,068 bytes). When out-of-range branches are
/// found we currently emit a diagnostic and return their count — the
/// actual relax-to-\c s_setpc_b64 rewrite (with SGPR scavenging from
/// per-MBB live-ins and SVA-lane spill fallback per
/// \c StateValueArraySpecs::findLowestFreeLanes) is the next phase.
///
/// Why we need this even though stock LLVM \c BranchRelaxationPass
/// exists: \c CodeGenerator::printAssemblyFile invokes
/// \c TM.addAsmPrinter directly, skipping the standard post-RA
/// machine-pass chain. So no LLVM pass runs between TargetModulePatcher
/// and AsmPrinter; out-of-range branches would be silently emitted
/// with truncated displacements.
/// One entry per direct branch whose target lies beyond \c s_branch's
/// signed 16-bit-word range. Populated by \c detectOutOfRangeBranches
/// and consumed by the eventual \c s_setpc_b64 rewriter (task #26
/// rewrite phase, not yet implemented).
struct OutOfRangeBranchRecord {
  const llvm::MachineFunction *MF;
  const llvm::MachineInstr *Branch;
  const llvm::MachineBasicBlock *Target;
  int64_t BranchOffset;
  int64_t Delta;
};

unsigned
detectOutOfRangeBranches(const llvm::MachineFunction &MF,
                         llvm::SmallVectorImpl<OutOfRangeBranchRecord> &Out) {
  static constexpr int64_t kSBranchMaxBytes = (1LL << 18) - 4;
  const auto &TII = *MF.getSubtarget().getInstrInfo();
  llvm::DenseMap<const llvm::MachineBasicBlock *, int64_t> MBBOffset;
  int64_t Cursor = 0;
  for (const auto &MBB : MF) {
    MBBOffset[&MBB] = Cursor;
    for (const auto &MI : MBB)
      Cursor += TII.getInstSizeInBytes(MI);
  }
  unsigned NumOutOfRange = 0;
  Cursor = 0;
  for (const auto &MBB : MF) {
    int64_t MIOffset = Cursor;
    for (const auto &MI : MBB) {
      if (MI.isBranch() && !MI.isIndirectBranch()) {
        if (auto *TargetMBB = TII.getBranchDestBlock(MI)) {
          int64_t TgtOff = MBBOffset[TargetMBB];
          int64_t Delta = TgtOff - (MIOffset + TII.getInstSizeInBytes(MI));
          if (Delta > kSBranchMaxBytes || Delta < -kSBranchMaxBytes) {
            ++NumOutOfRange;
            Out.push_back({&MF, &MI, TargetMBB, MIOffset, Delta});
          }
        }
      }
      MIOffset += TII.getInstSizeInBytes(MI);
    }
    Cursor = MIOffset;
  }
  return NumOutOfRange;
}

} // namespace

bool TargetModulePatcherPass::runOnModule(llvm::Module &IModule) {
  LLVM_DEBUG(llvm::dbgs() << "=== " << getPassName() << " ===\n");

  llvm::LLVMContext &Ctx = IModule.getContext();
  llvm::ModuleAnalysisManager &IMAM =
      getAnalysis<IModuleMAMWrapperPass>().getMAM();
  llvm::MachineModuleInfo &TargetMMI =
      getAnalysis<llvm::MachineModuleInfoWrapperPass>().getMMI();

  auto &TargetModAndMAM = IMAM.getResult<TargetAppModuleAndMAMAnalysis>(IModule);
  llvm::Module &TargetModule = TargetModAndMAM.getTargetAppModule();
  llvm::ModuleAnalysisManager &TargetMAM = TargetModAndMAM.getTargetAppMAM();

  const SVStorageAndLoadLocations &SVLocations =
      getAnalysis<LRStateValueStorageAndLoadLocationsAnalysis>().getResult();

  const llvm::TargetMachine &TM =
      TargetMMI.getTarget();
  std::unique_ptr<StateValueArraySpecs> SVASpecs =
      StateValueArraySpecs::getSVASpecs(IModule, TM);
  if (!SVASpecs) {
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx, LUTHIER_MAKE_GENERIC_ERROR(
                 "TargetModulePatcherPass: StateValueArraySpecs::getSVASpecs "
                 "returned null; expected the IModule to carry SVA-spec "
                 "metadata by this stage"));
    return false;
  }

  const FunctionPreambleDescriptor &FPD =
      TargetMAM.getResult<FunctionPreambleDescriptorAnalysis>(TargetModule);

  const MMISlotIndexesAnalysis::Result &SlotIndexes =
      TargetMAM.getResult<MMISlotIndexesAnalysis>(TargetModule);

  // ============= Phase A: SVA Setup & Storage Code Emission ===============
  //
  // For each target MF, walk SVStorageAndLoadLocations'
  // StateValueStorageIntervals and emit the SVS switch code at each
  // interval boundary. The initial-entry-point kernel additionally needs
  // the kernarg-preload setup sequence at its entry; that's deferred to
  // the next iteration alongside the FPD-keyed iteration. For now we
  // emit only the per-MBB switches — which is the part that exercises
  // the cross-MBB storage relocation logic.
  bool Changed = false;
  for (const llvm::Function &F : TargetModule) {
    llvm::MachineFunction *MF = TargetMMI.getMachineFunction(F);
    if (!MF)
      continue;
    emitSVSSwitchesForMF(*MF, SVLocations, SlotIndexes.at(*MF));
    Changed = true;
  }

  // Phase A.2: initial-entry-kernel SVA preload setup (scratch + kernarg
  // spills into SVA lanes) at every kernel entry that uses the SVA.
  if (auto Err = emitInitialEntryKernelSetup(TargetMMI, TargetModule, FPD,
                                             SVLocations, *SVASpecs)) {
    LUTHIER_CTX_EMIT_ON_ERROR(Ctx, std::move(Err));
    return Changed;
  }

  // ============= Phase B: Target Patching ===============================
  //
  // Step 1: Clone IModule globals + non-payload non-hook Functions (with
  // their MachineFunctions) into the target module/MMI. The returned VMap
  // is used by the inliner so cross-module operands resolve.
  llvm::MachineModuleInfo &IMMI =
      getAnalysis<llvm::MachineModuleInfoWrapperPass>().getMMI();
  llvm::ValueToValueMapTy VMap;
  if (auto Err =
          cloneIModuleIntoTarget(IModule, TargetModule, IMMI, TargetMMI, VMap)) {
    LUTHIER_CTX_EMIT_ON_ERROR(Ctx, std::move(Err));
    return Changed;
  }

  // Step 2: Strip stale num-{vgpr,sgpr} attrs — CodeDiscoveryPass set
  // these from the original code object, and they're wrong now that
  // we've inlined payloads + cloned helpers.
  stripStaleNumRegsAttrs(TargetModule);

  // Step 3: Inline every injected payload at its corresponding target
  // MachineInstr. Following the design directive, payload MIs (minus
  // their return terminators) are deep-cloned into the host MF right
  // before the target MI; the payload's return-edge terminators are
  // replaced by fall-through / branch into the host continuation MBB,
  // matching the prior PatchLiftedRepresentationPass inline path.
  const InjectedPayloadAndInstPoint &IPIP =
      IMAM.getResult<InjectedPayloadAndInstPointAnalysis>(IModule);

  for (const auto &[InjectedPayloadFunc, InsertionPointMI] :
       IPIP.payload_mi()) {
    llvm::DenseMap<const llvm::MachineBasicBlock *, llvm::MachineBasicBlock *>
        MBBMap;
    const auto *InjectedPayloadMF =
        IMMI.getMachineFunction(*InjectedPayloadFunc);
    if (!InjectedPayloadMF) {
      LUTHIER_CTX_EMIT_ON_ERROR(
          Ctx, LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                   "TargetModulePatcherPass: payload function '{0}' has no "
                   "MachineFunction in the IModule MMI",
                   InjectedPayloadFunc->getName())));
      return Changed;
    }
    patchFrameInfo(*InjectedPayloadMF, *InsertionPointMI->getParent()->getParent());
    inlineInjectedPayload(*InjectedPayloadMF, *InsertionPointMI, MBBMap, VMap);
  }

  // Post-inline branch displacement check. CodeGenerator::printAssemblyFile
  // invokes AsmPrinter directly with no intermediate machine-pass chain, so
  // LLVM's BranchRelaxationPass never runs on the target module — out-of-range
  // branches would otherwise be silently truncated by the encoder. For now we
  // count + diagnose; the actual relaxation (s_setpc_b64 + SGPR scavenging
  // via per-MBB live-ins, falling back to spilling two app SGPRs into the
  // lowest free SVA lanes per StateValueArraySpecs::findLowestFreeLanes) is
  // the next phase.
  // Phase B step 4: invoke LLVM's stock BranchRelaxationPass on every
  // patched target MF. CodeGenerator::printAssemblyFile takes the MMI
  // straight to AsmPrinter (no addPassesToEmitFile), so far-jumps need
  // explicit relaxation here or they'd silently emit with truncated
  // displacements. The new-PM BranchRelaxationPass::run signature takes
  // an MFAM but doesn't actually consult it — the body just calls the
  // internal BranchRelaxation worker which sets up its own RegScavenger
  // via trackLivenessAfterRegAlloc. We construct an empty MFAM purely
  // to satisfy the signature. Lit-testable via the AMDGPU backend's
  // hidden --amdgpu-s-branch-bits=<N> knob (defined in SIInstrInfo.cpp)
  // which shrinks the s_branch range so small kernels trigger the
  // long-jump path.
  llvm::MachineFunctionAnalysisManager MFAM;
  llvm::BranchRelaxationPass BRPass;
  for (llvm::Function &F : TargetModule) {
    if (auto *MF = TargetMMI.getMachineFunction(F))
      BRPass.run(*MF, MFAM);
  }

  // Sanity-check: re-run the detector and hard-error if anything
  // remains out of range. Either the stock relaxer didn't run (e.g.,
  // AMDGPU-specific corner case) or our offset accounting disagrees
  // with the asm printer's.
  llvm::SmallVector<OutOfRangeBranchRecord, 4> OutOfRange;
  for (const llvm::Function &F : TargetModule) {
    if (auto *MF = TargetMMI.getMachineFunction(F))
      detectOutOfRangeBranches(*MF, OutOfRange);
  }
  if (!OutOfRange.empty()) {
    std::string Detail;
    llvm::raw_string_ostream OS(Detail);
    OS << "TargetModulePatcherPass: " << OutOfRange.size()
       << " branch(es) remain over-range after BranchRelaxationPass; "
       << "branches:";
    for (const auto &R : OutOfRange) {
      OS << "\n  - " << R.MF->getName() << " offset 0x";
      OS.write_hex(static_cast<uint64_t>(R.BranchOffset));
      OS << " → " << R.Target->getName()
         << " (delta " << R.Delta << " bytes)";
    }
    LUTHIER_CTX_EMIT_ON_ERROR(Ctx, LUTHIER_MAKE_GENERIC_ERROR(Detail));
    return Changed;
  }
  return true;
}

} // namespace luthier
