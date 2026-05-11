//===-- IntrinsicMIRLoweringPass.cpp --------------------------------------===//
// Copyright 2022-2025 @ Northeastern University Computer Architecture Lab
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
/// \file
/// This file implements the Intrinsic MIR Lowering Pass.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/IntrinsicMIRLoweringPass.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/Intrinsic/IntrinsicProcessor.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include "luthier/ToolCodeGen/InitialEntryPointAnalysis.h"
#include "luthier/ToolCodeGen/IntrinsicProcessorsAnalysis.h"
#include "luthier/ToolCodeGen/MIRConvenience.h"
#include "luthier/ToolCodeGen/ProcessIntrinsicsAtIRLevelPass.h"
#include "luthier/ToolCodeGen/StateValueArraySpecs.h"
#include "luthier/ToolCodeGen/WrapperAnalysisPasses.h"
#include <AMDGPU.h>
#include <SIInstrInfo.h>
#include <llvm/ADT/BreadthFirstIterator.h>
#include <llvm/CodeGen/LivePhysRegs.h>
#include <llvm/CodeGen/MachineDominators.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/MachineSSAUpdater.h>
#include <llvm/CodeGen/SlotIndexes.h>
#include <llvm/CodeGen/TargetInstrInfo.h>
#include <llvm/CodeGen/TargetSubtargetInfo.h>
#include <llvm/Support/FormatVariadic.h>

namespace luthier {

char IntrinsicMIRLoweringPass::ID = 0;

LUTHIER_INITIALIZE_LEGACY_PASS_BODY(IntrinsicMIRLoweringPass, "mir-lowering",
                                    "Intrinsic MIR lowering pass",
                                    true /* Only looks at CFG */,
                                    false /* Analysis Pass */)

static llvm::SmallVector<std::pair<llvm::InlineAsm::Flag, llvm::Register>>
getInlineAsmArgs(const llvm::MachineInstr &MI) {
  llvm::SmallVector<std::pair<llvm::InlineAsm::Flag, llvm::Register>> Out;
  for (unsigned I = llvm::InlineAsm::MIOp_FirstOperand,
                NumOps = MI.getNumOperands();
       I < NumOps; ++I) {
    const llvm::MachineOperand &MO = MI.getOperand(I);
    if (!MO.isImm())
      continue;
    const llvm::InlineAsm::Flag F(MO.getImm());
    const llvm::Register Reg(MI.getOperand(I + 1).getReg());
    Out.emplace_back(F, Reg);
    // Skip to one before the next operand descriptor, if it exists.
    I += F.getNumOperandRegisters();
  }
  return Out;
}

/// Returns the SGPR register class for \p NumLanes 32-bit sub-registers.
static const llvm::TargetRegisterClass *
getSGPRRegClassForLanes(unsigned NumLanes) {
  switch (NumLanes) {
  case 1:
    return &llvm::AMDGPU::SGPR_32RegClass;
  case 2:
    return &llvm::AMDGPU::SGPR_64RegClass;
  case 4:
    return &llvm::AMDGPU::SGPR_128RegClass;
  default:
    llvm_unreachable("Unsupported lane count for SVA scalar argument");
  }
}

bool IntrinsicMIRLoweringPass::lowerIntrinsics(
    llvm::Module &IModule,
    llvm::DenseMap<llvm::MachineFunction *, PerFunctionSVAInfo> &SVAInfoByMF,
    std::unique_ptr<StateValueArraySpecs> &SVASpecs) {
  bool Changed{false};

  llvm::LLVMContext &Ctx = IModule.getContext();

  llvm::MachineModuleInfo &MMI =
      getAnalysis<llvm::MachineModuleInfoWrapperPass>().getMMI();

  llvm::ModuleAnalysisManager &IMAM =
      getAnalysis<IModuleMAMWrapperPass>().getMAM();

  const auto &IntrinsicsProcessors =
      IMAM.getResult<IntrinsicsProcessorsAnalysis>(IModule);

  auto &TargetModuleAndMAM =
      IMAM.getResult<TargetAppModuleAndMAMAnalysis>(IModule);
  llvm::Module &TargetModule = TargetModuleAndMAM.getTargetAppModule();
  llvm::ModuleAnalysisManager &TargetMAM = TargetModuleAndMAM.getTargetAppMAM();
  bool IsInitialEntryPointKernel =
      TargetMAM.getResult<InitialEntryPointAnalysis>(TargetModule)
          .getInitialEntryPoint()
          .isKernel();

  /// Set of all scalar arguments used across the entire module
  llvm::SmallDenseSet<ScalarValueArgument> ScalarArgumentsUsed{};

  /// If the initial entry point is not a kernel, then we are instrumenting
  /// newly discovered code from an already running instrumented kernel. In
  /// this situation, we have already initialized the SVA to save all possible
  /// scalar arguments just to be safe
  if (!IsInitialEntryPointKernel) {
    for (std::underlying_type_t<ScalarValueArgument> I =
             SCALAR_VALUE_ARGUMENT_FIRST;
         I <= SCALAR_VALUE_ARGUMENT_LAST; I++) {
      ScalarArgumentsUsed.insert(static_cast<ScalarValueArgument>(I));
    }
  }

  for (llvm::Function &F : IModule) {
    bool IsInjectedPayload = F.hasFnAttribute(InjectedPayloadAttribute);
    if (llvm::MachineFunction *MF = MMI.getMachineFunction(F)) {
      const llvm::TargetInstrInfo *TII = MF->getSubtarget().getInstrInfo();
      const llvm::TargetRegisterInfo *TRI =
          MF->getSubtarget().getRegisterInfo();
      llvm::MachineRegisterInfo &MRI = MF->getRegInfo();

      /// Per-function SVA placeholder state
      PerFunctionSVAInfo &MFSVAInfo = SVAInfoByMF[MF];

      /// Cache: (SA, lane_within_SA) -> SGPR_32 IMPLICIT_DEF placeholder vreg.
      /// Prevents creating duplicate readlane placeholders for the same SA lane.
      llvm::DenseMap<std::pair<ScalarValueArgument, uint8_t>, llvm::Register>
          SALaneCache;

      /// Cache: SA -> merged wide-SGPR virtual register (for multi-lane SAs).
      /// The merged register is a REG_SEQUENCE of the per-lane SGPR_32 regs.
      llvm::DenseMap<ScalarValueArgument, llvm::Register> SAMergedCache;

      /// Fixed insertion point for SVA-related instructions in the entry block.
      /// Always insert before the first terminator so the order is deterministic
      /// and all inserted instructions dominate the entire function.
      llvm::MachineBasicBlock::iterator SVAInsertPt =
          MF->front().getFirstTerminator();

      /// To ensure access to physical registers required by intrinsics, we
      /// create an SSAUpdater per non-overlapping physical registers inside
      /// each machine function the first time it is read/written by an
      /// intrinsic. The SSAUpdaters keep track of each physical register's
      /// virtual value in each basic block and materilizes new vregs as
      /// requested by each intrinsic. To ensure PHI nodes are correctly emitted
      /// by the SSAUpdaters, we traverse the MF in dominance order so that each
      /// block has all its predecessors processed before we emit its PHIs.
      /// When a phys reg is read by an intrinsic for the very first time, a
      /// read from the physical register to a virtual register is emitted in
      /// the entry block of the function to be used by the intrinsic. After we
      /// process a return block of the machine function, all physical registers
      /// that have an SSA updater associated with them will have a read from
      /// their virt reg back to their physical register to indicate the value
      /// should be restored. The last instruction of the return block will also
      /// implicitly use the physical registers to indicate to the register
      /// allocator they are indeed used.
      /// If an intrinsic requests access to a physical regunit larger than
      /// what we keep track of, we emit a reg sequenece instruction to
      /// merge the register units together
      llvm::DenseMap<llvm::MCRegister, std::unique_ptr<llvm::MachineSSAUpdater>>
          PhysRegValueSSAUpdaters;

      llvm::MachineDominatorTree &DOMTree =
          getAnalysis<llvm::MachineDominatorTreeWrapperPass>(F).getDomTree();

      for (auto *MBBNode : llvm::breadth_first(DOMTree.getRootNode())) {
        llvm::MachineBasicBlock *MBB = MBBNode->getBlock();
        for (llvm::MachineInstr &MI : llvm::make_early_inc_range(*MBB)) {
          if (!MI.isInlineAsm())
            continue;

          // Identify Luthier intrinsic placeholders by scanning all sections
          // in the !pcsections attachment.  The Luthier section may not be
          // first — other passes may have prepended their own sections.
          // Format: [!"name"[, !aux_data], !"name2"[, !aux_data2], ...]
          // MDStrings are section names; MDNodes are aux data for the
          // preceding section and are skipped when searching.
          llvm::MDNode *PCS = MI.getPCSections();
          if (!PCS)
            continue;

          llvm::StringRef IntrinsicName;
          llvm::MDNode *IntrinsicPayload = nullptr;
          bool IsLuthierIntrinsic = false;
          for (unsigned I = 0, E = PCS->getNumOperands(); I < E; ++I) {
            auto *SectionNameMD =
                llvm::dyn_cast<llvm::MDString>(PCS->getOperand(I));
            if (!SectionNameMD)
              continue; // aux data node — skip
            llvm::StringRef SectionName = SectionNameMD->getString();
            if (!SectionName.starts_with(LuthierIntrinsicPCSectionPrefix))
              continue;
            IntrinsicName = SectionName.drop_front(
                LuthierIntrinsicPCSectionPrefix.size());
            if (I + 1 < E)
              IntrinsicPayload =
                  llvm::dyn_cast<llvm::MDNode>(PCS->getOperand(I + 1));
            IsLuthierIntrinsic = true;
            break;
          }
          if (!IsLuthierIntrinsic)
            continue;

          auto ArgVec = getInlineAsmArgs(MI);

          auto MIBuilder = [&](int Opcode) {
            llvm::MachineInstrBuilder Builder = llvm::BuildMI(
                *MBB, MI, llvm::MIMetadata(MI), TII->get(Opcode));
            /// Don't propagate the PC sections since it's only used for
            /// intrinsic lowering
            Builder->setPCSections(*MF, nullptr);
            return Builder;
          };

          /// SVA scalar argument accessor: returns a virtual register holding
          /// the value of the requested scalar argument.
          ///
          /// For single-lane SAs an SGPR_32 IMPLICIT_DEF placeholder is
          /// created in the entry block on the first request and cached;
          /// subsequent requests for the same (SA, lane) reuse it.  For
          /// multi-lane SAs the individual SGPR_32 placeholders are merged
          /// via a REG_SEQUENCE into a wider SGPR virtual register.
          ///
          /// All IMPLICIT_DEF placeholders are replaced by V_READLANE_B32
          /// instructions in phase 2 of \c runOnModule, once
          /// \c StateValueArraySpecs has been computed and absolute lane
          /// offsets are known.
          auto SVAScalarArgumentAccessor = [&](ScalarValueArgument SA)
              -> llvm::Register {
            unsigned NumLanes = StateValueArraySpecs::getArgumentLaneSize(SA);
            ScalarArgumentsUsed.insert(SA);

            // Fast path: return cached merged register for multi-lane SAs
            if (NumLanes > 1) {
              auto MIt = SAMergedCache.find(SA);
              if (MIt != SAMergedCache.end())
                return MIt->second;
            } else {
              auto It = SALaneCache.find({SA, (uint8_t)0});
              if (It != SALaneCache.end())
                return It->second;
            }

            llvm::MachineBasicBlock &EntryBlock = MF->front();

            // Create the per-function SVA VGPR placeholder on first use.
            // The IMPLICIT_DEF is marked with a pcsections node so a later
            // pre-RA pass can locate it and wire it to the actual SVA VGPR.
            if (!MFSVAInfo.SVAVGPRPlaceholder.isValid()) {
              llvm::Register SVAPlaceholder =
                  MRI.createVirtualRegister(&llvm::AMDGPU::VGPR_32RegClass);
              llvm::MDNode *MarkerNode = llvm::MDNode::get(
                  Ctx, {llvm::MDString::get(Ctx, "luthier.sva_vgpr_placeholder")});
              auto *SVAImplDef =
                  llvm::BuildMI(EntryBlock, SVAInsertPt, llvm::MIMetadata(),
                                TII->get(llvm::AMDGPU::IMPLICIT_DEF),
                                SVAPlaceholder)
                      .getInstr();
              SVAImplDef->setPCSections(*MF, MarkerNode);
              MFSVAInfo.SVAVGPRPlaceholder = SVAPlaceholder;
            }

            // Create per-lane SGPR_32 IMPLICIT_DEF placeholders, caching each.
            // For multi-lane SAs the placeholders are also merged into a
            // REG_SEQUENCE so the caller receives an appropriately sized SGPR.
            static const unsigned SubRegForLane[] = {
                llvm::AMDGPU::sub0, llvm::AMDGPU::sub1,
                llvm::AMDGPU::sub2, llvm::AMDGPU::sub3};

            llvm::SmallVector<llvm::Register, 4> LaneRegs;
            for (uint8_t Lane = 0; Lane < NumLanes; ++Lane) {
              auto Key = std::make_pair(SA, Lane);
              auto It = SALaneCache.find(Key);
              if (It != SALaneCache.end()) {
                LaneRegs.push_back(It->second);
              } else {
                llvm::Register LaneReg =
                    MRI.createVirtualRegister(&llvm::AMDGPU::SGPR_32RegClass);
                llvm::BuildMI(EntryBlock, SVAInsertPt, llvm::MIMetadata(),
                              TII->get(llvm::AMDGPU::IMPLICIT_DEF), LaneReg);
                SALaneCache[Key] = LaneReg;
                MFSVAInfo.Readlanes.push_back({LaneReg, SA, Lane});
                LaneRegs.push_back(LaneReg);
              }
            }

            if (NumLanes == 1)
              return LaneRegs[0];

            // Multi-lane: REG_SEQUENCE into a single wide SGPR virtual reg
            const llvm::TargetRegisterClass *MergedRC =
                getSGPRRegClassForLanes(NumLanes);
            llvm::Register MergedReg = MRI.createVirtualRegister(MergedRC);
            auto RSBuilder =
                llvm::BuildMI(EntryBlock, SVAInsertPt, llvm::MIMetadata(),
                              TII->get(llvm::AMDGPU::REG_SEQUENCE), MergedReg);
            for (uint8_t Lane = 0; Lane < NumLanes; ++Lane)
              RSBuilder.addReg(LaneRegs[Lane]).addImm(SubRegForLane[Lane]);
            SAMergedCache[SA] = MergedReg;
            return MergedReg;
          };

          auto VirtRegBuilder = [&](const llvm::TargetRegisterClass *RC) {
            return MRI.createVirtualRegister(RC);
          };

          /// Physical register accessor: returns a virtual register tracking
          /// the value of the requested physical register within this injected
          /// payload function.  Uses per-root MachineSSAUpdater instances so
          /// that cross-block uses get correct PHIs.  A REG_SEQUENCE merges
          /// multi-root physical registers into a single virtual register.
          auto PhysRegAccessor = [&](llvm::MCRegister Reg) -> llvm::Register {
            if (!IsInjectedPayload)
              LUTHIER_CTX_EMIT_ON_ERROR(
                  Ctx,
                  LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                      "Function {0} is not an injected payload. Physical "
                      "registers can only be accessed inside "
                      "injected payloads",
                      MF->getName())));

            // Collect (root phys reg, virtual sub-reg) pairs.  We need the
            // physical root to compute correct REG_SEQUENCE sub-register
            // indices later; using an enumerate index would be wrong.
            llvm::SmallVector<std::pair<llvm::MCRegister, llvm::Register>, 4>
                RootAndVirtRegs;

            for (llvm::MCRegUnit RegUnit : TRI->regunits(Reg)) {
              for (llvm::MCRegUnitRootIterator Root(RegUnit, TRI);
                   Root.isValid(); ++Root) {
                auto RootPhysRegIt = PhysRegValueSSAUpdaters.find(*Root);
                if (RootPhysRegIt == PhysRegValueSSAUpdaters.end()) {
                  RootPhysRegIt =
                      PhysRegValueSSAUpdaters
                          .insert({*Root,
                                   std::make_unique<llvm::MachineSSAUpdater>(
                                       *MF)})
                          .first;
                  llvm::MachineBasicBlock &EntryBlock = MF->front();
                  EntryBlock.addLiveIn(*Root);
                  const llvm::TargetRegisterClass *RootRegClass =
                      TRI->getPhysRegBaseClass(*Root);

                  if (!RootRegClass)
                    LUTHIER_CTX_EMIT_ON_ERROR(
                        Ctx,
                        LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                            "Physical register {0} doesn't have a reg class",
                            llvm::printReg(*Root, TRI))));
                  const llvm::TargetRegisterClass *RootCrossCopyRegClass =
                      TRI->getCrossCopyRegClass(RootRegClass);
                  if (!RootCrossCopyRegClass)
                    LUTHIER_CTX_EMIT_ON_ERROR(
                        Ctx, LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                                 "Physical register {0} doesn't have a copy "
                                 "reg class",
                                 llvm::printReg(*Root, TRI))));
                  llvm::Register NewRootVirtReg =
                      MRI.createVirtualRegister(RootCrossCopyRegClass);
                  (void)llvm::BuildMI(EntryBlock, EntryBlock.begin(),
                                      llvm::MIMetadata(),
                                      TII->get(llvm::AMDGPU::COPY))
                      .addReg(NewRootVirtReg, llvm::RegState::Define)
                      .addReg(*Root);
                  RootPhysRegIt->getSecond()->Initialize(NewRootVirtReg);
                }
                RootAndVirtRegs.emplace_back(
                    *Root,
                    RootPhysRegIt->getSecond()->GetValueInMiddleOfBlock(MBB));
              }
            }

            if (RootAndVirtRegs.size() == 1)
              return RootAndVirtRegs[0].second;

            // Multiple roots: build a REG_SEQUENCE.  Use
            // TRI->getSubRegIndex(Reg, Root) for each root's sub-register
            // index rather than an enumerate index; the latter would produce
            // 0, 1, 2, … instead of the correct AMDGPU::sub0, sub1, … values.
            auto Builder = MIBuilder(llvm::AMDGPU::REG_SEQUENCE);
            auto MergedReg = VirtRegBuilder(TRI->getPhysRegBaseClass(Reg));
            (void)Builder.addReg(MergedReg, llvm::RegState::Define);

            for (auto [RootPhysReg, VirtSubReg] : RootAndVirtRegs) {
              unsigned SubIdx = TRI->getSubRegIndex(Reg, RootPhysReg);
              (void)Builder.addReg(VirtSubReg).addImm(SubIdx);
            }
            return MergedReg;
          };

          // Set of physical registers written to by the current intrinsic
          llvm::DenseMap<llvm::MCRegister, llvm::Register> ToBeOverwrittenRegs;

          std::optional<IntrinsicProcessor> Processor =
              IntrinsicsProcessors.getProcessorIfRegistered(IntrinsicName);
          if (!Processor.has_value())
            LUTHIER_CTX_EMIT_ON_ERROR(
                Ctx, LUTHIER_MAKE_GENERIC_ERROR(
                         llvm::formatv("Intrinsic processor for {0} was not "
                                       "found in the intrinsic processors.",
                                       IntrinsicName)));
          if (auto Err = Processor->MIRProcessor(
                  *MF, ArgVec, IntrinsicPayload, MIBuilder, VirtRegBuilder,
                  SVAScalarArgumentAccessor, PhysRegAccessor,
                  ToBeOverwrittenRegs)) {
            LUTHIER_CTX_EMIT_ON_ERROR(Ctx, Err);
          }

          // Record overwritten physical registers
          for (const auto &[PhysReg, VirtReg] : ToBeOverwrittenRegs) {
            for (llvm::MCRegUnit RegUnit : TRI->regunits(PhysReg)) {
              for (llvm::MCRegUnitRootIterator Root(RegUnit, TRI);
                   Root.isValid(); ++Root) {
                const llvm::TargetRegisterClass *RootRegClass =
                    TRI->getPhysRegBaseClass(*Root);

                if (!RootRegClass)
                  LUTHIER_CTX_EMIT_ON_ERROR(
                      Ctx,
                      LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                          "Physical register {0} doesn't have a reg class",
                          llvm::printReg(*Root, TRI))));
                const llvm::TargetRegisterClass *RootCrossCopyRegClass =
                    TRI->getCrossCopyRegClass(RootRegClass);
                if (!RootCrossCopyRegClass)
                  LUTHIER_CTX_EMIT_ON_ERROR(
                      Ctx, LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                               "Physical register {0} doesn't have a copy "
                               "reg class",
                               llvm::printReg(*Root, TRI))));

                auto SubIdx = TRI->getSubRegIndex(PhysReg, *Root);

                llvm::Register SubVirtReg =
                    MRI.createVirtualRegister(RootCrossCopyRegClass);
                (void)MIBuilder(llvm::AMDGPU::COPY)
                    .addReg(SubVirtReg, llvm::RegState::Define)
                    .addReg(VirtReg, 0, SubIdx);
                auto RootPhysRegIt = PhysRegValueSSAUpdaters.find(*Root);
                if (RootPhysRegIt == PhysRegValueSSAUpdaters.end()) {
                  RootPhysRegIt =
                      PhysRegValueSSAUpdaters
                          .insert({*Root,
                                   std::make_unique<llvm::MachineSSAUpdater>(
                                       *MF)})
                          .first;
                  RootPhysRegIt->getSecond()->Initialize(SubVirtReg);
                }
                RootPhysRegIt->getSecond()->AddAvailableValue(MBB, SubVirtReg);
              }
            }
          }

          // Remove the inline assembly placeholder of the processed intrinsic
          MI.eraseFromParent();
          Changed |= true;
        }

        // Emit physical register restore COPYs at each return block.
        // This is done after all MIs in the block are processed (not per-MI)
        // so that a block with multiple intrinsic placeholders only emits
        // one set of restores.  Restores are inserted before the first
        // terminator so that RA sees them as live-out values.
        if (MBB->isReturnBlock() && !PhysRegValueSSAUpdaters.empty()) {
          auto FirstTerm = MBB->getFirstTerminator();
          for (auto &[PhysReg, SSAUpdater] : PhysRegValueSSAUpdaters) {
            llvm::Register FinalVReg =
                SSAUpdater->GetValueAtEndOfBlock(MBB);
            (void)llvm::BuildMI(*MBB, FirstTerm, llvm::MIMetadata(),
                                TII->get(llvm::AMDGPU::COPY))
                .addReg(PhysReg, llvm::RegState::Define)
                .addReg(FinalVReg);
            // Add an implicit use of PhysReg to the return terminator so RA
            // treats it as live out of the function.
            MBB->back().addOperand(
                llvm::MachineOperand::CreateReg(PhysReg, false, true));
          }
        }
      }
    }
  }

  /// Now that we have a head count of what scalar argument values all the
  /// intrinsics use across the module we can finalize the layout of the
  /// state-value array
  SVASpecs = StateValueArraySpecs::setModuleSVASpec(IModule, MMI.getTarget(),
                                                    ScalarArgumentsUsed);
  return Changed;
}

bool IntrinsicMIRLoweringPass::runOnModule(llvm::Module &IModule) {
  llvm::DenseMap<llvm::MachineFunction *, PerFunctionSVAInfo> SVAInfoByMF;
  std::unique_ptr<StateValueArraySpecs> SVASpecs{nullptr};

  bool Changed = lowerIntrinsics(IModule, SVAInfoByMF, SVASpecs);

  // Phase 2: replace SGPR_32 IMPLICIT_DEF placeholders emitted by
  // SVAScalarArgumentAccessor with V_READLANE_B32 instructions.
  //
  // Now that SVASpecs is available we know the absolute SVA lane offset for
  // every ScalarValueArgument, so we can emit the real readlane ops.
  if (SVASpecs) {
    llvm::MachineModuleInfo &MMI =
        getAnalysis<llvm::MachineModuleInfoWrapperPass>().getMMI();

    for (auto &[MF, SVAInfo] : SVAInfoByMF) {
      if (SVAInfo.Readlanes.empty())
        continue;

      const llvm::TargetInstrInfo *TII = MF->getSubtarget().getInstrInfo();
      llvm::MachineRegisterInfo &MRI = MF->getRegInfo();
      llvm::Register SVAVGPRPlaceholder = SVAInfo.SVAVGPRPlaceholder;

      for (const PendingSVAReadlane &Entry : SVAInfo.Readlanes) {
        auto LaneIt = SVASpecs->findArgumentLane(Entry.SA);
        assert(LaneIt != SVASpecs->argument_lane_end() &&
               "SA was requested but not found in SVASpecs");
        uint8_t AbsLane = LaneIt->second + Entry.LaneWithinSA;

        // Find and replace the IMPLICIT_DEF that defines SGPRPlaceholder
        llvm::MachineInstr *ImplDef = MRI.getUniqueVRegDef(Entry.SGPRPlaceholder);
        assert(ImplDef && ImplDef->isImplicitDef() &&
               "SVA lane placeholder must be defined by an IMPLICIT_DEF");

        llvm::MachineBasicBlock *DefMBB = ImplDef->getParent();
        llvm::MachineBasicBlock::iterator InsertPt = ImplDef->getIterator();

        llvm::BuildMI(*DefMBB, InsertPt, llvm::MIMetadata(),
                      TII->get(llvm::AMDGPU::V_READLANE_B32),
                      Entry.SGPRPlaceholder)
            .addReg(SVAVGPRPlaceholder)
            .addImm(AbsLane);

        ImplDef->eraseFromParent();
        Changed = true;
      }
    }
  }

  return Changed;
}

void IntrinsicMIRLoweringPass::getAnalysisUsage(llvm::AnalysisUsage &AU) const {
  AU.addRequired<IModuleMAMWrapperPass>();
  AU.addRequired<llvm::MachineModuleInfoWrapperPass>();
  AU.addRequired<llvm::MachineDominatorTreeWrapperPass>();
  ModulePass::getAnalysisUsage(AU);
};

} // namespace luthier
