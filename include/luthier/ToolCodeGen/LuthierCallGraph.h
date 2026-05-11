//===-- LuthierCallGraph.h - Luthier IR call graph analysis -----*- C++ -*-===//
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
/// \file LuthierCallGraph.h
/// Declares the \c LuthierCallGraph module analysis that recovers the call
/// graph of a Luthier-translated IR module.
///
/// Unlike LLVM's LazyCallGraph, this analysis resolves indirect call targets
/// by symbolically evaluating the callee operands, handling
/// \c amdgcn_s_getpc intrinsic chains (whose folded value is read from
/// \c MD_pcsections metadata) and performing inter-procedural constant
/// propagation through function arguments.  A single call site may map to
/// multiple target \c Function* values; call sites that cannot be fully
/// resolved are flagged as incomplete.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_LUTHIER_CALL_GRAPH_H
#define LUTHIER_TOOL_CODE_GEN_LUTHIER_CALL_GRAPH_H

#include <llvm/ADT/DenseMap.h>
#include <llvm/ADT/DenseSet.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/IR/PassManager.h>
#include <llvm/Support/raw_os_ostream.h>

namespace llvm {
class CallInst;
class Function;
class Module;
} // namespace llvm

namespace luthier {

/// TODO: Make these fields private, and provide public accessors instead.
/// Result of the \c LuthierCallGraphAnalysis.
struct LuthierCallGraph {
  /// Map from an indirect \c CallInst to its discovered \c Function targets.
  /// Only indirect calls (those without a compile-time \c Function* callee)
  /// appear here; direct calls are already resolved by the IR.
  llvm::DenseMap<llvm::CallInst *, llvm::SmallVector<llvm::Function *>>
      CallTargets;

  /// All binary addresses discovered as indirect call targets, regardless of
  /// whether the corresponding \c Function* already exists in the module.
  /// This is used by the \c CodeDiscoveryPass to enqueue new entry points
  /// before the callee stubs have been created.
  llvm::DenseSet<uint64_t> DiscoveredCallTargetAddresses;

  /// Call sites for which the analysis could not determine ALL targets.
  /// A call site may be partially resolved (some targets in \c CallTargets)
  /// yet still appear here if other targets remain unknown.
  llvm::DenseSet<llvm::CallInst *> IncompleteCallSites;

  /// True iff every indirect call site in the module has been fully resolved.
  bool FullyRecovered = true;

  /// Standard LLVM invalidation protocol.
  /// The analysis is invalidated whenever the module IR is modified
  /// (e.g. a new function is added or a CFG edge changes).
  bool invalidate(llvm::Module &M, const llvm::PreservedAnalyses &PA,
                  llvm::ModuleAnalysisManager::Invalidator &Inv);
};

/// Module analysis that recovers the IR-level call graph of a
/// Luthier-translated module.
class LuthierCallGraphAnalysis
    : public llvm::AnalysisInfoMixin<LuthierCallGraphAnalysis> {
  friend llvm::AnalysisInfoMixin<LuthierCallGraphAnalysis>;
  static llvm::AnalysisKey Key;

public:
  using Result = LuthierCallGraph;

  Result run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM);
};

/// Pass that prints the \c LuthierCallGraph result to an output stream.
/// Intended to be inserted after \c luthier-code-discovery in the pipeline.
class LuthierCallGraphPrinter
    : public llvm::PassInfoMixin<LuthierCallGraphPrinter> {
  llvm::raw_ostream &OS;

public:
  explicit LuthierCallGraphPrinter(llvm::raw_ostream &OS) : OS(OS) {}

  llvm::PreservedAnalyses run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM);
};

} // namespace luthier

#endif
