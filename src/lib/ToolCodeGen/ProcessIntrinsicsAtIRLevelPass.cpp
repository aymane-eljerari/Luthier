//===-- ProcessIntrinsicsAtIRLevelPass.cpp --------------------------------===//
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
/// \file ProcessIntrinsicsAtIRLevelPass.cpp
/// Implements the \c ProcessIntrinsicsAtIRLevelPass class.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/ProcessIntrinsicsAtIRLevelPass.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/Intrinsic/IntrinsicProcessor.h"
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include "luthier/ToolCodeGen/IntrinsicProcessorsAnalysis.h"
#include "luthier/ToolCodeGen/WrapperAnalysisPasses.h"
#include <llvm/ADT/Twine.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/ScopedPrinter.h>
#include <sstream>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-process-intrinsics-at-ir-level-pass"

llvm::PreservedAnalyses luthier::ProcessIntrinsicsAtIRLevelPass::run(
    llvm::Module &IModule, llvm::ModuleAnalysisManager &IMAM) {

  LLVM_DEBUG(llvm::dbgs() << "=== ProcessIntrinsicsAtIRLevelPass: module '"
                          << IModule.getName() << "' ===\n");

  const auto &IntrinsicsProcessors =
      IMAM.getResult<IntrinsicsProcessorsAnalysis>(IModule);

  llvm::LLVMContext &Ctx = IModule.getContext();

  // Iterate over all functions and find the ones marked as a Luthier
  // intrinsic
  // Do an early increment on the range since we will remove the intrinsic
  // function once we have processed all its users
  for (auto &F : llvm::make_early_inc_range(IModule.functions())) {
    if (F.hasFnAttribute(IntrinsicAttribute)) {
      // Find the processor for this intrinsic
      auto IntrinsicName =
          F.getFnAttribute(IntrinsicAttribute).getValueAsString();
      // Ensure the processor is indeed registered with the Code Generator
      std::optional<IntrinsicProcessor> Processor =
          IntrinsicsProcessors.getProcessorIfRegistered(IntrinsicName);
      if (!Processor.has_value()) {
        LUTHIER_CTX_EMIT_ON_ERROR(
            Ctx, LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
                     "Intrinsic {0} is not registered", IntrinsicName)));
      }

      LLVM_DEBUG({
        llvm::dbgs() << "\n--- Intrinsic '" << IntrinsicName << "' ("
                     << F.getNumUses() << " use(s)) ---\n";
      });

      // Iterate over all users of the intrinsic
      // Early increment the loop range since we will replace and delete the
      // user in the process
      for (auto *User : llvm::make_early_inc_range(F.users())) {
        // Ensure the user is a Call instruction; Anything other usage is
        // illegal
        auto *CallInst = llvm::dyn_cast<llvm::CallInst>(User);

        if (!CallInst) {
          IModule.getContext().emitError(
              llvm::formatv("Found a user of intrinsic {0} which is not a "
                            "call instruction: {1}.",
                            IntrinsicName, *User));
          return llvm::PreservedAnalyses::all();
        }

        LLVM_DEBUG({
          llvm::dbgs() << "  Call site in '"
                       << CallInst->getFunction()->getName() << "': ";
          CallInst->print(llvm::dbgs());
          llvm::dbgs() << "\n";
        });

        // Call the IR processor of the intrinsic on the user
        llvm::Expected<IntrinsicIRLoweringInfo> IRLoweringInfoOrErr =
            Processor->IRProcessor(F, *CallInst, TM);
        if (auto Err = IRLoweringInfoOrErr.takeError()) {
          IModule.getContext().emitError(CallInst,
                                         llvm::toString(std::move(Err)));
        }

        // Set up the input/output value constraints

        // Add the output operand constraint, if the output is not void
        const auto &ReturnValInfo = IRLoweringInfoOrErr->getReturnValueInfo();
        std::stringstream ConstraintSS;

        if (!ReturnValInfo.Val->getType()->isVoidTy())
          ConstraintSS << "=" << ReturnValInfo.Constraint;
        // Construct argument type vector
        llvm::SmallVector<llvm::Type *, 4> ArgTypes;
        llvm::SmallVector<llvm::Value *, 4> ArgValues;
        ArgTypes.reserve(IRLoweringInfoOrErr->getArgsInfo().size());
        ArgValues.reserve(IRLoweringInfoOrErr->getArgsInfo().size());
        for (const auto &[I, ArgInfo] :
             llvm::enumerate(IRLoweringInfoOrErr->getArgsInfo())) {
          if (I != 0 || (I == 0 && !ReturnValInfo.Val->getType()->isVoidTy()))
            ConstraintSS << ",";
          ArgTypes.push_back(ArgInfo.Val->getType());
          ArgValues.push_back(const_cast<llvm::Value *>(ArgInfo.Val));
          ConstraintSS << ArgInfo.Constraint;
        }

        LLVM_DEBUG({
          llvm::dbgs() << "  IR lowering:\n";
          if (!ReturnValInfo.Val->getType()->isVoidTy())
            llvm::dbgs() << "    Return: constraint '=" << ReturnValInfo.Constraint
                         << "'\n";
          else
            llvm::dbgs() << "    Return: void\n";
          for (const auto &[I, ArgInfo] :
               llvm::enumerate(IRLoweringInfoOrErr->getArgsInfo()))
            llvm::dbgs() << "    Arg " << I << ": constraint '"
                         << ArgInfo.Constraint << "'\n";
          llvm::dbgs() << "    Extra forwarding values: "
                       << IRLoweringInfoOrErr->getExtraLoweringValues().size()
                       << "\n";
          llvm::dbgs() << "    Full constraint string: '" << ConstraintSS.str()
                       << "'\n";
        });

        // Build the Luthier intrinsic section operands: section name followed
        // by an optional aux data node holding the extra forwarding values.
        llvm::SmallVector<llvm::Metadata *, 2> LuthierSectionOperands;
        LuthierSectionOperands.push_back(llvm::MDString::get(
            Ctx, (llvm::Twine(LuthierIntrinsicPCSectionPrefix) + IntrinsicName)
                     .str()));
        llvm::ArrayRef<llvm::Metadata *> ExtraVals =
            IRLoweringInfoOrErr->getExtraLoweringValues();
        if (!ExtraVals.empty())
          LuthierSectionOperands.push_back(llvm::MDNode::get(Ctx, ExtraVals));

        // Create a placeholder inline assembly instruction in the place of
        // the user; the asm template string is empty — the intrinsic identity
        // is carried by the !pcsections attachment instead.
        auto *PlaceHolderInlineAsm = llvm::InlineAsm::get(
            llvm::FunctionType::get(ReturnValInfo.Val->getType(), ArgTypes,
                                    false),
            "", ConstraintSS.str(), true);
        auto *InlineAsmPlaceholderCall =
            llvm::CallInst::Create(PlaceHolderInlineAsm, ArgValues);
        InlineAsmPlaceholderCall->insertBefore(*CallInst->getParent(),
                                               CallInst->getIterator());
        // Replace all occurrences of the user with the inline assembly
        // placeholder
        CallInst->replaceAllUsesWith(InlineAsmPlaceholderCall);
        // Transfer debug info of the original use to the inline assembly
        // placeholder
        InlineAsmPlaceholderCall->setDebugLoc(CallInst->getDebugLoc());

        // Build the pcsections node, preserving any sections already on the
        // original call site from prior instrumentation passes
        // Non-distinct (uniqued) nodes may be shared across instructions and
        // cannot be extended in-place; distinct nodes also have a fixed
        // operand count at creation. In both cases collect the existing
        // operands and build a fresh distinct node exclusively owned by this
        // placeholder.
        llvm::SmallVector<llvm::Metadata *> PCSOperands;
        if (llvm::MDNode *Existing =
                CallInst->getMetadata(llvm::LLVMContext::MD_pcsections))
          for (const llvm::MDOperand &Op : Existing->operands())
            PCSOperands.push_back(Op.get());
        PCSOperands.append(LuthierSectionOperands.begin(),
                           LuthierSectionOperands.end());
        unsigned NumPreservedOps =
            PCSOperands.size() - LuthierSectionOperands.size();
        InlineAsmPlaceholderCall->setMetadata(
            llvm::LLVMContext::MD_pcsections,
            llvm::MDNode::getDistinct(Ctx, PCSOperands));

        LLVM_DEBUG({
          llvm::dbgs() << "  PCSections: section 'luthier.intrinsic: "
                       << IntrinsicName << "'";
          if (!ExtraVals.empty())
            llvm::dbgs() << " (" << ExtraVals.size()
                         << " extra forwarded value(s))";
          if (NumPreservedOps > 0)
            llvm::dbgs() << ", preserved " << NumPreservedOps
                         << " existing operand(s) from call site";
          llvm::dbgs() << "\n";
          llvm::dbgs() << "  Placeholder: ";
          InlineAsmPlaceholderCall->print(llvm::dbgs());
          llvm::dbgs() << "\n";
        });

        // Remove the original user from its parent function
        CallInst->eraseFromParent();
      }
      // Remove the intrinsic function once all its users has been processed
      F.dropAllReferences();
      F.eraseFromParent();
    }
  }

  return llvm::PreservedAnalyses::all();
}
