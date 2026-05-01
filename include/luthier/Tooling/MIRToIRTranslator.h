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
/// Describes the \c MIRToIRTranslator class which is used to translate
/// discovered machine function traces by the \c CodeDiscoveryPass to LLVM IR.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_MIR_TO_IR_TRANSLATOR_H
#define LUTHIER_TOOLING_MIR_TO_IR_TRANSLATOR_H
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

/// Individual machine instruction to LLVM IR translation functions emitted
/// by the tablegen backend. Each of these function is specialized on
/// \p MI's opcode. \c MIRToIRTranslator::raiseMachineInstr is in charge
/// of dispatching the correct specialization
template <uint16_t Opcode>
void raiseMachineInstr(const llvm::MachineInstr &MI,
                       llvm::IRBuilderBase &Builder,
                       MIRToIRTranslator &Translator);

/// \brief Used by the \c CodeDiscoveryPass to translate Machine instructions
/// in a machine function trace to LLVM IR and inserts the translated IR into
/// the associated LLVM Function handle. The translated IR can then be used
/// to query semantics-related information about the instructions inside
/// the target module
/// \details The translator performs a per-basic block translation of the
/// machine function. Each basic block maintains a mapping between registers
/// and a list of available LLVM values hashed based on their type. The map
/// gets updated after translating each instruction in the basic block
/// from the basic block's beginning. The entry basic block's initial values
/// are initialized based on the calling convention of the function; Kernels'
/// initial values are populated according to the AMD GPU kernel initial
/// state described by the AMDGPU backend documentation; Device (non-entry)
/// function's entry basic blocks obtain their initial values from their
/// arguments. Other basic blocks emit unresolved PHI nodes for any registers
/// that have been used for the first time by an instruction. After all
/// basic blocks have been translated, the PHI nodes will be then be resolved
/// by connecting them to their incoming values in their predecessor blocks if
/// they already exist, or making additional PHIs to request them from///
/// predecessors further away. If making additional PHI nodes results in
/// requesting an uninitialized value from the entry basic block, a
/// \c freeze(poision) value is emitted to serve as a place holder.
/// This process is performed until all unresolved PHI nodes have been
/// resolved. \n
/// Instead of directly using MC register enums to map registers to their
/// associated set of values, This class instead uses the following three
/// things to distinguish each register entry: 1. The base physical MC register
/// of a "register file", 2. The base hardware register index offset in units of
/// half-words (16-bits), and 3. The size of the register in half-words
/// (16-bits). This was chosen instead of utilizing the register's MC reg enum
/// as a key, to allow for assigning values to arbitrarily-sized regions inside
/// the register file arbitrarily-sized registers inside the value map,
/// (which includes the entire register file itself). The hardware
/// register index (opcode encoding) of each register can be queried from
/// both LLVM's AMDGPU register records (see \c llvm::AMDGPU::getMCReg and
/// \c llvm::SIRegisterInfo::getEncodingValue) and the AMD GPU public ISA docs
/// (see section named "Scalar ALU Operands").
/// Possible register files include:
/// - <b>User SGPR register file</b>, with \c SGPR0 as its base index.
/// This file covers the entire number of SGPRs the kernel descriptor requests
/// in its \c RSRC1 field via the `amdgpu-num-sgpr` function attribute.
/// Special registers \c VCC, and on GFX9 and earlier targets,
/// \c FLAT_SCR and \c XNACK_MASK are placed at the end of this file, mimicing
/// documented hardware behavior. This implies that these special registers
/// can be addressed with both their special name (e.g. \c VCC) and their
/// logical name (e.g. \c SGPR16), also mimicing how the hardware works.
/// The translator's hash function detects if a logical SGPR encoding was used
/// in a machine instruction to refer to where these special registers and
/// aliases them to the same entry. The aliasing behavior has been removed in
/// GFX10+, but \c VCC still remains in the same \c SGPR file.
/// The maximum size of this region at the time of writing is 108 DWORDs,
/// ending right after \c VCC_HI
/// - <b>The Trap handler SGPR register file</b>, which starts from the
/// first encoded trap handler register located right after \c VCC_HI
/// (index 108) in all targets. On older targets, the base register of this
/// file is \c TBA_LO and on newer targets, \c TTMP0. This region includes all
/// trap handler registers. This region usually ends right before index 124.
/// - <b>\c EXEC mask, \c MO, and \c SGPR_NULL (if available on the target)
/// register file</b>, starts from the last trap handler index (124) to
/// the end of the \c EXEC_HI's encoding, which is 128 (exclusive).
/// - <b>Aperature register file</b>, which includes \c SRC_SHARED_BASE,
/// \c SRC_SHARED_LIMIT, \c SRC_PRIVATE_BASE, \c SRC_PRIVATE_LIMIT, and \c
/// (on GFX9 and GFX10) \c SRC_POPS_EXITING_WAVE_ID. On GFX8 and earlier
/// targets, these registers are not available, hence this register file
/// is empty on those targets. The hardware encoding range of this file is from
/// 235 to 239, inclusive.
/// - <b>Status register SGPR file</b>, which includes \c SRC_VCCZ, \c
/// SRC_EXECZ, and \c SRC_SCC, ranging from hardware index of 251 to 253 on
/// all targets, inclusive. These are modelled as 32-bit SGPR registers in the
/// AMDGPU backend, and the translator honors that in its register files.
/// All reads/writes for the pseudo register \c SCC will be resolved into
/// \c SRC_SCC.
/// - <b>Hardware register file</b>, with the \c MODE register as its base,
/// is meant to model the value of the hardware registers that can be
/// read/written to via the \c S_GETREG_B32 and \c S_SETREG_B32 instructions.
/// As of right now, only the \c MODE register is supported, as it is the
/// only register with an MC enum in the AMD GPU backen. Additional hardware
/// register will be added in the future as conversion of \c S_GETREG_B32
/// and \c S_SETREG_B32 instructions to simple read/writes to hardware
/// register values is implemented.
/// - <b>VGPR register file</b>, with \c VGPR0 as its base register. The number
/// of VGPRs is determined by the `amdgpu-num-vgpr` function attribute. If
/// it is determined that the function is using the dynamic VGPR feature
/// introduced in GFX12+ (how to detect this is TBD), maximum number of
/// addressable VGPRs for the sub target is assumed.
/// - <b>AGPR register file</b>, with \c AGPR0 as its base register. On targets
/// that support it, its size should be the same as the number of VGPRs
/// requested by the kernel. \n
/// The register files' formats are deduced primarily by looking at certain
/// function attributes populated by the \c CodeDiscoveryPass as well as the
/// features of the function's sub target. \n
/// Following Luthier's machine function trace semantics, transfer of control
/// from one trace function to another results in a call instruction that pass
/// the entire register file of the caller to the callee as argument. The
/// prototype of the callee can be queried via
/// \c MIRToIRTranslator::getStandardDeviceFunctionType function.
/// When passing device (i.e. non-entry) function to the translator the
/// \p CodeDiscoveryPass must ensure the function's prototype matches the
/// type returned by \c getStandardDeviceFunctionType, since the function's
/// prototype cannot be changed later by the translator. Kernel and other
/// entry functions don't have to follow this rule, as their initial/// register
/// values are initialized in the body of the function according to the initial
/// kernel state documented by the AMDGPU LLVM backend; For example, \c
/// llvm.amdgcn.kernarg.segment.ptr() is used to initialize the SGPR pair's
/// value holding the kernel argument buffer's address. \n The translator also
/// takes care of materializing register values as the instruction semantics
/// translator functions (i.e. \c raiseMachineInstr) requests them. The
/// translator materializes sub-registers of register values via bitcasting the
/// available register values into vector types and using the \c
/// `extractelement` IR instruction to retrieve the requested sub-register. The
/// same process is also done for when a super register of a requested register
/// already has a value materialized in the value map. Registers that overlap
/// but are not strictly super or sub-registers (rare) will be broken down to
/// reg units and then processed via the super reg logic.
/// \n
/// On a write to a register, all overlapping entries (sub- and super-regs)
/// are invalidated so that subsequent reads through a different alias will
/// lazily recompute the value from the register's entry. If a register being
/// written only partially overlaps with a tracked value, only the
/// overlapped part is invalidated. \n
/// As of right now, Luthier does not model read/write privilege of registers.
/// Luthier also does not currently model VGPR indexing operand access
/// used in GFX9.
/// \note The initial basic block in the machine function must not have any
/// predecessors. The \c CodeDiscoveryPass is in charge of detecting this
/// issue and fixing it up in the discovered trace before passing the
/// machine function for translation.
class MIRToIRTranslator {
  template <uint16_t Opcode>
  friend void luthier::raiseMachineInstr(const llvm::MachineInstr &MI,
                                         llvm::IRBuilderBase &Builder,
                                         MIRToIRTranslator &Translator);

  /// Primary interface for raising machine instructions to LLVM IR in the
  /// translator loop. If a semantic for the \p MI's opcode exists, the
  /// appropriate specialization of raiseMachineInstr is dispatched; If not,
  /// an inline assembly version of the instruction the appropriate number of
  /// input and output operands are emitted
  void raiseMachineInstr(const llvm::MachineInstr &MI,
                         llvm::IRBuilderBase &Builder);

  llvm::MachineFunction &MF;

  /// IR Inline assembly instruction emitter used to emit place holder
  /// inline assembly IR instructions for machine instructions with no
  /// semantics
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

  /// Register file key used to hash register values:
  /// - First element: the base register of the register file
  /// - Second element: the hardware index offset of the register
  /// from the base (in half-word units)
  /// - Third element: the size of the register (in half-word units)
  using RegFileKey = std::tuple<llvm::MCRegister, unsigned, unsigned>;

  /// Register size granularity; Remains 16 until something changes in AMD
  /// GPUs
  static constexpr unsigned RegGranule = 16;

  /// Cache for registers in a basic block
  using RegValueMap = llvm::DenseMap<RegFileKey, ValueTypeMap>;

  using BBStateMap =
      llvm::DenseMap<std::reference_wrapper<const llvm::MachineBasicBlock>,
                     RegValueMap>;

  /// Total 16-bit-lane footprint of each register file.
  llvm::SmallDenseMap<llvm::MCRegister, unsigned> RegFileSize{};

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

  /// SGPR half-word index where the status registers are encoded in the
  /// SGPR file; This usually comes after the aperture registers on GFX9+
  /// targets
  unsigned SGPRStatusRegHWordOffsetStart = 0;

  struct ToBeFixedRegValuePhiInfo {
    const llvm::MachineBasicBlock *MBB;
    RegFileKey RegKey;
    llvm::PHINode *Phi;
  };

  /// Register value placeholder PHIs that need to be fixed up after the
  /// function has been translated
  llvm::SmallVector<ToBeFixedRegValuePhiInfo> ToBeFixedPhis{};

  /// Per-basic block register file value mapping; This is updated every
  /// time a single register/file is read/written to
  BBStateMap VM{};

  /// Provides the DWORD index of \p Reg w.r.t the base of the register
  /// file \p Reg resides in
  unsigned getHardwareIdxOffsetFromBaseReg(llvm::MCRegister Reg) const;

  /// Maps the physical pseudo register to its hardware register
  /// \note Use this instead of \c llvm::AMDGPU::getMCReg directly
  llvm::MCRegister getPhysReg(llvm::MCRegister Reg) const;

  /// Provides the register's physical size
  /// \note Use this instead of \c llvm::TargetRegisterInfo::getRegSizeInBits
  unsigned getPhysRegisterSize(llvm::MCRegister Reg) const;

  /// Given the base register of the register file, returns the value name
  /// for that register file; Primarily used for creating value entries
  /// covering the entirety of the register file
  static llvm::StringRef getRegfileValueName(llvm::MCRegister BaseReg);

  /// Given a \p Reg prvoides the base register of the register file it
  /// belongs to
  llvm::MCRegister getRegFileBaseReg(llvm::MCRegister Reg);

  /// Retrieves and translates the named operand \p OpName to a value
  /// and caches it for the \p MI's basic block
  /// If \p OutType is given, truncates or zero-extends the returned
  /// register to match its size and type; Otherwise, an int with the size of
  /// the register or a 64-bit immediate is returned.
  /// \note \p OutType's scalar type must be either integer, floating point,
  /// or pointer
  /// \note The named operand represented by \p OpName must be either a
  /// register or an integer
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
      llvm::IRBuilderBase &Builder, llvm::Type *OutValueType);

  /// Try to compose \p Slot from stored sub-register entries in the file's
  /// cache. Builds a vector via insertelement for each half-window, then
  /// bitcasts to the target integer type.
  llvm::Value *tryComposeFromSubRegs(RegValueMap &State, const RegFileKey &Key,
                                     llvm::IRBuilderBase &Builder,
                                     llvm::Type *RegType = nullptr);

  llvm::Value *tryComposeFromOverlappingRegs(
      RegValueMap &State, const llvm::MachineBasicBlock &MBB,
      const std::tuple<llvm::MCRegister, unsigned, unsigned> &KeyReg,
      llvm::IRBuilderBase &Builder, llvm::Type *RegType);

  /// Materialize the value of \p Reg in \p MBB.  Searches for an exact
  /// match first, then a containing super-register, then composable
  /// sub-registers, and finally falls back to predecessor PHI/ freeze(poison)
  llvm::Value &getOperandAsValue(const llvm::MachineBasicBlock &MBB,
                                 llvm::MCRegister Reg, llvm::Type *OutRegType);

  llvm::Value &
  getOperandAsValue(const llvm::MachineBasicBlock &MBB,
                    const std::tuple<llvm::MCRegister, unsigned, unsigned> &Key,
                    llvm::IRBuilderBase &Builder,
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
  void invalidateOverlaps(RegValueMap &State, const RegFileKey &Slot,
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

  /// Initializes the register layout of the current function based on its
  /// subtarget, and the number of SGPR and VGPRs it contains
  ///
  llvm::Error initRegFileLayouts();

  /// Classify \p Reg into one of the modeled register files. Returns
  /// \c std::nullopt if \p Reg is not file-backed (e.g. SCC, MODE, VCCZ,
  /// EXECZ — those go through \c BlockRegState::OtherCache instead).
  std::optional<llvm::MCRegister>
  getBaseRegForRegFile(llvm::MCRegister Reg) const {
    return std::get<0>(getRegFileSlot(Reg));
  }

  /// Resolve \p Reg to a \c RegFileKey (register base index + 16-bit-lane
  /// offset + number of 16-bit halves). Returns \c std::nullopt for
  /// non-file-backed registers. Performs GFX9- alias translation for
  /// VCC/XNACK_MASK/ FLAT_SCR before encoding lookup.
  RegFileKey getRegFileSlot(llvm::MCRegister Reg) const;

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