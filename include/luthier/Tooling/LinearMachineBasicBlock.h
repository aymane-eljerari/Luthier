//===-- LinearMachineBasicBlock.h -------------------------------*- C++ -*-===//
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
/// \file LinearMachineBasicBlock.h
/// Defines the \c LinearMachineBasicBlock class.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_LINEAR_MACHINE_BASIC_BLOCK_H
#define LUTHIER_TOOLING_LINEAR_MACHINE_BASIC_BLOCK_H
#include "luthier/Tooling/PredicatedMachineBasicBlock.h"
#include <llvm/CodeGen/MachineBasicBlock.h>

namespace luthier {

class PredicatedCFG;

class LinearMBBBuilder;

/// \brief a wrapper around a group of <tt>VectorMBB</tt>s inside a single
/// \c llvm::MachineBasicBlock for easier construction of the \c VectorCFG
class LinearMachineBasicBlock {
  friend LinearMBBBuilder;

  /// The CFG this scalar MBB belongs to
  PredicatedCFG &ParentCFG;
  /// The MIR MBB this scalar block wraps around; If \c nullptr then this
  /// is an entry/exit block of the \c IPVectorCFG
  llvm::MachineBasicBlock *ParentMBB{nullptr};

  llvm::SmallVector<PredMBBBuilder, 6> PredMBBs{};

  LinearMachineBasicBlock(llvm::MachineBasicBlock &ParentMBB,
                          PredicatedCFG &ParentCFG)
      : ParentCFG(ParentCFG), ParentMBB(&ParentMBB) {};

  explicit LinearMachineBasicBlock(PredicatedCFG &ParentCFG)
      : ParentCFG(ParentCFG) {};

public:
  /// Disallowed copy construction
  LinearMachineBasicBlock(const LinearMachineBasicBlock &) = delete;

  /// Disallowed assignment operation
  LinearMachineBasicBlock &operator=(const LinearMachineBasicBlock &) = delete;

  class iterator {
    decltype(PredMBBs)::iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = PredicatedMachineBasicBlock;
    using reference = value_type &;
    using pointer = value_type *;

    explicit iterator(const decltype(PredMBBs)::iterator &It) : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->operator->(); }

    iterator operator++() {
      ++It;
      return *this;
    }

    iterator operator++(int) {
      auto Copy = *this;
      ++(*this);
      return Copy;
    }

    bool operator==(const iterator &Other) const { return It == Other.It; }

    bool operator!=(const iterator &Other) const { return !(*this == Other); }
  };

  class const_iterator {
    decltype(PredMBBs)::const_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = const PredicatedMachineBasicBlock;
    using reference = value_type &;
    using pointer = value_type *;

    explicit const_iterator(const decltype(PredMBBs)::const_iterator &It)
        : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->operator->(); }

    const_iterator operator++() {
      ++It;
      return *this;
    }

    const_iterator operator++(int) {
      auto Copy = *this;
      ++(*this);
      return Copy;
    }

    bool operator==(const const_iterator &Other) const {
      return It == Other.It;
    }

    bool operator!=(const const_iterator &Other) const {
      return !(*this == Other);
    }
  };

  [[nodiscard]] const PredicatedCFG &getParent() const { return ParentCFG; }

  [[nodiscard]] PredicatedCFG &getParent() { return ParentCFG; }

  [[nodiscard]] const llvm::MachineBasicBlock *getMBB() const {
    return ParentMBB;
  }

  iterator begin() { return iterator(PredMBBs.begin()); }

  [[nodiscard]] const_iterator begin() const {
    return const_iterator(PredMBBs.begin());
  }

  iterator end() { return iterator(PredMBBs.end()); }

  [[nodiscard]] const_iterator end() const {
    return const_iterator(PredMBBs.end());
  }

  [[nodiscard]] const PredicatedMachineBasicBlock &front() const {
    return *PredMBBs.front();
  }

  [[nodiscard]] const PredicatedMachineBasicBlock &back() const {
    return *PredMBBs.back();
  }

  void print(llvm::raw_ostream &OS, unsigned int Indent) const;
};

class LinearMBBBuilder {

  std::unique_ptr<LinearMachineBasicBlock> Out;
  PredMBBBuilder *EntryPredOneBlock{nullptr};
  PredMBBBuilder *EntryPredZeroOrOneBlock{nullptr};
  PredMBBBuilder *ExitPredOneBlock{nullptr};
  PredMBBBuilder *ExitPredZeroOrOneBlock{nullptr};

  explicit LinearMBBBuilder(PredicatedCFG &ParentCFG)
      : Out(new LinearMachineBasicBlock(ParentCFG)) {};

public:
  LinearMBBBuilder(const LinearMBBBuilder &Other) = delete;

  LinearMBBBuilder(LinearMBBBuilder &&Other) noexcept
      : Out(std::move(Other.Out)), EntryPredOneBlock(Other.EntryPredOneBlock),
        EntryPredZeroOrOneBlock(Other.EntryPredZeroOrOneBlock),
        ExitPredOneBlock(Other.ExitPredOneBlock),
        ExitPredZeroOrOneBlock(Other.ExitPredZeroOrOneBlock) {}

  LinearMBBBuilder &operator=(const LinearMBBBuilder &Other) = delete;

  LinearMBBBuilder &operator=(LinearMBBBuilder &&Other) noexcept {
    if (this == &Other)
      return *this;
    Out = std::move(Other.Out);
    EntryPredOneBlock = Other.EntryPredOneBlock;
    EntryPredZeroOrOneBlock = Other.EntryPredZeroOrOneBlock;
    ExitPredOneBlock = Other.ExitPredOneBlock;
    ExitPredZeroOrOneBlock = Other.ExitPredZeroOrOneBlock;
    return *this;
  }

  const LinearMachineBasicBlock &operator*() const { return *Out; }

  const LinearMachineBasicBlock *operator->() const { return Out.get(); }

  LinearMachineBasicBlock &operator*() { return *Out; }

  LinearMachineBasicBlock *operator->() { return Out.get(); }

  static LinearMBBBuilder createScalarMBB(llvm::MachineBasicBlock &ParentMBB,
                                          PredicatedCFG &ParentCFG);

  static LinearMBBBuilder createEntryScalarMBB(PredicatedCFG &ParentCFG);

  [[nodiscard]] bool hasFinalizedLinking() const {
    return !EntryPredOneBlock || !EntryPredZeroOrOneBlock ||
           !ExitPredOneBlock || !ExitPredZeroOrOneBlock;
  }

  void addSuccessor(LinearMBBBuilder &LMBB);

  void addPredecessor(LinearMBBBuilder &LMBB);

  void finalizeLinking();
};

} // namespace luthier

#endif