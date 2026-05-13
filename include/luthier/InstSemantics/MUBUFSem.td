//===- MUBUFSem.td ---------------------------------------------*- tblgen -*-===//
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
// MUBUF Instructions - Buffer Load/Store (opcodes 0-39)
//------------------------------------------------------------------------------
//
// Sources:
//   southern-islands-instruction-set-architecture.pdf, pages 238-240.
//   sea-islands-instruction-set-architecture_0.pdf, pages 247-249.
//   gcn3-instruction-set-architecture.pdf, Ch.8 (Vector Memory Buffer Instructions) & Sec 12.14 (MUBUF Instructions).
//   vega-shader-instruction-set-architecture.pdf, Sec 8.1 (p.50-62) & Sec 12.14 (MUBUF Instructions, p.198+).
//   vega-7nm-shader-instruction-set-architecture.pdf, Sec 8.1 (p.51-63) & Sec 12.14 (MUBUF Instructions, p.200+).
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, Sec 9.1 (p.55-67) & Sec 12.14 (MUBUF Instructions, p.188+).
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, Sec 9.1 (p.55-67) & Sec 12.13 (MUBUF Instructions, p.182+).
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, Sec 9.1 (p.63-72) & Sec 12.13 (MUBUF Instructions, p.450+).
//   amd-instinct-cdna4-instruction-set-architecture.pdf, Sec 9.1 (p.74-83) & Sec 12.13 (MUBUF Instructions, p.495+).
//   rdna-shader-instruction-set-architecture.pdf, Sec 8.1 (p.56-67) & Sec 12.14 (MUBUF Instructions, p.216+).
//   rdna2-shader-instruction-set-architecture.pdf, Sec 8.1 (p.55-66) & Sec 12.14 (MUBUF Instructions, p.209+).
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, Ch.9 (p.80-107) & Sec 16.16 (MUBUF Instructions, p.538+).
//   rdna4-instruction-set-architecture.pdf, Ch.9 (p.102-129) & Sec 16.16 (VBUFFER Instructions, p.616+).

def BUFFER_LOAD_SBYTE_D16_HI_OFFSET_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_OFFSET> {
  let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $hi16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $hi16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
  ];
}

def BUFFER_STORE_SHORT_D16_HI_OFFSET_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_OFFSET> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

//------------------------------------------------------------------------------
// MUBUF Instructions - Buffer Atomic Operations (opcodes 51-77)
//------------------------------------------------------------------------------
//
// Sources:
//   southern-islands-instruction-set-architecture.pdf, pages 238-240.
//   sea-islands-instruction-set-architecture_0.pdf, pages 247-249.
//   gcn3-instruction-set-architecture.pdf, Ch.8 (Vector Memory Buffer Instructions) & Sec 12.14 (MUBUF Instructions).
//   vega-shader-instruction-set-architecture.pdf, Sec 8.1 (p.50-62) & Sec 12.14 (MUBUF Instructions, p.198+).
//   vega-7nm-shader-instruction-set-architecture.pdf, Sec 8.1 (p.51-63) & Sec 12.14 (MUBUF Instructions, p.200+).
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, Sec 9.1 (p.55-67) & Sec 12.14 (MUBUF Instructions, p.188+).
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, Sec 9.1 (p.55-67) & Sec 12.13 (MUBUF Instructions, p.182+).
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, Sec 9.1 (p.63-72) & Sec 12.13 (MUBUF Instructions, p.450+).
//   amd-instinct-cdna4-instruction-set-architecture.pdf, Sec 9.1 (p.74-83) & Sec 12.13 (MUBUF Instructions, p.495+).
//   rdna-shader-instruction-set-architecture.pdf, Sec 8.1 (p.56-67) & Sec 12.14 (MUBUF Instructions, p.216+).
//   rdna2-shader-instruction-set-architecture.pdf, Sec 8.1 (p.55-66) & Sec 12.14 (MUBUF Instructions, p.209+).
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, Ch.9 (p.80-107) & Sec 16.16 (MUBUF Instructions, p.538+).
//   rdna4-instruction-set-architecture.pdf, Ch.9 (p.102-129) & Sec 16.16 (VBUFFER Instructions, p.616+).

//------------------------------------------------------------------------------
// TBUFFER Instructions (opcodes 128+)
//------------------------------------------------------------------------------
//
// Sources:
//   southern-islands-instruction-set-architecture.pdf, pages 241-242.
//   sea-islands-instruction-set-architecture_0.pdf, pages 250-251.
//   gcn3-instruction-set-architecture.pdf, Ch.8 & Sec 12.15 (MTBUF Instructions).
//   vega-shader-instruction-set-architecture.pdf, Sec 8.1 & Sec 12.15 (MTBUF Instructions).
//   vega-7nm-shader-instruction-set-architecture.pdf, Sec 8.1 & Sec 12.15 (MTBUF Instructions).
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, Sec 9.1 & Sec 12.15 (MTBUF Instructions).
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, Sec 9.1 & Sec 12.14 (MTBUF Instructions).
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, Sec 9.1 & Sec 12.14 (MTBUF Instructions).
//   amd-instinct-cdna4-instruction-set-architecture.pdf, Sec 9.1 & Sec 12.14 (MTBUF Instructions).
//   rdna-shader-instruction-set-architecture.pdf, Sec 8.1 & Sec 12.15 (MTBUF Instructions).
//   rdna2-shader-instruction-set-architecture.pdf, Sec 8.1 & Sec 12.15 (MTBUF Instructions).
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, Ch.9 & Sec 16.17 (MTBUF Instructions).
//   rdna4-instruction-set-architecture.pdf, Ch.9 & Sec 16.17 (MTBUF Instructions).

//==============================================================================
// Address mode, RTN, TFE, LDS, and legacy naming variants
// (empty semantics -- same core operation as base instruction)
//==============================================================================
//
// Sources:
//   southern-islands-instruction-set-architecture.pdf, pages 238-240.
//   sea-islands-instruction-set-architecture_0.pdf, pages 247-249.
//   gcn3-instruction-set-architecture.pdf, Ch.8 (Vector Memory Buffer Instructions) & Sec 12.14 (MUBUF Instructions).
//   vega-shader-instruction-set-architecture.pdf, Sec 8.1 (p.50-62) & Sec 12.14 (MUBUF Instructions, p.198+).
//   vega-7nm-shader-instruction-set-architecture.pdf, Sec 8.1 (p.51-63) & Sec 12.14 (MUBUF Instructions, p.200+).
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, Sec 9.1 (p.55-67) & Sec 12.14 (MUBUF Instructions, p.188+).
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, Sec 9.1 (p.55-67) & Sec 12.13 (MUBUF Instructions, p.182+).
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, Sec 9.1 (p.63-72) & Sec 12.13 (MUBUF Instructions, p.450+).
//   amd-instinct-cdna4-instruction-set-architecture.pdf, Sec 9.1 (p.74-83) & Sec 12.13 (MUBUF Instructions, p.495+).
//   rdna-shader-instruction-set-architecture.pdf, Sec 8.1 (p.56-67) & Sec 12.14 (MUBUF Instructions, p.216+).
//   rdna2-shader-instruction-set-architecture.pdf, Sec 8.1 (p.55-66) & Sec 12.14 (MUBUF Instructions, p.209+).
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, Ch.9 (p.80-107) & Sec 16.16 (MUBUF Instructions, p.538+).
//   rdna4-instruction-set-architecture.pdf, Ch.9 (p.102-129) & Sec 16.16 (VBUFFER Instructions, p.616+).

// Buffer Load Format address mode / TFE / LDS variants -- same semantics as base.

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_HI_X_ADDR64,
    BUFFER_LOAD_FORMAT_D16_HI_X_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_IDXEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_OFFEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $fval,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $ival, (LLVMBitCast (GetVal $fval), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $ival), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_HI_X_OFFSET,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $fval,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $ival, (LLVMBitCast (GetVal $fval), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $ival), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_XYZW_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_XYZW_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_XYZ_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_XYZ_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_XY_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XY_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XY_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XY_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_XY_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_X_ADDR64,
    BUFFER_LOAD_FORMAT_D16_X_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_X_IDXEN,
    BUFFER_LOAD_FORMAT_D16_X_OFFEN,
    BUFFER_LOAD_FORMAT_D16_X_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_D16_X_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_X_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_D16_X_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_D16_X_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_D16_X_OFFSET,
    BUFFER_LOAD_FORMAT_D16_X_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_XYZW_ADDR64,
    BUFFER_LOAD_FORMAT_XYZW_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZW_IDXEN,
    BUFFER_LOAD_FORMAT_XYZW_OFFEN,
    BUFFER_LOAD_FORMAT_XYZW_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_XYZW_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZW_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_XYZW_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_XYZW_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_XYZW_OFFSET,
    BUFFER_LOAD_FORMAT_XYZW_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_XYZ_ADDR64,
    BUFFER_LOAD_FORMAT_XYZ_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZ_IDXEN,
    BUFFER_LOAD_FORMAT_XYZ_OFFEN,
    BUFFER_LOAD_FORMAT_XYZ_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_XYZ_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZ_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_XYZ_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_XYZ_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_XYZ_OFFSET,
    BUFFER_LOAD_FORMAT_XYZ_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_XY_ADDR64,
    BUFFER_LOAD_FORMAT_XY_BOTHEN,
    BUFFER_LOAD_FORMAT_XY_IDXEN,
    BUFFER_LOAD_FORMAT_XY_OFFEN,
    BUFFER_LOAD_FORMAT_XY_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_XY_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_XY_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_XY_TFE_OFFEN,
    BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_XY_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_XY_OFFSET,
    BUFFER_LOAD_FORMAT_XY_TFE_OFFSET,
    BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_X_ADDR64,
    BUFFER_LOAD_FORMAT_X_BOTHEN,
    BUFFER_LOAD_FORMAT_X_IDXEN,
    BUFFER_LOAD_FORMAT_X_LDS_ADDR64,
    BUFFER_LOAD_FORMAT_X_LDS_BOTHEN,
    BUFFER_LOAD_FORMAT_X_LDS_IDXEN,
    BUFFER_LOAD_FORMAT_X_LDS_OFFEN,
    BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_X_OFFEN,
    BUFFER_LOAD_FORMAT_X_TFE_ADDR64,
    BUFFER_LOAD_FORMAT_X_TFE_BOTHEN,
    BUFFER_LOAD_FORMAT_X_TFE_IDXEN,
    BUFFER_LOAD_FORMAT_X_TFE_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_X_LDS_OFFSET,
    BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_X_OFFSET,
    BUFFER_LOAD_FORMAT_X_TFE_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_FORMAT_X_VBUFFER_ADDR64,
    BUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN,
    BUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN,
    BUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

// Buffer Store Format address mode / TFE variants -- same semantics as base.

foreach inst = [
    BUFFER_STORE_FORMAT_D16_HI_X_ADDR64,
    BUFFER_STORE_FORMAT_D16_HI_X_BOTHEN,
    BUFFER_STORE_FORMAT_D16_HI_X_IDXEN,
    BUFFER_STORE_FORMAT_D16_HI_X_OFFEN,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_ADDR64,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_IDXEN,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFEN,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $shifted, (LLVMLShr (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 16))),
    (DefVal $half, (LLVMTrunc (GetVal $shifted), si_llvm_i16_ty)),
    (DefVal $fval, (LLVMBitCast (GetVal $half), si_llvm_half_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal $fval), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_HI_X_OFFSET,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFSET,
    BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $shifted, (LLVMLShr (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 16))),
    (DefVal $half, (LLVMTrunc (GetVal $shifted), si_llvm_i16_ty)),
    (DefVal $fval, (LLVMBitCast (GetVal $half), si_llvm_half_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal $fval), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_XYZW_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZW_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZW_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZW_OFFEN,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFEN,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_XYZW_OFFSET,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFSET,
    BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_XYZ_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZ_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZ_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZ_OFFEN,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFEN,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_XYZ_OFFSET,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFSET,
    BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_XY_ADDR64,
    BUFFER_STORE_FORMAT_D16_XY_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XY_IDXEN,
    BUFFER_STORE_FORMAT_D16_XY_OFFEN,
    BUFFER_STORE_FORMAT_D16_XY_TFE_ADDR64,
    BUFFER_STORE_FORMAT_D16_XY_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XY_TFE_IDXEN,
    BUFFER_STORE_FORMAT_D16_XY_TFE_OFFEN,
    BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_D16_XY_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_XY_OFFSET,
    BUFFER_STORE_FORMAT_D16_XY_TFE_OFFSET,
    BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_X_ADDR64,
    BUFFER_STORE_FORMAT_D16_X_BOTHEN,
    BUFFER_STORE_FORMAT_D16_X_IDXEN,
    BUFFER_STORE_FORMAT_D16_X_OFFEN,
    BUFFER_STORE_FORMAT_D16_X_TFE_ADDR64,
    BUFFER_STORE_FORMAT_D16_X_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_D16_X_TFE_IDXEN,
    BUFFER_STORE_FORMAT_D16_X_TFE_OFFEN,
    BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_D16_X_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_D16_X_OFFSET,
    BUFFER_STORE_FORMAT_D16_X_TFE_OFFSET,
    BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_XYZW_ADDR64,
    BUFFER_STORE_FORMAT_XYZW_BOTHEN,
    BUFFER_STORE_FORMAT_XYZW_IDXEN,
    BUFFER_STORE_FORMAT_XYZW_OFFEN,
    BUFFER_STORE_FORMAT_XYZW_TFE_ADDR64,
    BUFFER_STORE_FORMAT_XYZW_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_XYZW_TFE_IDXEN,
    BUFFER_STORE_FORMAT_XYZW_TFE_OFFEN,
    BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_XYZW_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_XYZW_OFFSET,
    BUFFER_STORE_FORMAT_XYZW_TFE_OFFSET,
    BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_XYZ_ADDR64,
    BUFFER_STORE_FORMAT_XYZ_BOTHEN,
    BUFFER_STORE_FORMAT_XYZ_IDXEN,
    BUFFER_STORE_FORMAT_XYZ_OFFEN,
    BUFFER_STORE_FORMAT_XYZ_TFE_ADDR64,
    BUFFER_STORE_FORMAT_XYZ_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_XYZ_TFE_IDXEN,
    BUFFER_STORE_FORMAT_XYZ_TFE_OFFEN,
    BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_XYZ_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_XYZ_OFFSET,
    BUFFER_STORE_FORMAT_XYZ_TFE_OFFSET,
    BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_XY_ADDR64,
    BUFFER_STORE_FORMAT_XY_BOTHEN,
    BUFFER_STORE_FORMAT_XY_IDXEN,
    BUFFER_STORE_FORMAT_XY_OFFEN,
    BUFFER_STORE_FORMAT_XY_TFE_ADDR64,
    BUFFER_STORE_FORMAT_XY_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_XY_TFE_IDXEN,
    BUFFER_STORE_FORMAT_XY_TFE_OFFEN,
    BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_XY_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_XY_OFFSET,
    BUFFER_STORE_FORMAT_XY_TFE_OFFSET,
    BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_X_ADDR64,
    BUFFER_STORE_FORMAT_X_BOTHEN,
    BUFFER_STORE_FORMAT_X_IDXEN,
    BUFFER_STORE_FORMAT_X_OFFEN,
    BUFFER_STORE_FORMAT_X_TFE_ADDR64,
    BUFFER_STORE_FORMAT_X_TFE_BOTHEN,
    BUFFER_STORE_FORMAT_X_TFE_IDXEN,
    BUFFER_STORE_FORMAT_X_TFE_OFFEN,
    BUFFER_STORE_FORMAT_X_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_X_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_X_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_FORMAT_X_VBUFFER_ADDR64,
    BUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN,
    BUFFER_STORE_FORMAT_X_VBUFFER_IDXEN,
    BUFFER_STORE_FORMAT_X_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_FORMAT_X_OFFSET,
    BUFFER_STORE_FORMAT_X_TFE_OFFSET,
    BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_FORMAT_X_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

// Buffer Load address mode / TFE / LDS / legacy naming variants -- same semantics as base.

foreach inst = [
    BUFFER_LOAD_DWORDX2_ADDR64,
    BUFFER_LOAD_DWORDX2_BOTHEN,
    BUFFER_LOAD_DWORDX2_IDXEN,
    BUFFER_LOAD_DWORDX2_OFFEN,
    BUFFER_LOAD_DWORDX2_TFE_ADDR64,
    BUFFER_LOAD_DWORDX2_TFE_BOTHEN,
    BUFFER_LOAD_DWORDX2_TFE_IDXEN,
    BUFFER_LOAD_DWORDX2_TFE_OFFEN,
    BUFFER_LOAD_DWORDX2_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORDX2_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORDX2_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_DWORDX2_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORDX2_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORDX2_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORDX2_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORDX2_OFFSET,
    BUFFER_LOAD_DWORDX2_TFE_OFFSET,
    BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_DWORDX2_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORDX3_ADDR64,
    BUFFER_LOAD_DWORDX3_BOTHEN,
    BUFFER_LOAD_DWORDX3_IDXEN,
    BUFFER_LOAD_DWORDX3_OFFEN,
    BUFFER_LOAD_DWORDX3_TFE_ADDR64,
    BUFFER_LOAD_DWORDX3_TFE_BOTHEN,
    BUFFER_LOAD_DWORDX3_TFE_IDXEN,
    BUFFER_LOAD_DWORDX3_TFE_OFFEN,
    BUFFER_LOAD_DWORDX3_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORDX3_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORDX3_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_DWORDX3_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORDX3_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORDX3_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORDX3_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORDX3_OFFSET,
    BUFFER_LOAD_DWORDX3_TFE_OFFSET,
    BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_DWORDX3_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORDX4_ADDR64,
    BUFFER_LOAD_DWORDX4_BOTHEN,
    BUFFER_LOAD_DWORDX4_IDXEN,
    BUFFER_LOAD_DWORDX4_OFFEN,
    BUFFER_LOAD_DWORDX4_TFE_ADDR64,
    BUFFER_LOAD_DWORDX4_TFE_BOTHEN,
    BUFFER_LOAD_DWORDX4_TFE_IDXEN,
    BUFFER_LOAD_DWORDX4_TFE_OFFEN,
    BUFFER_LOAD_DWORDX4_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORDX4_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORDX4_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_DWORDX4_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORDX4_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORDX4_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORDX4_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORDX4_OFFSET,
    BUFFER_LOAD_DWORDX4_TFE_OFFSET,
    BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_DWORDX4_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORD_ADDR64,
    BUFFER_LOAD_DWORD_BOTHEN,
    BUFFER_LOAD_DWORD_IDXEN,
    BUFFER_LOAD_DWORD_LDS_ADDR64,
    BUFFER_LOAD_DWORD_LDS_BOTHEN,
    BUFFER_LOAD_DWORD_LDS_IDXEN,
    BUFFER_LOAD_DWORD_LDS_OFFEN,
    BUFFER_LOAD_DWORD_LDS_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORD_LDS_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORD_LDS_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFEN,
    BUFFER_LOAD_DWORD_OFFEN,
    BUFFER_LOAD_DWORD_TFE_ADDR64,
    BUFFER_LOAD_DWORD_TFE_BOTHEN,
    BUFFER_LOAD_DWORD_TFE_IDXEN,
    BUFFER_LOAD_DWORD_TFE_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORD_LDS_OFFSET,
    BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFSET,
    BUFFER_LOAD_DWORD_OFFSET,
    BUFFER_LOAD_DWORD_TFE_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORD_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORD_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORD_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_DWORD_VBUFFER_ADDR64,
    BUFFER_LOAD_DWORD_VBUFFER_BOTHEN,
    BUFFER_LOAD_DWORD_VBUFFER_IDXEN,
    BUFFER_LOAD_DWORD_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_DWORD_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

def BUFFER_LOAD_SBYTE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_D16_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_D16_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_D16_HI_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_ADDR64> {
  let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
  ];
}

def BUFFER_LOAD_SBYTE_D16_HI_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_BOTHEN> {
  let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
  ];
}

def BUFFER_LOAD_SBYTE_D16_HI_IDXEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_IDXEN> {
  let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
  ];
}

def BUFFER_LOAD_SBYTE_D16_HI_OFFEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_OFFEN> {
  let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
  ];
}

def BUFFER_LOAD_SBYTE_D16_HI_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_ADDR64> {
  let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
  ];
}

foreach inst = [
    BUFFER_LOAD_SBYTE_D16_HI_TFE_BOTHEN,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_IDXEN,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFEN,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_ADDR64,
    BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_BOTHEN,
    BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_IDXEN,
    BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFEN,
    BUFFER_LOAD_SBYTE_D16_IDXEN,
    BUFFER_LOAD_SBYTE_D16_OFFEN,
    BUFFER_LOAD_SBYTE_D16_TFE_ADDR64,
    BUFFER_LOAD_SBYTE_D16_TFE_BOTHEN,
    BUFFER_LOAD_SBYTE_D16_TFE_IDXEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFSET,
    BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFSET,
    BUFFER_LOAD_SBYTE_D16_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $sext16, (LLVMSExt (GetVal $tmp), si_llvm_i16_ty)),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $sext16), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SBYTE_D16_TFE_OFFEN,
    BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_SBYTE_D16_VBUFFER_ADDR64,
    BUFFER_LOAD_SBYTE_D16_VBUFFER_BOTHEN,
    BUFFER_LOAD_SBYTE_D16_VBUFFER_IDXEN,
    BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFEN,
    BUFFER_LOAD_SBYTE_IDXEN,
    BUFFER_LOAD_SBYTE_LDS_ADDR64,
    BUFFER_LOAD_SBYTE_LDS_BOTHEN,
    BUFFER_LOAD_SBYTE_LDS_IDXEN,
    BUFFER_LOAD_SBYTE_LDS_OFFEN,
    BUFFER_LOAD_SBYTE_LDS_VBUFFER_ADDR64,
    BUFFER_LOAD_SBYTE_LDS_VBUFFER_BOTHEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SBYTE_D16_TFE_OFFSET,
    BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFSET,
    BUFFER_LOAD_SBYTE_LDS_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

def BUFFER_LOAD_SBYTE_LDS_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_LOAD_SBYTE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_SBYTE_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_IDXEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_SBYTE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

foreach inst = [
    BUFFER_LOAD_SHORT_D16_ADDR64,
    BUFFER_LOAD_SHORT_D16_BOTHEN,
    BUFFER_LOAD_SHORT_D16_HI_ADDR64,
    BUFFER_LOAD_SHORT_D16_HI_BOTHEN,
    BUFFER_LOAD_SHORT_D16_HI_IDXEN,
    BUFFER_LOAD_SHORT_D16_HI_OFFEN,
    BUFFER_LOAD_SHORT_D16_HI_TFE_ADDR64,
    BUFFER_LOAD_SHORT_D16_HI_TFE_BOTHEN,
    BUFFER_LOAD_SHORT_D16_HI_TFE_IDXEN,
    BUFFER_LOAD_SHORT_D16_HI_TFE_OFFEN,
    BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_SHORT_D16_HI_VBUFFER_ADDR64,
    BUFFER_LOAD_SHORT_D16_HI_VBUFFER_BOTHEN,
    BUFFER_LOAD_SHORT_D16_HI_VBUFFER_IDXEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SHORT_D16_HI_OFFSET,
    BUFFER_LOAD_SHORT_D16_HI_TFE_OFFSET,
    BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFEN,
    BUFFER_LOAD_SHORT_D16_IDXEN,
    BUFFER_LOAD_SHORT_D16_OFFEN,
    BUFFER_LOAD_SHORT_D16_TFE_ADDR64,
    BUFFER_LOAD_SHORT_D16_TFE_BOTHEN,
    BUFFER_LOAD_SHORT_D16_TFE_IDXEN,
    BUFFER_LOAD_SHORT_D16_TFE_OFFEN,
    BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_SHORT_D16_VBUFFER_ADDR64,
    BUFFER_LOAD_SHORT_D16_VBUFFER_BOTHEN,
    BUFFER_LOAD_SHORT_D16_VBUFFER_IDXEN,
    BUFFER_LOAD_SHORT_D16_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $tmp), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFSET,
    BUFFER_LOAD_SHORT_D16_OFFSET,
    BUFFER_LOAD_SHORT_D16_TFE_OFFSET,
    BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_SHORT_D16_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $tmp), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SSHORT_ADDR64,
    BUFFER_LOAD_SSHORT_BOTHEN,
    BUFFER_LOAD_SSHORT_IDXEN,
    BUFFER_LOAD_SSHORT_LDS_ADDR64,
    BUFFER_LOAD_SSHORT_LDS_BOTHEN,
    BUFFER_LOAD_SSHORT_LDS_IDXEN,
    BUFFER_LOAD_SSHORT_LDS_OFFEN,
    BUFFER_LOAD_SSHORT_LDS_VBUFFER_ADDR64,
    BUFFER_LOAD_SSHORT_LDS_VBUFFER_BOTHEN,
    BUFFER_LOAD_SSHORT_LDS_VBUFFER_IDXEN,
    BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFEN,
    BUFFER_LOAD_SSHORT_OFFEN,
    BUFFER_LOAD_SSHORT_TFE_ADDR64,
    BUFFER_LOAD_SSHORT_TFE_BOTHEN,
    BUFFER_LOAD_SSHORT_TFE_IDXEN,
    BUFFER_LOAD_SSHORT_TFE_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SSHORT_LDS_OFFSET,
    BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFSET,
    BUFFER_LOAD_SSHORT_OFFSET,
    BUFFER_LOAD_SSHORT_TFE_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SSHORT_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_SSHORT_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_SSHORT_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_SSHORT_VBUFFER_ADDR64,
    BUFFER_LOAD_SSHORT_VBUFFER_BOTHEN,
    BUFFER_LOAD_SSHORT_VBUFFER_IDXEN,
    BUFFER_LOAD_SSHORT_VBUFFER_OFFEN,
    BUFFER_LOAD_UBYTE_ADDR64,
    BUFFER_LOAD_UBYTE_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_ADDR64,
    BUFFER_LOAD_UBYTE_D16_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_HI_ADDR64,
    BUFFER_LOAD_UBYTE_D16_HI_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_HI_IDXEN,
    BUFFER_LOAD_UBYTE_D16_HI_OFFEN,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_ADDR64
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_SSHORT_VBUFFER_OFFSET,
    BUFFER_LOAD_UBYTE_D16_HI_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_UBYTE_D16_HI_TFE_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_IDXEN,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFEN,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_ADDR64,
    BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_IDXEN,
    BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFEN,
    BUFFER_LOAD_UBYTE_D16_IDXEN,
    BUFFER_LOAD_UBYTE_D16_OFFEN,
    BUFFER_LOAD_UBYTE_D16_TFE_ADDR64,
    BUFFER_LOAD_UBYTE_D16_TFE_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_TFE_IDXEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $tmp), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFSET,
    BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFSET,
    BUFFER_LOAD_UBYTE_D16_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])),
    (DefVal $vdata_hi, (LLVMShl (LLVMZExt (GetVal $tmp), si_llvm_i32_ty), 16)),
    (DefVal $vdata_lo, (LLVMAnd (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0xFFFF))),
    (SetNamedOperand $vdata, (LLVMOr (GetVal $vdata_hi), (GetVal $vdata_lo)))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_UBYTE_D16_TFE_OFFEN,
    BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_UBYTE_D16_VBUFFER_ADDR64,
    BUFFER_LOAD_UBYTE_D16_VBUFFER_BOTHEN,
    BUFFER_LOAD_UBYTE_D16_VBUFFER_IDXEN,
    BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFEN,
    BUFFER_LOAD_UBYTE_IDXEN,
    BUFFER_LOAD_UBYTE_LDS_ADDR64,
    BUFFER_LOAD_UBYTE_LDS_BOTHEN,
    BUFFER_LOAD_UBYTE_LDS_IDXEN,
    BUFFER_LOAD_UBYTE_LDS_OFFEN,
    BUFFER_LOAD_UBYTE_LDS_VBUFFER_ADDR64,
    BUFFER_LOAD_UBYTE_LDS_VBUFFER_BOTHEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_UBYTE_D16_TFE_OFFSET,
    BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFSET,
    BUFFER_LOAD_UBYTE_LDS_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

def BUFFER_LOAD_UBYTE_LDS_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_IDXEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFEN> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFSET> {
  let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_LOAD_UBYTE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_UBYTE_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_IDXEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_ADDR64> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_BOTHEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_IDXEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_OFFEN> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

def BUFFER_LOAD_UBYTE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_OFFSET> {
  let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
  ];
}

foreach inst = [
    BUFFER_LOAD_USHORT_ADDR64,
    BUFFER_LOAD_USHORT_BOTHEN,
    BUFFER_LOAD_USHORT_IDXEN,
    BUFFER_LOAD_USHORT_LDS_ADDR64,
    BUFFER_LOAD_USHORT_LDS_BOTHEN,
    BUFFER_LOAD_USHORT_LDS_IDXEN,
    BUFFER_LOAD_USHORT_LDS_OFFEN,
    BUFFER_LOAD_USHORT_LDS_VBUFFER_ADDR64,
    BUFFER_LOAD_USHORT_LDS_VBUFFER_BOTHEN,
    BUFFER_LOAD_USHORT_LDS_VBUFFER_IDXEN,
    BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFEN,
    BUFFER_LOAD_USHORT_OFFEN,
    BUFFER_LOAD_USHORT_TFE_ADDR64,
    BUFFER_LOAD_USHORT_TFE_BOTHEN,
    BUFFER_LOAD_USHORT_TFE_IDXEN,
    BUFFER_LOAD_USHORT_TFE_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_USHORT_LDS_OFFSET,
    BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFSET,
    BUFFER_LOAD_USHORT_OFFSET,
    BUFFER_LOAD_USHORT_TFE_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_USHORT_TFE_VBUFFER_ADDR64,
    BUFFER_LOAD_USHORT_TFE_VBUFFER_BOTHEN,
    BUFFER_LOAD_USHORT_TFE_VBUFFER_IDXEN,
    BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFEN,
    BUFFER_LOAD_USHORT_VBUFFER_ADDR64,
    BUFFER_LOAD_USHORT_VBUFFER_BOTHEN,
    BUFFER_LOAD_USHORT_VBUFFER_IDXEN,
    BUFFER_LOAD_USHORT_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFSET,
    BUFFER_LOAD_USHORT_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

// Buffer Store address mode / TFE / legacy naming variants -- same semantics as base.

foreach inst = [
    BUFFER_STORE_BYTE_ADDR64,
    BUFFER_STORE_BYTE_BOTHEN,
    BUFFER_STORE_BYTE_D16_HI_ADDR64,
    BUFFER_STORE_BYTE_D16_HI_BOTHEN,
    BUFFER_STORE_BYTE_D16_HI_IDXEN,
    BUFFER_STORE_BYTE_D16_HI_OFFEN,
    BUFFER_STORE_BYTE_D16_HI_TFE_ADDR64,
    BUFFER_STORE_BYTE_D16_HI_TFE_BOTHEN,
    BUFFER_STORE_BYTE_D16_HI_TFE_IDXEN,
    BUFFER_STORE_BYTE_D16_HI_TFE_OFFEN,
    BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_BYTE_D16_HI_VBUFFER_ADDR64,
    BUFFER_STORE_BYTE_D16_HI_VBUFFER_BOTHEN,
    BUFFER_STORE_BYTE_D16_HI_VBUFFER_IDXEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i8_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_BYTE_D16_HI_OFFSET,
    BUFFER_STORE_BYTE_D16_HI_TFE_OFFSET,
    BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i8_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFEN,
    BUFFER_STORE_BYTE_IDXEN,
    BUFFER_STORE_BYTE_OFFEN,
    BUFFER_STORE_BYTE_TFE_ADDR64,
    BUFFER_STORE_BYTE_TFE_BOTHEN,
    BUFFER_STORE_BYTE_TFE_IDXEN,
    BUFFER_STORE_BYTE_TFE_OFFEN,
    BUFFER_STORE_BYTE_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_BYTE_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_BYTE_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_BYTE_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_BYTE_VBUFFER_ADDR64,
    BUFFER_STORE_BYTE_VBUFFER_BOTHEN,
    BUFFER_STORE_BYTE_VBUFFER_IDXEN,
    BUFFER_STORE_BYTE_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i8_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp8), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFSET,
    BUFFER_STORE_BYTE_OFFSET,
    BUFFER_STORE_BYTE_TFE_OFFSET,
    BUFFER_STORE_BYTE_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_BYTE_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i8_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp8), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORDX2_ADDR64,
    BUFFER_STORE_DWORDX2_BOTHEN,
    BUFFER_STORE_DWORDX2_IDXEN,
    BUFFER_STORE_DWORDX2_OFFEN,
    BUFFER_STORE_DWORDX2_TFE_ADDR64,
    BUFFER_STORE_DWORDX2_TFE_BOTHEN,
    BUFFER_STORE_DWORDX2_TFE_IDXEN,
    BUFFER_STORE_DWORDX2_TFE_OFFEN,
    BUFFER_STORE_DWORDX2_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_DWORDX2_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORDX2_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_DWORDX2_VBUFFER_ADDR64,
    BUFFER_STORE_DWORDX2_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORDX2_VBUFFER_IDXEN,
    BUFFER_STORE_DWORDX2_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORDX2_OFFSET,
    BUFFER_STORE_DWORDX2_TFE_OFFSET,
    BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_DWORDX2_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORDX3_ADDR64,
    BUFFER_STORE_DWORDX3_BOTHEN,
    BUFFER_STORE_DWORDX3_IDXEN,
    BUFFER_STORE_DWORDX3_OFFEN,
    BUFFER_STORE_DWORDX3_TFE_ADDR64,
    BUFFER_STORE_DWORDX3_TFE_BOTHEN,
    BUFFER_STORE_DWORDX3_TFE_IDXEN,
    BUFFER_STORE_DWORDX3_TFE_OFFEN,
    BUFFER_STORE_DWORDX3_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_DWORDX3_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORDX3_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_DWORDX3_VBUFFER_ADDR64,
    BUFFER_STORE_DWORDX3_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORDX3_VBUFFER_IDXEN,
    BUFFER_STORE_DWORDX3_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORDX3_OFFSET,
    BUFFER_STORE_DWORDX3_TFE_OFFSET,
    BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_DWORDX3_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORDX4_ADDR64,
    BUFFER_STORE_DWORDX4_BOTHEN,
    BUFFER_STORE_DWORDX4_IDXEN,
    BUFFER_STORE_DWORDX4_OFFEN,
    BUFFER_STORE_DWORDX4_TFE_ADDR64,
    BUFFER_STORE_DWORDX4_TFE_BOTHEN,
    BUFFER_STORE_DWORDX4_TFE_IDXEN,
    BUFFER_STORE_DWORDX4_TFE_OFFEN,
    BUFFER_STORE_DWORDX4_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_DWORDX4_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORDX4_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_DWORDX4_VBUFFER_ADDR64,
    BUFFER_STORE_DWORDX4_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORDX4_VBUFFER_IDXEN,
    BUFFER_STORE_DWORDX4_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORDX4_OFFSET,
    BUFFER_STORE_DWORDX4_TFE_OFFSET,
    BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_DWORDX4_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORD_ADDR64,
    BUFFER_STORE_DWORD_BOTHEN,
    BUFFER_STORE_DWORD_IDXEN,
    BUFFER_STORE_DWORD_OFFEN,
    BUFFER_STORE_DWORD_TFE_ADDR64,
    BUFFER_STORE_DWORD_TFE_BOTHEN,
    BUFFER_STORE_DWORD_TFE_IDXEN,
    BUFFER_STORE_DWORD_TFE_OFFEN,
    BUFFER_STORE_DWORD_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_DWORD_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORD_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_DWORD_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_DWORD_VBUFFER_ADDR64,
    BUFFER_STORE_DWORD_VBUFFER_BOTHEN,
    BUFFER_STORE_DWORD_VBUFFER_IDXEN,
    BUFFER_STORE_DWORD_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_DWORD_OFFSET,
    BUFFER_STORE_DWORD_TFE_OFFSET,
    BUFFER_STORE_DWORD_TFE_VBUFFER_OFFSET,
    BUFFER_STORE_DWORD_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

def BUFFER_STORE_SHORT_ADDR64_sem : InstSISemantic<BUFFER_STORE_SHORT_ADDR64> {
  let Semantic = [
    (DefVal $tmp, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_BOTHEN_sem : InstSISemantic<BUFFER_STORE_SHORT_BOTHEN> {
  let Semantic = [
    (DefVal $tmp, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_ADDR64_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_ADDR64> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_BOTHEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_BOTHEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_IDXEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_IDXEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_OFFEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_OFFEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_ADDR64_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_ADDR64> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_BOTHEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_BOTHEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_IDXEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_IDXEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_OFFEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_OFFEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_OFFSET_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_OFFSET> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_ADDR64> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_BOTHEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_IDXEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFSET> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_VBUFFER_ADDR64> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

def BUFFER_STORE_SHORT_D16_HI_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_VBUFFER_BOTHEN> {
  let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
  ];
}

foreach inst = [
    BUFFER_STORE_SHORT_D16_HI_VBUFFER_IDXEN,
    BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFEN,
    BUFFER_STORE_SHORT_IDXEN,
    BUFFER_STORE_SHORT_OFFEN,
    BUFFER_STORE_SHORT_TFE_ADDR64,
    BUFFER_STORE_SHORT_TFE_BOTHEN,
    BUFFER_STORE_SHORT_TFE_IDXEN,
    BUFFER_STORE_SHORT_TFE_OFFEN,
    BUFFER_STORE_SHORT_TFE_VBUFFER_ADDR64,
    BUFFER_STORE_SHORT_TFE_VBUFFER_BOTHEN,
    BUFFER_STORE_SHORT_TFE_VBUFFER_IDXEN,
    BUFFER_STORE_SHORT_TFE_VBUFFER_OFFEN,
    BUFFER_STORE_SHORT_VBUFFER_ADDR64,
    BUFFER_STORE_SHORT_VBUFFER_BOTHEN,
    BUFFER_STORE_SHORT_VBUFFER_IDXEN,
    BUFFER_STORE_SHORT_VBUFFER_OFFEN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFSET,
    BUFFER_STORE_SHORT_OFFSET,
    BUFFER_STORE_SHORT_TFE_OFFSET,
    BUFFER_STORE_SHORT_TFE_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand $vdata), 16), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp16), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

foreach inst = [
    BUFFER_STORE_SHORT_VBUFFER_OFFSET
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $tmp, (LLVMTrunc (GetNamedOperand $vdata), si_llvm_i16_ty)),
    (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal $tmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)])
    ];
  }
}

// Buffer Atomic address mode / RTN / legacy naming / float variants -- same semantics as base.

foreach inst = [
    BUFFER_ATOMIC_ADD_ADDR64,
    BUFFER_ATOMIC_ADD_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_BOTHEN,
    BUFFER_ATOMIC_ADD_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_F32_ADDR64,
    BUFFER_ATOMIC_ADD_F32_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_F32_BOTHEN,
    BUFFER_ATOMIC_ADD_F32_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_F32_IDXEN,
    BUFFER_ATOMIC_ADD_F32_IDXEN_RTN,
    BUFFER_ATOMIC_ADD_F32_OFFEN,
    BUFFER_ATOMIC_ADD_F32_OFFEN_RTN,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_ADDR64,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_IDXEN,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_IDXEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_F32_OFFSET,
    BUFFER_ATOMIC_ADD_F32_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_F32_VBUFFER_OFFEN,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_OFFEN_RTN,
    BUFFER_ATOMIC_ADD_F64_ADDR64,
    BUFFER_ATOMIC_ADD_F64_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_F64_BOTHEN,
    BUFFER_ATOMIC_ADD_F64_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_F64_IDXEN,
    BUFFER_ATOMIC_ADD_F64_IDXEN_RTN,
    BUFFER_ATOMIC_ADD_F64_OFFEN,
    BUFFER_ATOMIC_ADD_F64_OFFEN_RTN,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_ADDR64,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_IDXEN,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_IDXEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_F32_VBUFFER_OFFSET,
    BUFFER_ATOMIC_ADD_F32_VBUFFER_OFFSET_RTN,
    BUFFER_ATOMIC_ADD_F64_OFFSET,
    BUFFER_ATOMIC_ADD_F64_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_F64_VBUFFER_OFFEN,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_OFFEN_RTN,
    BUFFER_ATOMIC_ADD_IDXEN,
    BUFFER_ATOMIC_ADD_IDXEN_RTN,
    BUFFER_ATOMIC_ADD_OFFEN,
    BUFFER_ATOMIC_ADD_OFFEN_RTN,
    BUFFER_ATOMIC_ADD_VBUFFER_ADDR64,
    BUFFER_ATOMIC_ADD_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_ADD_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_VBUFFER_IDXEN,
    BUFFER_ATOMIC_ADD_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_ADD_VBUFFER_OFFEN,
    BUFFER_ATOMIC_ADD_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_F64_VBUFFER_OFFSET,
    BUFFER_ATOMIC_ADD_F64_VBUFFER_OFFSET_RTN,
    BUFFER_ATOMIC_ADD_OFFSET,
    BUFFER_ATOMIC_ADD_OFFSET_RTN,
    BUFFER_ATOMIC_ADD_VBUFFER_OFFSET,
    BUFFER_ATOMIC_ADD_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_X2_ADDR64,
    BUFFER_ATOMIC_ADD_X2_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_X2_BOTHEN,
    BUFFER_ATOMIC_ADD_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_X2_IDXEN,
    BUFFER_ATOMIC_ADD_X2_IDXEN_RTN,
    BUFFER_ATOMIC_ADD_X2_OFFEN,
    BUFFER_ATOMIC_ADD_X2_OFFEN_RTN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_ADD_X2_OFFSET,
    BUFFER_ATOMIC_ADD_X2_OFFSET_RTN,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_ADD_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_add, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_AND_ADDR64,
    BUFFER_ATOMIC_AND_ADDR64_RTN,
    BUFFER_ATOMIC_AND_BOTHEN,
    BUFFER_ATOMIC_AND_BOTHEN_RTN,
    BUFFER_ATOMIC_AND_IDXEN,
    BUFFER_ATOMIC_AND_IDXEN_RTN,
    BUFFER_ATOMIC_AND_OFFEN,
    BUFFER_ATOMIC_AND_OFFEN_RTN,
    BUFFER_ATOMIC_AND_VBUFFER_ADDR64,
    BUFFER_ATOMIC_AND_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_AND_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_AND_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_AND_VBUFFER_IDXEN,
    BUFFER_ATOMIC_AND_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_AND_VBUFFER_OFFEN,
    BUFFER_ATOMIC_AND_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_AND_OFFSET,
    BUFFER_ATOMIC_AND_OFFSET_RTN,
    BUFFER_ATOMIC_AND_VBUFFER_OFFSET,
    BUFFER_ATOMIC_AND_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_AND_X2_ADDR64,
    BUFFER_ATOMIC_AND_X2_ADDR64_RTN,
    BUFFER_ATOMIC_AND_X2_BOTHEN,
    BUFFER_ATOMIC_AND_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_AND_X2_IDXEN,
    BUFFER_ATOMIC_AND_X2_IDXEN_RTN,
    BUFFER_ATOMIC_AND_X2_OFFEN,
    BUFFER_ATOMIC_AND_X2_OFFEN_RTN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_AND_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_AND_X2_OFFSET,
    BUFFER_ATOMIC_AND_X2_OFFSET_RTN,
    BUFFER_ATOMIC_AND_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_AND_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_and, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_CMPSWAP_ADDR64,
    BUFFER_ATOMIC_CMPSWAP_ADDR64_RTN,
    BUFFER_ATOMIC_CMPSWAP_BOTHEN,
    BUFFER_ATOMIC_CMPSWAP_BOTHEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_IDXEN,
    BUFFER_ATOMIC_CMPSWAP_IDXEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_OFFEN,
    BUFFER_ATOMIC_CMPSWAP_OFFEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_ADDR64,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_IDXEN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_OFFEN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_CMPSWAP_OFFSET,
    BUFFER_ATOMIC_CMPSWAP_OFFSET_RTN,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_OFFSET,
    BUFFER_ATOMIC_CMPSWAP_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_CMPSWAP_X2_ADDR64,
    BUFFER_ATOMIC_CMPSWAP_X2_ADDR64_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_BOTHEN,
    BUFFER_ATOMIC_CMPSWAP_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_IDXEN,
    BUFFER_ATOMIC_CMPSWAP_X2_IDXEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_OFFEN,
    BUFFER_ATOMIC_CMPSWAP_X2_OFFEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_CMPSWAP_X2_OFFSET,
    BUFFER_ATOMIC_CMPSWAP_X2_OFFSET_RTN,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_CMPSWAP_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_COND_SUB_U32_ADDR64,
    BUFFER_ATOMIC_COND_SUB_U32_ADDR64_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_BOTHEN,
    BUFFER_ATOMIC_COND_SUB_U32_BOTHEN_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_IDXEN,
    BUFFER_ATOMIC_COND_SUB_U32_IDXEN_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_OFFEN,
    BUFFER_ATOMIC_COND_SUB_U32_OFFEN_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_ADDR64,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_IDXEN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_OFFEN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cond_sub_u32, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_COND_SUB_U32_OFFSET,
    BUFFER_ATOMIC_COND_SUB_U32_OFFSET_RTN,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_OFFSET,
    BUFFER_ATOMIC_COND_SUB_U32_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_cond_sub_u32, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_CSUB_ADDR64,
    BUFFER_ATOMIC_CSUB_ADDR64_RTN,
    BUFFER_ATOMIC_CSUB_BOTHEN,
    BUFFER_ATOMIC_CSUB_BOTHEN_RTN,
    BUFFER_ATOMIC_CSUB_IDXEN,
    BUFFER_ATOMIC_CSUB_IDXEN_RTN,
    BUFFER_ATOMIC_CSUB_OFFEN,
    BUFFER_ATOMIC_CSUB_OFFEN_RTN,
    BUFFER_ATOMIC_CSUB_VBUFFER_ADDR64,
    BUFFER_ATOMIC_CSUB_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_CSUB_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_CSUB_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_CSUB_VBUFFER_IDXEN,
    BUFFER_ATOMIC_CSUB_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_CSUB_VBUFFER_OFFEN,
    BUFFER_ATOMIC_CSUB_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub_clamp_u32, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_CSUB_OFFSET,
    BUFFER_ATOMIC_CSUB_OFFSET_RTN,
    BUFFER_ATOMIC_CSUB_VBUFFER_OFFSET,
    BUFFER_ATOMIC_CSUB_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub_clamp_u32, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_DEC_ADDR64,
    BUFFER_ATOMIC_DEC_ADDR64_RTN,
    BUFFER_ATOMIC_DEC_BOTHEN,
    BUFFER_ATOMIC_DEC_BOTHEN_RTN,
    BUFFER_ATOMIC_DEC_IDXEN,
    BUFFER_ATOMIC_DEC_IDXEN_RTN,
    BUFFER_ATOMIC_DEC_OFFEN,
    BUFFER_ATOMIC_DEC_OFFEN_RTN,
    BUFFER_ATOMIC_DEC_VBUFFER_ADDR64,
    BUFFER_ATOMIC_DEC_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_DEC_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_DEC_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_DEC_VBUFFER_IDXEN,
    BUFFER_ATOMIC_DEC_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_DEC_VBUFFER_OFFEN,
    BUFFER_ATOMIC_DEC_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_dec, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_DEC_OFFSET,
    BUFFER_ATOMIC_DEC_OFFSET_RTN,
    BUFFER_ATOMIC_DEC_VBUFFER_OFFSET,
    BUFFER_ATOMIC_DEC_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_dec, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_DEC_X2_ADDR64,
    BUFFER_ATOMIC_DEC_X2_ADDR64_RTN,
    BUFFER_ATOMIC_DEC_X2_BOTHEN,
    BUFFER_ATOMIC_DEC_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_DEC_X2_IDXEN,
    BUFFER_ATOMIC_DEC_X2_IDXEN_RTN,
    BUFFER_ATOMIC_DEC_X2_OFFEN,
    BUFFER_ATOMIC_DEC_X2_OFFEN_RTN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_dec, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_DEC_X2_OFFSET,
    BUFFER_ATOMIC_DEC_X2_OFFSET_RTN,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_DEC_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_dec, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FCMPSWAP_ADDR64,
    BUFFER_ATOMIC_FCMPSWAP_ADDR64_RTN,
    BUFFER_ATOMIC_FCMPSWAP_BOTHEN,
    BUFFER_ATOMIC_FCMPSWAP_BOTHEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_IDXEN,
    BUFFER_ATOMIC_FCMPSWAP_IDXEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_OFFEN,
    BUFFER_ATOMIC_FCMPSWAP_OFFEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_ADDR64,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_IDXEN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_OFFEN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FCMPSWAP_OFFSET,
    BUFFER_ATOMIC_FCMPSWAP_OFFSET_RTN,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_OFFSET,
    BUFFER_ATOMIC_FCMPSWAP_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FCMPSWAP_X2_ADDR64,
    BUFFER_ATOMIC_FCMPSWAP_X2_ADDR64_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_BOTHEN,
    BUFFER_ATOMIC_FCMPSWAP_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_IDXEN,
    BUFFER_ATOMIC_FCMPSWAP_X2_IDXEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_OFFEN,
    BUFFER_ATOMIC_FCMPSWAP_X2_OFFEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FCMPSWAP_X2_OFFSET,
    BUFFER_ATOMIC_FCMPSWAP_X2_OFFSET_RTN,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_FCMPSWAP_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (DefVal $src, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 0))),
    (DefVal $cmp, (LLVMExtractElement (GetNamedOperand $vdata), (ConstantInt si_llvm_i32_ty, 1))),
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_cmpswap, [(GetVal $src), (GetVal $cmp), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FMAX_ADDR64,
    BUFFER_ATOMIC_FMAX_ADDR64_RTN,
    BUFFER_ATOMIC_FMAX_BOTHEN,
    BUFFER_ATOMIC_FMAX_BOTHEN_RTN,
    BUFFER_ATOMIC_FMAX_IDXEN,
    BUFFER_ATOMIC_FMAX_IDXEN_RTN,
    BUFFER_ATOMIC_FMAX_OFFEN,
    BUFFER_ATOMIC_FMAX_OFFEN_RTN,
    BUFFER_ATOMIC_FMAX_VBUFFER_ADDR64,
    BUFFER_ATOMIC_FMAX_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_FMAX_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_FMAX_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_FMAX_VBUFFER_IDXEN,
    BUFFER_ATOMIC_FMAX_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_FMAX_VBUFFER_OFFEN,
    BUFFER_ATOMIC_FMAX_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_fmax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FMAX_OFFSET,
    BUFFER_ATOMIC_FMAX_OFFSET_RTN,
    BUFFER_ATOMIC_FMAX_VBUFFER_OFFSET,
    BUFFER_ATOMIC_FMAX_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_fmax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FMIN_ADDR64,
    BUFFER_ATOMIC_FMIN_ADDR64_RTN,
    BUFFER_ATOMIC_FMIN_BOTHEN,
    BUFFER_ATOMIC_FMIN_BOTHEN_RTN,
    BUFFER_ATOMIC_FMIN_IDXEN,
    BUFFER_ATOMIC_FMIN_IDXEN_RTN,
    BUFFER_ATOMIC_FMIN_OFFEN,
    BUFFER_ATOMIC_FMIN_OFFEN_RTN,
    BUFFER_ATOMIC_FMIN_VBUFFER_ADDR64,
    BUFFER_ATOMIC_FMIN_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_FMIN_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_FMIN_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_FMIN_VBUFFER_IDXEN,
    BUFFER_ATOMIC_FMIN_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_FMIN_VBUFFER_OFFEN,
    BUFFER_ATOMIC_FMIN_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_fmin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_FMIN_OFFSET,
    BUFFER_ATOMIC_FMIN_OFFSET_RTN,
    BUFFER_ATOMIC_FMIN_VBUFFER_OFFSET,
    BUFFER_ATOMIC_FMIN_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_atomic_fmin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_INC_ADDR64,
    BUFFER_ATOMIC_INC_ADDR64_RTN,
    BUFFER_ATOMIC_INC_BOTHEN,
    BUFFER_ATOMIC_INC_BOTHEN_RTN,
    BUFFER_ATOMIC_INC_IDXEN,
    BUFFER_ATOMIC_INC_IDXEN_RTN,
    BUFFER_ATOMIC_INC_OFFEN,
    BUFFER_ATOMIC_INC_OFFEN_RTN,
    BUFFER_ATOMIC_INC_VBUFFER_ADDR64,
    BUFFER_ATOMIC_INC_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_INC_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_INC_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_INC_VBUFFER_IDXEN,
    BUFFER_ATOMIC_INC_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_INC_VBUFFER_OFFEN,
    BUFFER_ATOMIC_INC_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_inc, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_INC_OFFSET,
    BUFFER_ATOMIC_INC_OFFSET_RTN,
    BUFFER_ATOMIC_INC_VBUFFER_OFFSET,
    BUFFER_ATOMIC_INC_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_inc, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_INC_X2_ADDR64,
    BUFFER_ATOMIC_INC_X2_ADDR64_RTN,
    BUFFER_ATOMIC_INC_X2_BOTHEN,
    BUFFER_ATOMIC_INC_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_INC_X2_IDXEN,
    BUFFER_ATOMIC_INC_X2_IDXEN_RTN,
    BUFFER_ATOMIC_INC_X2_OFFEN,
    BUFFER_ATOMIC_INC_X2_OFFEN_RTN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_INC_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_inc, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_INC_X2_OFFSET,
    BUFFER_ATOMIC_INC_X2_OFFSET_RTN,
    BUFFER_ATOMIC_INC_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_INC_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_inc, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_MAX_F64_ADDR64,
    BUFFER_ATOMIC_MAX_F64_ADDR64_RTN,
    BUFFER_ATOMIC_MAX_F64_BOTHEN,
    BUFFER_ATOMIC_MAX_F64_BOTHEN_RTN,
    BUFFER_ATOMIC_MAX_F64_IDXEN,
    BUFFER_ATOMIC_MAX_F64_IDXEN_RTN,
    BUFFER_ATOMIC_MAX_F64_OFFEN,
    BUFFER_ATOMIC_MAX_F64_OFFEN_RTN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_ADDR64,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_IDXEN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_OFFEN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_fmax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_MAX_F64_OFFSET,
    BUFFER_ATOMIC_MAX_F64_OFFSET_RTN,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_OFFSET,
    BUFFER_ATOMIC_MAX_F64_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_fmax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_MIN_F64_ADDR64,
    BUFFER_ATOMIC_MIN_F64_ADDR64_RTN,
    BUFFER_ATOMIC_MIN_F64_BOTHEN,
    BUFFER_ATOMIC_MIN_F64_BOTHEN_RTN,
    BUFFER_ATOMIC_MIN_F64_IDXEN,
    BUFFER_ATOMIC_MIN_F64_IDXEN_RTN,
    BUFFER_ATOMIC_MIN_F64_OFFEN,
    BUFFER_ATOMIC_MIN_F64_OFFEN_RTN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_ADDR64,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_IDXEN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_OFFEN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_fmin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_MIN_F64_OFFSET,
    BUFFER_ATOMIC_MIN_F64_OFFSET_RTN,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_OFFSET,
    BUFFER_ATOMIC_MIN_F64_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_double_ty, int_amdgcn_struct_buffer_atomic_fmin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_OR_ADDR64,
    BUFFER_ATOMIC_OR_ADDR64_RTN,
    BUFFER_ATOMIC_OR_BOTHEN,
    BUFFER_ATOMIC_OR_BOTHEN_RTN,
    BUFFER_ATOMIC_OR_IDXEN,
    BUFFER_ATOMIC_OR_IDXEN_RTN,
    BUFFER_ATOMIC_OR_OFFEN,
    BUFFER_ATOMIC_OR_OFFEN_RTN,
    BUFFER_ATOMIC_OR_VBUFFER_ADDR64,
    BUFFER_ATOMIC_OR_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_OR_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_OR_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_OR_VBUFFER_IDXEN,
    BUFFER_ATOMIC_OR_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_OR_VBUFFER_OFFEN,
    BUFFER_ATOMIC_OR_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_OR_OFFSET,
    BUFFER_ATOMIC_OR_OFFSET_RTN,
    BUFFER_ATOMIC_OR_VBUFFER_OFFSET,
    BUFFER_ATOMIC_OR_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_OR_X2_ADDR64,
    BUFFER_ATOMIC_OR_X2_ADDR64_RTN,
    BUFFER_ATOMIC_OR_X2_BOTHEN,
    BUFFER_ATOMIC_OR_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_OR_X2_IDXEN,
    BUFFER_ATOMIC_OR_X2_IDXEN_RTN,
    BUFFER_ATOMIC_OR_X2_OFFEN,
    BUFFER_ATOMIC_OR_X2_OFFEN_RTN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_OR_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_OR_X2_OFFSET,
    BUFFER_ATOMIC_OR_X2_OFFSET_RTN,
    BUFFER_ATOMIC_OR_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_OR_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_or, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_PK_ADD_BF16_ADDR64,
    BUFFER_ATOMIC_PK_ADD_BF16_ADDR64_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_BOTHEN,
    BUFFER_ATOMIC_PK_ADD_BF16_BOTHEN_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_IDXEN,
    BUFFER_ATOMIC_PK_ADD_BF16_IDXEN_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_OFFEN,
    BUFFER_ATOMIC_PK_ADD_BF16_OFFEN_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_ADDR64,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_IDXEN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_OFFEN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2bf16_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_PK_ADD_BF16_OFFSET,
    BUFFER_ATOMIC_PK_ADD_BF16_OFFSET_RTN,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_OFFSET,
    BUFFER_ATOMIC_PK_ADD_BF16_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2bf16_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_PK_ADD_F16_ADDR64,
    BUFFER_ATOMIC_PK_ADD_F16_ADDR64_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_BOTHEN,
    BUFFER_ATOMIC_PK_ADD_F16_BOTHEN_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_IDXEN,
    BUFFER_ATOMIC_PK_ADD_F16_IDXEN_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_OFFEN,
    BUFFER_ATOMIC_PK_ADD_F16_OFFEN_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_ADDR64,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_IDXEN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_OFFEN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_PK_ADD_F16_OFFSET,
    BUFFER_ATOMIC_PK_ADD_F16_OFFSET_RTN,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_OFFSET,
    BUFFER_ATOMIC_PK_ADD_F16_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_atomic_fadd, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMAX_ADDR64,
    BUFFER_ATOMIC_SMAX_ADDR64_RTN,
    BUFFER_ATOMIC_SMAX_BOTHEN,
    BUFFER_ATOMIC_SMAX_BOTHEN_RTN,
    BUFFER_ATOMIC_SMAX_IDXEN,
    BUFFER_ATOMIC_SMAX_IDXEN_RTN,
    BUFFER_ATOMIC_SMAX_OFFEN,
    BUFFER_ATOMIC_SMAX_OFFEN_RTN,
    BUFFER_ATOMIC_SMAX_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SMAX_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SMAX_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SMAX_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SMAX_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SMAX_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SMAX_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SMAX_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMAX_OFFSET,
    BUFFER_ATOMIC_SMAX_OFFSET_RTN,
    BUFFER_ATOMIC_SMAX_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SMAX_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMAX_X2_ADDR64,
    BUFFER_ATOMIC_SMAX_X2_ADDR64_RTN,
    BUFFER_ATOMIC_SMAX_X2_BOTHEN,
    BUFFER_ATOMIC_SMAX_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_SMAX_X2_IDXEN,
    BUFFER_ATOMIC_SMAX_X2_IDXEN_RTN,
    BUFFER_ATOMIC_SMAX_X2_OFFEN,
    BUFFER_ATOMIC_SMAX_X2_OFFEN_RTN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMAX_X2_OFFSET,
    BUFFER_ATOMIC_SMAX_X2_OFFSET_RTN,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SMAX_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMIN_ADDR64,
    BUFFER_ATOMIC_SMIN_ADDR64_RTN,
    BUFFER_ATOMIC_SMIN_BOTHEN,
    BUFFER_ATOMIC_SMIN_BOTHEN_RTN,
    BUFFER_ATOMIC_SMIN_IDXEN,
    BUFFER_ATOMIC_SMIN_IDXEN_RTN,
    BUFFER_ATOMIC_SMIN_OFFEN,
    BUFFER_ATOMIC_SMIN_OFFEN_RTN,
    BUFFER_ATOMIC_SMIN_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SMIN_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SMIN_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SMIN_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SMIN_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SMIN_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SMIN_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SMIN_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMIN_OFFSET,
    BUFFER_ATOMIC_SMIN_OFFSET_RTN,
    BUFFER_ATOMIC_SMIN_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SMIN_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMIN_X2_ADDR64,
    BUFFER_ATOMIC_SMIN_X2_ADDR64_RTN,
    BUFFER_ATOMIC_SMIN_X2_BOTHEN,
    BUFFER_ATOMIC_SMIN_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_SMIN_X2_IDXEN,
    BUFFER_ATOMIC_SMIN_X2_IDXEN_RTN,
    BUFFER_ATOMIC_SMIN_X2_OFFEN,
    BUFFER_ATOMIC_SMIN_X2_OFFEN_RTN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SMIN_X2_OFFSET,
    BUFFER_ATOMIC_SMIN_X2_OFFSET_RTN,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SMIN_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_smin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SUB_ADDR64,
    BUFFER_ATOMIC_SUB_ADDR64_RTN,
    BUFFER_ATOMIC_SUB_BOTHEN,
    BUFFER_ATOMIC_SUB_BOTHEN_RTN,
    BUFFER_ATOMIC_SUB_IDXEN,
    BUFFER_ATOMIC_SUB_IDXEN_RTN,
    BUFFER_ATOMIC_SUB_OFFEN,
    BUFFER_ATOMIC_SUB_OFFEN_RTN,
    BUFFER_ATOMIC_SUB_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SUB_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SUB_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SUB_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SUB_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SUB_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SUB_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SUB_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SUB_OFFSET,
    BUFFER_ATOMIC_SUB_OFFSET_RTN,
    BUFFER_ATOMIC_SUB_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SUB_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SUB_X2_ADDR64,
    BUFFER_ATOMIC_SUB_X2_ADDR64_RTN,
    BUFFER_ATOMIC_SUB_X2_BOTHEN,
    BUFFER_ATOMIC_SUB_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_SUB_X2_IDXEN,
    BUFFER_ATOMIC_SUB_X2_IDXEN_RTN,
    BUFFER_ATOMIC_SUB_X2_OFFEN,
    BUFFER_ATOMIC_SUB_X2_OFFEN_RTN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SUB_X2_OFFSET,
    BUFFER_ATOMIC_SUB_X2_OFFSET_RTN,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SUB_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_sub, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SWAP_ADDR64,
    BUFFER_ATOMIC_SWAP_ADDR64_RTN,
    BUFFER_ATOMIC_SWAP_BOTHEN,
    BUFFER_ATOMIC_SWAP_BOTHEN_RTN,
    BUFFER_ATOMIC_SWAP_IDXEN,
    BUFFER_ATOMIC_SWAP_IDXEN_RTN,
    BUFFER_ATOMIC_SWAP_OFFEN,
    BUFFER_ATOMIC_SWAP_OFFEN_RTN,
    BUFFER_ATOMIC_SWAP_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SWAP_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SWAP_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SWAP_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SWAP_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SWAP_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SWAP_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SWAP_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SWAP_OFFSET,
    BUFFER_ATOMIC_SWAP_OFFSET_RTN,
    BUFFER_ATOMIC_SWAP_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SWAP_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SWAP_X2_ADDR64,
    BUFFER_ATOMIC_SWAP_X2_ADDR64_RTN,
    BUFFER_ATOMIC_SWAP_X2_BOTHEN,
    BUFFER_ATOMIC_SWAP_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_SWAP_X2_IDXEN,
    BUFFER_ATOMIC_SWAP_X2_IDXEN_RTN,
    BUFFER_ATOMIC_SWAP_X2_OFFEN,
    BUFFER_ATOMIC_SWAP_X2_OFFEN_RTN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_SWAP_X2_OFFSET,
    BUFFER_ATOMIC_SWAP_X2_OFFSET_RTN,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_SWAP_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_swap, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMAX_ADDR64,
    BUFFER_ATOMIC_UMAX_ADDR64_RTN,
    BUFFER_ATOMIC_UMAX_BOTHEN,
    BUFFER_ATOMIC_UMAX_BOTHEN_RTN,
    BUFFER_ATOMIC_UMAX_IDXEN,
    BUFFER_ATOMIC_UMAX_IDXEN_RTN,
    BUFFER_ATOMIC_UMAX_OFFEN,
    BUFFER_ATOMIC_UMAX_OFFEN_RTN,
    BUFFER_ATOMIC_UMAX_VBUFFER_ADDR64,
    BUFFER_ATOMIC_UMAX_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_UMAX_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_UMAX_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_UMAX_VBUFFER_IDXEN,
    BUFFER_ATOMIC_UMAX_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_UMAX_VBUFFER_OFFEN,
    BUFFER_ATOMIC_UMAX_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMAX_OFFSET,
    BUFFER_ATOMIC_UMAX_OFFSET_RTN,
    BUFFER_ATOMIC_UMAX_VBUFFER_OFFSET,
    BUFFER_ATOMIC_UMAX_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMAX_X2_ADDR64,
    BUFFER_ATOMIC_UMAX_X2_ADDR64_RTN,
    BUFFER_ATOMIC_UMAX_X2_BOTHEN,
    BUFFER_ATOMIC_UMAX_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_UMAX_X2_IDXEN,
    BUFFER_ATOMIC_UMAX_X2_IDXEN_RTN,
    BUFFER_ATOMIC_UMAX_X2_OFFEN,
    BUFFER_ATOMIC_UMAX_X2_OFFEN_RTN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMAX_X2_OFFSET,
    BUFFER_ATOMIC_UMAX_X2_OFFSET_RTN,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_UMAX_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umax, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMIN_ADDR64,
    BUFFER_ATOMIC_UMIN_ADDR64_RTN,
    BUFFER_ATOMIC_UMIN_BOTHEN,
    BUFFER_ATOMIC_UMIN_BOTHEN_RTN,
    BUFFER_ATOMIC_UMIN_IDXEN,
    BUFFER_ATOMIC_UMIN_IDXEN_RTN,
    BUFFER_ATOMIC_UMIN_OFFEN,
    BUFFER_ATOMIC_UMIN_OFFEN_RTN,
    BUFFER_ATOMIC_UMIN_VBUFFER_ADDR64,
    BUFFER_ATOMIC_UMIN_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_UMIN_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_UMIN_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_UMIN_VBUFFER_IDXEN,
    BUFFER_ATOMIC_UMIN_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_UMIN_VBUFFER_OFFEN,
    BUFFER_ATOMIC_UMIN_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMIN_OFFSET,
    BUFFER_ATOMIC_UMIN_OFFSET_RTN,
    BUFFER_ATOMIC_UMIN_VBUFFER_OFFSET,
    BUFFER_ATOMIC_UMIN_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMIN_X2_ADDR64,
    BUFFER_ATOMIC_UMIN_X2_ADDR64_RTN,
    BUFFER_ATOMIC_UMIN_X2_BOTHEN,
    BUFFER_ATOMIC_UMIN_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_UMIN_X2_IDXEN,
    BUFFER_ATOMIC_UMIN_X2_IDXEN_RTN,
    BUFFER_ATOMIC_UMIN_X2_OFFEN,
    BUFFER_ATOMIC_UMIN_X2_OFFEN_RTN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_UMIN_X2_OFFSET,
    BUFFER_ATOMIC_UMIN_X2_OFFSET_RTN,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_UMIN_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_umin, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_XOR_ADDR64,
    BUFFER_ATOMIC_XOR_ADDR64_RTN,
    BUFFER_ATOMIC_XOR_BOTHEN,
    BUFFER_ATOMIC_XOR_BOTHEN_RTN,
    BUFFER_ATOMIC_XOR_IDXEN,
    BUFFER_ATOMIC_XOR_IDXEN_RTN,
    BUFFER_ATOMIC_XOR_OFFEN,
    BUFFER_ATOMIC_XOR_OFFEN_RTN,
    BUFFER_ATOMIC_XOR_VBUFFER_ADDR64,
    BUFFER_ATOMIC_XOR_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_XOR_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_XOR_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_XOR_VBUFFER_IDXEN,
    BUFFER_ATOMIC_XOR_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_XOR_VBUFFER_OFFEN,
    BUFFER_ATOMIC_XOR_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_XOR_OFFSET,
    BUFFER_ATOMIC_XOR_OFFSET_RTN,
    BUFFER_ATOMIC_XOR_VBUFFER_OFFSET,
    BUFFER_ATOMIC_XOR_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_XOR_X2_ADDR64,
    BUFFER_ATOMIC_XOR_X2_ADDR64_RTN,
    BUFFER_ATOMIC_XOR_X2_BOTHEN,
    BUFFER_ATOMIC_XOR_X2_BOTHEN_RTN,
    BUFFER_ATOMIC_XOR_X2_IDXEN,
    BUFFER_ATOMIC_XOR_X2_IDXEN_RTN,
    BUFFER_ATOMIC_XOR_X2_OFFEN,
    BUFFER_ATOMIC_XOR_X2_OFFEN_RTN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_ADDR64,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_ADDR64_RTN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_BOTHEN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_BOTHEN_RTN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_IDXEN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_IDXEN_RTN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_OFFEN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_OFFEN_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (GetNamedOperand $vaddr), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

foreach inst = [
    BUFFER_ATOMIC_XOR_X2_OFFSET,
    BUFFER_ATOMIC_XOR_X2_OFFSET_RTN,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_OFFSET,
    BUFFER_ATOMIC_XOR_X2_VBUFFER_OFFSET_RTN
] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
    (SetNamedOperand $vdata,
      (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_struct_buffer_atomic_xor, [(GetNamedOperand $vdata), (LLVMBitCast (GetNamedOperand $srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand $offset), (GetNamedOperand $soffset), (GetNamedOperand $cpol)]))
    ];
  }
}

// Buffer cache management instructions.


//==============================================================================
// BUFFER _exact alignment-marker variants (Phase 8)
// _exact variants share IR semantics with the base op; alignment is metadata.
//==============================================================================

// _exact alias of BUFFER_LOAD_DWORDX2_BOTHEN
def BUFFER_LOAD_DWORDX2_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_IDXEN
def BUFFER_LOAD_DWORDX2_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_OFFEN
def BUFFER_LOAD_DWORDX2_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_OFFSET
def BUFFER_LOAD_DWORDX2_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_BOTHEN
def BUFFER_LOAD_DWORDX2_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_IDXEN
def BUFFER_LOAD_DWORDX2_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_OFFEN
def BUFFER_LOAD_DWORDX2_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_OFFSET
def BUFFER_LOAD_DWORDX2_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX2_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX2_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX2_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX2_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX2_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX2_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX2_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX2_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_BOTHEN
def BUFFER_LOAD_DWORDX3_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_IDXEN
def BUFFER_LOAD_DWORDX3_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_OFFEN
def BUFFER_LOAD_DWORDX3_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_OFFSET
def BUFFER_LOAD_DWORDX3_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_BOTHEN
def BUFFER_LOAD_DWORDX3_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_IDXEN
def BUFFER_LOAD_DWORDX3_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_OFFEN
def BUFFER_LOAD_DWORDX3_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_OFFSET
def BUFFER_LOAD_DWORDX3_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX3_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX3_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX3_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX3_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX3_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX3_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX3_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_BOTHEN
def BUFFER_LOAD_DWORDX4_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_IDXEN
def BUFFER_LOAD_DWORDX4_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_OFFEN
def BUFFER_LOAD_DWORDX4_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_OFFSET
def BUFFER_LOAD_DWORDX4_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_BOTHEN
def BUFFER_LOAD_DWORDX4_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_IDXEN
def BUFFER_LOAD_DWORDX4_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_OFFEN
def BUFFER_LOAD_DWORDX4_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_OFFSET
def BUFFER_LOAD_DWORDX4_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX4_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX4_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX4_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX4_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX4_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORDX4_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX4_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_BOTHEN
def BUFFER_LOAD_DWORD_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_IDXEN
def BUFFER_LOAD_DWORD_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_BOTHEN
def BUFFER_LOAD_DWORD_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_IDXEN
def BUFFER_LOAD_DWORD_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_OFFEN
def BUFFER_LOAD_DWORD_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_OFFSET
def BUFFER_LOAD_DWORD_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORD_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_VBUFFER_IDXEN
def BUFFER_LOAD_DWORD_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFEN
def BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFSET
def BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_OFFEN
def BUFFER_LOAD_DWORD_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_OFFSET
def BUFFER_LOAD_DWORD_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_BOTHEN
def BUFFER_LOAD_DWORD_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_IDXEN
def BUFFER_LOAD_DWORD_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_OFFEN
def BUFFER_LOAD_DWORD_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_OFFSET
def BUFFER_LOAD_DWORD_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORD_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_DWORD_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORD_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_VBUFFER_IDXEN
def BUFFER_LOAD_DWORD_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_VBUFFER_OFFEN
def BUFFER_LOAD_DWORD_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_DWORD_VBUFFER_OFFSET
def BUFFER_LOAD_DWORD_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORD_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_BOTHEN
def BUFFER_LOAD_FORMAT_D16_HI_X_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_IDXEN
def BUFFER_LOAD_FORMAT_D16_HI_X_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_IDXEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_OFFEN
def BUFFER_LOAD_FORMAT_D16_HI_X_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_OFFEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_OFFSET
def BUFFER_LOAD_FORMAT_D16_HI_X_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_OFFSET_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_HI_X_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$fval, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$ival, (LLVMBitCast (GetVal ?:$fval), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$ival), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_BOTHEN
def BUFFER_LOAD_FORMAT_XYZW_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_IDXEN
def BUFFER_LOAD_FORMAT_XYZW_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_OFFEN
def BUFFER_LOAD_FORMAT_XYZW_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_OFFSET
def BUFFER_LOAD_FORMAT_XYZW_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_XYZW_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_IDXEN
def BUFFER_LOAD_FORMAT_XYZW_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_OFFEN
def BUFFER_LOAD_FORMAT_XYZW_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_OFFSET
def BUFFER_LOAD_FORMAT_XYZW_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_BOTHEN
def BUFFER_LOAD_FORMAT_XYZ_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_IDXEN
def BUFFER_LOAD_FORMAT_XYZ_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_OFFEN
def BUFFER_LOAD_FORMAT_XYZ_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_OFFSET
def BUFFER_LOAD_FORMAT_XYZ_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_XYZ_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_IDXEN
def BUFFER_LOAD_FORMAT_XYZ_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_OFFEN
def BUFFER_LOAD_FORMAT_XYZ_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_OFFSET
def BUFFER_LOAD_FORMAT_XYZ_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_BOTHEN
def BUFFER_LOAD_FORMAT_XY_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_IDXEN
def BUFFER_LOAD_FORMAT_XY_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_OFFEN
def BUFFER_LOAD_FORMAT_XY_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_OFFSET
def BUFFER_LOAD_FORMAT_XY_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_XY_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_IDXEN
def BUFFER_LOAD_FORMAT_XY_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_OFFEN
def BUFFER_LOAD_FORMAT_XY_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_OFFSET
def BUFFER_LOAD_FORMAT_XY_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f32_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_BOTHEN
def BUFFER_LOAD_FORMAT_X_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_IDXEN
def BUFFER_LOAD_FORMAT_X_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_BOTHEN
def BUFFER_LOAD_FORMAT_X_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_IDXEN
def BUFFER_LOAD_FORMAT_X_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_OFFEN
def BUFFER_LOAD_FORMAT_X_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_OFFSET
def BUFFER_LOAD_FORMAT_X_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_OFFEN
def BUFFER_LOAD_FORMAT_X_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_OFFSET
def BUFFER_LOAD_FORMAT_X_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_X_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_IDXEN
def BUFFER_LOAD_FORMAT_X_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_OFFEN
def BUFFER_LOAD_FORMAT_X_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_OFFSET
def BUFFER_LOAD_FORMAT_X_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_X_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_float_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_BOTHEN
def BUFFER_LOAD_SBYTE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_BOTHEN
def BUFFER_LOAD_SBYTE_D16_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_BOTHEN
def BUFFER_LOAD_SBYTE_D16_HI_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_IDXEN
def BUFFER_LOAD_SBYTE_D16_HI_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_OFFEN
def BUFFER_LOAD_SBYTE_D16_HI_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_OFFSET
def BUFFER_LOAD_SBYTE_D16_HI_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$hi16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$hi16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_BOTHEN
def BUFFER_LOAD_SBYTE_D16_HI_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_IDXEN
def BUFFER_LOAD_SBYTE_D16_HI_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFEN
def BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFSET
def BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_HI_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_IDXEN
def BUFFER_LOAD_SBYTE_D16_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_OFFEN
def BUFFER_LOAD_SBYTE_D16_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_OFFSET
def BUFFER_LOAD_SBYTE_D16_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_BOTHEN
def BUFFER_LOAD_SBYTE_D16_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_IDXEN
def BUFFER_LOAD_SBYTE_D16_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$sext16, (LLVMSExt (GetVal ?:$tmp), si_llvm_i16_ty)), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$sext16), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_OFFEN
def BUFFER_LOAD_SBYTE_D16_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_OFFSET
def BUFFER_LOAD_SBYTE_D16_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_D16_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_D16_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_D16_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_IDXEN
def BUFFER_LOAD_SBYTE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_BOTHEN
def BUFFER_LOAD_SBYTE_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_IDXEN
def BUFFER_LOAD_SBYTE_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_OFFEN
def BUFFER_LOAD_SBYTE_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_OFFSET
def BUFFER_LOAD_SBYTE_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_LOAD_SBYTE_OFFEN
def BUFFER_LOAD_SBYTE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_OFFSET
def BUFFER_LOAD_SBYTE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_BOTHEN
def BUFFER_LOAD_SBYTE_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_IDXEN
def BUFFER_LOAD_SBYTE_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_OFFEN
def BUFFER_LOAD_SBYTE_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_OFFSET
def BUFFER_LOAD_SBYTE_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_VBUFFER_BOTHEN
def BUFFER_LOAD_SBYTE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_VBUFFER_IDXEN
def BUFFER_LOAD_SBYTE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_VBUFFER_OFFEN
def BUFFER_LOAD_SBYTE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SBYTE_VBUFFER_OFFSET
def BUFFER_LOAD_SBYTE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SBYTE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_BOTHEN
def BUFFER_LOAD_SHORT_D16_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_BOTHEN
def BUFFER_LOAD_SHORT_D16_HI_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_IDXEN
def BUFFER_LOAD_SHORT_D16_HI_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_OFFEN
def BUFFER_LOAD_SHORT_D16_HI_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_OFFSET
def BUFFER_LOAD_SHORT_D16_HI_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_BOTHEN
def BUFFER_LOAD_SHORT_D16_HI_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_IDXEN
def BUFFER_LOAD_SHORT_D16_HI_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_OFFEN
def BUFFER_LOAD_SHORT_D16_HI_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_OFFSET
def BUFFER_LOAD_SHORT_D16_HI_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_VBUFFER_BOTHEN
def BUFFER_LOAD_SHORT_D16_HI_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_VBUFFER_IDXEN
def BUFFER_LOAD_SHORT_D16_HI_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFEN
def BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFSET
def BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_HI_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_IDXEN
def BUFFER_LOAD_SHORT_D16_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_OFFEN
def BUFFER_LOAD_SHORT_D16_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_OFFSET
def BUFFER_LOAD_SHORT_D16_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_BOTHEN
def BUFFER_LOAD_SHORT_D16_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_IDXEN
def BUFFER_LOAD_SHORT_D16_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_OFFEN
def BUFFER_LOAD_SHORT_D16_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_OFFSET
def BUFFER_LOAD_SHORT_D16_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_VBUFFER_BOTHEN
def BUFFER_LOAD_SHORT_D16_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_VBUFFER_IDXEN
def BUFFER_LOAD_SHORT_D16_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_VBUFFER_OFFEN
def BUFFER_LOAD_SHORT_D16_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SHORT_D16_VBUFFER_OFFSET
def BUFFER_LOAD_SHORT_D16_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SHORT_D16_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_SSHORT_BOTHEN
def BUFFER_LOAD_SSHORT_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_IDXEN
def BUFFER_LOAD_SSHORT_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_BOTHEN
def BUFFER_LOAD_SSHORT_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_IDXEN
def BUFFER_LOAD_SSHORT_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_OFFEN
def BUFFER_LOAD_SSHORT_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_OFFSET
def BUFFER_LOAD_SSHORT_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_VBUFFER_BOTHEN
def BUFFER_LOAD_SSHORT_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_VBUFFER_IDXEN
def BUFFER_LOAD_SSHORT_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFEN
def BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFSET
def BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_OFFEN
def BUFFER_LOAD_SSHORT_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_OFFSET
def BUFFER_LOAD_SSHORT_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_BOTHEN
def BUFFER_LOAD_SSHORT_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_IDXEN
def BUFFER_LOAD_SSHORT_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_OFFEN
def BUFFER_LOAD_SSHORT_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_OFFSET
def BUFFER_LOAD_SSHORT_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_SSHORT_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_SSHORT_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_VBUFFER_BOTHEN
def BUFFER_LOAD_SSHORT_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_VBUFFER_IDXEN
def BUFFER_LOAD_SSHORT_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_VBUFFER_OFFEN
def BUFFER_LOAD_SSHORT_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_SSHORT_VBUFFER_OFFSET
def BUFFER_LOAD_SSHORT_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_SSHORT_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_BOTHEN
def BUFFER_LOAD_UBYTE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_BOTHEN
def BUFFER_LOAD_UBYTE_D16_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_BOTHEN
def BUFFER_LOAD_UBYTE_D16_HI_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_IDXEN
def BUFFER_LOAD_UBYTE_D16_HI_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_OFFEN
def BUFFER_LOAD_UBYTE_D16_HI_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_OFFSET
def BUFFER_LOAD_UBYTE_D16_HI_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_BOTHEN
def BUFFER_LOAD_UBYTE_D16_HI_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_IDXEN
def BUFFER_LOAD_UBYTE_D16_HI_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFEN
def BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFSET
def BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_HI_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_IDXEN
def BUFFER_LOAD_UBYTE_D16_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_OFFEN
def BUFFER_LOAD_UBYTE_D16_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_OFFSET
def BUFFER_LOAD_UBYTE_D16_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_BOTHEN
def BUFFER_LOAD_UBYTE_D16_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_IDXEN
def BUFFER_LOAD_UBYTE_D16_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])), (DefVal ?:$vdata_hi, (LLVMShl (LLVMZExt (GetVal ?:$tmp), si_llvm_i32_ty), 16)), (DefVal ?:$vdata_lo, (LLVMAnd (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 65535))), (SetNamedOperand ?:$vdata, (LLVMOr (GetVal ?:$vdata_hi), (GetVal ?:$vdata_lo)))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_OFFEN
def BUFFER_LOAD_UBYTE_D16_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_OFFSET
def BUFFER_LOAD_UBYTE_D16_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_D16_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_D16_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_D16_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_IDXEN
def BUFFER_LOAD_UBYTE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_BOTHEN
def BUFFER_LOAD_UBYTE_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_IDXEN
def BUFFER_LOAD_UBYTE_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_OFFEN
def BUFFER_LOAD_UBYTE_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_OFFSET
def BUFFER_LOAD_UBYTE_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_load_lds, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (ConstantInt si_llvm_i32_ty, 1), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_LOAD_UBYTE_OFFEN
def BUFFER_LOAD_UBYTE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_OFFSET
def BUFFER_LOAD_UBYTE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_BOTHEN
def BUFFER_LOAD_UBYTE_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_IDXEN
def BUFFER_LOAD_UBYTE_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_OFFEN
def BUFFER_LOAD_UBYTE_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_OFFSET
def BUFFER_LOAD_UBYTE_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_VBUFFER_BOTHEN
def BUFFER_LOAD_UBYTE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_VBUFFER_IDXEN
def BUFFER_LOAD_UBYTE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_VBUFFER_OFFEN
def BUFFER_LOAD_UBYTE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_UBYTE_VBUFFER_OFFSET
def BUFFER_LOAD_UBYTE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_UBYTE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i8_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_BOTHEN
def BUFFER_LOAD_USHORT_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_IDXEN
def BUFFER_LOAD_USHORT_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_BOTHEN
def BUFFER_LOAD_USHORT_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_IDXEN
def BUFFER_LOAD_USHORT_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_OFFEN
def BUFFER_LOAD_USHORT_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_OFFSET
def BUFFER_LOAD_USHORT_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_VBUFFER_BOTHEN
def BUFFER_LOAD_USHORT_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_VBUFFER_IDXEN
def BUFFER_LOAD_USHORT_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFEN
def BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFSET
def BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_OFFEN
def BUFFER_LOAD_USHORT_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_OFFSET
def BUFFER_LOAD_USHORT_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_BOTHEN
def BUFFER_LOAD_USHORT_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_IDXEN
def BUFFER_LOAD_USHORT_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_OFFEN
def BUFFER_LOAD_USHORT_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_OFFSET
def BUFFER_LOAD_USHORT_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_USHORT_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_USHORT_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_VBUFFER_BOTHEN
def BUFFER_LOAD_USHORT_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_VBUFFER_IDXEN
def BUFFER_LOAD_USHORT_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_VBUFFER_OFFEN
def BUFFER_LOAD_USHORT_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_LOAD_USHORT_VBUFFER_OFFSET
def BUFFER_LOAD_USHORT_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_USHORT_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_i16_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// _exact alias of BUFFER_STORE_BYTE_BOTHEN
def BUFFER_STORE_BYTE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_BOTHEN
def BUFFER_STORE_BYTE_D16_HI_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_IDXEN
def BUFFER_STORE_BYTE_D16_HI_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_OFFEN
def BUFFER_STORE_BYTE_D16_HI_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_OFFSET
def BUFFER_STORE_BYTE_D16_HI_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_BOTHEN
def BUFFER_STORE_BYTE_D16_HI_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_IDXEN
def BUFFER_STORE_BYTE_D16_HI_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_OFFEN
def BUFFER_STORE_BYTE_D16_HI_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_OFFSET
def BUFFER_STORE_BYTE_D16_HI_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_IDXEN
def BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFEN
def BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFSET
def BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_VBUFFER_BOTHEN
def BUFFER_STORE_BYTE_D16_HI_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_VBUFFER_IDXEN
def BUFFER_STORE_BYTE_D16_HI_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFEN
def BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFSET
def BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_D16_HI_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_IDXEN
def BUFFER_STORE_BYTE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_OFFEN
def BUFFER_STORE_BYTE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_OFFSET
def BUFFER_STORE_BYTE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_BOTHEN
def BUFFER_STORE_BYTE_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_IDXEN
def BUFFER_STORE_BYTE_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_OFFEN
def BUFFER_STORE_BYTE_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_OFFSET
def BUFFER_STORE_BYTE_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_BYTE_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_VBUFFER_IDXEN
def BUFFER_STORE_BYTE_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_VBUFFER_OFFEN
def BUFFER_STORE_BYTE_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_TFE_VBUFFER_OFFSET
def BUFFER_STORE_BYTE_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_VBUFFER_BOTHEN
def BUFFER_STORE_BYTE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_VBUFFER_IDXEN
def BUFFER_STORE_BYTE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_VBUFFER_OFFEN
def BUFFER_STORE_BYTE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_BYTE_VBUFFER_OFFSET
def BUFFER_STORE_BYTE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_BYTE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp8, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i8_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp8), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_BOTHEN
def BUFFER_STORE_DWORDX2_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_IDXEN
def BUFFER_STORE_DWORDX2_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_OFFEN
def BUFFER_STORE_DWORDX2_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_OFFSET
def BUFFER_STORE_DWORDX2_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_BOTHEN
def BUFFER_STORE_DWORDX2_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_IDXEN
def BUFFER_STORE_DWORDX2_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_OFFEN
def BUFFER_STORE_DWORDX2_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_OFFSET
def BUFFER_STORE_DWORDX2_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_DWORDX2_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_VBUFFER_IDXEN
def BUFFER_STORE_DWORDX2_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFEN
def BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFSET
def BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_VBUFFER_BOTHEN
def BUFFER_STORE_DWORDX2_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_VBUFFER_IDXEN
def BUFFER_STORE_DWORDX2_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_VBUFFER_OFFEN
def BUFFER_STORE_DWORDX2_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX2_VBUFFER_OFFSET
def BUFFER_STORE_DWORDX2_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX2_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_BOTHEN
def BUFFER_STORE_DWORDX3_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_IDXEN
def BUFFER_STORE_DWORDX3_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_OFFEN
def BUFFER_STORE_DWORDX3_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_OFFSET
def BUFFER_STORE_DWORDX3_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_BOTHEN
def BUFFER_STORE_DWORDX3_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_IDXEN
def BUFFER_STORE_DWORDX3_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_OFFEN
def BUFFER_STORE_DWORDX3_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_OFFSET
def BUFFER_STORE_DWORDX3_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_DWORDX3_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_VBUFFER_IDXEN
def BUFFER_STORE_DWORDX3_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFEN
def BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFSET
def BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_VBUFFER_BOTHEN
def BUFFER_STORE_DWORDX3_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_VBUFFER_IDXEN
def BUFFER_STORE_DWORDX3_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_VBUFFER_OFFEN
def BUFFER_STORE_DWORDX3_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX3_VBUFFER_OFFSET
def BUFFER_STORE_DWORDX3_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX3_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_BOTHEN
def BUFFER_STORE_DWORDX4_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_IDXEN
def BUFFER_STORE_DWORDX4_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_OFFEN
def BUFFER_STORE_DWORDX4_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_OFFSET
def BUFFER_STORE_DWORDX4_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_BOTHEN
def BUFFER_STORE_DWORDX4_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_IDXEN
def BUFFER_STORE_DWORDX4_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_OFFEN
def BUFFER_STORE_DWORDX4_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_OFFSET
def BUFFER_STORE_DWORDX4_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_DWORDX4_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_VBUFFER_IDXEN
def BUFFER_STORE_DWORDX4_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFEN
def BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFSET
def BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_VBUFFER_BOTHEN
def BUFFER_STORE_DWORDX4_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_VBUFFER_IDXEN
def BUFFER_STORE_DWORDX4_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_VBUFFER_OFFEN
def BUFFER_STORE_DWORDX4_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORDX4_VBUFFER_OFFSET
def BUFFER_STORE_DWORDX4_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORDX4_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_BOTHEN
def BUFFER_STORE_DWORD_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_IDXEN
def BUFFER_STORE_DWORD_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_OFFEN
def BUFFER_STORE_DWORD_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_OFFSET
def BUFFER_STORE_DWORD_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_BOTHEN
def BUFFER_STORE_DWORD_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_IDXEN
def BUFFER_STORE_DWORD_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_OFFEN
def BUFFER_STORE_DWORD_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_OFFSET
def BUFFER_STORE_DWORD_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_DWORD_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_VBUFFER_IDXEN
def BUFFER_STORE_DWORD_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_VBUFFER_OFFEN
def BUFFER_STORE_DWORD_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_TFE_VBUFFER_OFFSET
def BUFFER_STORE_DWORD_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_VBUFFER_BOTHEN
def BUFFER_STORE_DWORD_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_VBUFFER_IDXEN
def BUFFER_STORE_DWORD_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_VBUFFER_OFFEN
def BUFFER_STORE_DWORD_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_DWORD_VBUFFER_OFFSET
def BUFFER_STORE_DWORD_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_DWORD_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_BOTHEN
def BUFFER_STORE_FORMAT_D16_HI_X_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_IDXEN
def BUFFER_STORE_FORMAT_D16_HI_X_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_IDXEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_OFFEN
def BUFFER_STORE_FORMAT_D16_HI_X_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_OFFEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_OFFSET
def BUFFER_STORE_FORMAT_D16_HI_X_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_OFFSET_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_HI_X_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$shifted, (LLVMLShr (GetNamedOperand ?:$vdata), (ConstantInt si_llvm_i32_ty, 16))), (DefVal ?:$half, (LLVMTrunc (GetVal ?:$shifted), si_llvm_i16_ty)), (DefVal ?:$fval, (LLVMBitCast (GetVal ?:$half), si_llvm_half_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetVal ?:$fval), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_IDXEN
def BUFFER_STORE_FORMAT_D16_X_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_OFFEN
def BUFFER_STORE_FORMAT_D16_X_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_OFFSET
def BUFFER_STORE_FORMAT_D16_X_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_X_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_X_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_X_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_BOTHEN
def BUFFER_STORE_FORMAT_XYZW_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_IDXEN
def BUFFER_STORE_FORMAT_XYZW_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_OFFEN
def BUFFER_STORE_FORMAT_XYZW_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_OFFSET
def BUFFER_STORE_FORMAT_XYZW_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_BOTHEN
def BUFFER_STORE_FORMAT_XYZW_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_IDXEN
def BUFFER_STORE_FORMAT_XYZW_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_OFFEN
def BUFFER_STORE_FORMAT_XYZW_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_OFFSET
def BUFFER_STORE_FORMAT_XYZW_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZW_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_BOTHEN
def BUFFER_STORE_FORMAT_XYZ_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_IDXEN
def BUFFER_STORE_FORMAT_XYZ_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_OFFEN
def BUFFER_STORE_FORMAT_XYZ_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_OFFSET
def BUFFER_STORE_FORMAT_XYZ_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_BOTHEN
def BUFFER_STORE_FORMAT_XYZ_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_IDXEN
def BUFFER_STORE_FORMAT_XYZ_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_OFFEN
def BUFFER_STORE_FORMAT_XYZ_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_OFFSET
def BUFFER_STORE_FORMAT_XYZ_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XYZ_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_BOTHEN
def BUFFER_STORE_FORMAT_XY_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_IDXEN
def BUFFER_STORE_FORMAT_XY_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_OFFEN
def BUFFER_STORE_FORMAT_XY_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_OFFSET
def BUFFER_STORE_FORMAT_XY_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_BOTHEN
def BUFFER_STORE_FORMAT_XY_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_IDXEN
def BUFFER_STORE_FORMAT_XY_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_OFFEN
def BUFFER_STORE_FORMAT_XY_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_OFFSET
def BUFFER_STORE_FORMAT_XY_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_XY_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_BOTHEN
def BUFFER_STORE_FORMAT_X_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_IDXEN
def BUFFER_STORE_FORMAT_X_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_OFFEN
def BUFFER_STORE_FORMAT_X_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_OFFSET
def BUFFER_STORE_FORMAT_X_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_BOTHEN
def BUFFER_STORE_FORMAT_X_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_IDXEN
def BUFFER_STORE_FORMAT_X_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_OFFEN
def BUFFER_STORE_FORMAT_X_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_OFFSET
def BUFFER_STORE_FORMAT_X_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_X_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_X_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_X_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_X_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_FORMAT_X_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_X_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_X_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_BOTHEN
def BUFFER_STORE_SHORT_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_BOTHEN
def BUFFER_STORE_SHORT_D16_HI_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_IDXEN
def BUFFER_STORE_SHORT_D16_HI_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_OFFEN
def BUFFER_STORE_SHORT_D16_HI_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_OFFSET
def BUFFER_STORE_SHORT_D16_HI_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_BOTHEN
def BUFFER_STORE_SHORT_D16_HI_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_IDXEN
def BUFFER_STORE_SHORT_D16_HI_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_OFFEN
def BUFFER_STORE_SHORT_D16_HI_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_OFFSET
def BUFFER_STORE_SHORT_D16_HI_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_IDXEN
def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFEN
def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFSET
def BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_VBUFFER_BOTHEN
def BUFFER_STORE_SHORT_D16_HI_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_VBUFFER_IDXEN
def BUFFER_STORE_SHORT_D16_HI_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFEN
def BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFSET
def BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_D16_HI_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_IDXEN
def BUFFER_STORE_SHORT_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_OFFEN
def BUFFER_STORE_SHORT_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_OFFSET
def BUFFER_STORE_SHORT_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_BOTHEN
def BUFFER_STORE_SHORT_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_IDXEN
def BUFFER_STORE_SHORT_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_OFFEN
def BUFFER_STORE_SHORT_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_OFFSET
def BUFFER_STORE_SHORT_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_SHORT_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_VBUFFER_IDXEN
def BUFFER_STORE_SHORT_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_VBUFFER_OFFEN
def BUFFER_STORE_SHORT_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_TFE_VBUFFER_OFFSET
def BUFFER_STORE_SHORT_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_VBUFFER_BOTHEN
def BUFFER_STORE_SHORT_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_VBUFFER_BOTHEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_VBUFFER_IDXEN
def BUFFER_STORE_SHORT_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_VBUFFER_IDXEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_VBUFFER_OFFEN
def BUFFER_STORE_SHORT_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_VBUFFER_OFFEN_exact> {
  let Semantic = [(DefVal ?:$tmp16, (LLVMTrunc (LLVMLShr (GetNamedOperand ?:$vdata), 16), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp16), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// _exact alias of BUFFER_STORE_SHORT_VBUFFER_OFFSET
def BUFFER_STORE_SHORT_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_SHORT_VBUFFER_OFFSET_exact> {
  let Semantic = [(DefVal ?:$tmp, (LLVMTrunc (GetNamedOperand ?:$vdata), si_llvm_i16_ty)), (LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store, [(GetVal ?:$tmp), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

//==============================================================================
// BUFFER _TFE / _LDS / _gfx80 cross-product aliases (Phase 8 pass 3)
//==============================================================================

// alias of BUFFER_LOAD_DWORDX3_ADDR64
def BUFFER_LOAD_DWORDX3_LDS_ADDR64_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_BOTHEN
def BUFFER_LOAD_DWORDX3_LDS_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_BOTHEN_exact
def BUFFER_LOAD_DWORDX3_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_IDXEN
def BUFFER_LOAD_DWORDX3_LDS_IDXEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_IDXEN_exact
def BUFFER_LOAD_DWORDX3_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_OFFEN
def BUFFER_LOAD_DWORDX3_LDS_OFFEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_OFFEN_exact
def BUFFER_LOAD_DWORDX3_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_OFFSET
def BUFFER_LOAD_DWORDX3_LDS_OFFSET_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_OFFSET_exact
def BUFFER_LOAD_DWORDX3_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_ADDR64
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_IDXEN_exact
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_OFFEN_exact
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX3_VBUFFER_OFFSET_exact
def BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX3_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_ADDR64
def BUFFER_LOAD_DWORDX4_LDS_ADDR64_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_BOTHEN
def BUFFER_LOAD_DWORDX4_LDS_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_BOTHEN_exact
def BUFFER_LOAD_DWORDX4_LDS_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_IDXEN
def BUFFER_LOAD_DWORDX4_LDS_IDXEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_IDXEN_exact
def BUFFER_LOAD_DWORDX4_LDS_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_OFFEN
def BUFFER_LOAD_DWORDX4_LDS_OFFEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_OFFEN_exact
def BUFFER_LOAD_DWORDX4_LDS_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_OFFSET
def BUFFER_LOAD_DWORDX4_LDS_OFFSET_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_OFFSET_exact
def BUFFER_LOAD_DWORDX4_LDS_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_ADDR64
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_BOTHEN
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_IDXEN
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_IDXEN_exact
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_OFFEN
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_OFFEN_exact
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_OFFSET
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_DWORDX4_VBUFFER_OFFSET_exact
def BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_DWORDX4_LDS_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4i32_ty, int_amdgcn_struct_buffer_load, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v4f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v3f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_ADDR64
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_ADDR64
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_TFE_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_XY_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_v2f16_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_ADDR64
def BUFFER_LOAD_FORMAT_D16_X_gfx80_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_ADDR64
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_TFE_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_ADDR64
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_BOTHEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_IDXEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFEN_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_LOAD_FORMAT_D16_X_VBUFFER_OFFSET_exact
def BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_LOAD_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(SetNamedOperand ?:$vdata, (LLVMIntrinsic si_llvm_half_ty, int_amdgcn_struct_buffer_load_format, [(LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)]))];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_TFE_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZW_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZW_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_TFE_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XYZ_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XYZ_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_ADDR64
def BUFFER_STORE_FORMAT_D16_XY_gfx80_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_ADDR64
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_TFE_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_XY_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_XY_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_ADDR64
def BUFFER_STORE_FORMAT_D16_X_gfx80_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_IDXEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_OFFEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_OFFSET
def BUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_ADDR64
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_IDXEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_OFFEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_OFFSET
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_TFE_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_TFE_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_ADDR64
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_ADDR64_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_ADDR64> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_BOTHEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_BOTHEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_IDXEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_IDXEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFEN_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFEN_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (GetNamedOperand ?:$vaddr), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}

// alias of BUFFER_STORE_FORMAT_D16_X_VBUFFER_OFFSET_exact
def BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact_sem : InstSISemantic<BUFFER_STORE_FORMAT_D16_X_gfx80_VBUFFER_OFFSET_exact> {
  let Semantic = [(LLVMIntrinsic si_llvm_void_ty, int_amdgcn_struct_buffer_store_format, [(GetNamedOperand ?:$vdata), (LLVMBitCast (GetNamedOperand ?:$srsrc), si_llvm_v4i32_ty), (ConstantInt si_llvm_i32_ty, 0), (GetNamedOperand ?:$offset), (GetNamedOperand ?:$soffset), (GetNamedOperand ?:$cpol)])];
}
