//===-- MIInlineAsmEmitter.h -------------------------------------*- C++-*-===//
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
/// \file MIInlineAsmEmitter.h
/// Describes the \c MIInlineAsmEmitter class used to take in
/// a \c llvm::MachineInstr instance and converts it to an LLVM IR Inline
/// assembly instruction.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_MI_INLINE_ASM_EMITTER
#define LUTHIER_TOOL_CODE_GEN_MI_INLINE_ASM_EMITTER
#include <GCNSubtarget.h>
#include <SIInstrInfo.h>
#include <llvm/CodeGen/AsmPrinter.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/MC/MCAsmInfo.h>
#include <llvm/MC/MCContext.h>
#include <llvm/MC/MCInstPrinter.h>
#include <llvm/MC/MCStreamer.h>
#include <llvm/Support/CodeGen.h>
#include <llvm/Support/Error.h>

namespace llvm {
class TargetMachine;
class MachineInstr;
class MachineOperand;
class MCRegister;
} // namespace llvm

namespace luthier {

/// \brief Converts a single machine instruction into an IR-level inline
/// assembly instruction. For instructions with multiple outputs, emits
/// additional \c llvm::ExtractElementInst instructions to extract the output
/// registers
/// \details This class leverages the \c llvm::AsmPrinter pass's internal
/// functionality to first obtain the textual representation of the
/// target instruction, and
class MIInlineAsmEmitter {
private:
  std::unique_ptr<llvm::MCContext> MCCtx;
  std::unique_ptr<llvm::MCInstPrinter> IP;
  std::unique_ptr<llvm::AsmPrinter> AP;
  llvm::SmallString<20> AsmString{};
  std::unique_ptr<llvm::raw_svector_ostream> AsmStringOS;
  llvm::TargetMachine &TM;

  explicit MIInlineAsmEmitter(llvm::TargetMachine &TM);

  std::string emitAsmString(const llvm::MachineInstr &MI);

  std::string getRegisterName(llvm::MCRegister Reg);

public:
  static llvm::Expected<std::unique_ptr<MIInlineAsmEmitter>>
  get(llvm::TargetMachine &TM);

  void emitInlineAsm(
      llvm::IRBuilderBase &Builder, const llvm::MachineInstr &MI,
      const std::function<llvm::Value &(llvm::MCRegister)> &InputRegValMap,
      const std::function<void(llvm::MCRegister, llvm::Value &)>
          &OutputRegValMap);
};

} // namespace luthier

#endif