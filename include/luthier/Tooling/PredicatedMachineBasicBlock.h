//===-- PredicatedMachineBasicBlock.h ---------------------------*- C++ -*-===//
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
/// \file PredicatedMachineBasicBlock.h
/// Defines the \c PredicatedMachineBasicBlock class.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_PREDICATED_MACHINE_BASIC_BLOCK_H
#define LUTHIER_TOOLING_PREDICATED_MACHINE_BASIC_BLOCK_H
#include "luthier/Common/DenseMapInfo.h"
#include <llvm/ADT/DenseSet.h>
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineInstrBundle.h>
#include <llvm/Support/GenericDomTree.h>

namespace luthier {

class IPPredicatedCFG;
class PredMBBBuilder;

/// \brief A node in the inter-procedural predicated control-flow graph,
/// wrapping a single \c llvm::MachineBasicBlock that contains exclusively
/// scalar or exclusively vector instructions (as guaranteed by
/// \c CodeDiscoveryPass)
class PredicatedMachineBasicBlock {
  friend class PredMBBBuilder;

public:
  using EdgeSetType =
      llvm::SmallDenseSet<std::reference_wrapper<PredMBBBuilder>>;

private:
  llvm::MachineBasicBlock &MBB;

  IPPredicatedCFG &Parent;

  /// Index of the predicated MBB in the parent
  unsigned GlobalIdx;

  /// True when the call/branch targets of this block could not all be resolved
  bool HasUnresolvedEdges{false};

  EdgeSetType Predecessors{};

  EdgeSetType Successors{};

  PredicatedMachineBasicBlock(llvm::MachineBasicBlock &MBB,
                              IPPredicatedCFG &Parent, unsigned GlobalIdx)
      : MBB(MBB), Parent(Parent), GlobalIdx(GlobalIdx) {}

public:
  PredicatedMachineBasicBlock(const PredicatedMachineBasicBlock &) = delete;

  PredicatedMachineBasicBlock &
  operator=(const PredicatedMachineBasicBlock &) = delete;

  [[nodiscard]] const llvm::MachineBasicBlock &getMBB() const { return MBB; }
  [[nodiscard]] llvm::MachineBasicBlock &getMBB() { return MBB; }

  [[nodiscard]] const IPPredicatedCFG &getParent() const { return Parent; }
  [[nodiscard]] IPPredicatedCFG &getParent() { return Parent; }

  using instr_iterator = llvm::MachineBasicBlock::instr_iterator;
  using const_instr_iterator = llvm::MachineBasicBlock::const_instr_iterator;
  using iterator = llvm::MachineBasicBlock::iterator;
  using const_iterator = llvm::MachineBasicBlock::const_iterator;
  using reverse_instr_iterator = std::reverse_iterator<instr_iterator>;
  using const_reverse_instr_iterator =
      std::reverse_iterator<const_instr_iterator>;
  using reverse_iterator = std::reverse_iterator<iterator>;
  using const_reverse_iterator = std::reverse_iterator<const_iterator>;

  iterator begin() { return MBB.begin(); }
  [[nodiscard]] const_iterator begin() const { return MBB.begin(); }
  instr_iterator instr_begin() { return MBB.instr_begin(); }
  [[nodiscard]] const_instr_iterator instr_begin() const {
    return MBB.instr_begin();
  }

  [[nodiscard]] iterator end() { return MBB.end(); }
  [[nodiscard]] const_iterator end() const { return MBB.end(); }
  [[nodiscard]] instr_iterator instr_end() { return MBB.instr_end(); }
  [[nodiscard]] const_instr_iterator instr_end() const {
    return MBB.instr_end();
  }

  reverse_iterator rbegin() { return std::make_reverse_iterator(end()); }
  [[nodiscard]] const_reverse_iterator rbegin() const {
    return std::make_reverse_iterator(end());
  }
  reverse_instr_iterator instr_rbegin() {
    return std::make_reverse_iterator(instr_end());
  }
  [[nodiscard]] const_reverse_instr_iterator instr_rbegin() const {
    return std::make_reverse_iterator(instr_end());
  }

  reverse_iterator rend() { return std::make_reverse_iterator(begin()); }
  [[nodiscard]] const_reverse_iterator rend() const {
    return std::make_reverse_iterator(begin());
  }
  reverse_instr_iterator instr_rend() {
    return std::make_reverse_iterator(instr_begin());
  }
  [[nodiscard]] const_reverse_instr_iterator instr_rend() const {
    return std::make_reverse_iterator(instr_begin());
  }

  [[nodiscard]] bool contains(const llvm::MachineInstr &MI) const {
    return MI.getParent() == &MBB;
  }

  llvm::MachineInstr &front() { return MBB.front(); }
  [[nodiscard]] const llvm::MachineInstr &front() const { return MBB.front(); }
  llvm::MachineInstr &back() { return MBB.back(); }
  [[nodiscard]] const llvm::MachineInstr &back() const { return MBB.back(); }
  llvm::MachineInstr &instr_front() { return MBB.instr_front(); }
  [[nodiscard]] const llvm::MachineInstr &instr_front() const {
    return MBB.instr_front();
  }
  llvm::MachineInstr &instr_back() { return MBB.instr_back(); }
  [[nodiscard]] const llvm::MachineInstr &instr_back() const {
    return MBB.instr_back();
  }

  [[nodiscard]] bool empty() const { return MBB.empty(); }
  [[nodiscard]] unsigned size() const { return MBB.size(); }
  [[nodiscard]] unsigned instr_size() const {
    return std::distance(instr_begin(), instr_end());
  }

  [[nodiscard]] unsigned getGlobalNumber() const { return GlobalIdx; }

  [[nodiscard]] bool hasUnresolvedEdges() const { return HasUnresolvedEdges; }
  [[nodiscard]] std::string getName() const;

  class edge_iterator {
    EdgeSetType::iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = PredicatedMachineBasicBlock;
    using reference = value_type &;
    using pointer = value_type *;

    explicit edge_iterator(const EdgeSetType::iterator &It) : It(It) {}

    reference operator*() const;
    pointer operator->() const;

    edge_iterator operator++() {
      ++It;
      return *this;
    }
    edge_iterator operator++(int) {
      auto Copy = *this;
      ++(*this);
      return Copy;
    }
    bool operator==(const edge_iterator &Other) const { return It == Other.It; }
    bool operator!=(const edge_iterator &Other) const {
      return !(*this == Other);
    }
  };

  class const_pred_succ_iterator {
    EdgeSetType::const_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = const PredicatedMachineBasicBlock;
    using reference = value_type &;
    using pointer = value_type *;

    explicit const_pred_succ_iterator(const EdgeSetType::const_iterator &It)
        : It(It) {}

    reference operator*() const;
    pointer operator->() const;

    [[nodiscard]] decltype(It) getIterator() const { return It; }

    const_pred_succ_iterator operator++() {
      ++It;
      return *this;
    }
    const_pred_succ_iterator operator++(int) {
      auto Copy = *this;
      ++(*this);
      return Copy;
    }
    bool operator==(const const_pred_succ_iterator &Other) const {
      return It == Other.It;
    }
    bool operator!=(const const_pred_succ_iterator &Other) const {
      return !(*this == Other);
    }
  };

  edge_iterator preds_begin() { return edge_iterator(Predecessors.begin()); }
  [[nodiscard]] const_pred_succ_iterator preds_begin() const {
    return const_pred_succ_iterator(Predecessors.begin());
  }
  edge_iterator preds_end() { return edge_iterator(Predecessors.end()); }
  [[nodiscard]] const_pred_succ_iterator preds_end() const {
    return const_pred_succ_iterator(Predecessors.end());
  }
  [[nodiscard]] llvm::iterator_range<const_pred_succ_iterator>
  predecessors() const {
    return llvm::make_range(preds_begin(), preds_end());
  }
  [[nodiscard]] llvm::iterator_range<edge_iterator> predecessors() {
    return llvm::make_range(preds_begin(), preds_end());
  }
  [[nodiscard]] unsigned preds_size() const { return Predecessors.size(); }
  [[nodiscard]] bool preds_empty() const { return Predecessors.empty(); }

  edge_iterator succs_begin() { return edge_iterator(Successors.begin()); }
  [[nodiscard]] const_pred_succ_iterator succs_begin() const {
    return const_pred_succ_iterator(Successors.begin());
  }
  [[nodiscard]] const_pred_succ_iterator succs_end() const {
    return const_pred_succ_iterator(Successors.end());
  }
  edge_iterator succs_end() { return edge_iterator(Successors.end()); }
  [[nodiscard]] llvm::iterator_range<const_pred_succ_iterator>
  successors() const {
    return llvm::make_range(succs_begin(), succs_end());
  }
  [[nodiscard]] llvm::iterator_range<edge_iterator> successors() {
    return llvm::make_range(succs_begin(), succs_end());
  }
  [[nodiscard]] unsigned succs_size() const { return Successors.size(); }
  [[nodiscard]] bool succs_empty() const { return Successors.empty(); }

  iterator getFirstNonDebugInstr(bool SkipPseudoOp = true);
  [[nodiscard]] const_iterator
  getFirstNonDebugInstr(bool SkipPseudoOp = true) const {
    return const_cast<PredicatedMachineBasicBlock *>(this)
        ->getFirstNonDebugInstr(SkipPseudoOp);
  }

  iterator getLastNonDebugInstr(bool SkipPseudoOp = true);
  [[nodiscard]] const_iterator
  getLastNonDebugInstr(bool SkipPseudoOp = true) const {
    return const_cast<PredicatedMachineBasicBlock *>(this)
        ->getLastNonDebugInstr(SkipPseudoOp);
  }

  [[nodiscard]] bool doesLastInstrModifyPredicate() const;

  void print(llvm::raw_ostream &OS, unsigned Indent) const;

  LLVM_DUMP_METHOD void dump() const;
};

/// \brief Builder for \c PredicatedMachineBasicBlock instances.
class PredMBBBuilder {
  PredicatedMachineBasicBlock Out;

public:
  explicit PredMBBBuilder(llvm::MachineBasicBlock &MBB, IPPredicatedCFG &Parent,
                          unsigned GlobalIdx)
      : Out(MBB, Parent, GlobalIdx) {}

  PredMBBBuilder(const PredMBBBuilder &) = delete;
  PredMBBBuilder &operator=(const PredMBBBuilder &) = delete;

  void addPredecessorBlock(PredMBBBuilder &MBB) {
    Out.Predecessors.insert(MBB);
    MBB.Out.Successors.insert(*this);
  }

  void removePredecessorBlock(PredMBBBuilder &MBB) {
    Out.Predecessors.erase(MBB);
    MBB.Out.Successors.erase(*this);
  }

  void addSuccessorBlock(PredMBBBuilder &MBB) {
    Out.Successors.insert(MBB);
    MBB.Out.Predecessors.insert(*this);
  }

  void removeSuccessorBlock(PredMBBBuilder &MBB) {
    Out.Successors.erase(MBB);
    MBB.Out.Predecessors.erase(*this);
  }
  void setHasUnresolvedEdges(bool V) { Out.HasUnresolvedEdges = V; }

  PredicatedMachineBasicBlock &getPredMBB() { return Out; }
  [[nodiscard]] const PredicatedMachineBasicBlock &getPredMBB() const {
    return Out;
  }
};

inline PredicatedMachineBasicBlock::edge_iterator::reference
PredicatedMachineBasicBlock::edge_iterator::operator*() const {
  return It->get().getPredMBB();
}

inline PredicatedMachineBasicBlock::edge_iterator::pointer
PredicatedMachineBasicBlock::edge_iterator::operator->() const {
  return &It->get().getPredMBB();
}

inline PredicatedMachineBasicBlock::const_pred_succ_iterator::reference
PredicatedMachineBasicBlock::const_pred_succ_iterator::operator*() const {
  return It->get().getPredMBB();
}

inline PredicatedMachineBasicBlock::const_pred_succ_iterator::pointer
PredicatedMachineBasicBlock::const_pred_succ_iterator::operator->() const {
  return &It->get().getPredMBB();
}

} // namespace luthier

namespace llvm {

template <> struct GraphTraits<luthier::PredicatedMachineBasicBlock *> {
  using NodeRef = luthier::PredicatedMachineBasicBlock *;
  using ChildIteratorType = llvm::pointer_iterator<
      luthier::PredicatedMachineBasicBlock::edge_iterator>;

  static NodeRef getEntryNode(luthier::PredicatedMachineBasicBlock *BB) {
    return BB;
  }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->succs_begin());
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->succs_end());
  }
  static unsigned getNumber(luthier::PredicatedMachineBasicBlock *BB) {
    return BB->getGlobalNumber();
  }
};

static_assert(GraphHasNodeNumbers<luthier::PredicatedMachineBasicBlock *>,
              "GraphTraits getNumber() not detected");

template <> struct GraphTraits<const luthier::PredicatedMachineBasicBlock *> {
  using NodeRef = const luthier::PredicatedMachineBasicBlock *;
  using ChildIteratorType = llvm::pointer_iterator<
      luthier::PredicatedMachineBasicBlock::const_pred_succ_iterator>;

  static NodeRef getEntryNode(const luthier::PredicatedMachineBasicBlock *BB) {
    return BB;
  }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->succs_begin());
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->succs_end());
  }
  static unsigned getNumber(const luthier::PredicatedMachineBasicBlock *BB) {
    return BB->getGlobalNumber();
  }
};

static_assert(GraphHasNodeNumbers<const luthier::PredicatedMachineBasicBlock *>,
              "GraphTraits getNumber() not detected");

template <>
struct GraphTraits<Inverse<luthier::PredicatedMachineBasicBlock *>> {
  using NodeRef = luthier::PredicatedMachineBasicBlock *;
  using ChildIteratorType = llvm::pointer_iterator<
      luthier::PredicatedMachineBasicBlock::edge_iterator>;

  static NodeRef
  getEntryNode(Inverse<luthier::PredicatedMachineBasicBlock *> G) {
    return G.Graph;
  }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->preds_begin());
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->preds_end());
  }
  static unsigned getNumber(luthier::PredicatedMachineBasicBlock *BB) {
    return BB->getGlobalNumber();
  }
};

template <>
struct GraphTraits<Inverse<const luthier::PredicatedMachineBasicBlock *>> {
  using NodeRef = const luthier::PredicatedMachineBasicBlock *;
  using ChildIteratorType = llvm::pointer_iterator<
      luthier::PredicatedMachineBasicBlock::const_pred_succ_iterator>;

  static NodeRef
  getEntryNode(Inverse<const luthier::PredicatedMachineBasicBlock *> G) {
    return G.Graph;
  }
  static ChildIteratorType child_begin(NodeRef N) {
    return ChildIteratorType(N->preds_begin());
  }
  static ChildIteratorType child_end(NodeRef N) {
    return ChildIteratorType(N->preds_end());
  }
  static unsigned getNumber(const luthier::PredicatedMachineBasicBlock *BB) {
    return BB->getGlobalNumber();
  }
};

static_assert(
    GraphHasNodeNumbers<Inverse<const luthier::PredicatedMachineBasicBlock *>>,
    "GraphTraits getNumber() not detected");

} // namespace llvm

#endif
