//===-- InjectedPayloadAccessedRegsAnalysis.cpp ---------------------------===//
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
/// \file InjectedPayloadAccessedRegsAnalysis.cpp
/// Implements \c InjectedPayloadAccessedRegsAnalysis.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/InjectedPayloadAccessedRegsAnalysis.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineInstr.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/MachineRegisterInfo.h>
#include <llvm/CodeGen/TargetRegisterInfo.h>
#include <llvm/CodeGen/TargetSubtargetInfo.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/raw_ostream.h>

namespace luthier {

char InjectedPayloadAccessedRegsAnalysis::ID = 0;

LUTHIER_INITIALIZE_LEGACY_PASS_BODY(InjectedPayloadAccessedRegsAnalysis,
                                    "injected-payload-accessed-regs",
                                    "Injected Payload Accessed Regs Analysis",
                                    true /* Only looks at CFG */,
                                    true /* Analysis Pass */)

namespace {

/// Returns true iff \p MI is a `COPY %vreg, $physreg` (i.e. defines a vreg
/// from a physreg) in the function's entry block. The entry block COPYs
/// emitted by IntrinsicMIRLoweringPass for phys-reg access have this exact
/// shape.
bool isEntryCopyFromPhysReg(const llvm::MachineInstr &MI,
                            llvm::MCRegister &OutPhysReg) {
  if (!MI.isCopy())
    return false;
  const llvm::MachineOperand &Dst = MI.getOperand(0);
  const llvm::MachineOperand &Src = MI.getOperand(1);
  if (!Dst.isReg() || !Src.isReg())
    return false;
  if (!Dst.getReg().isVirtual() || !Src.getReg().isPhysical())
    return false;
  OutPhysReg = Src.getReg().asMCReg();
  return true;
}

/// Returns true iff \p MI is a `COPY $physreg, %vreg` (i.e. defines a
/// physreg from a vreg). The return-block restore COPYs emitted by
/// IntrinsicMIRLoweringPass have this shape.
bool isReturnRestoreCopyToPhysReg(const llvm::MachineInstr &MI,
                                  llvm::MCRegister &OutPhysReg,
                                  llvm::Register &OutSrcVReg) {
  if (!MI.isCopy())
    return false;
  const llvm::MachineOperand &Dst = MI.getOperand(0);
  const llvm::MachineOperand &Src = MI.getOperand(1);
  if (!Dst.isReg() || !Src.isReg())
    return false;
  if (!Dst.getReg().isPhysical() || !Src.getReg().isVirtual())
    return false;
  OutPhysReg = Dst.getReg().asMCReg();
  OutSrcVReg = Src.getReg();
  return true;
}

/// Walk back from \p VReg through COPY chains (including REG_SEQUENCE
/// sub-register chains via the per-sub-reg COPY pattern) to determine
/// whether the value ultimately originates from an entry-block
/// `%root = COPY $r` where \p r matches \p ExpectedPhysReg. Returns true
/// if so. Bounded by a small visit count to guarantee termination on
/// pathological IR.
bool valueChainRootsInEntryCopyOf(const llvm::MachineRegisterInfo &MRI,
                                  const llvm::MachineBasicBlock &EntryBlock,
                                  llvm::Register VReg,
                                  llvm::MCRegister ExpectedPhysReg) {
  constexpr unsigned MaxVisits = 32;
  llvm::SmallVector<llvm::Register, 4> Worklist;
  llvm::DenseSet<llvm::Register> Seen;
  Worklist.push_back(VReg);
  unsigned Visits = 0;
  while (!Worklist.empty()) {
    if (++Visits > MaxVisits)
      return false;
    llvm::Register R = Worklist.pop_back_val();
    if (!R.isVirtual())
      return false;
    if (!Seen.insert(R).second)
      continue;
    llvm::MachineInstr *Def = MRI.getUniqueVRegDef(R);
    if (!Def)
      return false;
    // Entry-block COPY-from-physreg: terminal node.
    if (Def->getParent() == &EntryBlock) {
      llvm::MCRegister PhysReg;
      if (isEntryCopyFromPhysReg(*Def, PhysReg))
        return PhysReg == ExpectedPhysReg;
    }
    // PHI: enqueue all incoming vregs.
    if (Def->isPHI()) {
      for (unsigned I = 1, E = Def->getNumOperands(); I < E; I += 2) {
        const llvm::MachineOperand &MO = Def->getOperand(I);
        if (MO.isReg() && MO.getReg().isVirtual())
          Worklist.push_back(MO.getReg());
      }
      continue;
    }
    // COPY %v, %src — chase the source.
    if (Def->isCopy()) {
      const llvm::MachineOperand &Src = Def->getOperand(1);
      if (Src.isReg() && Src.getReg().isVirtual()) {
        Worklist.push_back(Src.getReg());
        continue;
      }
      return false;
    }
    // Any other defining instruction means the value is not a pure
    // pass-through of the entry phys-reg COPY.
    return false;
  }
  return false;
}

void analyzePayload(const llvm::MachineFunction &MF,
                    InjectedPayloadAccessedRegs &Out) {
  const llvm::MachineBasicBlock &EntryBlock = MF.front();
  const llvm::MachineRegisterInfo &MRI = MF.getRegInfo();

  // Reads: live-ins to the entry block plus phys-regs appearing as COPY
  // sources in the entry block.
  for (const auto &LI : EntryBlock.liveins())
    Out.Reads.insert(LI.PhysReg);
  for (const llvm::MachineInstr &MI : EntryBlock) {
    llvm::MCRegister PhysReg;
    if (isEntryCopyFromPhysReg(MI, PhysReg))
      Out.Reads.insert(PhysReg);
  }

  // Writes: phys-regs defined by COPYs in return blocks whose source
  // value chain does *not* root in the matching entry-block
  // COPY-from-physreg. Anything that does root there is a pure preserve
  // and stays out of Writes.
  for (const llvm::MachineBasicBlock &MBB : MF) {
    if (!MBB.isReturnBlock())
      continue;
    for (const llvm::MachineInstr &MI : MBB) {
      llvm::MCRegister PhysReg;
      llvm::Register SrcVReg;
      if (!isReturnRestoreCopyToPhysReg(MI, PhysReg, SrcVReg))
        continue;
      if (!valueChainRootsInEntryCopyOf(MRI, EntryBlock, SrcVReg, PhysReg))
        Out.Writes.insert(PhysReg);
    }
  }
}

} // namespace

bool InjectedPayloadAccessedRegsAnalysis::runOnModule(llvm::Module &IModule) {
  AccessedRegsByPayload.clear();

  llvm::MachineModuleInfo &MMI =
      getAnalysis<llvm::MachineModuleInfoWrapperPass>().getMMI();

  for (llvm::Function &F : IModule) {
    if (!F.hasFnAttribute(InjectedPayloadAttribute))
      continue;
    llvm::MachineFunction *MF = MMI.getMachineFunction(F);
    if (!MF)
      continue;
    InjectedPayloadAccessedRegs &Entry = AccessedRegsByPayload[&F];
    analyzePayload(*MF, Entry);
  }

  return false;
}

void InjectedPayloadAccessedRegsAnalysis::getAnalysisUsage(
    llvm::AnalysisUsage &AU) const {
  AU.addRequired<llvm::MachineModuleInfoWrapperPass>();
  AU.setPreservesAll();
  ModulePass::getAnalysisUsage(AU);
}

char InjectedPayloadAccessedRegsPrinterPass::ID = 0;

LUTHIER_INITIALIZE_LEGACY_PASS_BODY(InjectedPayloadAccessedRegsPrinterPass,
                                    "injected-payload-accessed-regs-print",
                                    "Injected Payload Accessed Regs Printer",
                                    true /* Only looks at CFG */,
                                    false /* Analysis Pass */)

bool InjectedPayloadAccessedRegsPrinterPass::runOnModule(llvm::Module &IModule) {
  const auto &Analysis =
      getAnalysis<InjectedPayloadAccessedRegsAnalysis>();
  llvm::MachineModuleInfo &MMI =
      getAnalysis<llvm::MachineModuleInfoWrapperPass>().getMMI();

  // Pick any payload's MF to find a TRI for pretty-printing. Falls back to
  // raw register numbers if no MF exists yet.
  const llvm::TargetRegisterInfo *TRI = nullptr;
  for (const auto &[F, _] : Analysis.getMap()) {
    if (auto *MF = MMI.getMachineFunction(*F)) {
      TRI = MF->getSubtarget().getRegisterInfo();
      break;
    }
  }

  // Sort entries by function name for stable output.
  llvm::SmallVector<const llvm::Function *, 4> Funcs;
  for (const auto &[F, _] : Analysis.getMap())
    Funcs.push_back(F);
  llvm::sort(Funcs, [](const llvm::Function *A, const llvm::Function *B) {
    return A->getName() < B->getName();
  });

  auto printRegs = [&](const char *Label,
                       const llvm::DenseSet<llvm::MCRegister> &Regs) {
    llvm::SmallVector<llvm::MCRegister> Sorted(Regs.begin(), Regs.end());
    llvm::sort(Sorted, [](llvm::MCRegister A, llvm::MCRegister B) {
      return A.id() < B.id();
    });
    llvm::outs() << "    " << Label << ":";
    for (llvm::MCRegister R : Sorted) {
      llvm::outs() << " ";
      if (TRI)
        llvm::outs() << TRI->getName(R);
      else
        llvm::outs() << R.id();
    }
    llvm::outs() << "\n";
  };

  for (const llvm::Function *F : Funcs) {
    const auto *Entry = Analysis.lookup(*F);
    if (!Entry)
      continue;
    llvm::outs() << "Payload " << F->getName() << ":\n";
    printRegs("Reads", Entry->Reads);
    printRegs("Writes", Entry->Writes);
  }
  return false;
}

void InjectedPayloadAccessedRegsPrinterPass::getAnalysisUsage(
    llvm::AnalysisUsage &AU) const {
  AU.addRequired<InjectedPayloadAccessedRegsAnalysis>();
  AU.addRequired<llvm::MachineModuleInfoWrapperPass>();
  AU.setPreservesAll();
  ModulePass::getAnalysisUsage(AU);
}

} // namespace luthier
