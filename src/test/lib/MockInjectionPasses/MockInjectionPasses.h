//===-- MockInjectionPasses.h - test-only payload-injection passes -*-C++-*===//
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
/// \file
/// Test-only mock instrumentation passes deriving from
/// \c InjectedPayloadCreationPass. Each picks a deterministic set of
/// MachineInstr's in the target MF and creates an injected-payload
/// function in the IModule that calls a configured hook for each one.
///
/// Hook lookup: each pass reads a hook name from a global \c cl::opt
/// (default: \c "bumpCounter") and scans the IModule for a function with
/// the \c luthier.function.hook attribute whose value matches that name.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TEST_MOCK_INJECTION_PASSES_H
#define LUTHIER_TEST_MOCK_INJECTION_PASSES_H
#include "luthier/ToolCodeGen/FunctionAnnotations.h"
#include "luthier/ToolCodeGen/InjectedPayloadCreationPass.h"
#include "luthier/ToolCodeGen/InstrumentationPass.h"
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/CodeGen/TargetInstrInfo.h>
#include <llvm/CodeGen/TargetSubtargetInfo.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/CommandLine.h>

namespace luthier::test {

llvm::Function *findHookByName(llvm::Module &IModule, llvm::StringRef HookName);

llvm::StringRef getMockHookNameOpt();
llvm::StringRef getMockOpcodeMnemonicOpt();

//===----------------------------------------------------------------------===//
// At-function-entry: inject before the first MI of the entry MBB
//===----------------------------------------------------------------------===//

class MockInjectAtFunctionEntryPass
    : public luthier::InjectedPayloadCreationPass<MockInjectAtFunctionEntryPass,
                                                  llvm::MachineFunction> {
public:
  static llvm::StringRef name() {
    return "luthier-mock-inject-at-function-entry";
  }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

//===----------------------------------------------------------------------===//
// At-MBB-entry: inject before the first MI of every MBB
//===----------------------------------------------------------------------===//

class MockInjectAtMBBEntryPass
    : public luthier::InjectedPayloadCreationPass<MockInjectAtMBBEntryPass,
                                                  llvm::MachineFunction> {
public:
  static llvm::StringRef name() { return "luthier-mock-inject-at-mbb-entry"; }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

//===----------------------------------------------------------------------===//
// At-MBB-terminator: inject before each MBB's terminator
//===----------------------------------------------------------------------===//

class MockInjectAtMBBTerminatorPass
    : public luthier::InjectedPayloadCreationPass<MockInjectAtMBBTerminatorPass,
                                                  llvm::MachineFunction> {
public:
  static llvm::StringRef name() {
    return "luthier-mock-inject-at-mbb-terminator";
  }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

//===----------------------------------------------------------------------===//
// At-all-VALU: inject before every vector ALU MI
//===----------------------------------------------------------------------===//

class MockInjectAtAllVALUPass
    : public luthier::InjectedPayloadCreationPass<MockInjectAtAllVALUPass,
                                                  llvm::MachineFunction> {
public:
  static llvm::StringRef name() { return "luthier-mock-inject-at-all-valu"; }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

//===----------------------------------------------------------------------===//
// At-all-scalar: inject before every scalar ALU MI
//===----------------------------------------------------------------------===//

class MockInjectAtAllScalarPass
    : public luthier::InjectedPayloadCreationPass<MockInjectAtAllScalarPass,
                                                  llvm::MachineFunction> {
public:
  static llvm::StringRef name() { return "luthier-mock-inject-at-all-scalar"; }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

//===----------------------------------------------------------------------===//
// At-opcode: inject before every MI whose mnemonic matches a cl::opt-supplied
// string (case-sensitive substring match).
//===----------------------------------------------------------------------===//

class MockInjectAtOpcodePass
    : public luthier::InjectedPayloadCreationPass<MockInjectAtOpcodePass,
                                                  llvm::MachineFunction> {
public:
  static llvm::StringRef name() { return "luthier-mock-inject-at-opcode"; }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

//===----------------------------------------------------------------------===//
// At-all-VGPR-defs-with-regarg: for every MI that defines a VGPR, inject a
// payload that forwards the first defined VGPR as a uint32_t RegArg, to
// exercise the luthier::readReg intrinsic call lowering.
//===----------------------------------------------------------------------===//

class MockInjectAtAllVGPRDefsWithRegArgPass
    : public luthier::InjectedPayloadCreationPass<
          MockInjectAtAllVGPRDefsWithRegArgPass, llvm::MachineFunction> {
public:
  static llvm::StringRef name() {
    return "luthier-mock-inject-at-all-vgpr-defs-with-regarg";
  }

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule,
                         llvm::ModuleAnalysisManager &IMAM,
                         llvm::MachineFunction &TargetMF,
                         llvm::FunctionAnalysisManager &TargetFAM);
};

} // namespace luthier::test

#endif
