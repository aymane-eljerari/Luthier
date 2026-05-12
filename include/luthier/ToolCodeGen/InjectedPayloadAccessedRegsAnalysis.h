//===-- InjectedPayloadAccessedRegsAnalysis.h -------------------*- C++ -*-===//
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
/// \file InjectedPayloadAccessedRegsAnalysis.h
/// Describes \c InjectedPayloadAccessedRegsAnalysis, a module analysis on the
/// instrumentation module that produces, for each injected-payload function,
/// the set of physical registers the payload reads from the target
/// application and the set of physical registers it writes back to the target
/// application after \c IntrinsicMIRLoweringPass has run.
///
/// Implemented as a legacy \c ModulePass for symmetry with
/// \c IntrinsicMIRLoweringPass and access to the legacy \c MachineModuleInfo.
/// The result is a plain serializable map; downstream consumers in either pass
/// manager can adopt it without changing the data shape.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_INJECTED_PAYLOAD_ACCESSED_REGS_ANALYSIS_H
#define LUTHIER_TOOL_CODE_GEN_INJECTED_PAYLOAD_ACCESSED_REGS_ANALYSIS_H
#include "luthier/ToolCodeGen/LegacyPassSupport.h"
#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/DenseSet.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/MC/MCRegister.h>
#include <llvm/Pass.h>

namespace llvm {
class Function;
} // namespace llvm

namespace luthier {

/// \brief Per-payload phys-reg read/write sets.
///
/// \c Reads are the target-application physical registers an injected payload
/// consumes at its insertion point. \c Writes are the physical registers the
/// payload writes back into the target application after running. A register
/// that the payload only shuttles through (entry-COPY → vreg-SSA →
/// return-COPY-back) is classified as Read-only — this preserves the user's
/// decision when an intrinsic merely observes ISA state.
struct InjectedPayloadAccessedRegs {
  llvm::DenseSet<llvm::MCRegister> Reads;
  llvm::DenseSet<llvm::MCRegister> Writes;
};

class InjectedPayloadAccessedRegsAnalysis;

LUTHIER_INITIALIZE_LEGACY_PASS_PROTOTYPE(InjectedPayloadAccessedRegsAnalysis);

/// \brief Legacy module analysis pass: per-payload accessed phys-reg sets.
class InjectedPayloadAccessedRegsAnalysis : public llvm::ModulePass {
public:
  using Map =
      llvm::DenseMap<const llvm::Function *, InjectedPayloadAccessedRegs>;

private:
  Map AccessedRegsByPayload;

public:
  static char ID;

  InjectedPayloadAccessedRegsAnalysis() : llvm::ModulePass(ID) {};

  [[nodiscard]] llvm::StringRef getPassName() const override {
    return "Luthier Injected Payload Accessed Registers Analysis";
  }

  bool runOnModule(llvm::Module &IModule) override;

  void getAnalysisUsage(llvm::AnalysisUsage &AU) const override;

  /// \returns the per-payload accessed-regs map.
  [[nodiscard]] const Map &getMap() const { return AccessedRegsByPayload; }

  /// \returns the entry for \p Payload or nullptr if the payload has no
  /// recorded accessed-regs entry.
  [[nodiscard]] const InjectedPayloadAccessedRegs *
  lookup(const llvm::Function &Payload) const {
    auto It = AccessedRegsByPayload.find(&Payload);
    return It == AccessedRegsByPayload.end() ? nullptr : &It->second;
  }
};

class InjectedPayloadAccessedRegsPrinterPass;

LUTHIER_INITIALIZE_LEGACY_PASS_PROTOTYPE(InjectedPayloadAccessedRegsPrinterPass);

/// Legacy printer pass — depends on
/// \c InjectedPayloadAccessedRegsAnalysis and dumps its per-payload
/// Reads/Writes sets to stdout in a stable, FileCheck-friendly format.
class InjectedPayloadAccessedRegsPrinterPass : public llvm::ModulePass {
public:
  static char ID;
  InjectedPayloadAccessedRegsPrinterPass() : llvm::ModulePass(ID) {};
  [[nodiscard]] llvm::StringRef getPassName() const override {
    return "Luthier Injected Payload Accessed Registers Printer";
  }
  bool runOnModule(llvm::Module &IModule) override;
  void getAnalysisUsage(llvm::AnalysisUsage &AU) const override;
};

} // namespace luthier

#endif
