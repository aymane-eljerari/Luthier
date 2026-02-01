//===-- IPPredicatedCFG.cpp -----------------------------------------------===//
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
/// \file IPPredicatedCFG.cpp
/// Implements the \c IPPredicatedCFG class.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/IPPredicatedCFG.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/LLVM/CodeGenHelpers.h"
#include "luthier/LLVM/streams.h"
#include "luthier/Tooling/EntryPoint.h"
#include "luthier/Tooling/InitialEntryPointAnalysis.h"
#include "luthier/Tooling/PredicatedMachineFunction.h"
#include "luthier/Tooling/TargetMachineInstrMDNode.h"
#include <SIInstrInfo.h>
#include <SIMachineFunctionInfo.h>
#include <llvm/ADT/DenseSet.h>
#include <llvm/CodeGen/LivePhysRegs.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/Support/FormatVariadic.h>
#include <luthier/Tooling/FunctionAnnotations.h>

namespace luthier {

void IPPredicatedCFG::print(llvm::raw_ostream &OS) const {
  for (const auto &PredMF : *this) {
    PredMF.print(OS);
  }
}

#if !defined(NDEBUG) || defined(LLVM_ENABLE_DUMP)
void IPPredicatedCFG::dump() const { return print(llvm::dbgs()); }
#endif

IPPredicatedCFG::iterator IPPredicatedCFG::getEntry() {
  return iterator(
      llvm::find_if(PredMFs, [&](std::unique_ptr<PredMFBuilder> &PredMF) {
        return PredMF->getPredMF().getMF().getFunction().hasFnAttribute(
            EntryPointAddrAttr);
      }));
}

IPPredicatedCFG::const_iterator IPPredicatedCFG::getEntry() const {
  return const_iterator(
      llvm::find_if(PredMFs, [&](const std::unique_ptr<PredMFBuilder> &PredMF) {
        return PredMF->getPredMF().getMF().getFunction().hasFnAttribute(
            EntryPointAddrAttr);
      }));
}

llvm::Expected<std::unique_ptr<IPPredicatedCFG>>
IPPredicatedCFG::getIPPredCFG(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM) {

  llvm::FunctionAnalysisManager &FAM =
      MAM.getResult<llvm::FunctionAnalysisManagerModuleProxy>(M).getManager();

  auto Out = std::unique_ptr<IPPredicatedCFG>(new IPPredicatedCFG());

  Out->PredMFs.reserve(M.size());
  /// Populate the CFG
  for (llvm::Function &F : M) {
    llvm::MachineFunction &MF =
        FAM.getResult<llvm::MachineFunctionAnalysis>(F).getMF();
    auto &PredMF =
        *Out->PredMFs.emplace_back(PredMFBuilder::createPredMF(*Out, MF));
    Out->MFToPredMF.insert({std::ref(MF), std::ref(PredMF)});
  }

  /// Link the call and indirect jump instructions + sort the numbering of
  /// all vector CFGs
  unsigned CurrentGlobalPredMBBIdx = 0;
  for (std::unique_ptr<PredMFBuilder> &PredMF : Out->PredMFs) {
    const llvm::MachineFunction &MF = PredMF->getPredMF().getMF();
    bool IsEntry = MF.getFunction().hasFnAttribute(InitialEntryPointAttr);
    for (std::unique_ptr<LinearMBBBuilder> &LinearMBB : *PredMF) {
      for (std::unique_ptr<PredMBBBuilder> &PredMBBBuilder : *LinearMBB) {
        PredMBBBuilder->setGlobalIndex(CurrentGlobalPredMBBIdx);
        CurrentGlobalPredMBBIdx++;
        if (auto &PredMBB = PredMBBBuilder->getPredMBB(); !PredMBB.empty()) {
          const llvm::MachineInstr &LastMI = PredMBB.back();
          if (LastMI.isCall() ||
              (!IsEntry && LastMI.isReturn() &&
               LastMI.getOpcode() != llvm::AMDGPU::S_ENDPGM)) {
            auto *MD = TargetMachineInstrMDNode::getInstrMDNodeIfExists(LastMI);
            if (!MD) {
              return LUTHIER_MAKE_GENERIC_ERROR(
                  "Failed to get the metadata associated with a call or "
                  "return instruction");
            }
            llvm::SmallVector<llvm::Function *> Targets =
                MD->getIndirectBranchAndCallTargets();
            for (llvm::Function *Target : Targets) {
              llvm::MachineFunction &TargetMF =
                  FAM.getResult<llvm::MachineFunctionAnalysis>(*Target).getMF();
              PredMFBuilder &TargetPredMF = Out->MFToPredMF.at(TargetMF);
              auto &TargetBeginVecMBB = **(*TargetPredMF.begin())->begin();
              PredMBBBuilder->addSuccessorBlock(TargetBeginVecMBB);
            }
          }
        }
      }
    }
  }

  Out->dump();

  CurrentGlobalPredMBBIdx = 0;
  for (std::unique_ptr<PredMFBuilder> &PredMF : Out->PredMFs) {
    for (std::unique_ptr<LinearMBBBuilder> &LinearMBB : *PredMF) {
      LinearMBB->pruneTrivialBlocks();
      unsigned CurrentLocalPredMBBIdx = 0;
      for (std::unique_ptr<PredMBBBuilder> &PredMBB : *LinearMBB) {
        PredMBB->setGlobalIndex(CurrentGlobalPredMBBIdx);
        PredMBB->setScalarIndex(CurrentLocalPredMBBIdx);
        CurrentLocalPredMBBIdx++;
        CurrentGlobalPredMBBIdx++;
      }
    }
  }

  Out->NumVecMBBs = CurrentGlobalPredMBBIdx;
  return Out;
}

llvm::AnalysisKey IPPredCFGAnalysis::Key;

bool IPPredCFGAnalysis::Result::invalidate(
    llvm::Module &M, const llvm::PreservedAnalyses &PA,
    llvm::ModuleAnalysisManager::Invalidator &Inv) {
  auto PAC = PA.getChecker<IPPredCFGAnalysis>();
  return !PAC.preserved() &&
         !PAC.preservedSet<llvm::AllAnalysesOn<
             llvm::MachineFunctionAnalysisManagerModuleProxy>>() &&
         !PAC.preservedSet<llvm::CFGAnalyses>();
}

IPPredCFGAnalysis::Result
IPPredCFGAnalysis::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM) {
  llvm::LLVMContext &Ctx = M.getContext();
  llvm::Expected<std::unique_ptr<IPPredicatedCFG>> ResOrErr =
      IPPredicatedCFG::getIPPredCFG(M, MAM);
  LUTHIER_CTX_EMIT_ON_ERROR(Ctx, ResOrErr.takeError());
  return Result{std::move(*ResOrErr)};
}

llvm::PreservedAnalyses
IPPredCFGPrinter::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM) {
  auto &IPVecCFG = MAM.getResult<IPPredCFGAnalysis>(M).getVecCFG();
  IPVecCFG.print(OS);
  return llvm::PreservedAnalyses::all();
}

} // namespace luthier