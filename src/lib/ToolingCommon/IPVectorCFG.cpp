//===-- VectorCFG.cpp -----------------------------------------------------===//
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
/// \file IPVectorCFG.cpp
/// Implements the \c VectorMBB and \c VectorCFG classes.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/IPVectorCFG.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/LLVM/CodeGenHelpers.h"
#include "luthier/LLVM/streams.h"
#include "luthier/Tooling/EntryPoint.h"
#include "luthier/Tooling/InitialEntryPointAnalysis.h"
#include <SIInstrInfo.h>
#include <SIMachineFunctionInfo.h>
#include <llvm/ADT/DenseSet.h>
#include <llvm/CodeGen/LivePhysRegs.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/Support/FormatVariadic.h>
#include <luthier/Tooling/TargetMachineInstrMDNode.h>

namespace luthier {

void VectorMBB::setInstRange(
    llvm::MachineBasicBlock::const_instr_iterator Begin,
    llvm::MachineBasicBlock::const_instr_iterator End) {
  Instructions = {Begin, End};
}

std::string VectorMBB::getName() const {
  const ScalarMBB &SMBB = getParent();
  const llvm::MachineFunction &MF = SMBB.getParent().getMF();
  const llvm::MachineBasicBlock *MBB = getParent().getMBB();

  return llvm::formatv("{0}.{1}",
                       MBB ? MBB->getFullName() : MF.getName() + ".none",
                       getGlobalNumber())
      .str();
}

void VectorMBB::print(llvm::raw_ostream &OS, unsigned int Indent) const {
  const auto &ST = getParent().getParent().getMF().getSubtarget();
  const auto TII = ST.getInstrInfo();
  const auto TRI = ST.getRegisterInfo();
  OS.indent(Indent) << "Vector MBB " << getName() << "\n";

  OS.indent(Indent) << "Predecessors: [";
  llvm::interleave(
      Predecessors.begin(), Predecessors.end(),
      [&](const VectorMBB *MBB) { OS << "MBB " << MBB->getName(); },
      [&]() { OS << ", "; });
  OS << "]\n";

  if (!this->empty()) {
    OS.indent(Indent) << "Instructions:\n";
    for (const auto &MI : *this) {
      MI->print(OS.indent(Indent + 2), true, false, false, true, TII);
    }
  }

  OS.indent(Indent) << "Successors: [";
  llvm::interleave(
      Successors.begin(), Successors.end(),
      [&](const VectorMBB *MBB) { OS << "MBB " << MBB->getName(); },
      [&]() { OS << ", "; });
  OS << "]\n";
}

void VectorMBB::dump() const { print(llvm::dbgs(), 0); }

llvm::Expected<std::unique_ptr<ScalarMBB>>
ScalarMBB::createScalarMBB(const llvm::MachineBasicBlock &ParentMBB,
                           VectorCFG &ParentCFG) {
  auto Out = std::unique_ptr<ScalarMBB>(new (std::nothrow)
                                            ScalarMBB(ParentMBB, ParentCFG));
  if (!Out) {
    return LUTHIER_MAKE_GENERIC_ERROR("Failed to create a scalar MBB");
  }

  auto VectorMBBAllocator =
      [&](VectorMBB::ExecMaskValue EMV) -> llvm::Expected<VectorMBB *> {
    auto *VecMBB = new (std::nothrow) VectorMBB(*Out, EMV);
    if (!VecMBB) {
      return LUTHIER_MAKE_GENERIC_ERROR("Failed to create vector MBB");
    }
    Out->VectorMBBs.emplace_back(VecMBB);
    return VecMBB;
  };

  struct ScalarEntryOrExitBlocks {
    VectorMBB *TakenBlock{nullptr};
    VectorMBB *NotTakenBlock{nullptr};
  };

  ScalarEntryOrExitBlocks Entry{};

  ScalarEntryOrExitBlocks Exit{};

  LUTHIER_RETURN_ON_ERROR(
      VectorMBBAllocator(VectorMBB::One).moveInto(Entry.TakenBlock));
  LUTHIER_RETURN_ON_ERROR(
      VectorMBBAllocator(VectorMBB::ZeroOrOne).moveInto(Entry.NotTakenBlock));

  auto *TRI = ParentCFG.getMF().getSubtarget().getRegisterInfo();
  // The currently taken block in the MBB
  auto *CurrentTakenBlock = Entry.TakenBlock;
  // Set of VectorMBBs that are waiting to be connected to the next non-taken
  // block or joined into the next block that starts with a scalar instruction
  llvm::SmallDenseSet<VectorMBB *> NotTakenBlocksWithHangingEdges{
      Entry.NotTakenBlock};

  for (auto MI = ParentMBB.instr_begin(), PrevMI = ParentMBB.instr_end(),
            NextMI = ++ParentMBB.instr_begin();
       MI != ParentMBB.instr_end(); PrevMI = MI, ++MI,
            NextMI = NextMI != ParentMBB.instr_end() ? ++NextMI
                                                     : ParentMBB.instr_end()) {
    // Ignore debug instructions
    if (MI->isDebugInstr())
      continue;
    // Check if the MI is vector (i.e. not scalar nor lane access),
    // whether it writes to the exec mask, and whether the last MI
    // (if exists) was a scalar instruction

    bool IsVector = isVector(*MI);
    bool WritesExecMask = MI->modifiesRegister(llvm::AMDGPU::EXEC, TRI);
    bool IsFormerMIScalar = PrevMI != ParentMBB.instr_end() &&
                            (isScalar(*PrevMI) || isLaneAccess(*PrevMI));
    if (IsVector && (WritesExecMask || IsFormerMIScalar)) {
      // If the current instruction is a vector inst, and if it writes
      // to the exec mask or if the last instruction was a scalar inst,
      // then we need to do a "split": Create a new VectorMBB to
      // replace the current taken block and make the new block the successor
      // of the current block, and then put the just-replaced taken block
      // into the list of not-taken blocks that are yet to be connected
      VectorMBB *NewCurrentTakenBlock{nullptr};
      LUTHIER_RETURN_ON_ERROR(
          VectorMBBAllocator(VectorMBB::One).moveInto(NewCurrentTakenBlock));

      NewCurrentTakenBlock->addPredecessorBlock(*CurrentTakenBlock);
      NotTakenBlocksWithHangingEdges.insert(CurrentTakenBlock);
      CurrentTakenBlock = NewCurrentTakenBlock;

      if (CurrentTakenBlock->empty())
        CurrentTakenBlock->setInstRange(MI, NextMI);
      else
        CurrentTakenBlock->setInstRange(
            CurrentTakenBlock->begin().getIterator(), MI);
    } else if (!IsVector && !IsFormerMIScalar) {
      // Otherwise, if we observe a scalar instruction, we have to do a "join"
      // operation: Create a new VectorMBB to replace the current taken block,
      // and make it the successor of the current taken block. Also make
      // all not taken blocks with hanging edges the predecessor of the new
      // taken block, and then clear the not-taken set
      VectorMBB *NewCurrentTakenBlock{nullptr};
      LUTHIER_RETURN_ON_ERROR(VectorMBBAllocator(VectorMBB::ZeroOrOne)
                                  .moveInto(NewCurrentTakenBlock));

      NewCurrentTakenBlock->addPredecessorBlock(*CurrentTakenBlock);
      for (auto NonTakenBlock : NotTakenBlocksWithHangingEdges) {
        NonTakenBlock->addSuccessorBlock(*NewCurrentTakenBlock);
      }
      NotTakenBlocksWithHangingEdges.clear();
      CurrentTakenBlock = NewCurrentTakenBlock;
    }
    // Add the current instruction to the current taken block
    if (CurrentTakenBlock->empty())
      CurrentTakenBlock->setInstRange(MI, NextMI);
    else
      CurrentTakenBlock->setInstRange(CurrentTakenBlock->begin().getIterator(),
                                      NextMI);

    /// If the current MI is a call, create a new block and set it to the
    /// current taken block
    /// Since calls are scalar, there aren't any not taken blocks with hanging
    /// edges we have to worry about here
    /// We let the IPVectorCFG take care of linking the successors of this
    /// block according to the MI's metadata
    // if (MI->isCall()) {
    //   LUTHIER_RETURN_ON_ERROR(VectorMBBAllocator().moveInto(CurrentTakenBlock));
    // }
  }

  LUTHIER_RETURN_ON_ERROR(
      VectorMBBAllocator(VectorMBB::One).moveInto(Exit.TakenBlock));
  LUTHIER_RETURN_ON_ERROR(
      VectorMBBAllocator(VectorMBB::ZeroOrOne).moveInto(Exit.NotTakenBlock));

  // Connect the current taken block to the exit taken block of the current
  // MBB
  CurrentTakenBlock->addSuccessorBlock(*Exit.TakenBlock);
  // Connect all the non-taken blocks to the exit non-taken block of the
  // current MBB if there are any left; Otherwise, connect the current
  // taken block to the exit not taken block because it must have ended with
  // a join (scalar instruction)
  if (!NotTakenBlocksWithHangingEdges.empty()) {
    for (auto *NonTakenBlock : NotTakenBlocksWithHangingEdges) {
      NonTakenBlock->addSuccessorBlock(*Exit.NotTakenBlock);
    }
  } else {
    CurrentTakenBlock->addSuccessorBlock(*Exit.NotTakenBlock);
  }
  return std::move(Out);
}

llvm::Expected<std::unique_ptr<ScalarMBB>>
ScalarMBB::createEntryScalarMBB(VectorCFG &ParentCFG) {
  std::unique_ptr<ScalarMBB> Out{new (std::nothrow) ScalarMBB(ParentCFG)};
  if (!Out) {
    return LUTHIER_MAKE_GENERIC_ERROR("Failed to create scalar MBB");
  }
  auto *VecMBB = new (std::nothrow) VectorMBB(*Out, VectorMBB::ZeroOrOne);
  if (!VecMBB) {
    return LUTHIER_MAKE_GENERIC_ERROR("Failed to create vector MBB");
  }
  Out->VectorMBBs.emplace_back(VecMBB);
  return std::move(Out);
};

void ScalarMBB::addSuccessor(ScalarMBB &SMBB) {
  this->Exit.TakenBlock->addSuccessorBlock(*SMBB.Entry.TakenBlock);
  this->Exit.NotTakenBlock->addSuccessorBlock(*SMBB.Entry.NotTakenBlock);
}

void ScalarMBB::addPredecessor(ScalarMBB &SMBB) {
  this->Entry.TakenBlock->addPredecessorBlock(*SMBB.Exit.TakenBlock);
  this->Entry.NotTakenBlock->addPredecessorBlock(*SMBB.Exit.NotTakenBlock);
}

void ScalarMBB::eliminateTrivialEmptyBlocks() {
  if (Entry.TakenBlock->empty()) {
  }
}

void ScalarMBB::print(llvm::raw_ostream &OS, unsigned int Indent) const {
  OS.indent(Indent) << "Scalar MBB "
                    << (ParentMBB ? ParentMBB->getFullName()
                                  : getParent().getMF().getName())
                    << ":\n";
  for (const auto &MBB : VectorMBBs) {
    MBB->print(OS, Indent + 2);
    OS << "\n";
  }
}

llvm::Expected<std::unique_ptr<VectorCFG>>
VectorCFG::createVectorCFG(IPVectorCFG &ParentCFG,
                           const llvm::MachineFunction &MF) {
  auto Out = std::unique_ptr<VectorCFG>(new VectorCFG(ParentCFG, MF));
  ScalarMBB *EntryFuncScalarMBB{nullptr};
  if (MF.getInfo<llvm::SIMachineFunctionInfo>()->isEntryFunction() ||
      MF.empty()) {
    auto EntryScalarMBBOrErr = ScalarMBB::createEntryScalarMBB(*Out);
    LUTHIER_RETURN_ON_ERROR(EntryScalarMBBOrErr.takeError());
    EntryFuncScalarMBB = EntryScalarMBBOrErr->get();
    Out->ScalarMBBs.push_back(std::move(*EntryScalarMBBOrErr));
  }

  for (const auto &MBB : MF) {
    auto ScalarMBBOrErr = ScalarMBB::createScalarMBB(MBB, *Out);
    LUTHIER_RETURN_ON_ERROR(ScalarMBBOrErr.takeError());
    Out->MBBToScalarMBBs.insert({&MBB, ScalarMBBOrErr->get()});
    Out->ScalarMBBs.push_back(std::move(*ScalarMBBOrErr));
  }

  // Link scalar MBBs and the entry/exit vector blocks
  for (auto &[MBB, SMBB] : Out->MBBToScalarMBBs) {
    if (EntryFuncScalarMBB && MBB->isEntryBlock()) {
      EntryFuncScalarMBB->addSuccessor(*SMBB);
    }
    for (const auto *MBBSucc : MBB->successors()) {
      SMBB->addSuccessor(*Out->MBBToScalarMBBs.at(MBBSucc));
    }
    for (const auto *MBBPred : MBB->predecessors()) {
      SMBB->addPredecessor(*Out->MBBToScalarMBBs.at(MBBPred));
    }
  }
  return Out;
}

void VectorCFG::print(llvm::raw_ostream &OS) const {
  MF.print(OS);
  OS << "=======";
  OS << "# Vector CFG for Machine Function " << MF.getName() << ":\n";
  OS << "\n";
  for (const auto &SMBB : *this) {
    SMBB.print(OS, 2);
  }
  OS << "\n";
  OS << "\n# End Vector CFG for Machine Function " << MF.getName() << ".\n\n";
}

#if !defined(NDEBUG) || defined(LLVM_ENABLE_DUMP)
void VectorCFG::dump() const { print(llvm::dbgs()); }
#endif

void IPVectorCFG::print(llvm::raw_ostream &OS) const {
  for (const auto &VecCFG : *this) {
    VecCFG.print(OS);
  }
}

#if !defined(NDEBUG) || defined(LLVM_ENABLE_DUMP)
void IPVectorCFG::dump() const { return print(llvm::dbgs()); }
#endif

llvm::Expected<std::unique_ptr<IPVectorCFG>>
IPVectorCFG::calculateIPVectorCFG(llvm::Module &M,
                                  llvm::ModuleAnalysisManager &MAM) {

  llvm::FunctionAnalysisManager &FAM =
      MAM.getResult<llvm::FunctionAnalysisManagerModuleProxy>(M).getManager();

  auto Out = std::unique_ptr<IPVectorCFG>(new IPVectorCFG());

  Out->VectorCFGs.reserve(M.size());
  /// Populate the CFG
  for (llvm::Function &F : M) {
    llvm::MachineFunction &MF =
        FAM.getResult<llvm::MachineFunctionAnalysis>(F).getMF();
    auto VectorCFGOrErr = VectorCFG::createVectorCFG(*Out, MF);
    LUTHIER_RETURN_ON_ERROR(VectorCFGOrErr.takeError());
    Out->MFToVecCFGMap.insert({&MF, VectorCFGOrErr->get()});
    Out->VectorCFGs.emplace_back(std::move(*VectorCFGOrErr));
  }

  /// Link the call and indirect jump instructions + sort the numbering of
  /// all vector CFGs
  unsigned CurrentVectorMBBIdx = 0;
  for (VectorCFG &VecCFG : *Out) {
    for (luthier::ScalarMBB &ScalarMBB : VecCFG) {
      for (luthier::VectorMBB &VectorMBB : ScalarMBB) {
        VectorMBB.setGlobalIndex(CurrentVectorMBBIdx);
        CurrentVectorMBBIdx++;
        if (!VectorMBB.empty()) {
          const llvm::MachineInstr &LastMI = *VectorMBB.back();
          if (LastMI.isCall() || LastMI.isIndirectBranch()) {
            auto *MD = TargetMachineInstrMDNode::getInstrMDNodeIfExists(LastMI);
            if (!MD) {
              return LUTHIER_MAKE_GENERIC_ERROR(
                  "Failed to get the metadata associated with a call or "
                  "indirect "
                  "branch instruction");
            }
            llvm::SmallVector<llvm::Function *> Targets =
                MD->getIndirectBranchAndCallTargets();
            for (llvm::Function *Target : Targets) {
              llvm::MachineFunction &TargetMF =
                  FAM.getResult<llvm::MachineFunctionAnalysis>(*Target).getMF();
              auto &TargetBeginVecMBB = *(*Out)[TargetMF].begin()->begin();
              VectorMBB.addSuccessorBlock(TargetBeginVecMBB);
            }
          }
        } else {
        }
      }
    }
  }
  Out->NumVecMBBs = CurrentVectorMBBIdx;
  return Out;
}

llvm::AnalysisKey IPVectorCFGAnalysis::Key;

bool IPVectorCFGAnalysis::Result::invalidate(
    llvm::Module &M, const llvm::PreservedAnalyses &PA,
    llvm::ModuleAnalysisManager::Invalidator &Inv) {
  auto PAC = PA.getChecker<IPVectorCFGAnalysis>();
  return !PAC.preserved() &&
         !PAC.preservedSet<llvm::AllAnalysesOn<
             llvm::MachineFunctionAnalysisManagerModuleProxy>>() &&
         !PAC.preservedSet<llvm::CFGAnalyses>();
}

IPVectorCFGAnalysis::Result
IPVectorCFGAnalysis::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM) {
  llvm::LLVMContext &Ctx = M.getContext();
  llvm::Expected<std::unique_ptr<IPVectorCFG>> ResOrErr =
      IPVectorCFG::calculateIPVectorCFG(M, MAM);
  LUTHIER_CTX_EMIT_ON_ERROR(Ctx, ResOrErr.takeError());
  return {std::move(*ResOrErr)};
}

llvm::PreservedAnalyses
IPVectorCFGPrinterPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM) {
  auto &IPVecCFG = MAM.getResult<IPVectorCFGAnalysis>(M).getVecCFG();
  IPVecCFG.print(OS);
  return llvm::PreservedAnalyses::all();
}

} // namespace luthier