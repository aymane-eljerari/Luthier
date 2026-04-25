//===-- MIRToIRTranslator.h -------------------------------------*- C++ -*-===//
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
/// \file MIRToIRTranslator.h
/// Describes a set of APIs used to translate machine functions and
/// individual machine instructions to LLVM IR.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_MIR_TO_IR_TRANSLATOR_H
#define LUTHIER_TOOLING_MIR_TO_IR_TRANSLATOR_H
#include "luthier/Common/DenseMapInfo.h"
#include "luthier/Tooling/MIInlineAsmEmitter.h"
#include <GCNSubtarget.h>
#include <SIInstrInfo.h>
#include <llvm/ADT/DenseMap.h>
#include <llvm/CodeGen/MachineDominators.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Value.h>
#include <llvm/MC/MCRegister.h>
#include <llvm/Support/Error.h>

namespace llvm {

class SIRegisterInfo;
class MachineInstr;
class MachineFunction;
class MachineBasicBlock;
class TargetRegisterInfo;
class MachineOperand;
class Error;

} // namespace llvm

namespace luthier {

class MIRToIRTranslator;

template <uint16_t Opcode>
void raiseMachineInstr(const llvm::MachineInstr &MI,
                       llvm::IRBuilderBase &Builder,
                       MIRToIRTranslator &Translator);

/// \brief A utility class that lazily materializes LLVM Values from
/// physical register operands for use with the IR translator functions.
///
/// \details The tracker stores values keyed by the *exact* register that
/// was written in each machine basic block by the translated IR instructions.
/// When a different-sized overlapping register is requested (sub-register
/// or super-register), the tracker extracts or merges values on demand rather
/// than eagerly splitting every write into register-unit granularity. Registers
/// that overlap but are not strictly super or sub-registers (rare) will be
/// broken down to reg units and then processed via the sub and super reg logic.
///
/// On a write to register R, all overlapping entries (sub- and super-regs)
/// are invalidated so that subsequent reads through a different alias will
/// lazily recompute the value from R's entry. If a register being written only
/// partially overlaps with a tracked value, only the overlapped part is
/// invalidated.
///
/// If being used to translate an entire machine function, the tracker uses
/// the function's prototype and calling convention to figure out the initial
/// values for each register in the entry basic block (a process we also
/// referred to as "seeding"). The function prototype must meet the following
/// requirements:
/// - Kernels and other entry functions shouldn't have any arguments in their
/// prototype. Access to the kernel argument pointer, as well as other SGPR and
/// VGPR registers initialized by the GPU will be instead materialized by
/// emitting both LLVM and Luthier intrinsics at the beginning of the entry
/// basic block, all before the translation process starts. For example,
/// llvm.amdgcn.kernarg.segment.ptr() is used to initialize the SGPR pair's
/// value holding the kernel argument buffer's address.
/// - Any other non-entry functions must have all read/writable GPRs passed
/// as an argument to the function. This includes VGPRs, SGPRs, AGPRs,
/// Exec mask, SCC, VCC, M0, MODE, and FLAT_SCRATCH (on targets that support
/// writing to it). EXECZ and VCCZ are exceptions, as they are indirectly
/// calculated based on the values of EXEC and VCC, respectively. PC is not
/// modeled by the IR translator. Read access to privileged or read-only
/// registers are done via LLVM and Luthier intrinsics.
///
/// As the function prototype is very hard to change after a machine function is
/// assigned ot it, it is the caller's responsibility to have counted all
/// possible GPRs used by the function and adding them to its prototype. To do
/// so, caller must take into account the value of the kernel descriptor or the
/// AMD kernel code's fields to ensure a non-entry function's prototype is
/// properly configured. If a non-entry function is invoked with dynamically
/// allocated VGPRs, it must include the maximum possible number of VGPRs
/// available to each wave.
///
/// The process of seeding can also be done manually when translating individual
/// basic blocks or instructions
class MIRToIRTranslator {
  template <uint16_t Opcode>
  friend void luthier::raiseMachineInstr(const llvm::MachineInstr &MI,
                                         llvm::IRBuilderBase &Builder,
                                         MIRToIRTranslator &Translator);

  void raiseMachineInstr(const llvm::MachineInstr &MI,
                         llvm::IRBuilderBase &Builder);

  /// We keep track of the same physical register's value per its available
  /// type inside each basic block; For example, if the translation requires a
  /// register value of i32 to be cast to a f32, we cache both values. This way,
  /// when a later instruction requests the f32 version, we don't emit a
  /// redundant cast instruction. Allowed types are ints, FP, and pointer types.
  /// Pointer types don't have to check for size compatibility, as they will
  /// use the \c llvm::IntToPtrInst which takes care of truncating/extending
  /// the output pointer size
  using ValueTypeMap = llvm::DenseMap<llvm::Type *, llvm::Value *>;

  using MCRegValueMap = llvm::DenseMap<llvm::MCRegister, ValueTypeMap>;

  /// Identifier for the four modeled register files. Stored as
  /// \c <N x i32> vectors in each block's \c BlockRegState.
  enum class RegFileID : uint8_t {
    SGPR = 0,
    VGPR = 1,
    AGPR = 2,
    TTMP = 3,
    NumFiles = 4
  };

  /// Location of a physical register inside one of the register file vectors.
  /// A slot covers \c NumLanes consecutive 16-bit lanes starting at
  /// \c LaneIdx in \c File
  struct RegFileSlotInfo {
    RegFileID File;    /// < Which register file this register belongs to
    uint64_t LaneIdx;  /// < Lane Idx of the register; Corresponds to the HW Idx
                       /// returned by the TRI
    uint64_t NumLanes; /// < Number of lanes covered by the register
  };

  /// Per-basic block state; Contains individual register read cache plus
  /// any built file vectors requested by the translation
  struct BlockRegState {
    MCRegValueMap RegCache;
    llvm::Value *FileCache[static_cast<size_t>(RegFileID::NumFiles)] = {};
  };

  using BBStateMap =
      llvm::DenseMap<std::reference_wrapper<const llvm::MachineBasicBlock>,
                     BlockRegState>;

  llvm::MachineFunction &MF;

  std::unique_ptr<MIInlineAsmEmitter> InlineAsmEmitter{};

  const llvm::SIRegisterInfo &TRI;

  const llvm::SIInstrInfo &TII;

  const llvm::GCNSubtarget &ST;

  /// Number of 16-bit lanes in each file. Zero if the file is unmodeled
  /// for this target (e.g. AGPRs on non-MAI targets).
  unsigned FileWidths[static_cast<size_t>(RegFileID::NumFiles)] = {};

  /// \c <N x i16> type for each modeled file; null if unmodeled.
  llvm::FixedVectorType *FileTypes[static_cast<size_t>(RegFileID::NumFiles)] =
      {};

  /// Logical SGPR that aliases \c VCC_LO for applicable targets
  llvm::MCRegister VccLoSgpr{llvm::MCRegister::NoRegister};
  /// Logical SGPR that aliases \c XNACK_MASK_LO on targets where xnack is
  /// supported
  llvm::MCRegister XnackMaskLoSgpr{llvm::MCRegister::NoRegister};
  /// Logical SGPR that aliases \c FLAT_SCR_LO on targets that store
  /// \c FLAT_SRC before the VCC with the rest of the normal SGPRs
  llvm::MCRegister FlatScrLoSgpr{llvm::MCRegister::NoRegister};

  struct ToBeFixedRegValuePhiInfo {
    const llvm::MachineBasicBlock *MBB;
    llvm::MCRegister Reg;
    llvm::PHINode *Phi;
  };

  /// Register value placeholder PHIs that need to be fixed up after the
  /// function has been translated
  llvm::SmallVector<ToBeFixedRegValuePhiInfo> ToBeFixedPhis{};

  struct ToBeFixedFilePhiInfo {
    const llvm::MachineBasicBlock *MBB;
    RegFileID File;
    llvm::PHINode *Phi;
  };

  /// File-level placeholder PHIs that need to be fixed up after the function
  /// has been translated
  llvm::SmallVector<ToBeFixedFilePhiInfo> ToBeFixedFilePhis{};

  /// Per-basic block register and file value mapping; This is updated every
  /// time a single register/file is read/written to
  BBStateMap VM{};

public:
  MIRToIRTranslator(llvm::MachineFunction &MF, llvm::Error &Err);

private:
  std::optional<unsigned> get16BitOffsetFromBaseReg(llvm::MCRegister Reg) const;

  unsigned getPhysRegisterSize(llvm::MCRegister Reg) const;

  static llvm::StringRef getFileDebugName(RegFileID File);

  llvm::Value &getOperandAsValue(const llvm::MachineInstr &MI,
                                 llvm::AMDGPU::OpName OpName,
                                 llvm::Type *RegType = nullptr);

  llvm::Value &getOperandAsValue(const llvm::MachineOperand &Op,
                                 llvm::Type *RegType = nullptr);

  llvm::BasicBlock &getOperandAsBasicBlock(const llvm::MachineInstr &MI,
                                           llvm::AMDGPU::OpName OpName);

  llvm::BasicBlock &getOperandAsBasicBlock(const llvm::MachineOperand &Op);

  llvm::Value &getRegisterOperand(const llvm::MachineInstr &MI,
                                  llvm::MCRegister Reg,
                                  llvm::Type *RegType = nullptr);

  llvm::Value &getRegisterOperand(const llvm::MachineBasicBlock &MBB,
                                  llvm::MCRegister Reg,
                                  llvm::Type *RegType = nullptr);

  void setRegOperandValue(const llvm::MachineInstr &MI, llvm::MCRegister Reg,
                          llvm::Value *Val);

  void setRegOperandValue(const llvm::MachineOperand &Op, llvm::Value *Val);

  void setRegOperandValue(const llvm::MachineInstr &MI,
                          llvm::AMDGPU::OpName OpName, llvm::Value *Val);

  /// Returns the fall-through BasicBlock (next block after the current MI's
  /// block). If there is no next block, returns a poison value.
  llvm::BasicBlock *getNextBB(const llvm::MachineInstr &MI);

  void fixupPhis();

  std::string getRegValueName(llvm::MCRegister Reg) const {
    return llvm::StringRef(TRI.getName(Reg)).lower() + "_val";
  }

  /// Handle overlapping entries in \p Map when \p Reg is about to be written.
  ///
  /// For each stored register that overlaps with \p Reg:
  ///  - If StoredReg is a *sub-register* of Reg (Reg fully covers it): erase.
  ///  - If StoredReg is a *super-register* of Reg (Reg partially overwrites
  ///    it): bitcast to vector, extractelement the non-overlapping sub-regs,
  ///    and preserve them as new entries.
  ///  - Otherwise (rare partial overlap): conservative erase.
  void invalidateOverlaps(MCRegValueMap &Map, llvm::MCRegister Reg,
                          llvm::IRBuilderBase &Builder);

  /// Search \p Map for a stored super-register that fully contains \p Reg.
  /// If found, bitcast to vector and extractelement the requested sub-reg.
  llvm::Value *tryExtractFromSuperReg(MCRegValueMap &Map, llvm::MCRegister Reg,
                                      llvm::Type *RegType,
                                      llvm::IRBuilderBase &Builder);

  /// Try to compose \p Reg from stored sub-register entries in \p Map.
  /// Builds a vector via insertelement for each sub-reg, then bitcasts to
  /// the target integer type.
  llvm::Value *tryComposeFromSubRegs(MCRegValueMap &Map, llvm::MCRegister Reg,
                                     llvm::IRBuilderBase &Builder,
                                     llvm::Type *RegType = nullptr);

  llvm::Value *tryComposeFromOverlappingRegs(const llvm::MachineBasicBlock &MBB,
                                             MCRegValueMap &Map,
                                             llvm::MCRegister Reg,
                                             llvm::IRBuilderBase &Builder,
                                             llvm::Type *RegType = nullptr);

  /// Materialize the value of \p Reg in \p MBB.  Searches for an exact
  /// match first, then a containing super-register, then composable
  /// sub-registers, and finally falls back to predecessor PHI / undef.
  llvm::Value &materializeReg(const llvm::MachineBasicBlock &MBB,
                              llvm::MCRegister Reg, llvm::Type *RegType);

  void initKernelEntryRegs(llvm::IRBuilderBase &Builder);

  /// Populate \c FileWidths, \c FileTypes, and the reserved LO-half SGPR
  /// MCRegisters from the function's \c amdgpu-num-sgpr / \c amdgpu-num-vgpr
  /// attributes and subtarget features. Called once from the constructor.
  void buildRegFileLayout();

  /// Classify \p Reg into one of the four modeled register files. Fires
  /// an assertion if \p Reg is not part of any modeled file — it is the
  /// instruction semantics' responsibility to only query file-backed
  /// registers.
  std::optional<RegFileID> getRegFileForReg(llvm::MCRegister Reg) const;

  /// Compute the lane range that \p Reg occupies within its file.
  std::optional<RegFileSlotInfo> getRegFileSlot(llvm::MCRegister Reg) const;

  /// Internal worker for \c getRegisterFileValue. Shared by the primary
  /// MI-taking overload and the PHI-fixup path that walks predecessors.
  llvm::Value *getRegisterFileValue(const llvm::MachineBasicBlock &MBB,
                                    RegFileID File,
                                    llvm::IRBuilderBase &Builder);

  /// Drop every \c RegCache entry in \p State whose register belongs to
  /// the given file. Used after a non-constant-index file write to make
  /// the newly written file the sole source of truth.
  void wipeFileRegsFromCache(BlockRegState &State, RegFileID File);

public:
  /// Return the LLVM value that represents the architectural register
  /// file containing \p Reg at the point in the function corresponding to
  /// \p MI. The result is an \c <N x i32> vector where lane \c k holds
  /// the 32-bit value of register \c k in that file.
  ///
  /// Result is cached per-MBB: the first call in a given block either
  /// builds the file from the cache (for entry / predecessor-less
  /// blocks — frozen poison for any lane not already cached) or emits a
  /// placeholder \c <N x i32> PHI that is wired up once all blocks have
  /// been translated.
  llvm::Value *getRegisterFileValue(const llvm::MachineInstr &MI,
                                    llvm::MCRegister Reg);

  /// Write \p Val into the file that contains \p Reg at lane \p Index.
  /// When \p Index is a \c ConstantInt the write is folded into a normal
  /// \c setRegOperandValue on the targeted sub-register; otherwise the
  /// whole-file \c insertelement is emitted and every per-register cache
  /// entry for that file is invalidated so that subsequent reads re-derive
  /// from the new file value.
  ///
  /// Writes to the TTMP file are silently discarded.
  void writeRegisterFile(const llvm::MachineInstr &MI, llvm::MCRegister Reg,
                         llvm::Value *Index, llvm::Value *Val);

  void translate();
};

} // namespace luthier

#endif