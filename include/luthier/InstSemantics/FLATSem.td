//===- FLATSem.td ------------------------------------------------------*- tblgen -*-===//
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

//------------------------------------------------------------------------------
// Convenience Functions
//------------------------------------------------------------------------------

class CalculateFlatAddr<dag vaddr, dag offset> {
  dag ret = (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $vaddr), flat_ptr_ty),
                         (GetNamedOperand $offset));
}

class CalculateGlobalAddr<dag vaddr, dag offset> {
  dag ret = (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $vaddr), global_ptr_ty),
                         (GetNamedOperand $offset));
}

class CalculateGlobalSAddr<dag saddr, dag vaddr, dag offset> {
  dag ret = (LLVMPtrAdd (LLVMIntToPtr (LLVMAdd (GetNamedOperand $saddr),
                                                 (LLVMZExt (GetNamedOperand $vaddr), si_llvm_i64_ty)),
                          global_ptr_ty),
                         (GetNamedOperand $offset));
}

class CalculateScratchAddr<dag vaddr, dag offset> {
  dag ret = (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $vaddr), scratch_ptr_ty),
                         (GetNamedOperand $offset));
}

//==============================================================================
// FLAT Instructions - Loads
// Sources:
//   gcn3-instruction-set-architecture.pdf, pages 283-284.
//   vega-shader-instruction-set-architecture.pdf, pages 218-222.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 220-224.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 207-209.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 200-203.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 205-210.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 210-215.
//   rdna-shader-instruction-set-architecture.pdf, pages 185-190.
//   rdna2-shader-instruction-set-architecture.pdf, pages 185-190.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 280-285.
//   rdna4-instruction-set-architecture.pdf, pages 290-295.
//==============================================================================

def FLAT_LOAD_UBYTE_sem : InstSISemantic<FLAT_LOAD_UBYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def FLAT_LOAD_SBYTE_sem : InstSISemantic<FLAT_LOAD_SBYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def FLAT_LOAD_USHORT_sem : InstSISemantic<FLAT_LOAD_USHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def FLAT_LOAD_SSHORT_sem : InstSISemantic<FLAT_LOAD_SSHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def FLAT_LOAD_DWORD_sem : InstSISemantic<FLAT_LOAD_DWORD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def FLAT_LOAD_DWORDX2_sem : InstSISemantic<FLAT_LOAD_DWORDX2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_LOAD_DWORDX3_sem : InstSISemantic<FLAT_LOAD_DWORDX3> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v3i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_LOAD_DWORDX4_sem : InstSISemantic<FLAT_LOAD_DWORDX4> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

//==============================================================================
// FLAT Instructions - D16 Loads
// Sources:
//   vega-shader-instruction-set-architecture.pdf, pages 218-222.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 220-224.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 207-209.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 200-203.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 205-210.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 210-215.
//   rdna-shader-instruction-set-architecture.pdf, pages 185-190.
//   rdna2-shader-instruction-set-architecture.pdf, pages 185-190.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 280-285.
//   rdna4-instruction-set-architecture.pdf, pages 290-295.
//==============================================================================

def FLAT_LOAD_UBYTE_D16_sem : InstSISemantic<FLAT_LOAD_UBYTE_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (LLVMZExt (GetVal $tmp), si_llvm_i16_ty))
  ];
}

def FLAT_LOAD_UBYTE_D16_HI_sem : InstSISemantic<FLAT_LOAD_UBYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMZExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

def FLAT_LOAD_SBYTE_D16_sem : InstSISemantic<FLAT_LOAD_SBYTE_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdata, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty))
  ];
}

def FLAT_LOAD_SBYTE_D16_HI_sem : InstSISemantic<FLAT_LOAD_SBYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

def FLAT_LOAD_SHORT_D16_sem : InstSISemantic<FLAT_LOAD_SHORT_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)))
  ];
}

def FLAT_LOAD_SHORT_D16_HI_sem : InstSISemantic<FLAT_LOAD_SHORT_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

//==============================================================================
// FLAT Instructions - Stores
// Sources:
//   gcn3-instruction-set-architecture.pdf, pages 283-284.
//   vega-shader-instruction-set-architecture.pdf, pages 218-222.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 220-224.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 207-209.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 200-203.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 205-210.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 210-215.
//   rdna-shader-instruction-set-architecture.pdf, pages 185-190.
//   rdna2-shader-instruction-set-architecture.pdf, pages 185-190.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 280-285.
//   rdna4-instruction-set-architecture.pdf, pages 290-295.
//==============================================================================

def FLAT_STORE_BYTE_sem : InstSISemantic<FLAT_STORE_BYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i8_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_BYTE_D16_HI_sem : InstSISemantic<FLAT_STORE_BYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i8_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_SHORT_sem : InstSISemantic<FLAT_STORE_SHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i16_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_SHORT_D16_HI_sem : InstSISemantic<FLAT_STORE_SHORT_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_DWORD_sem : InstSISemantic<FLAT_STORE_DWORD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_DWORDX2_sem : InstSISemantic<FLAT_STORE_DWORDX2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_DWORDX3_sem : InstSISemantic<FLAT_STORE_DWORDX3> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def FLAT_STORE_DWORDX4_sem : InstSISemantic<FLAT_STORE_DWORDX4> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

//==============================================================================
// FLAT Instructions - 32-bit Atomic Operations (using AtomicRMW)
// Sources:
//   gcn3-instruction-set-architecture.pdf, pages 283-284, 347-348.
//   vega-shader-instruction-set-architecture.pdf, pages 218-222, 292-293.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 220-224, 294-295.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 207-209, 280-281.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 200-203, 271-272.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 205-210.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 210-215.
//   rdna-shader-instruction-set-architecture.pdf, pages 185-192.
//   rdna2-shader-instruction-set-architecture.pdf, pages 185-192.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 280-290.
//   rdna4-instruction-set-architecture.pdf, pages 290-300.
//==============================================================================

def FLAT_ATOMIC_SWAP_sem : InstSISemantic<FLAT_ATOMIC_SWAP> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_CMPSWAP_sem : InstSISemantic<FLAT_ATOMIC_CMPSWAP> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_sem : InstSISemantic<FLAT_ATOMIC_ADD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SUB_sem : InstSISemantic<FLAT_ATOMIC_SUB> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMIN_sem : InstSISemantic<FLAT_ATOMIC_SMIN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMIN_sem : InstSISemantic<FLAT_ATOMIC_UMIN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMAX_sem : InstSISemantic<FLAT_ATOMIC_SMAX> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMAX_sem : InstSISemantic<FLAT_ATOMIC_UMAX> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_AND_sem : InstSISemantic<FLAT_ATOMIC_AND> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_OR_sem : InstSISemantic<FLAT_ATOMIC_OR> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_XOR_sem : InstSISemantic<FLAT_ATOMIC_XOR> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_INC_sem : InstSISemantic<FLAT_ATOMIC_INC> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_DEC_sem : InstSISemantic<FLAT_ATOMIC_DEC> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_COND_SUB_U32_sem : InstSISemantic<FLAT_ATOMIC_COND_SUB_U32> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_CSUB_U32_sem : InstSISemantic<FLAT_ATOMIC_CSUB_U32> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGT, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (ConstantInt si_llvm_i32_ty, 0))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_F32_sem : InstSISemantic<FLAT_ATOMIC_ADD_F32> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_F64_sem : InstSISemantic<FLAT_ATOMIC_ADD_F64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_MIN_F64_sem : InstSISemantic<FLAT_ATOMIC_MIN_F64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_MAX_F64_sem : InstSISemantic<FLAT_ATOMIC_MAX_F64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FMIN_sem : InstSISemantic<FLAT_ATOMIC_FMIN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FMAX_sem : InstSISemantic<FLAT_ATOMIC_FMAX> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FCMPSWAP_sem : InstSISemantic<FLAT_ATOMIC_FCMPSWAP> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_PK_ADD_F16_sem : InstSISemantic<FLAT_ATOMIC_PK_ADD_F16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_half_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_half_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_half_ty),
                               (LLVMBitCast (GetVal $src_hi), si_llvm_half_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                         (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_PK_ADD_BF16_sem : InstSISemantic<FLAT_ATOMIC_PK_ADD_BF16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_i16_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_i16_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_i16_ty),
                               (LLVMBitCast (GetVal $src_hi), si_llvm_i16_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                         (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

//==============================================================================
// FLAT Instructions - 64-bit Atomic Operations (X2, using AtomicRMW)
// Sources:
//   gcn3-instruction-set-architecture.pdf, pages 283-284, 347-348.
//   vega-shader-instruction-set-architecture.pdf, pages 218-222, 292-293.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 220-224, 294-295.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 207-209, 280-281.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 200-203, 271-272.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 205-210.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 210-215.
//   rdna-shader-instruction-set-architecture.pdf, pages 185-192.
//   rdna2-shader-instruction-set-architecture.pdf, pages 185-192.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 280-290.
//   rdna4-instruction-set-architecture.pdf, pages 290-300.
//==============================================================================

def FLAT_ATOMIC_SWAP_X2_sem : InstSISemantic<FLAT_ATOMIC_SWAP_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_CMPSWAP_X2_sem : InstSISemantic<FLAT_ATOMIC_CMPSWAP_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_X2_sem : InstSISemantic<FLAT_ATOMIC_ADD_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SUB_X2_sem : InstSISemantic<FLAT_ATOMIC_SUB_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMIN_X2_sem : InstSISemantic<FLAT_ATOMIC_SMIN_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMIN_X2_sem : InstSISemantic<FLAT_ATOMIC_UMIN_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMAX_X2_sem : InstSISemantic<FLAT_ATOMIC_SMAX_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMAX_X2_sem : InstSISemantic<FLAT_ATOMIC_UMAX_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_AND_X2_sem : InstSISemantic<FLAT_ATOMIC_AND_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_OR_X2_sem : InstSISemantic<FLAT_ATOMIC_OR_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_XOR_X2_sem : InstSISemantic<FLAT_ATOMIC_XOR_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_INC_X2_sem : InstSISemantic<FLAT_ATOMIC_INC_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_DEC_X2_sem : InstSISemantic<FLAT_ATOMIC_DEC_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_FCMPSWAP_X2_sem : InstSISemantic<FLAT_ATOMIC_FCMPSWAP_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

//==============================================================================
// FLAT Instructions - RTN (Return) variants
// Same semantics as non-RTN counterparts (the semantic already stores
// the old value in $vdata before the atomic operation).
// Sources:
//   gcn3-instruction-set-architecture.pdf, pages 283-284, 347-348.
//   vega-shader-instruction-set-architecture.pdf, pages 218-222, 292-293.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 220-224, 294-295.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 207-209, 280-281.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 200-203, 271-272.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 205-210.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 210-215.
//   rdna-shader-instruction-set-architecture.pdf, pages 185-192.
//   rdna2-shader-instruction-set-architecture.pdf, pages 185-192.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 280-290.
//   rdna4-instruction-set-architecture.pdf, pages 290-300.
//==============================================================================

def FLAT_ATOMIC_SWAP_RTN_sem : InstSISemantic<FLAT_ATOMIC_SWAP_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SWAP_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_SWAP_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_CMPSWAP_RTN_sem : InstSISemantic<FLAT_ATOMIC_CMPSWAP_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_CMPSWAP_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_CMPSWAP_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_RTN_sem : InstSISemantic<FLAT_ATOMIC_ADD_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_ADD_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_ADD_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SUB_RTN_sem : InstSISemantic<FLAT_ATOMIC_SUB_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SUB_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_SUB_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMIN_RTN_sem : InstSISemantic<FLAT_ATOMIC_SMIN_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMIN_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_SMIN_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMIN_RTN_sem : InstSISemantic<FLAT_ATOMIC_UMIN_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMIN_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_UMIN_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMAX_RTN_sem : InstSISemantic<FLAT_ATOMIC_SMAX_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_SMAX_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_SMAX_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMAX_RTN_sem : InstSISemantic<FLAT_ATOMIC_UMAX_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_UMAX_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_UMAX_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_AND_RTN_sem : InstSISemantic<FLAT_ATOMIC_AND_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_AND_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_AND_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_OR_RTN_sem : InstSISemantic<FLAT_ATOMIC_OR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_OR_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_OR_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_XOR_RTN_sem : InstSISemantic<FLAT_ATOMIC_XOR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_XOR_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_XOR_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_INC_RTN_sem : InstSISemantic<FLAT_ATOMIC_INC_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_INC_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_INC_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_DEC_RTN_sem : InstSISemantic<FLAT_ATOMIC_DEC_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_DEC_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_DEC_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def FLAT_ATOMIC_COND_SUB_U32_RTN_sem : InstSISemantic<FLAT_ATOMIC_COND_SUB_U32_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_CSUB_U32_RTN_sem : InstSISemantic<FLAT_ATOMIC_CSUB_U32_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGT, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (ConstantInt si_llvm_i32_ty, 0))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_F32_RTN_sem : InstSISemantic<FLAT_ATOMIC_ADD_F32_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_ADD_F64_RTN_sem : InstSISemantic<FLAT_ATOMIC_ADD_F64_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_MIN_F64_RTN_sem : InstSISemantic<FLAT_ATOMIC_MIN_F64_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_MAX_F64_RTN_sem : InstSISemantic<FLAT_ATOMIC_MAX_F64_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FMIN_RTN_sem : InstSISemantic<FLAT_ATOMIC_FMIN_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FMAX_RTN_sem : InstSISemantic<FLAT_ATOMIC_FMAX_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FCMPSWAP_RTN_sem : InstSISemantic<FLAT_ATOMIC_FCMPSWAP_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_FCMPSWAP_X2_RTN_sem : InstSISemantic<FLAT_ATOMIC_FCMPSWAP_X2_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_PK_ADD_F16_RTN_sem : InstSISemantic<FLAT_ATOMIC_PK_ADD_F16_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_half_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_half_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_half_ty),
                               (LLVMBitCast (GetVal $src_hi), si_llvm_half_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                         (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def FLAT_ATOMIC_PK_ADD_BF16_RTN_sem : InstSISemantic<FLAT_ATOMIC_PK_ADD_BF16_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_i16_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_i16_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_i16_ty),
                               (LLVMBitCast (GetVal $src_hi), si_llvm_i16_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                         (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

//==============================================================================
// GLOBAL Instructions - Loads
// Sources:
//   vega-shader-instruction-set-architecture.pdf, pages 224-227.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 226-229.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 211-214.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 205-208.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 210-215.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 215-220.
//   rdna-shader-instruction-set-architecture.pdf, pages 190-195.
//   rdna2-shader-instruction-set-architecture.pdf, pages 190-195.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 285-290.
//   rdna4-instruction-set-architecture.pdf, pages 295-300.
//==============================================================================

def GLOBAL_LOAD_UBYTE_sem : InstSISemantic<GLOBAL_LOAD_UBYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def GLOBAL_LOAD_SBYTE_sem : InstSISemantic<GLOBAL_LOAD_SBYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def GLOBAL_LOAD_USHORT_sem : InstSISemantic<GLOBAL_LOAD_USHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def GLOBAL_LOAD_SSHORT_sem : InstSISemantic<GLOBAL_LOAD_SSHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def GLOBAL_LOAD_DWORD_sem : InstSISemantic<GLOBAL_LOAD_DWORD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def GLOBAL_LOAD_DWORDX2_sem : InstSISemantic<GLOBAL_LOAD_DWORDX2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (GetVal $tmp))
  ];
}

def GLOBAL_LOAD_DWORDX3_sem : InstSISemantic<GLOBAL_LOAD_DWORDX3> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v3i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (GetVal $tmp))
  ];
}

def GLOBAL_LOAD_DWORDX4_sem : InstSISemantic<GLOBAL_LOAD_DWORDX4> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (GetVal $tmp))
  ];
}

//==============================================================================
// GLOBAL Instructions - D16 Loads
// Sources: Same as GLOBAL Loads above.

//==============================================================================

def GLOBAL_LOAD_UBYTE_D16_sem : InstSISemantic<GLOBAL_LOAD_UBYTE_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMZExt (GetVal $tmp), si_llvm_i16_ty))
  ];
}

def GLOBAL_LOAD_UBYTE_D16_HI_sem : InstSISemantic<GLOBAL_LOAD_UBYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMZExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdst), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdst, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

def GLOBAL_LOAD_SBYTE_D16_sem : InstSISemantic<GLOBAL_LOAD_SBYTE_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty))
  ];
}

def GLOBAL_LOAD_SBYTE_D16_HI_sem : InstSISemantic<GLOBAL_LOAD_SBYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdst), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdst, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

def GLOBAL_LOAD_SHORT_D16_sem : InstSISemantic<GLOBAL_LOAD_SHORT_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdst, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)))
  ];
}

def GLOBAL_LOAD_SHORT_D16_HI_sem : InstSISemantic<GLOBAL_LOAD_SHORT_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdst), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdst, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

//==============================================================================
// GLOBAL Instructions - Stores
// Sources: Same as GLOBAL Loads above.

//==============================================================================

def GLOBAL_STORE_BYTE_sem : InstSISemantic<GLOBAL_STORE_BYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i8_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_BYTE_D16_HI_sem : InstSISemantic<GLOBAL_STORE_BYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i8_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_SHORT_sem : InstSISemantic<GLOBAL_STORE_SHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i16_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_SHORT_D16_HI_sem : InstSISemantic<GLOBAL_STORE_SHORT_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_DWORD_sem : InstSISemantic<GLOBAL_STORE_DWORD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_DWORDX2_sem : InstSISemantic<GLOBAL_STORE_DWORDX2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_DWORDX3_sem : InstSISemantic<GLOBAL_STORE_DWORDX3> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def GLOBAL_STORE_DWORDX4_sem : InstSISemantic<GLOBAL_STORE_DWORDX4> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

//==============================================================================
// GLOBAL Instructions - _SADDR Load/Store variants (GFX9+)
// Same semantics as base GLOBAL loads/stores but with SADDR addressing mode.
// Uses scalar SGPR base address + VGPR offset instead of just VGPR.
// Sources: Same as GLOBAL Loads/Stores above.

//==============================================================================

// GLOBAL Load SADDR variants - empty semantics (same load behavior, different addressing)


// GLOBAL Store SADDR variants


//==============================================================================
// GLOBAL Instructions - Atomics (base, non-RTN)
// Sources:
//   vega-shader-instruction-set-architecture.pdf, pages 224-227, 293-294.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 226-229, 295-296.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 211-214, 281-282.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 205-208, 273-274.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 210-220.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 215-225.
//   rdna-shader-instruction-set-architecture.pdf, pages 190-200.
//   rdna2-shader-instruction-set-architecture.pdf, pages 190-200.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 285-300.
//   rdna4-instruction-set-architecture.pdf, pages 295-310.
//==============================================================================

def GLOBAL_ATOMIC_SWAP_sem : InstSISemantic<GLOBAL_ATOMIC_SWAP> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_ADD_sem : InstSISemantic<GLOBAL_ATOMIC_ADD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_SUB_sem : InstSISemantic<GLOBAL_ATOMIC_SUB> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_AND_sem : InstSISemantic<GLOBAL_ATOMIC_AND> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_OR_sem : InstSISemantic<GLOBAL_ATOMIC_OR> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_XOR_sem : InstSISemantic<GLOBAL_ATOMIC_XOR> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_SMIN_sem : InstSISemantic<GLOBAL_ATOMIC_SMIN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_UMIN_sem : InstSISemantic<GLOBAL_ATOMIC_UMIN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_SMAX_sem : InstSISemantic<GLOBAL_ATOMIC_SMAX> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_UMAX_sem : InstSISemantic<GLOBAL_ATOMIC_UMAX> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_INC_sem : InstSISemantic<GLOBAL_ATOMIC_INC> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_DEC_sem : InstSISemantic<GLOBAL_ATOMIC_DEC> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

def GLOBAL_ATOMIC_CMPSWAP_sem : InstSISemantic<GLOBAL_ATOMIC_CMPSWAP> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_ADD_F32_sem : InstSISemantic<GLOBAL_ATOMIC_ADD_F32> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_ADD_F64_sem : InstSISemantic<GLOBAL_ATOMIC_ADD_F64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_FCMPSWAP_sem : InstSISemantic<GLOBAL_ATOMIC_FCMPSWAP> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_FCMPSWAP_X2_sem : InstSISemantic<GLOBAL_ATOMIC_FCMPSWAP_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_FMIN_sem : InstSISemantic<GLOBAL_ATOMIC_FMIN> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_FMAX_sem : InstSISemantic<GLOBAL_ATOMIC_FMAX> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_MIN_F64_sem : InstSISemantic<GLOBAL_ATOMIC_MIN_F64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_MAX_F64_sem : InstSISemantic<GLOBAL_ATOMIC_MAX_F64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_PK_ADD_F16_sem : InstSISemantic<GLOBAL_ATOMIC_PK_ADD_F16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_half_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_half_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_half_ty),
                                (LLVMBitCast (GetVal $src_hi), si_llvm_half_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                          (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_PK_ADD_BF16_sem : InstSISemantic<GLOBAL_ATOMIC_PK_ADD_BF16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_i16_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_i16_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_i16_ty),
                                (LLVMBitCast (GetVal $src_hi), si_llvm_i16_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                          (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_CSUB_sem : InstSISemantic<GLOBAL_ATOMIC_CSUB> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGT, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (ConstantInt si_llvm_i32_ty, 0))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_COND_SUB_U32_sem : InstSISemantic<GLOBAL_ATOMIC_COND_SUB_U32> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

def GLOBAL_ATOMIC_ORDERED_ADD_B64_sem : InstSISemantic<GLOBAL_ATOMIC_ORDERED_ADD_B64> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

//==============================================================================
// GLOBAL Instructions - X2 (64-bit) Atomic variants
// Same atomic operations as 32-bit base but operating on 64-bit data.
// Sources: Same as GLOBAL Atomics above.

//==============================================================================



def GLOBAL_ATOMIC_CMPSWAP_X2_sem : InstSISemantic<GLOBAL_ATOMIC_CMPSWAP_X2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateGlobalAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

//==============================================================================
// GLOBAL Instructions - _SADDR Atomic variants
// Sources: Same as GLOBAL Atomics above.

//==============================================================================



//==============================================================================
// GLOBAL Instructions - _RTN Atomic variants
// Sources: Same as GLOBAL Atomics above.

//==============================================================================



//==============================================================================
// GLOBAL Instructions - _SADDR_RTN Atomic variants
// Sources: Same as GLOBAL Atomics above.

//==============================================================================



//==============================================================================
// GLOBAL Instructions - Load to LDS (GFX8+)
// Load from global memory directly into LDS, bypassing VGPRs.
// Sources:
//   vega-shader-instruction-set-architecture.pdf, pages 224-227.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 226-229.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 211-214.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 205-208.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 210-215.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 215-220.
//   rdna-shader-instruction-set-architecture.pdf, pages 190-195.
//   rdna2-shader-instruction-set-architecture.pdf, pages 190-195.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 285-290.
//   rdna4-instruction-set-architecture.pdf, pages 295-300.
//==============================================================================



//==============================================================================
// GLOBAL Instructions - ADDTID variants (GFX10+)
// Load/store with thread-ID offset added to the address.

//==============================================================================



//==============================================================================
// GLOBAL Instructions - Block Load/Store (GFX12+)
// Large block transfer operations.

//==============================================================================



//==============================================================================
// GLOBAL Instructions - Cache Management (GFX12+)

//==============================================================================

// GLOBAL_INV: Invalidate cache
def GLOBAL_INV_sem : InstSISemantic<GLOBAL_INV> {
  let Semantic = [];
}

// GLOBAL_WB: Write-back cache
def GLOBAL_WB_sem : InstSISemantic<GLOBAL_WB> {
  let Semantic = [];
}

// GLOBAL_WBINV: Write-back and invalidate cache
def GLOBAL_WBINV_sem : InstSISemantic<GLOBAL_WBINV> {
  let Semantic = [];
}

//==============================================================================
// SCRATCH Instructions - Loads
// Sources:
//   vega-shader-instruction-set-architecture.pdf, pages 222-223, 295.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 224-225, 297.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 210-211, 283.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 204, 274-275.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 210-215.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 215-220.
//   rdna-shader-instruction-set-architecture.pdf, pages 190-195.
//   rdna2-shader-instruction-set-architecture.pdf, pages 190-195.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 285-295.
//   rdna4-instruction-set-architecture.pdf, pages 295-310.
//==============================================================================

def SCRATCH_LOAD_UBYTE_sem : InstSISemantic<SCRATCH_LOAD_UBYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def SCRATCH_LOAD_SBYTE_sem : InstSISemantic<SCRATCH_LOAD_SBYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def SCRATCH_LOAD_USHORT_sem : InstSISemantic<SCRATCH_LOAD_USHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def SCRATCH_LOAD_SSHORT_sem : InstSISemantic<SCRATCH_LOAD_SSHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def SCRATCH_LOAD_DWORD_sem : InstSISemantic<SCRATCH_LOAD_DWORD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def SCRATCH_LOAD_DWORDX2_sem : InstSISemantic<SCRATCH_LOAD_DWORDX2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (GetVal $tmp))
  ];
}

def SCRATCH_LOAD_DWORDX3_sem : InstSISemantic<SCRATCH_LOAD_DWORDX3> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v3i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (GetVal $tmp))
  ];
}

def SCRATCH_LOAD_DWORDX4_sem : InstSISemantic<SCRATCH_LOAD_DWORDX4> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (GetVal $tmp))
  ];
}

//==============================================================================
// SCRATCH Instructions - D16 Loads
// Sources: Same as SCRATCH Loads above.

//==============================================================================

def SCRATCH_LOAD_UBYTE_D16_sem : InstSISemantic<SCRATCH_LOAD_UBYTE_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMZExt (GetVal $tmp), si_llvm_i16_ty))
  ];
}

def SCRATCH_LOAD_UBYTE_D16_HI_sem : InstSISemantic<SCRATCH_LOAD_UBYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMZExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdst), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdst, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

def SCRATCH_LOAD_SBYTE_D16_sem : InstSISemantic<SCRATCH_LOAD_SBYTE_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $vdst, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty))
  ];
}

def SCRATCH_LOAD_SBYTE_D16_HI_sem : InstSISemantic<SCRATCH_LOAD_SBYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdst), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdst, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

def SCRATCH_LOAD_SHORT_D16_sem : InstSISemantic<SCRATCH_LOAD_SHORT_D16> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdst, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)))
  ];
}

def SCRATCH_LOAD_SHORT_D16_HI_sem : InstSISemantic<SCRATCH_LOAD_SHORT_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr))),
    (DefVal $hi, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty)),
    (DefVal $hi_shift, (LLVMShl (GetVal $hi), 16)),
    (DefVal $lo, (LLVMAnd (GetNamedOperand $vdst), (ConstantInt si_llvm_i32_ty, 65535))),
    (SetNamedOperand $vdst, (LLVMOr (GetVal $hi_shift), (GetVal $lo)))
  ];
}

//==============================================================================
// SCRATCH Instructions - Stores
// Sources: Same as SCRATCH Loads above.

//==============================================================================

def SCRATCH_STORE_BYTE_sem : InstSISemantic<SCRATCH_STORE_BYTE> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i8_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_BYTE_D16_HI_sem : InstSISemantic<SCRATCH_STORE_BYTE_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i8_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_SHORT_sem : InstSISemantic<SCRATCH_STORE_SHORT> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i16_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_SHORT_D16_HI_sem : InstSISemantic<SCRATCH_STORE_SHORT_D16_HI> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMStore (GetVal $tmp8), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_DWORD_sem : InstSISemantic<SCRATCH_STORE_DWORD> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_DWORDX2_sem : InstSISemantic<SCRATCH_STORE_DWORDX2> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_DWORDX3_sem : InstSISemantic<SCRATCH_STORE_DWORDX3> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

def SCRATCH_STORE_DWORDX4_sem : InstSISemantic<SCRATCH_STORE_DWORDX4> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateScratchAddr<(GetNamedOperand $vaddr),
                                            (GetNamedOperand $offset)>.ret),
    (LLVMStore (GetNamedOperand $vdata), (GetVal $tmp_addr))
  ];
}

//==============================================================================
// SCRATCH Instructions - _SADDR, _SVS, and _ST variants
// _SADDR: Uses scalar SGPR address + offset (no VGPR base)
// _SVS: Stack + VGPR + SGPR addressing (GFX12+)
// _ST: Stack-relative addressing, no VGPR (GFX12+)
// Same load/store semantics as base, different addressing modes.
// Sources: Same as SCRATCH Loads/Stores above.

//==============================================================================

// SCRATCH Load _SADDR variants


// SCRATCH Load _SVS variants


// SCRATCH Load _ST variants


// SCRATCH Store _SADDR variants


// SCRATCH Store _SVS variants


// SCRATCH Store _ST variants


//==============================================================================
// SCRATCH Instructions - Load to LDS
// Load from scratch memory directly into LDS, bypassing VGPRs.
// Each has base, _SADDR, _SVS, and _ST variants.
// Sources: Same as SCRATCH Loads above.

//==============================================================================



//==============================================================================
// SCRATCH Instructions - Block Load/Store (GFX12+)
// Large block transfer operations on scratch memory.
// Each has base, _SADDR, _SVS, and _ST variants.

//==============================================================================



//==============================================================================
// FLAT _agpr variants (Phase 5) — replicated from base records.
//==============================================================================

// _agpr alias of FLAT_ATOMIC_ADD_F32_RTN
def FLAT_ATOMIC_ADD_F32_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_ADD_F32_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_ADD_F64_RTN
def FLAT_ATOMIC_ADD_F64_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_ADD_F64_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMFAdd (GetVal $tmp), (GetNamedOperand $vdata))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_ADD_RTN
def FLAT_ATOMIC_ADD_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_ADD_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_ADD_X2_RTN
def FLAT_ATOMIC_ADD_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_ADD_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_AND_RTN
def FLAT_ATOMIC_AND_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_AND_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_AND_X2_RTN
def FLAT_ATOMIC_AND_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_AND_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_CMPSWAP_RTN
def FLAT_ATOMIC_CMPSWAP_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_CMPSWAP_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_CMPSWAP_X2_RTN
def FLAT_ATOMIC_CMPSWAP_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_CMPSWAP_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_COND_SUB_U32_RTN
def FLAT_ATOMIC_COND_SUB_U32_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_COND_SUB_U32_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_CSUB_U32_RTN
def FLAT_ATOMIC_CSUB_U32_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_CSUB_U32_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGT, (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (LLVMSub (GetVal $tmp), (GetNamedOperand $vdata)),
                                 (ConstantInt si_llvm_i32_ty, 0))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_DEC_RTN
def FLAT_ATOMIC_DEC_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_DEC_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_DEC_X2_RTN
def FLAT_ATOMIC_DEC_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_DEC_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUDecWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_FCMPSWAP_RTN
def FLAT_ATOMIC_FCMPSWAP_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_FCMPSWAP_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_FCMPSWAP_X2_RTN
def FLAT_ATOMIC_FCMPSWAP_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_FCMPSWAP_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_FMAX_RTN
def FLAT_ATOMIC_FMAX_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_FMAX_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_FMIN_RTN
def FLAT_ATOMIC_FMIN_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_FMIN_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_float_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_INC_RTN
def FLAT_ATOMIC_INC_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_INC_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_INC_X2_RTN
def FLAT_ATOMIC_INC_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_INC_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUIncWrap, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_MAX_F64_RTN
def FLAT_ATOMIC_MAX_F64_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_MAX_F64_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOGT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_MIN_F64_RTN
def FLAT_ATOMIC_MIN_F64_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_MIN_F64_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_double_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMFCmp LLVMFCmpOLT, (GetNamedOperand $vdata), (GetVal $tmp)),
                                 (GetNamedOperand $vdata), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_OR_RTN
def FLAT_ATOMIC_OR_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_OR_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_OR_X2_RTN
def FLAT_ATOMIC_OR_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_OR_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_PK_ADD_BF16_RTN
def FLAT_ATOMIC_PK_ADD_BF16_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_PK_ADD_BF16_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_i16_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_i16_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_i16_ty),
                               (LLVMBitCast (GetVal $src_hi), si_llvm_i16_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                         (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_PK_ADD_F16_RTN
def FLAT_ATOMIC_PK_ADD_F16_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_PK_ADD_F16_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $src, (GetNamedOperand $vdata)),
    (DefVal $tmp_lo, (LLVMTrunc (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $src_lo, (LLVMTrunc (GetVal $src), si_llvm_i16_ty)),
    (DefVal $tmp_hi, (LLVMTrunc (LLVMLShr (GetVal $tmp), 16), si_llvm_i16_ty)),
    (DefVal $src_hi, (LLVMTrunc (LLVMLShr (GetVal $src), 16), si_llvm_i16_ty)),
    (DefVal $res_lo, (LLVMFAdd (LLVMBitCast (GetVal $tmp_lo), si_llvm_half_ty),
                              (LLVMBitCast (GetVal $src_lo), si_llvm_half_ty))),
    (DefVal $res_hi, (LLVMFAdd (LLVMBitCast (GetVal $tmp_hi), si_llvm_half_ty),
                               (LLVMBitCast (GetVal $src_hi), si_llvm_half_ty))),
    (DefVal $res, (LLVMOr (LLVMZExt (LLVMBitCast (GetVal $res_lo), si_llvm_i16_ty), si_llvm_i32_ty),
                         (LLVMShl (LLVMZExt (LLVMBitCast (GetVal $res_hi), si_llvm_i16_ty), si_llvm_i32_ty), 16))),
    (LLVMStore (GetVal $res), (GetVal $tmp_addr)),
    (SetNamedOperand $vdata, (GetVal $tmp))
  ];
}

// _agpr alias of FLAT_ATOMIC_SMAX_RTN
def FLAT_ATOMIC_SMAX_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SMAX_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SMAX_X2_RTN
def FLAT_ATOMIC_SMAX_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SMAX_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SMIN_RTN
def FLAT_ATOMIC_SMIN_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SMIN_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SMIN_X2_RTN
def FLAT_ATOMIC_SMIN_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SMIN_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SUB_RTN
def FLAT_ATOMIC_SUB_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SUB_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SUB_X2_RTN
def FLAT_ATOMIC_SUB_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SUB_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SWAP_RTN
def FLAT_ATOMIC_SWAP_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SWAP_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_SWAP_X2_RTN
def FLAT_ATOMIC_SWAP_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_SWAP_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_UMAX_RTN
def FLAT_ATOMIC_UMAX_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_UMAX_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_UMAX_X2_RTN
def FLAT_ATOMIC_UMAX_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_UMAX_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_UMIN_RTN
def FLAT_ATOMIC_UMIN_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_UMIN_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_UMIN_X2_RTN
def FLAT_ATOMIC_UMIN_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_UMIN_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_XOR_RTN
def FLAT_ATOMIC_XOR_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_XOR_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

// _agpr alias of FLAT_ATOMIC_XOR_X2_RTN
def FLAT_ATOMIC_XOR_X2_RTN_agpr_sem : InstSISemantic<FLAT_ATOMIC_XOR_X2_RTN_agpr> {
  let Semantic = [
    (DefVal $tmp_addr, CalculateFlatAddr<(GetNamedOperand $vaddr),
                                       (GetNamedOperand $offset)>.ret),
    (SetNamedOperand $vdata, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $vdata), AlignNone, AtomicOrderingMonotonic, SyncScopeSystem))
  ];
}

//==============================================================================
// GLOBAL _agpr variants (Phase 5) — replicated from base records.
//==============================================================================



//==============================================================================
// SCRATCH _agpr variants (Phase 5) — replicated from base records.
//==============================================================================


