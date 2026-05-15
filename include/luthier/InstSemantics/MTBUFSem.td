//===- MTBUFSem.td ---------------------------------------------*- tblgen -*-===//
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
// MTBUF Instructions - Typed Buffer Load/Store (TBUFFER)
//
// Maps each typed-buffer pseudo to int_amdgcn_struct_tbuffer_{load,store} with
// the appropriate vdata type per width:
//   X/XY/XYZ/XYZW       -> float / v2f32 / v3f32 / v4f32
//   D16_{X,XY,XYZ,XYZW} -> half  / v2f16 / v3f16 / v4f16
//
// All addressing modes (ADDR64, BOTHEN, IDXEN, OFFEN, OFFSET, _VBUFFER_*,
// _gfx80_*, _exact) share the same shape and are grouped via foreach. The
// OFFSET family has no $vaddr and passes vindex = 0; all other modes pass
// $vaddr as the struct vindex (same modeling convention as MUBUFSem.td -
// symbolic approximation of the addressing computation).
//
// $swz is not forwarded (folded into cpol bit 3 by SIMemoryLegalizer).
//------------------------------------------------------------------------------

// ---- TBUFFER_LOAD_FORMAT_X (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_X_ADDR64,
    TBUFFER_LOAD_FORMAT_X_BOTHEN,
    TBUFFER_LOAD_FORMAT_X_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_X_IDXEN,
    TBUFFER_LOAD_FORMAT_X_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_X_OFFEN,
    TBUFFER_LOAD_FORMAT_X_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_X (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_X_OFFSET,
    TBUFFER_LOAD_FORMAT_X_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_X (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_X_ADDR64,
    TBUFFER_STORE_FORMAT_X_BOTHEN,
    TBUFFER_STORE_FORMAT_X_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_X_IDXEN,
    TBUFFER_STORE_FORMAT_X_IDXEN_exact,
    TBUFFER_STORE_FORMAT_X_OFFEN,
    TBUFFER_STORE_FORMAT_X_OFFEN_exact,
    TBUFFER_STORE_FORMAT_X_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_X_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_X_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_X_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_X_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_X (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_X_OFFSET,
    TBUFFER_STORE_FORMAT_X_OFFSET_exact,
    TBUFFER_STORE_FORMAT_X_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_X_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_X (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_X_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_X_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_X_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_X_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_X_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_X (D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_X_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_X_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_X (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_X_ADDR64,
    TBUFFER_STORE_FORMAT_D16_X_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_X_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_IDXEN,
    TBUFFER_STORE_FORMAT_D16_X_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_OFFEN,
    TBUFFER_STORE_FORMAT_D16_X_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_ADDR64,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_X (D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_X_OFFSET,
    TBUFFER_STORE_FORMAT_D16_X_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_XY (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_XY_ADDR64,
    TBUFFER_LOAD_FORMAT_XY_BOTHEN,
    TBUFFER_LOAD_FORMAT_XY_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_XY_IDXEN,
    TBUFFER_LOAD_FORMAT_XY_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_XY_OFFEN,
    TBUFFER_LOAD_FORMAT_XY_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_XY (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_XY_OFFSET,
    TBUFFER_LOAD_FORMAT_XY_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_XY (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_XY_ADDR64,
    TBUFFER_STORE_FORMAT_XY_BOTHEN,
    TBUFFER_STORE_FORMAT_XY_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_XY_IDXEN,
    TBUFFER_STORE_FORMAT_XY_IDXEN_exact,
    TBUFFER_STORE_FORMAT_XY_OFFEN,
    TBUFFER_STORE_FORMAT_XY_OFFEN_exact,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_XY (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_XY_OFFSET,
    TBUFFER_STORE_FORMAT_XY_OFFSET_exact,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_XY (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_XY_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XY_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XY_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XY_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XY_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_XY (D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_XY_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XY_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_XY (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_XY_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XY_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XY_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XY_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XY_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_XY (D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_XY_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XY_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_XYZ (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_XYZ_ADDR64,
    TBUFFER_LOAD_FORMAT_XYZ_BOTHEN,
    TBUFFER_LOAD_FORMAT_XYZ_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_XYZ_IDXEN,
    TBUFFER_LOAD_FORMAT_XYZ_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_XYZ_OFFEN,
    TBUFFER_LOAD_FORMAT_XYZ_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_XYZ (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_XYZ_OFFSET,
    TBUFFER_LOAD_FORMAT_XYZ_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_XYZ (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_XYZ_ADDR64,
    TBUFFER_STORE_FORMAT_XYZ_BOTHEN,
    TBUFFER_STORE_FORMAT_XYZ_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_XYZ_IDXEN,
    TBUFFER_STORE_FORMAT_XYZ_IDXEN_exact,
    TBUFFER_STORE_FORMAT_XYZ_OFFEN,
    TBUFFER_STORE_FORMAT_XYZ_OFFEN_exact,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_XYZ (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_XYZ_OFFSET,
    TBUFFER_STORE_FORMAT_XYZ_OFFSET_exact,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_XYZ (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_XYZ_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_XYZ (D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_XYZ_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_XYZ (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_XYZ_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZ_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_XYZ (D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_XYZ_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZ_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_XYZW (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_XYZW_ADDR64,
    TBUFFER_LOAD_FORMAT_XYZW_BOTHEN,
    TBUFFER_LOAD_FORMAT_XYZW_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_XYZW_IDXEN,
    TBUFFER_LOAD_FORMAT_XYZW_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_XYZW_OFFEN,
    TBUFFER_LOAD_FORMAT_XYZW_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_XYZW (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_XYZW_OFFSET,
    TBUFFER_LOAD_FORMAT_XYZW_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_XYZW (non-D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_XYZW_ADDR64,
    TBUFFER_STORE_FORMAT_XYZW_BOTHEN,
    TBUFFER_STORE_FORMAT_XYZW_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_XYZW_IDXEN,
    TBUFFER_STORE_FORMAT_XYZW_IDXEN_exact,
    TBUFFER_STORE_FORMAT_XYZW_OFFEN,
    TBUFFER_STORE_FORMAT_XYZW_OFFEN_exact,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_XYZW (non-D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_XYZW_OFFSET,
    TBUFFER_STORE_FORMAT_XYZW_OFFSET_exact,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_XYZW (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_XYZW_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_LOAD_FORMAT_D16_XYZW (D16, offset-form) ----

foreach inst = [
    TBUFFER_LOAD_FORMAT_D16_XYZW_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_exact,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET,
    TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_XYZW (D16, vaddr-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_XYZW_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZW_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}

// ---- TBUFFER_STORE_FORMAT_D16_XYZW (D16, offset-form) ----

foreach inst = [
    TBUFFER_STORE_FORMAT_D16_XYZW_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZW_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_exact,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET,
    TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
    ];
  }
}
