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
/// Describes \c MIRToIRTranslator used to translate discovered machine
/// functions by the \c CodeDiscoveryPass to LLVM IR.
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

/// \brief Used by the \c CodeDiscoveryPass to translate lifted Machine IR
/// instructions in a machine function to their equivalent LLVM IR in the
/// associated \c llvm::Function
/// \details The translator stores values keyed by the *exact* register that
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

  llvm::MachineFunction &MF;

  std::unique_ptr<MIInlineAsmEmitter> InlineAsmEmitter{};

  const llvm::SIRegisterInfo &TRI;

  const llvm::SIInstrInfo &TII;

  const llvm::GCNSubtarget &ST;

  /// We keep track of the same physical register's value per its available
  /// type inside each basic block; For example, if the translation requires a
  /// register value of i32 to be cast to a f32, we cache both values. This way,
  /// when a later instruction requests the f32 version, we don't emit a
  /// redundant cast instruction. Allowed types are ints, FP, and pointer types.
  /// Pointer types don't have to check for size compatibility, as they will
  /// use the \c llvm::IntToPtrInst which takes care of truncating/extending
  /// the output pointer size
  using ValueTypeMap = llvm::DenseMap<llvm::Type *, llvm::Value *>;

  using RegFileKey = std::tuple<llvm::MCRegister, unsigned, unsigned>;

  static constexpr unsigned RegGranule = 16;

  /// Cache for registers
  /// The location of each register is identified by a 16-bit-lane
  /// offset within their associated register file
  /// (SGPR/VGPR/AGPR/Hardware registers)
  using RegValueMap = llvm::DenseMap<RegFileKey, ValueTypeMap>;

  using BBStateMap =
      llvm::DenseMap<std::reference_wrapper<const llvm::MachineBasicBlock>,
                     RegValueMap>;

  /// Logical SGPR that aliases \c VCC_LO for applicable targets
  llvm::MCRegister VccLoSgpr{llvm::MCRegister::NoRegister};

  /// Logical SGPR that aliases \c XNACK_MASK_LO on targets where xnack is
  /// supported
  llvm::MCRegister XnackMaskLoSgpr{llvm::MCRegister::NoRegister};

  /// Logical SGPR that aliases \c FLAT_SCR_LO on targets that store
  /// \c FLAT_SRC before the VCC with the rest of the normal SGPRs
  llvm::MCRegister FlatScrLoSgpr{llvm::MCRegister::NoRegister};

  /// Marks the start of the TTMP0 to EXEC HI register file
  llvm::MCRegister TTMPBaseReg = {llvm::AMDGPU::TTMP0};

  /// Encoding offset (in 16-bit lanes) of the lane right after the EXEC_HI
  /// register is encoded in the register file.
  unsigned ExecHiHalfWordOffset = 0;

  /// Encoding offset (in 16-bit lanes) of where the current subtarget encodes
  /// the first status register in the SGPR file (i.e., VCCZ)
  unsigned SrcVCCZHalfWordOffset = 0;

  /// Number of allocated Half-word SGPRs by the kernel descriptor; This number
  /// also signifies where the trap handler registers start
  unsigned NumPreVCCHiHalfWordSGPRs = 0;

  /// SGPR half-word index where the status registers are encoded in the
  /// SGPR file; This usually comes after the aperture registers on GFX9+
  /// targets
  unsigned SGPRStatusRegHWordOffsetStart = 0;

  /// Total 16-bit-lane footprint of each register file.
  /// For the SGPR file this is sized to cover all the encoded SGPR range; for
  /// VGPR/AGPR it's exactly \c 2 * NumGPRs.
  llvm::SmallDenseMap<llvm::MCRegister, unsigned> RegFileSize{};

  struct ToBeFixedRegValuePhiInfo {
    const llvm::MachineBasicBlock *MBB;
    RegFileKey RegKey;
    llvm::PHINode *Phi;
  };

  /// Register value placeholder PHIs that need to be fixed up after the
  /// function has been translated
  llvm::SmallVector<ToBeFixedRegValuePhiInfo> ToBeFixedPhis{};

  /// Per-basic block register and file value mapping; This is updated every
  /// time a single register/file is read/written to
  BBStateMap VM{};

  /// Provides the index of \p Reg w.r.t the base register of the register
  /// file \p Reg resides in
  unsigned getHardwareIdxOffsetFromBaseReg(llvm::MCRegister Reg) const;

  /// Provides the offset where the \p Reg will be encoded inside the
  /// translator's register file
  unsigned getRegFileHalfWordOffset(llvm::MCRegister Reg) const;

  /// Maps the physical pseudo register to its hardware register
  llvm::MCRegister getPhysReg(llvm::MCRegister Reg) const;

  unsigned getPhysRegisterSize(llvm::MCRegister Reg) const;

  static llvm::StringRef getRegfileValueName(llvm::MCRegister Reg);

  llvm::MCRegister getRegFileBaseReg(llvm::MCRegister Reg);

  /// Retrieves and translates the named operand of type register and immediate
  /// to a value and caches it for the current basic block
  /// If \p RegType is specified, the returned value will be bitcasted to  ///
  /// match the expected type. The returned value will also be truncated or
  /// zero-extended to match the \p RegType's bit width.
  /// If a pointer type is requested, a \c llvm::IntToPtrInst will be used
  /// to convert a cached integer value to the requested pointer type
  llvm::Value &getOperandAsValue(const llvm::MachineInstr &MI,
                                 llvm::AMDGPU::OpName OpName,
                                 llvm::Type *OutType = nullptr);

  llvm::Value &getOperandAsValue(const llvm::MachineOperand &Op,
                                 llvm::Type *OutType = nullptr);

  llvm::BasicBlock &getOperandAsBasicBlock(const llvm::MachineInstr &MI,
                                           llvm::AMDGPU::OpName OpName);

  llvm::BasicBlock &getOperandAsBasicBlock(const llvm::MachineOperand &Op);

  llvm::Value &getRegisterOperand(const llvm::MachineInstr &MI,
                                  llvm::MCRegister Reg,
                                  llvm::Type *RegType = nullptr);

  /// Search the file's cache for a stored super-register that fully
  /// contains \p Slot. If found, bitcast to vector and extractelement the
  /// requested 16-bit-aligned window.
  llvm::Value *tryExtractFromSuperReg(
      RegValueMap &State,
      const std::tuple<llvm::MCRegister, unsigned, unsigned> &RegFileKey,
      llvm::StringRef OutValueName, llvm::IRBuilderBase &Builder,
      llvm::Type *OutValueType);

  /// Try to compose \p Slot from stored sub-register entries in the file's
  /// cache. Builds a vector via insertelement for each half-window, then
  /// bitcasts to the target integer type.
  llvm::Value *tryComposeFromSubRegs(
      RegValueMap &State,
      const std::tuple<llvm::MCRegister, unsigned, unsigned> &Key,
      llvm::StringRef OutValName, llvm::IRBuilderBase &Builder,
      llvm::Type *RegType = nullptr);

  llvm::Value *tryComposeFromOverlappingRegs(
      RegValueMap &State, const llvm::MachineBasicBlock &MBB,
      const std::tuple<llvm::MCRegister, unsigned, unsigned> &KeyReg,
      llvm::StringRef OutValName, llvm::IRBuilderBase &Builder,
      llvm::Type *RegType);

  /// Materialize the value of \p Reg in \p MBB.  Searches for an exact
  /// match first, then a containing super-register, then composable
  /// sub-registers, and finally falls back to predecessor PHI/ freeze(poison)
  llvm::Value &getOperandAsValue(const llvm::MachineBasicBlock &MBB,
                                 llvm::MCRegister Reg, llvm::Type *OutRegType);

  llvm::Value &
  getOperandAsValue(const llvm::MachineBasicBlock &MBB,
                    const std::tuple<llvm::MCRegister, unsigned, unsigned> &Key,
                    llvm::IRBuilderBase &Builder, llvm::StringRef ValName,
                    llvm::Type *OutRegType = nullptr);

  /// Handle overlapping entries in the file's \c RegCache when a write of
  /// \p Slot is about to happen.
  ///
  /// For each stored entry whose \c [Offset, Offset+NumHalves) range overlaps:
  ///  - Stored ⊂ Slot (fully covered): erase.
  ///  - Slot ⊂ Stored (partial overwrite of super-reg): bitcast to
  ///    \c <NumHalves x i16>, extract the non-overlapping halves, and
  ///    preserve them as new sub-register entries.
  ///  - Otherwise (rare partial overlap): conservative erase.
  void
  invalidateOverlaps(RegValueMap &State,
                     std::tuple<llvm::MCRegister, unsigned, unsigned> &Slot,
                     llvm::MCRegister Reg, llvm::IRBuilderBase &Builder);

  void setRegOperandValue(const llvm::MachineInstr &MI, llvm::MCRegister Reg,
                          llvm::Value *Val);

  void setRegOperandValue(const llvm::MachineOperand &Op, llvm::Value *Val);

  void setRegOperandValue(const llvm::MachineInstr &MI,
                          llvm::AMDGPU::OpName OpName, llvm::Value *Val);

  /// Returns the fall-through BasicBlock (next block after the current MI's
  /// block). If there is no next block, returns a poison value.
  llvm::BasicBlock *getNextBB(const llvm::MachineInstr &MI);

  void fixupPhis();

  /// Used to get the final name of the value used for the physical register
  std::string getRegValueName(llvm::MCRegister Reg) const {
    return llvm::StringRef(TRI.getName(Reg)).lower() + "_val";
  }

  void initKernelEntryRegs(llvm::IRBuilderBase &Builder);

  /// Seed the entry block's register cache from the function's
  /// arguments (the standard device-function prototype). Called instead
  /// of \c initKernelEntryRegs for non-kernel-entry functions.
  void initDeviceFunctionEntryRegs(llvm::IRBuilderBase &Builder);

  /// Populate \c FileSize16, \c FileAllocated16, \c FileTypes,
  /// \c FirstSpecialSGPROffset, and the reserved LO-half SGPR MCRegisters
  /// from the function's \c amdgpu-num-sgpr / \c amdgpu-num-vgpr attributes
  /// and subtarget features. Called once from the constructor.
  llvm::Error buildRegFileLayout();

  /// Classify \p Reg into one of the modeled register files. Returns
  /// \c std::nullopt if \p Reg is not file-backed (e.g. SCC, MODE, VCCZ,
  /// EXECZ — those go through \c BlockRegState::OtherCache instead).
  std::optional<llvm::MCRegister>
  getBaseRegForRegFile(llvm::MCRegister Reg) const {
    return std::get<0>(getRegFileSlot(Reg));
  }

  /// Resolve \p Reg to a \c RegFileSlotInfo (file + 16-bit-lane offset +
  /// number of 16-bit halves). Returns \c std::nullopt for non-file-backed
  /// registers. Performs GFX9- alias translation for VCC/XNACK_MASK/
  /// FLAT_SCR before encoding lookup.
  std::tuple<llvm::MCRegister, unsigned, unsigned>
  getRegFileSlot(llvm::MCRegister Reg) const;

  /// True if \p Offset (in 16-bit-lane units) within \p File is a "special"
  /// slot — TTMP/M0/NULL/EXEC on every target plus VCC on GFX10+. These
  /// slots are always in-bounds for cache queries, regardless of the
  /// kernel's allocation count.
  bool isTTMPAndBeyondSGPRRegion(llvm::MCRegister BaseReg,
                                 uint32_t Offset) const;

  /// Build the canonical \c <NumLanes32 x i32> value for \p File at the
  /// point in the function corresponding to \p MBB. Each lane holds the
  /// i32 value of the corresponding hardware-encoded register slot;
  /// allocated SGPRs occupy lanes \c [0, NumSGPRs) and SGPR specials
  /// occupy lanes \c [FirstSpecialEnc, 128). Lanes between (the
  /// unallocated normal-SGPR gap) are frozen poison. VGPR/AGPR are
  /// dense \c [0, NumVGPRs) / \c [0, NumAGPRs).
  ///
  /// Cached per-block as a mega-entry in \c RegCache.
  llvm::Value *getRegisterFileFullCanonical(const llvm::MachineBasicBlock &MBB,
                                            llvm::MCRegister RegInFile,
                                            llvm::IRBuilderBase &Builder);

  /// Maps each 32-bit lane in the canonical SGPR file vector to the
  /// MCRegister whose HW encoding is that lane (or empty if the lane
  /// falls in the unallocated normal-SGPR gap).
  llvm::SmallVector<llvm::MCRegister> buildSGPRFileLayout() const;

  /// Public wrapper: returns the file as
  /// \c <(TotalCanonicalBits / LaneTy.bits) x LaneTy>.
  llvm::Value *getRegisterFileFull(const llvm::MachineInstr &MI,
                                   llvm::MCRegister RegFileBase,
                                   llvm::Type *LaneTy);

  /// Replace the file's canonical mega-entry with \p NewVec (which must
  /// have the same total bit width as the file). All per-register cache
  /// entries belonging to this file are invalidated by the existing
  /// overlap logic so subsequent reads extract from the new mega value.
  void setRegisterFileFull(const llvm::MachineInstr &MI, llvm::MCRegister Reg,
                           llvm::Value *NewVec);

  /// Build the function type used by all discovered device functions and
  /// indirect call targets in this module. The signature is:
  ///
  ///   { <128 x i32>, <NumVGPRs x i32>, [<NumAGPRs x i32>,] i1, iWave, i1 }
  ///   (<128 x i32>, <NumVGPRs x i32>, [<NumAGPRs x i32>,] i1, iWave, i1)
  ///
  /// where the i1 fields are SCC and VCCZ, the iWave field is VCC
  /// (wave-size-wide), and the AGPR vector is only present on targets
  /// with MAI support. The CodeDiscoveryPass uses this to give every
  /// discovered device function the same shape so indirect targets can
  /// be resolved via constant folding.
  static llvm::FunctionType *
  getStandardDeviceFunctionType(llvm::LLVMContext &Ctx,
                                const llvm::GCNSubtarget &ST, unsigned NumVGPRs,
                                unsigned NumAGPRs);

  /// Convenience overload: uses the current MF's subtarget and the
  /// allocation counts derived from \c amdgpu-num-vgpr (or the
  /// addressable max as a fallback).
  llvm::FunctionType *getStandardDeviceFunctionType() const;

  /// Like \c emitIndirectCall but the call is a tail call followed by
  /// \c ret of the call's return value. Used for \c S_SETPC_B64.
  void emitIndirectTailCall(const llvm::MachineInstr &MI, llvm::Value *Target);

  /// Write \p Val into the file that contains \p Reg at 32-bit lane index
  /// \p Index (the \c S_/V_MOVREL-style hardware index). When \p Index is
  /// a \c ConstantInt the write is folded into a normal
  /// \c setRegOperandValue on the targeted sub-register; otherwise the
  /// dynamic-index path materializes the whole file, performs an
  /// \c insertelement, and writes back via \c setRegisterFileFull.
  void writeRegisterFile(const llvm::MachineInstr &MI, llvm::MCRegister Reg,
                         llvm::Value *Index, llvm::Value *Val);

public:
  MIRToIRTranslator(llvm::MachineFunction &MF, llvm::Error &Err);

  void translate();
};

} // namespace luthier

#endif