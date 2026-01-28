//===-- IPVectorCFG.h --------------------------------------------*- C++-*-===//
// Copyright 2022-2026 @ Northeastern University Computer Architecture Lab
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
/// \file IPVectorCFG.h
/// Describes the \c IPVectorCFG class and its basic blocks.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_IP_VECTOR_CFG_H
#define LUTHIER_TOOLING_IP_VECTOR_CFG_H
#include <llvm/ADT/DenseSet.h>
#include <llvm/ADT/Twine.h>
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/Support/GenericDomTree.h>

namespace llvm {

class MachineInstr;

class MachineFunction;

class LivePhysRegs;
} // namespace llvm

namespace luthier {

class IPVectorCFG;

class VectorCFG;

class ScalarMBB;

class VectorMBB;

class VectorMachineInstr {
  VectorMBB &Parent;

  const llvm::MachineInstr &MI;

public:
  VectorMachineInstr(const VectorMBB &Parent, const llvm::MachineInstr &MI)
      : Parent(const_cast<VectorMBB &>(Parent)), MI(MI) {}

  VectorMachineInstr(VectorMBB &Parent, const llvm::MachineInstr &MI)
      : Parent(Parent), MI(MI) {}

  const llvm::MachineInstr &operator*() const { return MI; }

  const llvm::MachineInstr *operator->() const { return &MI; }

  VectorMBB &getParent() { return Parent; }

  [[nodiscard]] const VectorMBB &getParent() const { return Parent; }
};

/// \brief A basic block inside the inter-procedural vector control flow graph;
/// Used primarily in flow analysis involving vector GPRs and instructions
/// \details In addition to normal scalar control flow operations that end a
/// basic block in LLVM MIR, any operation that modifies the execute
/// mask or a call instruction will result in the termination of the vector
/// basic block
class VectorMBB {
public:
  enum ExecMaskValue { ZeroOrOne = 0, One = 1 };

private:
  /// Indicates the value of the execute mask inside this vector MBB
  ExecMaskValue EMV;

  /// Index of the vector MBB inside the IP vector CFG
  unsigned GlobalIdx;

  /// Index of the vector MBB inside its parent Scalar MBB
  unsigned ScalarMBBIdx;

  /// The scalar MBB this vector MBB belongs to
  ScalarMBB &Parent;

  /// The range of instructions in the block
  llvm::iterator_range<llvm::MachineBasicBlock::const_instr_iterator>
      Instructions{{}, {}};

  /// Set of predecessor blocks
  llvm::SmallDenseSet<VectorMBB *> Predecessors{};

  /// Set of successor blocks
  llvm::SmallDenseSet<VectorMBB *> Successors{};

public:
  /// \note Do not use; Use Scalar MBB to create VectorMBBs instead
  explicit VectorMBB(ScalarMBB &Parent, ExecMaskValue EMV)
      : EMV(EMV), GlobalIdx(0), ScalarMBBIdx(0), Parent(Parent) {}

  /// Makes the MBB point to a new range of instructions in a single MBB
  void setInstRange(llvm::MachineBasicBlock::const_instr_iterator Begin,
                    llvm::MachineBasicBlock::const_instr_iterator End);

  /// Disallowed copy construction
  VectorMBB(const VectorMBB &) = delete;

  /// Disallowed assignment operation
  VectorMBB &operator=(const VectorMBB &) = delete;

  [[nodiscard]] const ScalarMBB &getParent() const { return Parent; };

  [[nodiscard]] ScalarMBB &getParent() { return Parent; };

  class iterator {
    VectorMBB &Parent;
    llvm::MachineBasicBlock::const_instr_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = VectorMachineInstr;

    iterator(VectorMBB &Parent,
             llvm::MachineBasicBlock::const_instr_iterator It)
        : Parent(Parent), It(It) {}

    value_type operator*() const { return VectorMachineInstr{Parent, *It}; }

    value_type operator->() const { return VectorMachineInstr{Parent, *It}; }

    [[nodiscard]] decltype(It) getIterator() const { return It; }

    iterator operator++() {
      do {
        ++It;
      } while (It != Parent.end().getIterator() && It->isDebugInstr());
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
    VectorMBB &Parent;
    llvm::MachineBasicBlock::const_instr_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = const VectorMachineInstr;

    const_iterator(VectorMBB &Parent,
                   llvm::MachineBasicBlock::const_instr_iterator It)
        : Parent(Parent), It(It) {}

    explicit const_iterator(const VectorMachineInstr &MI)
        : Parent(const_cast<VectorMBB &>(MI.getParent())),
          It(MI->getIterator()) {};

    value_type operator*() const { return VectorMachineInstr{Parent, *It}; }

    value_type operator->() const { return VectorMachineInstr{Parent, *It}; }

    [[nodiscard]] decltype(It) getIterator() const { return It; }

    const_iterator operator++() {
      do {
        ++It;
      } while (It != Parent.end().getIterator() && It->isDebugInstr());

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

  [[nodiscard]] const_iterator begin() const {
    return const_iterator{*const_cast<VectorMBB *>(this), Instructions.begin()};
  }

  const VectorMachineInstr front() const { return *begin(); }

  [[nodiscard]] const_iterator end() const {
    return const_iterator{*const_cast<VectorMBB *>(this), Instructions.end()};
  }

  const VectorMachineInstr back() const {
    return *(
        const_iterator{*const_cast<VectorMBB *>(this), --Instructions.end()});
  }

  [[nodiscard]] bool empty() const { return Instructions.empty(); }

  unsigned size() const {
    return std::distance(Instructions.begin(), Instructions.end());
  }

  [[nodiscard]] ExecMaskValue getExecMaskValue() const { return EMV; }

  [[nodiscard]] unsigned getGlobalNumber() const { return GlobalIdx; }

  [[nodiscard]] unsigned getLocalNumber() const { return ScalarMBBIdx; }

  void setGlobalIndex(unsigned I) { GlobalIdx = I; }

  [[nodiscard]] std::string getName() const;

  auto preds_begin() { return Predecessors.begin(); }

  [[nodiscard]] auto preds_begin() const { return Predecessors.begin(); }

  [[nodiscard]] auto preds_end() const { return Predecessors.end(); }

  auto preds_end() { return Predecessors.end(); }

  [[nodiscard]] auto predecessors() const {
    return llvm::make_range(Predecessors.begin(), Predecessors.end());
  }

  [[nodiscard]] auto predecessors() {
    return llvm::make_range(Predecessors.begin(), Predecessors.end());
  }

  [[nodiscard]] auto preds_size() const { return Predecessors.size(); }

  [[nodiscard]] bool preds_empty() const { return Predecessors.empty(); }

  auto succs_begin() { return Successors.begin(); }

  [[nodiscard]] auto succs_begin() const { return Successors.begin(); }

  [[nodiscard]] auto succs_end() const { return Successors.end(); }

  auto succs_end() { return Successors.end(); }

  [[nodiscard]] auto successors() const {
    return llvm::make_range(Successors.begin(), Successors.end());
  }

  [[nodiscard]] auto successors() {
    return llvm::make_range(Successors.begin(), Successors.end());
  }

  [[nodiscard]] auto succs_size() const { return Successors.size(); }

  [[nodiscard]] bool succs_empty() const { return Successors.empty(); }

  void addPredecessorBlock(VectorMBB &MBB) {
    Predecessors.insert(&MBB);
    MBB.Successors.insert(this);
  }

  void removePredecessorBlock(VectorMBB &MBB) {
    Predecessors.erase(&MBB);
    MBB.Successors.erase(this);
  }

  void addSuccessorBlock(VectorMBB &MBB) {
    Successors.insert(&MBB);
    MBB.Predecessors.insert(this);
  }

  void removeSuccessorBlock(VectorMBB &MBB) {
    Successors.erase(&MBB);
    MBB.Predecessors.erase(this);
  }

  void print(llvm::raw_ostream &OS, unsigned int Indent) const;

  LLVM_DUMP_METHOD void dump() const;
};

/// \brief a wrapper around a group of <tt>VectorMBB</tt>s inside a single
/// \c llvm::MachineBasicBlock for easier construction of the \c VectorCFG
class ScalarMBB {
  /// The CFG this scalar MBB belongs to
  VectorCFG &ParentCFG;
  /// The MIR MBB this scalar block wraps around; If \c nullptr then this
  /// is an entry/exit block of the \c IPVectorCFG
  const llvm::MachineBasicBlock *ParentMBB{nullptr};

  llvm::SmallVector<std::unique_ptr<VectorMBB>> VectorMBBs{};

  ScalarMBB(const llvm::MachineBasicBlock &ParentMBB, VectorCFG &ParentCFG)
      : ParentCFG(ParentCFG), ParentMBB(&ParentMBB) {};

  explicit ScalarMBB(VectorCFG &ParentCFG) : ParentCFG(ParentCFG) {};

public:
  static llvm::Expected<std::unique_ptr<ScalarMBB>>
  createScalarMBB(const llvm::MachineBasicBlock &ParentMBB,
                  VectorCFG &ParentCFG);

  static llvm::Expected<std::unique_ptr<ScalarMBB>>
  createEntryScalarMBB(VectorCFG &ParentCFG);

  /// Disallowed copy construction
  ScalarMBB(const ScalarMBB &) = delete;

  /// Disallowed assignment operation
  ScalarMBB &operator=(const ScalarMBB &) = delete;

  class iterator {
    decltype(VectorMBBs)::iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = VectorMBB;
    using reference = value_type &;
    using pointer = value_type *;

    explicit iterator(const decltype(VectorMBBs)::iterator &It) : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->get(); }

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
    decltype(VectorMBBs)::const_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = const VectorMBB;
    using reference = value_type &;
    using pointer = value_type *;

    explicit const_iterator(const decltype(VectorMBBs)::const_iterator &It)
        : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->get(); }

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

  [[nodiscard]] const VectorCFG &getParent() const { return ParentCFG; }

  [[nodiscard]] VectorCFG &getParent() { return ParentCFG; }

  [[nodiscard]] const llvm::MachineBasicBlock *getMBB() const {
    return ParentMBB;
  }

  iterator begin() { return iterator(VectorMBBs.begin()); }

  [[nodiscard]] const_iterator begin() const {
    return const_iterator(VectorMBBs.begin());
  }

  iterator end() { return iterator(VectorMBBs.end()); }

  [[nodiscard]] const_iterator end() const {
    return const_iterator(VectorMBBs.end());
  }

  [[nodiscard]] const VectorMBB &front() const { return *VectorMBBs.front(); }

  [[nodiscard]] const VectorMBB &back() const { return *VectorMBBs.back(); }

  void addSuccessor(ScalarMBB &SMBB);

  void addPredecessor(ScalarMBB &SMBB);

  void eliminateTrivialEmptyBlocks();

  iterator findFirstTakenVectorMBB() {
    return iterator(
        llvm::find_if(VectorMBBs, [](std::unique_ptr<VectorMBB> &VMBB) {
          return VMBB->getExecMaskValue() == VectorMBB::ExecMaskValue::One;
        }));
  }

  [[nodiscard]] const_iterator findFirstTakenVectorMBB() const {
    return const_iterator(
        llvm::find_if(VectorMBBs, [](const std::unique_ptr<VectorMBB> &VMBB) {
          return VMBB->getExecMaskValue() == VectorMBB::ExecMaskValue::One;
        }));
  }

  iterator findFirstNonTakenVectorMBB() {
    return iterator(
        llvm::find_if(VectorMBBs, [](std::unique_ptr<VectorMBB> &VMBB) {
          return VMBB->getExecMaskValue() ==
                 VectorMBB::ExecMaskValue::ZeroOrOne;
        }));
  }

  [[nodiscard]] const_iterator findFirstNonTakenVectorMBB() const {
    return const_iterator(
        llvm::find_if(VectorMBBs, [](const std::unique_ptr<VectorMBB> &VMBB) {
          return VMBB->getExecMaskValue() ==
                 VectorMBB::ExecMaskValue::ZeroOrOne;
        }));
  }

  void print(llvm::raw_ostream &OS, unsigned int Indent) const;
};

class VectorCFG {
  IPVectorCFG &ParentCFG;

  const llvm::MachineFunction &MF;

  llvm::SmallVector<std::unique_ptr<ScalarMBB>> ScalarMBBs{};

  llvm::SmallDenseMap<const llvm::MachineBasicBlock *, ScalarMBB *>
      MBBToScalarMBBs{};

  VectorCFG(IPVectorCFG &ParentCFG, const llvm::MachineFunction &MF)
      : ParentCFG(ParentCFG), MF(MF) {};

public:
  /// Disallowed copy construction
  VectorCFG(const VectorCFG &) = delete;

  /// Disallowed assignment operation
  VectorCFG &operator=(const VectorCFG &) = delete;

  static llvm::Expected<std::unique_ptr<VectorCFG>>
  createVectorCFG(IPVectorCFG &ParentCFG, const llvm::MachineFunction &MF);

  class iterator {
    decltype(ScalarMBBs)::iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = ScalarMBB;
    using reference = value_type &;
    using pointer = value_type *;

    explicit iterator(const decltype(ScalarMBBs)::iterator &It) : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->get(); }

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
    decltype(ScalarMBBs)::const_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = const ScalarMBB;
    using reference = value_type &;
    using pointer = value_type *;

    explicit const_iterator(const decltype(ScalarMBBs)::const_iterator &It)
        : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->get(); }

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

  iterator begin() { return iterator(ScalarMBBs.begin()); }

  [[nodiscard]] const_iterator begin() const {
    return const_iterator(ScalarMBBs.begin());
  }

  iterator end() { return iterator(ScalarMBBs.end()); }

  [[nodiscard]] const_iterator end() const {
    return const_iterator(ScalarMBBs.end());
  }

  [[nodiscard]] const ScalarMBB &front() const { return *ScalarMBBs.front(); }

  [[nodiscard]] ScalarMBB &front() { return *ScalarMBBs.front(); }

  [[nodiscard]] const ScalarMBB &back() const { return *ScalarMBBs.back(); }

  [[nodiscard]] ScalarMBB &back() { return *ScalarMBBs.back(); }

  [[nodiscard]] const ScalarMBB &
  getScalarMBB(const llvm::MachineBasicBlock &MBB) const {
    return *MBBToScalarMBBs.at(&MBB);
  }

  [[nodiscard]] const llvm::MachineFunction &getMF() const { return MF; }

  [[nodiscard]] const IPVectorCFG &getParent() const { return ParentCFG; }

  [[nodiscard]] IPVectorCFG &getParent() { return ParentCFG; }

  void print(llvm::raw_ostream &OS) const;

  LLVM_DUMP_METHOD void dump() const;
};

/// \brief An inter-procedural control-flow graph representation for the MIR of
/// the AMDGPU backend that, in addition to scalar branches, regards
/// instructions that manipulate the execute mask as well as call instructions
/// as a terminator for its basic blocks
/// \details The vector CFG can be used to perform data flow analysis
/// involving vector registers (e.g. register liveness) which cannot be done
/// with the CFG of LLVM MIR for the AMD GPU backend
class IPVectorCFG {
private:
  llvm::SmallVector<std::unique_ptr<VectorCFG>> VectorCFGs{};

  llvm::SmallDenseMap<const llvm::MachineFunction *, VectorCFG *>
      MFToVecCFGMap{};

  unsigned NumVecMBBs{0};

  IPVectorCFG() = default;

public:
  class iterator {
    decltype(VectorCFGs)::iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = VectorCFG;
    using reference = value_type &;
    using pointer = value_type *;

    explicit iterator(const decltype(VectorCFGs)::iterator &It) : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->get(); }

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
    decltype(VectorCFGs)::const_iterator It;

  public:
    using difference_type = ptrdiff_t;
    using iterator_category = std::forward_iterator_tag;
    using value_type = const VectorCFG;
    using reference = value_type &;
    using pointer = value_type *;

    explicit const_iterator(const decltype(VectorCFGs)::const_iterator &It)
        : It(It) {}

    reference operator*() const { return **It; }

    pointer operator->() const { return It->get(); }

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

  iterator begin() { return iterator(VectorCFGs.begin()); }

  [[nodiscard]] const_iterator begin() const {
    return const_iterator(VectorCFGs.begin());
  }

  iterator end() { return iterator(VectorCFGs.end()); }

  [[nodiscard]] const_iterator end() const {
    return const_iterator(VectorCFGs.end());
  }

  [[nodiscard]] const VectorCFG &front() const { return *VectorCFGs.front(); }

  [[nodiscard]] const VectorCFG &back() const { return *VectorCFGs.back(); }

  [[nodiscard]] VectorCFG &back() { return *VectorCFGs.back(); }

  VectorCFG &operator[](const llvm::MachineFunction &MF) {
    assert(MFToVecCFGMap.contains(&MF) && "Entry is not in the map");
    return *MFToVecCFGMap[&MF];
  }

  [[nodiscard]] const VectorCFG &at(const llvm::MachineFunction &MF) const {
    assert(MFToVecCFGMap.contains(&MF) && "Entry is not in the map");
    return *MFToVecCFGMap.at(&MF);
  }

  [[nodiscard]] unsigned getNumVecMBBs() const { return NumVecMBBs; }

  void print(llvm::raw_ostream &OS) const;

  LLVM_DUMP_METHOD void dump() const;

  static llvm::Expected<std::unique_ptr<IPVectorCFG>>
  calculateIPVectorCFG(llvm::Module &M, llvm::ModuleAnalysisManager &MAM);
};

class IPVectorCFGAnalysis
    : public llvm::AnalysisInfoMixin<IPVectorCFGAnalysis> {
  friend llvm::AnalysisInfoMixin<IPVectorCFGAnalysis>;

private:
  static llvm::AnalysisKey Key;

public:
  class Result {
    friend IPVectorCFGAnalysis;

    std::unique_ptr<IPVectorCFG> IPCFG;

    Result(std::unique_ptr<IPVectorCFG> IPCFG) : IPCFG(std::move(IPCFG)) {};

  public:
    bool invalidate(llvm::Module &M, const llvm::PreservedAnalyses &PA,
                    llvm::ModuleAnalysisManager::Invalidator &Inv);

    const IPVectorCFG &getVecCFG() const { return *IPCFG; }

    IPVectorCFG &getVecCFG() { return *IPCFG; }
  };

  IPVectorCFGAnalysis() = default;

  Result run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM);
};

class IPVectorCFGPrinterPass : public llvm::PassInfoMixin<IPVectorCFGAnalysis> {

private:
  llvm::raw_ostream &OS;

public:
  explicit IPVectorCFGPrinterPass(llvm::raw_ostream &OS) : OS(OS) {};

  llvm::PreservedAnalyses run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM);
};

} // namespace luthier

namespace llvm {

template <> struct GraphTraits<luthier::VectorMBB *> {
  using NodeRef = luthier::VectorMBB *;
  using ChildIteratorType = SmallDenseSet<luthier::VectorMBB *>::iterator;

  static NodeRef getEntryNode(luthier::VectorMBB *BB) { return BB; }

  static ChildIteratorType child_begin(NodeRef N) { return N->succs_begin(); }

  static ChildIteratorType child_end(NodeRef N) {
    return N->successors().end();
  }

  static unsigned getNumber(luthier::VectorMBB *BB) {
    return BB->getGlobalNumber();
  }
};

static_assert(GraphHasNodeNumbers<luthier::VectorMBB *>,
              "GraphTraits getNumber() not detected");

template <> struct GraphTraits<const luthier::VectorMBB *> {
  using NodeRef = const luthier::VectorMBB *;
  using ChildIteratorType = SmallDenseSet<luthier::VectorMBB *>::const_iterator;

  static NodeRef getEntryNode(const luthier::VectorMBB *BB) { return BB; }

  static ChildIteratorType child_begin(NodeRef N) {
    return N->successors().begin();
  }

  static ChildIteratorType child_end(NodeRef N) {
    return N->successors().end();
  }

  static unsigned getNumber(const luthier::VectorMBB *BB) {
    return BB->getGlobalNumber();
  }
};

static_assert(GraphHasNodeNumbers<const luthier::VectorMBB *>,
              "GraphTraits getNumber() not detected");

template <> struct GraphTraits<Inverse<luthier::VectorMBB *>> {
  using NodeRef = luthier::VectorMBB *;
  using ChildIteratorType = SmallDenseSet<luthier::VectorMBB *>::iterator;

  static NodeRef getEntryNode(Inverse<luthier::VectorMBB *> G) {
    return G.Graph;
  }

  static ChildIteratorType child_begin(NodeRef N) { return N->preds_begin(); }
  static ChildIteratorType child_end(NodeRef N) { return N->preds_end(); }

  static unsigned getNumber(luthier::VectorMBB *BB) {
    return BB->getGlobalNumber();
  }
};

template <> struct GraphTraits<Inverse<const luthier::VectorMBB *>> {
  using NodeRef = const luthier::VectorMBB *;
  using ChildIteratorType = SmallDenseSet<luthier::VectorMBB *>::const_iterator;

  static NodeRef getEntryNode(Inverse<const luthier::VectorMBB *> G) {
    return G.Graph;
  }

  static ChildIteratorType child_begin(NodeRef N) { return N->preds_begin(); }
  static ChildIteratorType child_end(NodeRef N) { return N->preds_end(); }

  static unsigned getNumber(const luthier::VectorMBB *BB) {
    return BB->getGlobalNumber();
  }
};

static_assert(GraphHasNodeNumbers<Inverse<const luthier::VectorMBB *>>,
              "GraphTraits getNumber() not detected");

template <> struct DomTreeNodeTraits<luthier::VectorMBB> {
  using NodeType = luthier::VectorMBB;
  using NodePtr = luthier::VectorMBB *;
  using ParentPtr = luthier::IPVectorCFG *;
  using ParentType = std::remove_pointer_t<ParentPtr>;

  static luthier::VectorMBB *getEntryNode(ParentPtr Parent) {
    return &*Parent->begin()->begin()->begin();
  }

  static ParentPtr getParent(NodePtr BB) {
    return &BB->getParent().getParent().getParent();
  }
};

template <> struct DomTreeNodeTraits<const luthier::VectorMBB> {
  using NodeType = const luthier::VectorMBB;
  using NodePtr = const luthier::VectorMBB *;
  using ParentPtr = const luthier::IPVectorCFG *;
  using ParentType = std::remove_pointer_t<ParentPtr>;

  static const luthier::VectorMBB *getEntryNode(ParentPtr Parent) {
    return &*Parent->begin()->begin()->begin();
  }

  static ParentPtr getParent(NodePtr BB) {
    return &BB->getParent().getParent().getParent();
  }
};

template <>
struct GraphTraits<luthier::IPVectorCFG *>
    : public GraphTraits<luthier::VectorMBB *> {
  static NodeRef getEntryNode(luthier::IPVectorCFG *F) {
    return &*F->begin()->begin()->begin();
  }

  // nodes_iterator/begin/end - Allow iteration over all nodes in the graph
  using nodes_iterator = luthier::ScalarMBB::iterator;

  static nodes_iterator nodes_begin(luthier::IPVectorCFG *F) {
    return F->begin()->begin()->begin();
  }

  static nodes_iterator nodes_end(luthier::IPVectorCFG *F) {
    return F->back().back().end();
  }

  static unsigned size(luthier::IPVectorCFG *F) { return F->getNumVecMBBs(); }

  static unsigned getMaxNumber(luthier::IPVectorCFG *F) {
    return F->getNumVecMBBs();
  }
  static unsigned getNumberEpoch(luthier::IPVectorCFG *F) {
    return F->getNumVecMBBs();
  }
};

template <>
struct GraphTraits<const luthier::IPVectorCFG *>
    : public GraphTraits<const luthier::VectorMBB *> {
  static NodeRef getEntryNode(const luthier::IPVectorCFG *F) {
    return &*F->begin()->begin()->begin();
  }

  // nodes_iterator/begin/end - Allow iteration over all nodes in the graph
  using nodes_iterator = luthier::ScalarMBB::const_iterator;

  static nodes_iterator nodes_begin(const luthier::IPVectorCFG *F) {
    return F->begin()->begin()->begin();
  }

  static nodes_iterator nodes_end(const luthier::IPVectorCFG *F) {
    return nodes_iterator(F->back().back().end());
  }

  static unsigned size(const luthier::IPVectorCFG *F) {
    return F->getNumVecMBBs();
  }

  static unsigned getMaxNumber(const luthier::IPVectorCFG *F) {
    return F->getNumVecMBBs();
  }
  static unsigned getNumberEpoch(const luthier::IPVectorCFG *F) {
    return F->getNumVecMBBs();
  }
};

} // namespace llvm

#endif