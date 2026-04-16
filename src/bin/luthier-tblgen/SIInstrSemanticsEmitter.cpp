//===- SIInstrSemanticsEmitter.cpp - SI Instruction Semantics Emitter -----===//
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
/// \file SIInstrSemanticsEmitter.cpp
/// TableGen backend that emits C++ code to translate AMDGPU \c MachineInstr
/// instances into LLVM IR based on their \c InstSISemantic records.
//===----------------------------------------------------------------------===//
#include "SIInstrSemanticsEmitter.hpp"
#include <llvm/ADT/StringExtras.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/TableGen/Error.h>
#include <llvm/TableGen/Record.h>

namespace luthier {

void SIInstrSemanticsEmitter::emitSemanticStatement(
    llvm::raw_ostream &OS, const llvm::Init *Stmt,
    llvm::ArrayRef<llvm::SMLoc> Loc) {
  if (const auto *Dag = llvm::dyn_cast<llvm::DagInit>(Stmt)) {
    const llvm::Record *Op = Dag->getOperatorAsDef(Loc);
    llvm::StringRef OpName = Op->getName();
    const llvm::RecordRecTy *OpClass = Op->getType();

    // --- SetNamedOperand $name, value_dag ---
    if (OpName == "SetNamedOperand") {
      if (unsigned NumArgs = Dag->getNumArgs(); NumArgs != 2)
        llvm::PrintFatalError(
            Loc, "Expected `SetNamedOperand` to have 2 arguments, got " +
                     llvm::Twine(NumArgs) + " instead");
      llvm::StringRef OperandName = Dag->getArgNameStr(0);
      const auto *AssignmentDag = llvm::dyn_cast<llvm::DagInit>(Dag->getArg(1));
      if (!AssignmentDag)
        llvm::PrintFatalError(Loc, "`SetNamedOperand` second arg is not a DAG");
      OS << "Tracker.setRegOperandValue(";
      OS << "*Tracker.getTII().getNamedOperand(MI, "
            "llvm::AMDGPU::OpName::"
         << OperandName << "), ";
      emitSemanticStatement(OS, AssignmentDag, Loc);
      OS << ")";
    }
    // --- ImplicitDef REG, value_dag ---
    else if (OpName == "ImplicitDef") {
      if (unsigned NumArgs = Dag->getNumArgs(); NumArgs != 2)
        llvm::PrintFatalError(
            Loc, "Expected `ImplicitDef` to have 2 arguments, got " +
                     llvm::Twine(NumArgs) + " instead");

      const auto *RegDef = llvm::dyn_cast<llvm::DefInit>(Dag->getArg(0));
      if (!RegDef)
        llvm::PrintFatalError(
            Loc, "First argument of `ImplicitDef` is not a record definition");

      const llvm::Record *RegisterClass =
          RegDef->getRecordKeeper().getClass("Register");
      if (!RegisterClass) {
        llvm::PrintFatalError(Loc, "Failed to get SIReg");
      }
      if (!RegDef->getDef()->isSubClassOf(RegisterClass)) {
        llvm::PrintFatalError(
            Loc, "First argument of `ImplicitDef` is not an Register");
      }
      llvm::StringRef RegName = RegDef->getDef()->getName();

      const auto *ValDag = llvm::dyn_cast<llvm::DagInit>(Dag->getArg(1));
      if (!ValDag)
        llvm::PrintFatalError("ImplicitDef second arg is not a DAG");
      OS << "Tracker.setRegOperandValue(MI, llvm::AMDGPU::" << RegName << ", ";
      emitSemanticStatement(OS, ValDag, Loc);
      OS << ")";
    }
    // --- DefVal $name, value_dag ---
    else if (OpName == "DefVal") {
      llvm::StringRef ValName = Dag->getArgNameStr(0);
      const auto *ValDag = llvm::dyn_cast<llvm::DagInit>(Dag->getArg(1));
      if (!ValDag)
        llvm::PrintFatalError("DefVal second arg is not a DAG");
      OS << "llvm::Value *" << ValName << " = ";
      emitSemanticStatement(OS, ValDag, Loc);
    }

    // --- GetNamedOperand $name ---
    else if (OpName == "GetNamedOperand") {
      llvm::StringRef ArgName = Dag->getArgNameStr(0);
      OS << "&Tracker.getOperandAsValue("
         << "*Tracker.getTII().getNamedOperand(MI, "
            "llvm::AMDGPU::OpName::"
         << ArgName << ")";
      if (Dag->getNumArgs() > 1) {
        OS << ", ";
        emitSemanticStatement(OS, Dag->getArg(1), Loc);
      }
      OS << ")";
    }
    // --- GetNamedOperandAsBB $name ---
    else if (OpName == "GetNamedOperandAsBB") {
      llvm::StringRef ArgName = Dag->getArgNameStr(0);
      OS << "&Tracker.getOperandAsBasicBlock("
         << "*Tracker.getTII().getNamedOperand(MI, "
            "llvm::AMDGPU::OpName::"
         << ArgName << "))";
    }

    // --- GetVal $name ---
    else if (OpName == "GetVal") {
      OS << Dag->getArgNameStr(0);
    }

    // --- GetNextBB ---
    // Returns the fall-through BasicBlock (next block after current MI's block)
    else if (OpName == "GetNextBB") {
      OS << "Tracker.getNextBB(MI)";
    }

    // --- ImplicitUse REG ---
    else if (OpName == "ImplicitUse") {
      // First arg is a register def (e.g., VCC, EXEC, SCC)
      const auto *RegDef = llvm::dyn_cast<llvm::DefInit>(Dag->getArg(0));
      llvm::StringRef RegName = RegDef->getDef()->getName();
      OS << "&Tracker.getRegisterOperand(MI, llvm::AMDGPU::" << RegName << ")";
    }

    // --- LLVM Operands ---
    else if (OpClass->isSubClassOf(Records.getClass("LLVMOp"))) {
      OS << "Builder." << Op->getValueAsString("IRBuilderFunc") << "(";
      llvm::interleave(
          Dag->getArgs(),
          [&](const llvm::Init *Arg) { emitSemanticStatement(OS, Arg, Loc); },
          [&] { OS << ", "; });
      OS << ")";
    }

    // --- Constant Values ---
    else if (OpClass->isSubClassOf(Records.getClass("LLVMConstant"))) {
      OS << Op->getValueAsString("BuilderFunc") << "(";
      llvm::interleave(
          Dag->getArgs(),
          [&](const llvm::Init *Arg) { emitSemanticStatement(OS, Arg, Loc); },
          [&] { OS << ", "; });
      OS << ")";
    } else {
      llvm::PrintFatalError(Loc, "Unhandled operand: " + OpName + ".");
    }
  } else if (const auto *DefNode = llvm::dyn_cast<llvm::DefInit>(Stmt)) {
    const llvm::RecordRecTy *DefType = DefNode->getDef()->getType();

    /// LLVM Comparison predicates
    if (DefType->isSubClassOf(
            Stmt->getRecordKeeper().getClass("LLVMCmpPredicate"))) {
      OS << DefNode->getDef()->getValueAsString("Code");
    }

    /// LLVM Atomic ops
    else if (DefType->isSubClassOf(
                 Stmt->getRecordKeeper().getClass("AtomicRMWOp"))) {
      OS << DefNode->getDef()->getValueAsString("Op");
    }
    /// Alignment
    else if (DefType->isSubClassOf(
                 Stmt->getRecordKeeper().getClass("AlignVal"))) {
      OS << DefNode->getDef()->getValueAsString("Expr");
    }
    /// Atomic ordering
    else if (DefType->isSubClassOf(
                 Stmt->getRecordKeeper().getClass("AtomicOrderingVal"))) {
      OS << DefNode->getDef()->getValueAsString("Ordering");
    }
    /// Sync scope
    else if (DefType->isSubClassOf(
                 Stmt->getRecordKeeper().getClass("SyncScopeVal"))) {
      OS << DefNode->getDef()->getValueAsString("Expr");
    }
    /// Pointer type operands
    else if (DefType->isSubClassOf(
                 Stmt->getRecordKeeper().getClass("LLVMQualPointerType"))) {
      const llvm::Record *PtrRecord = DefNode->getDef();
      const llvm::ListInit *PtrSig = PtrRecord->getValueAsListInit("Sig");
      OS << "Builder.getPtrTy("
         << (PtrSig->size() == 2 ? PtrSig->getElement(1)->getAsString() : "0")
         << ")";
    } else if (DefType->isSubClassOf(
                   Stmt->getRecordKeeper().getClass("SILLVMType"))) {
      OS << DefNode->getDef()->getValueAsString("Builder");
    } else if (DefType->isSubClassOf(
                   Stmt->getRecordKeeper().getClass("LLVMComplexType"))) {
      OS << DefNode->getDef()->getValueAsString("Builder");
    } else if (DefType->isSubClassOf(
                   Stmt->getRecordKeeper().getClass("Intrinsic"))) {
      llvm::StringRef IntrinsicName = DefNode->getDef()->getName();
      if (!IntrinsicName.consume_front("int_")) {
        llvm::PrintFatalError(Loc, "Intrinsic record's name " + IntrinsicName +
                                       "does not start with 'int_'");
      }
      OS << "llvm::Intrinsic::" << IntrinsicName;
    } else if (DefType->isSubClassOf(
                   Stmt->getRecordKeeper().getClass("SuperRegFactory"))) {
      std::vector<const llvm::Record *> SubRegs =
          DefNode->getDef()->getValueAsListOfDefs("Regs");
      OS << "llvm::AMDGPU::";
      llvm::interleave(
          SubRegs, [&](const llvm::Record *SubReg) { OS << SubReg->getName(); },
          [&] { OS << "_"; });

    } else {
      llvm::PrintFatalError(
          Loc, "Unhandled def node: " + DefNode->getAsString() + ".");
    }
  } else if (const auto *ListNode = llvm::dyn_cast<llvm::ListInit>(Stmt)) {
    OS << "{";
    llvm::interleave(
        ListNode->getElements(),
        [&](const llvm::Init *Elem) { emitSemanticStatement(OS, Elem, Loc); },
        [&] { OS << ", "; });
    OS << "}";
  } else if (auto *IntNode = llvm::dyn_cast<llvm::IntInit>(Stmt)) {
    llvm::outs() << "Int node: " << IntNode->getValue() << "\n";
    OS << IntNode->getValue();
  } else if (auto *StrNode = llvm::dyn_cast<llvm::StringInit>(Stmt)) {
    llvm::outs() << "String node: " << StrNode->getValue() << "\n";
    OS << StrNode->getValue();
  } else {
    llvm::PrintFatalError(Loc, "Unhandled node: " + Stmt->getAsString() + ".");
  }
}

void SIInstrSemanticsEmitter::emitSemanticFunction(llvm::raw_ostream &OS,
                                                   const llvm::Record *Rec) {

  const llvm::Record *InstRec = Rec->getValueAsDef("Instruction");
  llvm::StringRef InstName = InstRec->getName();

  const llvm::ListInit *SemList = Rec->getValueAsListInit("Semantic");

  llvm::SMLoc SemanticLoc = Rec->getFieldLoc("Semantic");

  /// Skip instructions with empty semantic
  if (!SemList || SemList->empty())
    return; // Skip empty semantics

  OS << "template <>\n";
  OS << "void inline raiseMachineInstr<llvm::AMDGPU::" << InstName << ">(\n";
  OS << "    const llvm::MachineInstr &MI, llvm::IRBuilderBase &Builder,\n";
  OS << "    MBBOperandTracker &Tracker) {\n";

  for (const llvm::Init *El : SemList->getElements()) {
    const auto *StmtDag = llvm::dyn_cast<llvm::DagInit>(El);
    if (!StmtDag)
      PrintFatalError(Rec->getLoc(), "Semantic element is not a DAG");
    emitSemanticStatement(OS.indent(2), StmtDag, SemanticLoc);
    OS << ";\n";
  }

  OS << "}\n\n";
}

//===----------------------------------------------------------------------===//
// Dispatch function emitter
//===----------------------------------------------------------------------===//

void SIInstrSemanticsEmitter::emitMacro(
    llvm::raw_ostream &OS, llvm::ArrayRef<const llvm::Record *> Semantics) {
  OS << "#ifndef HANDLE_INST_SEMANTIC\n";
  OS << "#define HANDLE_INST_SEMANTIC(OPCODE) \n";
  OS << "#endif\n";
  for (const llvm::Record *Rec : Semantics) {
    const auto *SemList = Rec->getValueAsListInit("Semantic");
    if (!SemList || SemList->empty())
      continue;
    const llvm::Record *InstRec = Rec->getValueAsDef("Instruction");
    llvm::StringRef InstName = InstRec->getName();
    OS << "HANDLE_INST_SEMANTIC(" << InstName << ")\n";
  }
  OS << "#undef HANDLE_INST_SEMANTIC\n";
}

//===----------------------------------------------------------------------===//
// Header / Footer
//===----------------------------------------------------------------------===//

void SIInstrSemanticsEmitter::emitHeader(llvm::raw_ostream &OS) {
  OS << "//===-- SIInstrSemantics.inc - Generated SI Instruction Semantics "
        "---------===//\n";
  OS << "// Auto-generated by luthier-tblgen. DO NOT EDIT.\n";
  OS << "//===---------------------------------------------------"
        "-------------------===//\n\n";
}

//===----------------------------------------------------------------------===//
// Main entry point
//===----------------------------------------------------------------------===//

void SIInstrSemanticsEmitter::run(llvm::raw_ostream &OS) {
  llvm::ArrayRef<const llvm::Record *> Semantics =
      Records.getAllDerivedDefinitions("InstSISemantic");

  emitHeader(OS);

  OS << "#ifdef GET_SI_INSTR_SEMANTIC_FUNCTIONS\n";
  OS << "#undef GET_SI_INSTR_SEMANTIC_FUNCTIONS\n";

  for (const llvm::Record *Rec : Semantics) {
    emitSemanticFunction(OS, Rec);
  }

  OS << "#endif // GET_SI_INSTR_SEMANTIC_FUNCTIONS\n\n";

  emitMacro(OS, Semantics);

  // --- Emit array of all opcodes that have semantic definitions ---
  OS << "#ifdef GET_SI_INSTR_SEMANTIC_OPCODE_LIST\n";
  OS << "static constexpr uint16_t SemanticallyModeledOpcodes[] = {\n";
  for (const llvm::Record *Rec : Semantics) {
    const auto *SemList = Rec->getValueAsListInit("Semantic");
    if (!SemList || SemList->empty())
      continue;
    const llvm::Record *InstRec = Rec->getValueAsDef("Instruction");
    OS << "  llvm::AMDGPU::" << InstRec->getName() << ",\n";
  }
  OS << "};\n";
  OS << "static constexpr size_t NumSemanticallyModeledOpcodes = "
        "sizeof(SemanticallyModeledOpcodes) / "
        "sizeof(SemanticallyModeledOpcodes[0]);\n";
  OS << "#undef GET_SI_INSTR_SEMANTIC_OPCODE_LIST\n";
  OS << "#endif // GET_SI_INSTR_SEMANTIC_OPCODE_LIST\n\n";
}

//===----------------------------------------------------------------------===//
// Global entry point
//===----------------------------------------------------------------------===//

void emitSIInstrSemantics(const llvm::RecordKeeper &Records,
                          llvm::raw_ostream &OS) {
  SIInstrSemanticsEmitter Emitter(Records);
  Emitter.run(OS);
}

} // namespace luthier
