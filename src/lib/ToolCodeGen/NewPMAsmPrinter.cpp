//===-- NewPMAsmPrinter.h -  ----------------------------------------------===//
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
/// \file
/// Defines the \c NewPMAsmPrinter class.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/NewPMAsmPrinter.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include <AMDGPUResourceUsageAnalysis.h>
#include <llvm/Analysis/CallGraphSCCPass.h>
#include <llvm/Analysis/TargetLibraryInfo.h>
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/TargetPassConfig.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/Support/TimeProfiler.h>
#include <llvm/Target/TargetMachine.h>

namespace {

struct TagMachineFunctions {
  using type = llvm::DenseMap<const llvm::Function *,
                              std::unique_ptr<llvm::MachineFunction>>
      llvm::MachineModuleInfo::*;

  friend type get(TagMachineFunctions);
};

struct TagObjFileMMI {
  using type = llvm::MachineModuleInfoImpl *llvm::MachineModuleInfo::*;

  friend type get(TagObjFileMMI);
};

struct TagModule {
  using type = const llvm::Module *llvm::MachineModuleInfo::*;

  friend type get(TagModule);
};

// This class defines a friend function that can be called via ADL using the tag
// type.
template <typename Tag, typename Tag::type MemPtr> struct Access {
  friend typename Tag::type get(Tag) { return MemPtr; }
};

template struct Access<TagMachineFunctions,
                       &llvm::MachineModuleInfo::MachineFunctions>;

template struct Access<TagObjFileMMI, &llvm::MachineModuleInfo::ObjFileMMI>;

template struct Access<TagModule, &llvm::MachineModuleInfo::TheModule>;

/// \brief A dummy pass used in place of \c llvm::MachineModuleInfoWrapperPass
/// for printing
class DummyMachineModuleInfoWrapperPass
    : public llvm::MachineModuleInfoWrapperPass {
public:
  DummyMachineModuleInfoWrapperPass(const llvm::TargetMachine *TM,
                                    llvm::MCContext *MCCtx)
      : MachineModuleInfoWrapperPass(TM, MCCtx) {}

  void
  borrowMachineModuleAndMachineFunctions(llvm::Module &M,
                                         llvm::ModuleAnalysisManager &MAM) {
    llvm::MachineModuleInfo &OriginalMMI =
        MAM.getResult<llvm::MachineModuleAnalysis>(M).getMMI();
    llvm::MachineModuleInfo &DummyMMI = getMMI();
    DummyMMI.initialize();
    /// Borrow the module
    DummyMMI.*get(TagModule()) = &M;
    /// Borrow the ObjFileMMI pointer
    DummyMMI.*get(TagObjFileMMI()) = OriginalMMI.*get(TagObjFileMMI());
    /// Borrow the machine functions
    llvm::FunctionAnalysisManager &FAM =
        MAM.getResult<llvm::FunctionAnalysisManagerModuleProxy>(M).getManager();
    auto &MFMap = DummyMMI.*get(TagMachineFunctions());
    for (llvm::Function &F : M) {
      llvm::MachineFunction &MF =
          FAM.getResult<llvm::MachineFunctionAnalysis>(F).getMF();
      MFMap.insert(
          {&F, std::move(std::unique_ptr<llvm::MachineFunction>(&MF))});
    }
  }

  /// Don't do any initialization in the legacy pass because it's already
  /// done in the new PM
  bool doInitialization(llvm::Module &) override { return false; }

  /// Don't do any finalization in the legacy pass manager because the original
  /// MMI's constructor should take care of it
  bool doFinalization(llvm::Module &) override { return false; }

  ~DummyMachineModuleInfoWrapperPass() override {
    /// Don't allow any of the unique pointers we injected to call their
    /// delete functions since they actually belong to the FAM of the new PM
    for (auto &[F, MF] : getMMI().*get(TagMachineFunctions())) {
      const auto *P = MF.release();
      (void)P;
    };
    /// Set the ObjFileMMI to nullptr so that it doesn't get deleted
    getMMI().*get(TagObjFileMMI()) = nullptr;
  }
};

} // namespace

namespace luthier {

llvm::PreservedAnalyses NewPMAsmPrinter::run(llvm::Module &M,
                                             llvm::ModuleAnalysisManager &MAM) {
  llvm::TimeTraceScope Scope("LLVM Assembly Printing");
  llvm::LLVMContext &Ctx = M.getContext();

  llvm::MachineModuleInfo &OriginalMMI =
      MAM.getResult<llvm::MachineModuleAnalysis>(M).getMMI();

  auto &TM = const_cast<llvm::TargetMachine &>(OriginalMMI.getTarget());

  auto *MMIWP =
      new DummyMachineModuleInfoWrapperPass(&TM, &OriginalMMI.getContext());

  LUTHIER_CTX_EMIT_ON_ERROR(
      Ctx, LUTHIER_GENERIC_ERROR_CHECK(
               MMIWP != nullptr,
               "Failed to create a MMIWP for the assembly printer"));

  MMIWP->borrowMachineModuleAndMachineFunctions(M, MAM);

  // Create the legacy pass manager with minimal passes to print the
  // assembly file
  llvm::legacy::PassManager PM;
  // Add the target library info pass
  llvm::TargetLibraryInfoImpl TLII(llvm::Triple(M.getTargetTriple()));
  PM.add(new llvm::TargetLibraryInfoWrapperPass(TLII));
  // DummyCGSCCPass must also be added
  PM.add(new llvm::DummyCGSCCPass());
  // TargetPassConfig is expected by the passes involved, so it must be added
  auto *TPC = TM.createPassConfig(PM);
  // Don't run the machine verifier after each pass
  TPC->setDisableVerify(NoVerify);
  TPC->setInitialized();
  PM.add(TPC);
  // Add the MMI Wrapper pass
  PM.add(MMIWP);
  // Add the resource usage analysis, which is in charge of calculating the
  // kernel descriptor and the metadata fields
  PM.add(new llvm::AMDGPUResourceUsageAnalysisWrapperPass());

  // Finally, add the Assembly printer pass
  LUTHIER_CTX_EMIT_ON_ERROR(
      Ctx, LUTHIER_GENERIC_ERROR_CHECK(
               !TM.addAsmPrinter(PM, OS, nullptr, FileType,
                                 MMIWP->getMMI().getContext()),
               "Failed to add the assembly printer pass to the pass manager."));

  // Run the passes on the module to print the assembly
  PM.run(M);

  return llvm::PreservedAnalyses::all();
}

} // namespace luthier