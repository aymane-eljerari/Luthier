//===- SMEMSem.td -----------------------------------------------------*- tblgen -*-===//
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
// S_BUFFER_LOAD Instructions
// S_BUFFER_LOAD_DWORD: Load dword(s) from buffer descriptor + offset into SGPRs.
// Sources:
//   southern-islands-instruction-set-architecture.pdf, pages 140-142.
//   sea-islands-instruction-set-architecture_0.pdf, pages 142-144.
//   gcn3-instruction-set-architecture.pdf, page 154.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 123.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 120.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 119.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 149.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 161.
//   rdna-shader-instruction-set-architecture.pdf, page 139.
//   rdna2-shader-instruction-set-architecture.pdf, page 138.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 256 (as S_BUFFER_LOAD_B32).
//   rdna4-instruction-set-architecture.pdf, page 292 (as S_BUFFER_LOAD_B32).
//------------------------------------------------------------------------------

foreach inst = [
    S_BUFFER_STORE_DWORDX2_SGPR,
    S_BUFFER_STORE_DWORDX2_SGPR_IMM,
    S_BUFFER_STORE_DWORDX4_SGPR,
    S_BUFFER_STORE_DWORDX4_SGPR_IMM,
    S_BUFFER_STORE_DWORD_SGPR,
    S_BUFFER_STORE_DWORD_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

// ---- S_ATOMIC_SWAP_*_RTN — unconditional atomic xchg ----
foreach inst = [
    S_ATOMIC_SWAP_IMM_RTN,
    S_ATOMIC_SWAP_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SWAP_SGPR,
    S_ATOMIC_SWAP_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SWAP_SGPR_IMM_RTN,
    S_ATOMIC_SWAP_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SWAP_SGPR_RTN,
    S_ATOMIC_SWAP_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

// ---- S_ATOMIC_CMPSWAP_*_(RTN) — compare-and-swap; $sdata holds (src, cmp) ----
// $sdata: low half = new value (src), high half = expected value (cmp).
// cmpxchg returns {loaded_value, i1 success} — RTN takes element 0.
// non-X2 (i32 width): $sdata bitcast to v2i32 to extract two i32 halves.
def S_ATOMIC_CMPSWAP_IMM_RTN_sem : InstSISemantic<S_ATOMIC_CMPSWAP_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (GetNamedOperand $offset))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $rmw, (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                                     AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                                     (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMExtractValue (GetVal $rmw), 0), si_llvm_i64_ty))
  ];
}

def S_ATOMIC_CMPSWAP_X2_IMM_RTN_sem : InstSISemantic<S_ATOMIC_CMPSWAP_X2_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (GetNamedOperand $offset))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $rmw, (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                                     AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                                     (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMExtractValue (GetVal $rmw), 0), si_llvm_i128_ty))
  ];
}

def S_ATOMIC_CMPSWAP_SGPR_sem : InstSISemantic<S_ATOMIC_CMPSWAP_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (GetNamedOperand $soffset))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                       AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                       (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
}

def S_ATOMIC_CMPSWAP_X2_SGPR_sem : InstSISemantic<S_ATOMIC_CMPSWAP_X2_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (GetNamedOperand $soffset))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                       AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                       (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
}

def S_ATOMIC_CMPSWAP_SGPR_IMM_RTN_sem : InstSISemantic<S_ATOMIC_CMPSWAP_SGPR_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $rmw, (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                                     AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                                     (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMExtractValue (GetVal $rmw), 0), si_llvm_i64_ty))
  ];
}

def S_ATOMIC_CMPSWAP_X2_SGPR_IMM_RTN_sem : InstSISemantic<S_ATOMIC_CMPSWAP_X2_SGPR_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $rmw, (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                                     AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                                     (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMExtractValue (GetVal $rmw), 0), si_llvm_i128_ty))
  ];
}

def S_ATOMIC_CMPSWAP_SGPR_RTN_sem : InstSISemantic<S_ATOMIC_CMPSWAP_SGPR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (GetNamedOperand $soffset))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $rmw, (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                                     AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                                     (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMExtractValue (GetVal $rmw), 0), si_llvm_i64_ty))
  ];
}

def S_ATOMIC_CMPSWAP_X2_SGPR_RTN_sem : InstSISemantic<S_ATOMIC_CMPSWAP_X2_SGPR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                                   (GetNamedOperand $soffset))),
    (DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $rmw, (LLVMAtomicCmpXchg (GetVal $tmp_addr), (GetVal $cmp), (GetVal $src),
                                     AlignNone, AtomicOrderingMonotonic, AtomicOrderingMonotonic,
                                     (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMExtractValue (GetVal $rmw), 0), si_llvm_i128_ty))
  ];
}

foreach inst = [
    S_BUFFER_ATOMIC_ADD_SGPR,
    S_BUFFER_ATOMIC_ADD_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_ADD_X2_SGPR,
    S_BUFFER_ATOMIC_ADD_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_ADD_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_ADD_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_ADD_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_ADD_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_AND_SGPR,
    S_BUFFER_ATOMIC_AND_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_AND_X2_SGPR,
    S_BUFFER_ATOMIC_AND_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_AND_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_AND_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_AND_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_AND_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_OR_SGPR,
    S_BUFFER_ATOMIC_OR_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_OR_X2_SGPR,
    S_BUFFER_ATOMIC_OR_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_OR_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_OR_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_OR_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_OR_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMAX_SGPR,
    S_BUFFER_ATOMIC_SMAX_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMAX_X2_SGPR,
    S_BUFFER_ATOMIC_SMAX_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMAX_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SMAX_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMAX_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SMAX_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMIN_SGPR,
    S_BUFFER_ATOMIC_SMIN_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMIN_X2_SGPR,
    S_BUFFER_ATOMIC_SMIN_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMIN_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SMIN_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMIN_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SMIN_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SUB_SGPR,
    S_BUFFER_ATOMIC_SUB_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SUB_X2_SGPR,
    S_BUFFER_ATOMIC_SUB_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SUB_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SUB_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SUB_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SUB_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SWAP_SGPR,
    S_BUFFER_ATOMIC_SWAP_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SWAP_X2_SGPR,
    S_BUFFER_ATOMIC_SWAP_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SWAP_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SWAP_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SWAP_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_SWAP_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMAX_SGPR,
    S_BUFFER_ATOMIC_UMAX_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMAX_X2_SGPR,
    S_BUFFER_ATOMIC_UMAX_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMAX_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_UMAX_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMAX_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_UMAX_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMIN_SGPR,
    S_BUFFER_ATOMIC_UMIN_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMIN_X2_SGPR,
    S_BUFFER_ATOMIC_UMIN_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMIN_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_UMIN_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMIN_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_UMIN_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_XOR_SGPR,
    S_BUFFER_ATOMIC_XOR_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_XOR_X2_SGPR,
    S_BUFFER_ATOMIC_XOR_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_XOR_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_XOR_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_XOR_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_XOR_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_STORE_DWORDX2_IMM,
    S_BUFFER_STORE_DWORDX4_IMM,
    S_BUFFER_STORE_DWORD_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_SCRATCH_STORE_DWORDX2_IMM,
    S_SCRATCH_STORE_DWORDX4_IMM,
    S_SCRATCH_STORE_DWORD_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetNamedOperand $offset))),
    (LLVMStore (GetNamedOperand $sdata), (GetVal $tmp_addr))
  ];
  }
}

foreach inst = [
    S_SCRATCH_STORE_DWORDX2_SGPR,
    S_SCRATCH_STORE_DWORDX4_SGPR,
    S_SCRATCH_STORE_DWORD_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $soff_scaled))),
    (LLVMStore (GetNamedOperand $sdata), (GetVal $tmp_addr))
  ];
  }
}

foreach inst = [
    S_SCRATCH_STORE_DWORDX2_SGPR_IMM,
    S_SCRATCH_STORE_DWORDX4_SGPR_IMM,
    S_SCRATCH_STORE_DWORD_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetVal $soff_scaled))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $total_offset))),
    (LLVMStore (GetNamedOperand $sdata), (GetVal $tmp_addr))
  ];
  }
}

foreach inst = [
    S_STORE_DWORDX2_IMM,
    S_STORE_DWORDX4_IMM,
    S_STORE_DWORD_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMStore (GetNamedOperand $sdata), (GetVal $tmp_addr))
  ];
  }
}

foreach inst = [
    S_STORE_DWORDX2_SGPR,
    S_STORE_DWORDX4_SGPR,
    S_STORE_DWORD_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMStore (GetNamedOperand $sdata), (GetVal $tmp_addr))
  ];
  }
}

foreach inst = [
    S_STORE_DWORDX2_SGPR_IMM,
    S_STORE_DWORDX4_SGPR_IMM,
    S_STORE_DWORD_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMStore (GetNamedOperand $sdata), (GetVal $tmp_addr))
  ];
  }
}

foreach inst = [
    S_ATOMIC_ADD_IMM,
    S_ATOMIC_ADD_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_ADD_IMM_RTN,
    S_ATOMIC_ADD_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_ADD_SGPR,
    S_ATOMIC_ADD_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_ADD_SGPR_IMM,
    S_ATOMIC_ADD_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_ADD_SGPR_IMM_RTN,
    S_ATOMIC_ADD_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_ADD_SGPR_RTN,
    S_ATOMIC_ADD_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWAdd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_AND_IMM,
    S_ATOMIC_AND_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_AND_IMM_RTN,
    S_ATOMIC_AND_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_AND_SGPR,
    S_ATOMIC_AND_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_AND_SGPR_IMM,
    S_ATOMIC_AND_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_AND_SGPR_IMM_RTN,
    S_ATOMIC_AND_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_AND_SGPR_RTN,
    S_ATOMIC_AND_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWAnd, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_OR_IMM,
    S_ATOMIC_OR_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_OR_IMM_RTN,
    S_ATOMIC_OR_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_OR_SGPR,
    S_ATOMIC_OR_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_OR_SGPR_IMM,
    S_ATOMIC_OR_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_OR_SGPR_IMM_RTN,
    S_ATOMIC_OR_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_OR_SGPR_RTN,
    S_ATOMIC_OR_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWOr, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMAX_IMM,
    S_ATOMIC_SMAX_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMAX_IMM_RTN,
    S_ATOMIC_SMAX_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMAX_SGPR,
    S_ATOMIC_SMAX_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMAX_SGPR_IMM,
    S_ATOMIC_SMAX_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMAX_SGPR_IMM_RTN,
    S_ATOMIC_SMAX_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMAX_SGPR_RTN,
    S_ATOMIC_SMAX_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMIN_IMM,
    S_ATOMIC_SMIN_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMIN_IMM_RTN,
    S_ATOMIC_SMIN_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMIN_SGPR,
    S_ATOMIC_SMIN_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMIN_SGPR_IMM,
    S_ATOMIC_SMIN_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMIN_SGPR_IMM_RTN,
    S_ATOMIC_SMIN_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SMIN_SGPR_RTN,
    S_ATOMIC_SMIN_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SUB_IMM,
    S_ATOMIC_SUB_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SUB_IMM_RTN,
    S_ATOMIC_SUB_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SUB_SGPR,
    S_ATOMIC_SUB_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SUB_SGPR_IMM,
    S_ATOMIC_SUB_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SUB_SGPR_IMM_RTN,
    S_ATOMIC_SUB_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SUB_SGPR_RTN,
    S_ATOMIC_SUB_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWSub, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SWAP_IMM,
    S_ATOMIC_SWAP_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_SWAP_SGPR_IMM,
    S_ATOMIC_SWAP_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWXchg, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMAX_IMM,
    S_ATOMIC_UMAX_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMAX_IMM_RTN,
    S_ATOMIC_UMAX_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMAX_SGPR,
    S_ATOMIC_UMAX_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMAX_SGPR_IMM,
    S_ATOMIC_UMAX_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMAX_SGPR_IMM_RTN,
    S_ATOMIC_UMAX_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMAX_SGPR_RTN,
    S_ATOMIC_UMAX_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWUMax, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMIN_IMM,
    S_ATOMIC_UMIN_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMIN_IMM_RTN,
    S_ATOMIC_UMIN_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMIN_SGPR,
    S_ATOMIC_UMIN_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMIN_SGPR_IMM,
    S_ATOMIC_UMIN_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMIN_SGPR_IMM_RTN,
    S_ATOMIC_UMIN_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_UMIN_SGPR_RTN,
    S_ATOMIC_UMIN_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWUMin, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_XOR_IMM,
    S_ATOMIC_XOR_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_XOR_IMM_RTN,
    S_ATOMIC_XOR_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_XOR_SGPR,
    S_ATOMIC_XOR_X2_SGPR
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_XOR_SGPR_IMM,
    S_ATOMIC_XOR_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty)))
  ];
  }
}

foreach inst = [
    S_ATOMIC_XOR_SGPR_IMM_RTN,
    S_ATOMIC_XOR_X2_SGPR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_ATOMIC_XOR_SGPR_RTN,
    S_ATOMIC_XOR_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMAtomicRMW AtomicRMWXor, (GetVal $tmp_addr), (GetNamedOperand $sdata), AlignNone, AtomicOrderingMonotonic, (GetSyncScope (GetNamedOperand $cpol, si_llvm_i32_ty))))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_ADD_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_ADD_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_ADD_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_ADD_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_AND_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_AND_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_AND_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_AND_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_CMPSWAP_SGPR,
    S_BUFFER_ATOMIC_CMPSWAP_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_CMPSWAP_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_CMPSWAP_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (DefVal $tmp, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])),
    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i64_ty))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_CMPSWAP_X2_SGPR,
    S_BUFFER_ATOMIC_CMPSWAP_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_CMPSWAP_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_CMPSWAP_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (DefVal $tmp, (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])),
    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i128_ty))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_DEC_SGPR,
    S_BUFFER_ATOMIC_DEC_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_DEC_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_DEC_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_DEC_X2_SGPR,
    S_BUFFER_ATOMIC_DEC_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_DEC_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_DEC_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_INC_SGPR,
    S_BUFFER_ATOMIC_INC_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_INC_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_INC_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_INC_X2_SGPR,
    S_BUFFER_ATOMIC_INC_X2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_INC_X2_SGPR_IMM_RTN,
    S_BUFFER_ATOMIC_INC_X2_SGPR_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetVal $total_offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_OR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_OR_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_OR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_OR_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMAX_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMAX_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMAX_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMAX_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMIN_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMIN_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SMIN_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SMIN_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SUB_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SUB_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SUB_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SUB_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SWAP_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SWAP_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_SWAP_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_SWAP_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMAX_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMAX_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMAX_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMAX_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMIN_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMIN_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_UMIN_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_UMIN_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_XOR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_XOR_X2_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
  }
}


foreach inst = [
    S_BUFFER_ATOMIC_XOR_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_ATOMIC_XOR_X2_IMM_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $sdata), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
  }
}


foreach inst = [
    S_BUFFER_LOAD_DWORDX16_SGPR,
    S_BUFFER_LOAD_DWORDX16_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v16i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_DWORDX2_SGPR,
    S_BUFFER_LOAD_DWORDX2_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_DWORDX3_SGPR,
    S_BUFFER_LOAD_DWORDX3_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_DWORDX4_SGPR,
    S_BUFFER_LOAD_DWORDX4_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_DWORDX8_SGPR,
    S_BUFFER_LOAD_DWORDX8_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v8i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_DWORD_SGPR,
    S_BUFFER_LOAD_DWORD_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)]))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_I16_SGPR,
    S_BUFFER_LOAD_I16_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_I8_SGPR,
    S_BUFFER_LOAD_I8_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_U16_SGPR,
    S_BUFFER_LOAD_U16_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
  }
}

foreach inst = [
    S_BUFFER_LOAD_U8_SGPR,
    S_BUFFER_LOAD_U8_SGPR_IMM
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset))),

    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetVal $total_offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
  }
}

def S_ATOMIC_CMPSWAP_IMM_sem : InstSISemantic<S_ATOMIC_CMPSWAP_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_CMPSWAP_SGPR_IMM_sem : InstSISemantic<S_ATOMIC_CMPSWAP_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i32_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_CMPSWAP_X2_IMM_sem : InstSISemantic<S_ATOMIC_CMPSWAP_X2_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_CMPSWAP_X2_SGPR_IMM_sem : InstSISemantic<S_ATOMIC_CMPSWAP_X2_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i64_ty, 1))),
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $sdata), (ConstantInt si_llvm_i64_ty, 0))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpEQ, (GetVal $tmp), (GetVal $cmp)), (GetVal $src), (GetVal $tmp))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_IMM_sem : InstSISemantic<S_ATOMIC_DEC_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_IMM_RTN_sem : InstSISemantic<S_ATOMIC_DEC_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_DEC_SGPR_sem : InstSISemantic<S_ATOMIC_DEC_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_SGPR_IMM_sem : InstSISemantic<S_ATOMIC_DEC_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_SGPR_IMM_RTN_sem : InstSISemantic<S_ATOMIC_DEC_SGPR_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_DEC_SGPR_RTN_sem : InstSISemantic<S_ATOMIC_DEC_SGPR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_DEC_X2_IMM_sem : InstSISemantic<S_ATOMIC_DEC_X2_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_X2_IMM_RTN_sem : InstSISemantic<S_ATOMIC_DEC_X2_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_DEC_X2_SGPR_sem : InstSISemantic<S_ATOMIC_DEC_X2_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_X2_SGPR_IMM_sem : InstSISemantic<S_ATOMIC_DEC_X2_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_DEC_X2_SGPR_IMM_RTN_sem : InstSISemantic<S_ATOMIC_DEC_X2_SGPR_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_DEC_X2_SGPR_RTN_sem : InstSISemantic<S_ATOMIC_DEC_X2_SGPR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMOr (LLVMCmp LLVMICmpEQ, (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 0)),
                                           (LLVMCmp LLVMICmpUGT, (GetVal $tmp_val), (GetNamedOperand $sdata))),
                                   (GetNamedOperand $sdata),
                                   (LLVMSub (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_INC_IMM_sem : InstSISemantic<S_ATOMIC_INC_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_INC_IMM_RTN_sem : InstSISemantic<S_ATOMIC_INC_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_INC_SGPR_sem : InstSISemantic<S_ATOMIC_INC_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_INC_SGPR_IMM_sem : InstSISemantic<S_ATOMIC_INC_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_INC_SGPR_IMM_RTN_sem : InstSISemantic<S_ATOMIC_INC_SGPR_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_INC_SGPR_RTN_sem : InstSISemantic<S_ATOMIC_INC_SGPR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i32_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_INC_X2_IMM_sem : InstSISemantic<S_ATOMIC_INC_X2_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i64_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_INC_X2_IMM_RTN_sem : InstSISemantic<S_ATOMIC_INC_X2_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i64_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_INC_X2_SGPR_sem : InstSISemantic<S_ATOMIC_INC_X2_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i64_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_INC_X2_SGPR_IMM_sem : InstSISemantic<S_ATOMIC_INC_X2_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i64_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr))
  ];
}

def S_ATOMIC_INC_X2_SGPR_IMM_RTN_sem : InstSISemantic<S_ATOMIC_INC_X2_SGPR_IMM_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i64_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_ATOMIC_INC_X2_SGPR_RTN_sem : InstSISemantic<S_ATOMIC_INC_X2_SGPR_RTN> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp_val, (LLVMLoad si_llvm_i64_ty, (GetVal $tmp_addr))),
    (DefVal $new_val, (LLVMSelect (LLVMCmp LLVMICmpUGE, (GetVal $tmp_val), (GetNamedOperand $sdata)),
                                   (ConstantInt si_llvm_i64_ty, 0),
                                   (LLVMAdd (GetVal $tmp_val), (ConstantInt si_llvm_i64_ty, 1)))),
    (LLVMStore (GetVal $new_val), (GetVal $tmp_addr)),
    (SetNamedOperand $sdst, (GetVal $tmp_val))
  ];
}

def S_BUFFER_ATOMIC_CMPSWAP_IMM_sem : InstSISemantic<S_BUFFER_ATOMIC_CMPSWAP_IMM> {
  let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def S_BUFFER_ATOMIC_CMPSWAP_IMM_RTN_sem : InstSISemantic<S_BUFFER_ATOMIC_CMPSWAP_IMM_RTN> {
  let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i32_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (DefVal $tmp, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])),
    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i64_ty))
  ];
}

def S_BUFFER_ATOMIC_CMPSWAP_X2_IMM_sem : InstSISemantic<S_BUFFER_ATOMIC_CMPSWAP_X2_IMM> {
  let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def S_BUFFER_ATOMIC_CMPSWAP_X2_IMM_RTN_sem : InstSISemantic<S_BUFFER_ATOMIC_CMPSWAP_X2_IMM_RTN> {
  let Semantic = [(DefVal $sdata_v, (LLVMBitCast (GetNamedOperand $sdata), si_llvm_v2i64_ty)),
    
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (DefVal $src, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 0))),

    (DefVal $cmp, (LLVMExtractElement (GetVal $sdata_v), (ConstantInt si_llvm_i32_ty, 1))),

    (DefVal $tmp, (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])),
    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i128_ty))
  ];
}

def S_BUFFER_ATOMIC_DEC_IMM_sem : InstSISemantic<S_BUFFER_ATOMIC_DEC_IMM> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def S_BUFFER_ATOMIC_DEC_IMM_RTN_sem : InstSISemantic<S_BUFFER_ATOMIC_DEC_IMM_RTN> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_ATOMIC_DEC_X2_IMM_sem : InstSISemantic<S_BUFFER_ATOMIC_DEC_X2_IMM> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def S_BUFFER_ATOMIC_DEC_X2_IMM_RTN_sem : InstSISemantic<S_BUFFER_ATOMIC_DEC_X2_IMM_RTN> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_dec, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_ATOMIC_INC_IMM_sem : InstSISemantic<S_BUFFER_ATOMIC_INC_IMM> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def S_BUFFER_ATOMIC_INC_IMM_RTN_sem : InstSISemantic<S_BUFFER_ATOMIC_INC_IMM_RTN> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i32_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_ATOMIC_INC_X2_IMM_sem : InstSISemantic<S_BUFFER_ATOMIC_INC_X2_IMM> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def S_BUFFER_ATOMIC_INC_X2_IMM_RTN_sem : InstSISemantic<S_BUFFER_ATOMIC_INC_X2_IMM_RTN> {
  let Semantic = [
    (DefVal $rsrc, (LLVMInsertElement (LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty),
                                   (ConstantInt si_llvm_i32_ty, 0),
                                   (ConstantInt si_llvm_i32_ty, 3))),

    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_inc, [(ConstantInt si_llvm_i64_ty, 1), (GetVal $rsrc), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_DWORDX16_IMM_sem : InstSISemantic<S_BUFFER_LOAD_DWORDX16_IMM> {
  let Semantic = [
    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v16i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_DWORDX2_IMM_sem : InstSISemantic<S_BUFFER_LOAD_DWORDX2_IMM> {
  let Semantic = [
    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_DWORDX3_IMM_sem : InstSISemantic<S_BUFFER_LOAD_DWORDX3_IMM> {
  let Semantic = [
    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_DWORDX4_IMM_sem : InstSISemantic<S_BUFFER_LOAD_DWORDX4_IMM> {
  let Semantic = [
    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_DWORDX8_IMM_sem : InstSISemantic<S_BUFFER_LOAD_DWORDX8_IMM> {
  let Semantic = [
    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_v8i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_DWORD_IMM_sem : InstSISemantic<S_BUFFER_LOAD_DWORD_IMM> {
  let Semantic = [
    (SetNamedOperand $sdst,

      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)]))
  ];
}

def S_BUFFER_LOAD_I16_IMM_sem : InstSISemantic<S_BUFFER_LOAD_I16_IMM> {
  let Semantic = [
    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def S_BUFFER_LOAD_I8_IMM_sem : InstSISemantic<S_BUFFER_LOAD_I8_IMM> {
  let Semantic = [
    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMSExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def S_BUFFER_LOAD_U16_IMM_sem : InstSISemantic<S_BUFFER_LOAD_U16_IMM> {
  let Semantic = [
    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def S_BUFFER_LOAD_U8_IMM_sem : InstSISemantic<S_BUFFER_LOAD_U8_IMM> {
  let Semantic = [
    (DefVal $tmp,

      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_s_buffer_load, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $cpol)])),

    (SetNamedOperand $sdst, (LLVMZExt (GetVal $tmp), si_llvm_i32_ty))
  ];
}

def S_BUFFER_PREFETCH_DATA_sem : InstSISemantic<S_BUFFER_PREFETCH_DATA> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_buffer_prefetch_data, [(LLVMBitCast (GetNamedOperand $sbase), si_llvm_v4i32_ty), (GetNamedOperand $offset), (GetNamedOperand $sdata)])];
}

def S_DCACHE_INV_sem : InstSISemantic<S_DCACHE_INV> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_dcache_inv, []<dag>)];
}

def S_DCACHE_INV_VOL_sem : InstSISemantic<S_DCACHE_INV_VOL> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_dcache_inv_vol, []<dag>)];
}

def S_DCACHE_WB_sem : InstSISemantic<S_DCACHE_WB> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_dcache_wb, []<dag>)];
}

def S_DCACHE_WB_VOL_sem : InstSISemantic<S_DCACHE_WB_VOL> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_dcache_wb_vol, []<dag>)];
}

def S_GET_WAVEID_IN_WORKGROUP_sem : InstSISemantic<S_GET_WAVEID_IN_WORKGROUP> {
  let Semantic = [
    (SetNamedOperand $sdst,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_s_get_waveid_in_workgroup, []<dag>))
  ];
}

def S_GL1_INV_sem : InstSISemantic<S_GL1_INV> {
  let Semantic = [(LLVMFence AtomicOrderingAcquire, SyncScopeAgent)];
}

def S_LOAD_DWORDX16_IMM_sem : InstSISemantic<S_LOAD_DWORDX16_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v16i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX16_SGPR_sem : InstSISemantic<S_LOAD_DWORDX16_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v16i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX16_SGPR_IMM_sem : InstSISemantic<S_LOAD_DWORDX16_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_v16i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX2_IMM_sem : InstSISemantic<S_LOAD_DWORDX2_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX2_SGPR_sem : InstSISemantic<S_LOAD_DWORDX2_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX2_SGPR_IMM_sem : InstSISemantic<S_LOAD_DWORDX2_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX3_IMM_sem : InstSISemantic<S_LOAD_DWORDX3_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v3i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX3_SGPR_sem : InstSISemantic<S_LOAD_DWORDX3_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v3i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX3_SGPR_IMM_sem : InstSISemantic<S_LOAD_DWORDX3_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_v3i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX4_IMM_sem : InstSISemantic<S_LOAD_DWORDX4_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX4_SGPR_sem : InstSISemantic<S_LOAD_DWORDX4_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX4_SGPR_IMM_sem : InstSISemantic<S_LOAD_DWORDX4_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX8_IMM_sem : InstSISemantic<S_LOAD_DWORDX8_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v8i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX8_SGPR_sem : InstSISemantic<S_LOAD_DWORDX8_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v8i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORDX8_SGPR_IMM_sem : InstSISemantic<S_LOAD_DWORDX8_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (DefVal $tmp, (LLVMLoad si_llvm_v8i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_LOAD_DWORD_IMM_sem : InstSISemantic<S_LOAD_DWORD_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def S_LOAD_DWORD_SGPR_sem : InstSISemantic<S_LOAD_DWORD_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def S_LOAD_DWORD_SGPR_IMM_sem : InstSISemantic<S_LOAD_DWORD_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def S_LOAD_I16_IMM_sem : InstSISemantic<S_LOAD_I16_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMSExt (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_I16_SGPR_sem : InstSISemantic<S_LOAD_I16_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMSExt (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_I16_SGPR_IMM_sem : InstSISemantic<S_LOAD_I16_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMSExt (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_I8_IMM_sem : InstSISemantic<S_LOAD_I8_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMSExt (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_I8_SGPR_sem : InstSISemantic<S_LOAD_I8_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMSExt (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_I8_SGPR_IMM_sem : InstSISemantic<S_LOAD_I8_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMSExt (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_U16_IMM_sem : InstSISemantic<S_LOAD_U16_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_U16_SGPR_sem : InstSISemantic<S_LOAD_U16_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_U16_SGPR_IMM_sem : InstSISemantic<S_LOAD_U16_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMLoad si_llvm_i16_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_U8_IMM_sem : InstSISemantic<S_LOAD_U8_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_U8_SGPR_sem : InstSISemantic<S_LOAD_U8_SGPR> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (GetNamedOperand $soffset))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_LOAD_U8_SGPR_IMM_sem : InstSISemantic<S_LOAD_U8_SGPR_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty),
                               (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (SetNamedOperand $sdst, (LLVMZExt (LLVMLoad si_llvm_i8_ty, (GetVal $tmp_addr)), si_llvm_i32_ty))
  ];
}

def S_MEMREALTIME_sem : InstSISemantic<S_MEMREALTIME> {
  let Semantic = [
    (SetNamedOperand $sdst,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_s_memrealtime, []<dag>))
  ];
}

def S_MEMTIME_sem : InstSISemantic<S_MEMTIME> {
  let Semantic = [
    (SetNamedOperand $sdst,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_s_memtime, []<dag>))
  ];
}

def S_PREFETCH_DATA_sem : InstSISemantic<S_PREFETCH_DATA> {
  let Semantic = [(DefVal $ptr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), global_ptr_ty), (LLVMAdd (GetNamedOperand $offset), (GetNamedOperand $soffset)))),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_prefetch_data, [(GetVal $ptr), (GetNamedOperand $sdata)])];
}

def S_PREFETCH_DATA_PC_REL_sem : InstSISemantic<S_PREFETCH_DATA_PC_REL> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_s_prefetch_data, [(LLVMIntToPtr (GetNamedOperand $offset), global_ptr_ty), (GetNamedOperand $sdata)])];
}

def S_SCRATCH_LOAD_DWORDX2_IMM_sem : InstSISemantic<S_SCRATCH_LOAD_DWORDX2_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_SCRATCH_LOAD_DWORDX2_SGPR_sem : InstSISemantic<S_SCRATCH_LOAD_DWORDX2_SGPR> {
  let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $soff_scaled))),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_SCRATCH_LOAD_DWORDX2_SGPR_IMM_sem : InstSISemantic<S_SCRATCH_LOAD_DWORDX2_SGPR_IMM> {
  let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetVal $soff_scaled))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $total_offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v2i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_SCRATCH_LOAD_DWORDX4_IMM_sem : InstSISemantic<S_SCRATCH_LOAD_DWORDX4_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetNamedOperand $offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_SCRATCH_LOAD_DWORDX4_SGPR_sem : InstSISemantic<S_SCRATCH_LOAD_DWORDX4_SGPR> {
  let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $soff_scaled))),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_SCRATCH_LOAD_DWORDX4_SGPR_IMM_sem : InstSISemantic<S_SCRATCH_LOAD_DWORDX4_SGPR_IMM> {
  let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetVal $soff_scaled))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $total_offset))),
    (DefVal $tmp, (LLVMLoad si_llvm_v4i32_ty, (GetVal $tmp_addr))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

def S_SCRATCH_LOAD_DWORD_IMM_sem : InstSISemantic<S_SCRATCH_LOAD_DWORD_IMM> {
  let Semantic = [
    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetNamedOperand $offset))),
    (SetNamedOperand $sdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def S_SCRATCH_LOAD_DWORD_SGPR_sem : InstSISemantic<S_SCRATCH_LOAD_DWORD_SGPR> {
  let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $soff_scaled))),
    (SetNamedOperand $sdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

def S_SCRATCH_LOAD_DWORD_SGPR_IMM_sem : InstSISemantic<S_SCRATCH_LOAD_DWORD_SGPR_IMM> {
  let Semantic = [
    (DefVal $soff_scaled, (LLVMMul (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 64))),

    (DefVal $total_offset, (LLVMAdd (GetNamedOperand $offset), (GetVal $soff_scaled))),

    (DefVal $tmp_addr, (LLVMPtrAdd (LLVMIntToPtr (GetNamedOperand $sbase), scratch_ptr_ty),

                                   (GetVal $total_offset))),
    (SetNamedOperand $sdst, (LLVMLoad si_llvm_i32_ty, (GetVal $tmp_addr)))
  ];
}

// ---- Ops with no IR-level semantic (modeled as no-op) ----
def S_ATC_PROBE_BUFFER_IMM_sem : InstSISemantic<S_ATC_PROBE_BUFFER_IMM>;
def S_ATC_PROBE_BUFFER_SGPR_sem : InstSISemantic<S_ATC_PROBE_BUFFER_SGPR>;
def S_ATC_PROBE_BUFFER_SGPR_IMM_sem : InstSISemantic<S_ATC_PROBE_BUFFER_SGPR_IMM>;
def S_ATC_PROBE_BUFFER_SGPR_OPT_IMM_sem : InstSISemantic<S_ATC_PROBE_BUFFER_SGPR_OPT_IMM>;
def S_ATC_PROBE_IMM_sem : InstSISemantic<S_ATC_PROBE_IMM>;
def S_ATC_PROBE_SGPR_sem : InstSISemantic<S_ATC_PROBE_SGPR>;
def S_ATC_PROBE_SGPR_IMM_sem : InstSISemantic<S_ATC_PROBE_SGPR_IMM>;
def S_ATC_PROBE_SGPR_OPT_IMM_sem : InstSISemantic<S_ATC_PROBE_SGPR_OPT_IMM>;
def S_DCACHE_DISCARD_IMM_sem : InstSISemantic<S_DCACHE_DISCARD_IMM>;
def S_DCACHE_DISCARD_SGPR_sem : InstSISemantic<S_DCACHE_DISCARD_SGPR>;
def S_DCACHE_DISCARD_SGPR_IMM_sem : InstSISemantic<S_DCACHE_DISCARD_SGPR_IMM>;
def S_DCACHE_DISCARD_X2_IMM_sem : InstSISemantic<S_DCACHE_DISCARD_X2_IMM>;
def S_DCACHE_DISCARD_X2_SGPR_sem : InstSISemantic<S_DCACHE_DISCARD_X2_SGPR>;
def S_DCACHE_DISCARD_X2_SGPR_IMM_sem : InstSISemantic<S_DCACHE_DISCARD_X2_SGPR_IMM>;
def S_PREFETCH_INST_sem : InstSISemantic<S_PREFETCH_INST>;
def S_PREFETCH_INST_PC_REL_sem : InstSISemantic<S_PREFETCH_INST_PC_REL>;

