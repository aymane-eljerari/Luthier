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
// MTBUF Instructions — Typed Buffer Load/Store (TBUFFER)
//
// These instructions perform typed buffer (TBUFFER) memory operations with a
// hardware data format conversion specified by the $format field. Because the
// format conversion is performed in hardware and cannot be expressed in the
// current semantic DSL, all entries use empty semantics [].
//------------------------------------------------------------------------------

//==============================================================================
// MTBUF — Typed Buffer Load/Store semantics (Phase 13)
// Auto-generated from records.txt operand info; maps each opcode to either
// int_amdgcn_struct_tbuffer_load or int_amdgcn_struct_tbuffer_store with the
// appropriate result/operand types per addressing-mode + width.
//==============================================================================

def TBUFFER_LOAD_FORMAT_D16_XYZW_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_tbuffer_load,
        [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)]))
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_ADDR64_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_ADDR64> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_IDXEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_IDXEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_OFFEN_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_OFFEN_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_OFFSET_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}

def TBUFFER_STORE_FORMAT_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<TBUFFER_STORE_FORMAT_X_VBUFFER_OFFSET_exact> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_tbuffer_store,
      [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $format), (GetNamedOperand $cpol)])
  ];
}
