//===-- LinearMachineBasicBlock.cpp ---------------------------------------===//
// Copyright 2026 @ Northeastern University Computer Architecture Lab
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
/// \file LinearMachineBasicBlock.cpp
/// Defines the \c LinearMachineBasicBlock class.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/LinearMachineBasicBlock.h"
#include "luthier/Tooling/PredicatedMachineFunction.h"

namespace luthier {

void LinearMachineBasicBlock::print(llvm::raw_ostream &OS,
                                    unsigned int Indent) const {
  OS.indent(Indent) << "Scalar MBB "
                    << (ParentMBB ? ParentMBB->getFullName()
                                  : getParent().getMF().getName())
                    << ":\n";
  for (const auto &MBB : PredMBBs) {
    MBB->print(OS, Indent + 2);
    OS << "\n";
  }
}

LinearMBBBuilder
LinearMBBBuilder::createScalarMBB(llvm::MachineBasicBlock &ParentMBB,
                                  PredicatedCFG &ParentCFG) {

  LinearMBBBuilder Out{ParentCFG};

  Out->PredMBBs = PredMBBBuilder::BreakDownToPredicatedMBBs(*Out, ParentMBB);
  assert(Out->PredMBBs.size() >= 4 &&
         "No linking blocks are present in the returned vector MBBs");

  Out.EntryPredOneBlock = &Out->PredMBBs[0];
  Out.EntryPredZeroOrOneBlock = &Out->PredMBBs[1];
  Out.ExitPredZeroOrOneBlock = &Out->PredMBBs.back();
  Out.ExitPredOneBlock = &Out->PredMBBs.end()[-2];

  return Out;
}

LinearMBBBuilder
LinearMBBBuilder::createEntryScalarMBB(PredicatedCFG &ParentCFG) {
  LinearMBBBuilder Out{ParentCFG};
  Out.Out->PredMBBs.emplace_back(
      PredMBBBuilder(*Out, PredicatedMachineBasicBlock::ZeroOrOne));
  Out.EntryPredOneBlock = Out.Out->PredMBBs.begin();
  Out.EntryPredZeroOrOneBlock = Out.Out->PredMBBs.begin();
  Out.ExitPredOneBlock = Out.Out->PredMBBs.begin();
  Out.ExitPredZeroOrOneBlock = Out.Out->PredMBBs.begin();

  return Out;
};

void LinearMBBBuilder::addSuccessor(LinearMBBBuilder &LMBB) {
  assert(ExitPredOneBlock && "successor block has finalized linking");
  assert(ExitPredZeroOrOneBlock && "successor block has finalized linking");
  assert(LMBB.EntryPredOneBlock && "block has finalized linking");
  assert(LMBB.EntryPredZeroOrOneBlock && "block has finalized linking");

  this->ExitPredOneBlock->addSuccessorBlock(*LMBB.EntryPredOneBlock);
  this->ExitPredZeroOrOneBlock->addSuccessorBlock(*LMBB.ExitPredZeroOrOneBlock);
}

void LinearMBBBuilder::addPredecessor(LinearMBBBuilder &LMBB) {
  assert(EntryPredOneBlock && "block has finalized linking");
  assert(EntryPredZeroOrOneBlock && "block has finalized linking");
  assert(LMBB.ExitPredOneBlock && "predecessor block has finalized linking");
  assert(LMBB.ExitPredZeroOrOneBlock &&
         "predecessor block has finalized linking");

  this->EntryPredOneBlock->addPredecessorBlock(*LMBB.ExitPredOneBlock);
  this->EntryPredZeroOrOneBlock->addPredecessorBlock(
      *LMBB.ExitPredZeroOrOneBlock);
}

void LinearMBBBuilder::finalizeLinking() {
  if (hasFinalizedLinking())
    return;

  for (auto PredMBB = Out->PredMBBs.begin(); PredMBB != Out->PredMBBs.end();) {
    if (PredMBB->unlinkIfTrivialEmptyBlock()) {
      Out->PredMBBs.erase(PredMBB);
    } else
      PredMBB++;
  }

  EntryPredOneBlock = nullptr;
  EntryPredZeroOrOneBlock = nullptr;
  ExitPredOneBlock = nullptr;
  ExitPredZeroOrOneBlock = nullptr;
}

} // namespace luthier