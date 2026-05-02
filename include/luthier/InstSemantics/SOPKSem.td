//===- SOPKSem.td -----------------------------------------------------*- tblgen -*-===//
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
// SOPK Instructions
//------------------------------------------------------------------------------

// D.i = D.i + signext(SIMM16); SCC = unsigned overflow.
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 119.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 111.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 123.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 116.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 212.
//   rdna4-instruction-set-architecture.pdf, page 175.
def S_ADDK_I32_sem : InstSISemantic<S_ADDK_I32> {
  let Semantic = [
    (DefVal $tmp_add, (LLVMAdd (GetNamedOperand $src0), (GetNamedOperand $simm16))),
    SetSCCImplicit<(LLVMCmp LLVMICmpUGE, (GetVal $tmp_add), (ConstantInt si_llvm_i32_ty, 0x100000000))>.ret,
    (SetNamedOperand $sdst, (LLVMTrunc (GetVal $tmp_add), si_llvm_i32_ty))
  ];
}

// if (SCC) D.i = signext(SIMM16); else NOP.
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 119.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 109.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 121.
//   rdna-shader-instruction-set-architecture.pdf, page 115.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 209.
//   rdna4-instruction-set-architecture.pdf, page 176.
def S_CMOVK_I32_sem : InstSISemantic<S_CMOVK_I32> {
  let Semantic = [
    (DefVal $tmp, (LLVMSelect GetSCCImplicit.ret,
                            (GetNamedOperand $simm16), 
                            (GetNamedOperand $sdst))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

// D.i = signext(SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 123.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 109.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 121.
//   rdna-shader-instruction-set-architecture.pdf, page 115.
//   rdna2-shader-instruction-set-architecture.pdf, page 114.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 209.
//   rdna4-instruction-set-architecture.pdf, page 176.
def S_MOVK_I32_sem : InstSISemantic<S_MOVK_I32> {
  let Semantic = [
    (SetNamedOperand $sdst, (GetNamedOperand $simm16))
  ];
}

// D.i = D.i * signext(SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 123.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 111.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 123.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 116.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 212.
//   rdna4-instruction-set-architecture.pdf, page 176.
def S_MULK_I32_sem : InstSISemantic<S_MULK_I32> {
  let Semantic = [
    (DefVal $tmp, (LLVMMul (GetNamedOperand $src0), (GetNamedOperand $simm16))),
    (SetNamedOperand $sdst, (GetVal $tmp))
  ];
}

// SCC = (D.i == signext(SIMM16)).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 119.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 109.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 121.
//   rdna-shader-instruction-set-architecture.pdf, page 115.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_EQ_I32_sem : InstSISemantic<S_CMPK_EQ_I32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpEQ, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.u == SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 120.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 110.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 122.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_EQ_U32_sem : InstSISemantic<S_CMPK_EQ_U32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpEQ, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.i >= signext(SIMM16)).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 120.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 110.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 122.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_GE_I32_sem : InstSISemantic<S_CMPK_GE_I32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpSGE, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.u >= SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 120.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 111.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 123.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_GE_U32_sem : InstSISemantic<S_CMPK_GE_U32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpUGE, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.i > signext(SIMM16)).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 120.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 109.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 121.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_GT_I32_sem : InstSISemantic<S_CMPK_GT_I32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpSGT, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.u > SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 121.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 111.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 123.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_GT_U32_sem : InstSISemantic<S_CMPK_GT_U32> {
  let Semantic = [
     SetSCCImplicit<(LLVMCmp LLVMICmpUGT, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.i <= signext(SIMM16)).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 121.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 110.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 122.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_LE_I32_sem : InstSISemantic<S_CMPK_LE_I32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpSLE, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.u <= SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 121.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 111.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 123.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_LE_U32_sem : InstSISemantic<S_CMPK_LE_U32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpULE, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.i != signext(SIMM16)).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 121.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 109.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 121.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_LG_I32_sem : InstSISemantic<S_CMPK_LG_I32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpNE, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.u != SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 122.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 110.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 122.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_LG_U32_sem : InstSISemantic<S_CMPK_LG_U32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpNE, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.i < signext(SIMM16)).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 122.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 110.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 122.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_LT_I32_sem : InstSISemantic<S_CMPK_LT_I32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpSLT, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

// SCC = (D.u < SIMM16).
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 122.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 105.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 104.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 111.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 123.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 115.
def S_CMPK_LT_U32_sem : InstSISemantic<S_CMPK_LT_U32> {
  let Semantic = [
    SetSCCImplicit<(LLVMCmp LLVMICmpULT, (GetNamedOperand $sdst), (GetNamedOperand $simm16))>.ret
  ];
}

//------------------------------------------------------------------------------
// S_GETREG_B32
//------------------------------------------------------------------------------

// D = HWREG[SIMM16]. Read a hardware register.
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 122.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 105.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 112.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 124.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 116.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 212.
//   rdna4-instruction-set-architecture.pdf, page 176.
def S_GETREG_B32_sem : InstSISemantic<S_GETREG_B32> {
  let Semantic = [
    (SetNamedOperand $sdst, (LLVMUnaryIntrinsic int_amdgcn_s_getreg, (GetNamedOperand $simm16)))
  ];
}

//------------------------------------------------------------------------------
// S_SETREG_B32
//------------------------------------------------------------------------------

// HWREG[SIMM16] = S0. Write a hardware register.
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 123.
//   vega-7nm-shader-instruction-set-architecture.pdf, page 107.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, page 106.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, page 105.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, page 112.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, page 124.
//   rdna-shader-instruction-set-architecture.pdf, page 116.
//   rdna2-shader-instruction-set-architecture.pdf, page 116.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, page 213.
//   rdna4-instruction-set-architecture.pdf, page 176.
def S_SETREG_B32_sem : InstSISemantic<S_SETREG_B32> {
  let Semantic = [
    (LLVMBinaryIntrinsic int_amdgcn_s_setreg, (GetNamedOperand $simm16), (GetNamedOperand $sdst))
  ];
}

//------------------------------------------------------------------------------
// S_CBRANCH_I_FORK
//------------------------------------------------------------------------------

// S_CBRANCH_I_FORK: Fork with integer operand.
// $sdst = SGPR to store current EXEC mask
// $simm16 = PC-relative target (already translated to BasicBlock)
// mask_pass = exec & sdst
// mask_fail = exec & ~sdst
// Only available on GFX6-GFX9.
// Sources:
//   gcn3-instruction-set-architecture.pdf, page 112.
//def S_CBRANCH_I_FORK_sem : InstSISemantic<S_CBRANCH_I_FORK> {
//  let Semantic = [
//    // Get current PC for branch stack entry
//    (DefVal $current_pc, (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_s_getpc, []<dag>)),
//    // Store current EXEC to sdst
//    (SetNamedOperand $sdst, (ImplicitUse EXEC)),
//    // Compute pass and fail masks
//    (DefVal $pass_mask, (LLVMAnd (ImplicitUse EXEC), (GetNamedOperand $sdst))),
//    (DefVal $fail_mask, (LLVMAnd (ImplicitUse EXEC),
//                               (LLVMXor (GetNamedOperand $sdst),
//                                        (ConstantInt si_llvm_i64_ty, -1)))),
//    // Get CSP from MODE register (hwmode = 5953, returns i32)
//    (DefVal $csp, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_s_getreg,
//      [(ConstantInt si_llvm_i16_ty, 5953)]<dag>)),
//    // Read SGPR quads and bitcast to 128-bit vectors
//    (DefVal $sgpr0_3, (LLVMBitCast (ImplicitUse SGPR0_SGPR1_SGPR2_SGPR3), si_llvm_i128_ty)),
//    (DefVal $sgpr4_7, (LLVMBitCast (ImplicitUse SGPR4_SGPR5_SGPR6_SGPR7), si_llvm_i128_ty)),
//    (DefVal $sgpr8_11, (LLVMBitCast (ImplicitUse SGPR8_SGPR9_SGPR10_SGPR11), si_llvm_i128_ty)),
//    (DefVal $sgpr12_15, (LLVMBitCast (ImplicitUse SGPR12_SGPR13_SGPR14_SGPR15), si_llvm_i128_ty)),
//    (DefVal $sgpr16_19, (LLVMBitCast (ImplicitUse SGPR16_SGPR17_SGPR18_SGPR19), si_llvm_i128_ty)),
//    (DefVal $sgpr20_23, (LLVMBitCast (ImplicitUse SGPR20_SGPR21_SGPR22_SGPR23), si_llvm_i128_ty)),
//    // Create 6x128-bit vector of SGPR values
//    (DefVal $sgpr_vec, (LLVMInsertElement
//      (LLVMInsertElement
//        (LLVMInsertElement
//          (LLVMInsertElement
//            (LLVMInsertElement
//              (LLVMInsertElement (ConstantPoison si_llvm_v6i128_ty),
//                                 (GetVal $sgpr0_3), (ConstantInt si_llvm_i32_ty, 0)),
//                                 (GetVal $sgpr4_7), (ConstantInt si_llvm_i32_ty, 1)),
//                                 (GetVal $sgpr8_11), (ConstantInt si_llvm_i32_ty, 2)),
//                                 (GetVal $sgpr12_15), (ConstantInt si_llvm_i32_ty, 3)),
//                                 (GetVal $sgpr16_19), (ConstantInt si_llvm_i32_ty, 4)),
//                                 (GetVal $sgpr20_23), (ConstantInt si_llvm_i32_ty, 5))),
//    // Extract element at CSP index
//    (DefVal $csp_val, (LLVMExtractElement (GetVal $sgpr_vec), (GetVal $csp))),
//    // Branch to target (simm16 is already a BasicBlock)
//    (LLVMBranch (GetNamedOperand $simm16))
//  ];
//}
//
//def S_CBRANCH_I_FORK_gfx6_gfx7_sem : InstSISemantic<S_CBRANCH_I_FORK_gfx6_gfx7> {
//  let Semantic = [
//    (DefVal $current_pc, (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_s_getpc, []<dag>)),
//    (SetNamedOperand $sdst, (ImplicitUse EXEC)),
//    (DefVal $pass_mask, (LLVMAnd (ImplicitUse EXEC), (GetNamedOperand $sdst))),
//    (DefVal $fail_mask, (LLVMAnd (ImplicitUse EXEC),
//                               (LLVMXor (GetNamedOperand $sdst),
//                                        (ConstantInt si_llvm_i64_ty, -1)))),
//    (DefVal $csp, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_s_getreg,
//      [(ConstantInt si_llvm_i16_ty, 5953)]<dag>)),
//    (DefVal $sgpr0_3, (LLVMBitCast (ImplicitUse SGPR0_SGPR1_SGPR2_SGPR3), si_llvm_i128_ty)),
//    (DefVal $sgpr4_7, (LLVMBitCast (ImplicitUse SGPR4_SGPR5_SGPR6_SGPR7), si_llvm_i128_ty)),
//    (DefVal $sgpr8_11, (LLVMBitCast (ImplicitUse SGPR8_SGPR9_SGPR10_SGPR11), si_llvm_i128_ty)),
//    (DefVal $sgpr12_15, (LLVMBitCast (ImplicitUse SGPR12_SGPR13_SGPR14_SGPR15), si_llvm_i128_ty)),
//    (DefVal $sgpr16_19, (LLVMBitCast (ImplicitUse SGPR16_SGPR17_SGPR18_SGPR19), si_llvm_i128_ty)),
//    (DefVal $sgpr20_23, (LLVMBitCast (ImplicitUse SGPR20_SGPR21_SGPR22_SGPR23), si_llvm_i128_ty)),
//    (DefVal $sgpr_vec, (LLVMInsertElement
//      (LLVMInsertElement
//        (LLVMInsertElement
//          (LLVMInsertElement
//            (LLVMInsertElement
//              (LLVMInsertElement (ConstantPoison si_llvm_v6i128_ty),
//                                 (GetVal $sgpr0_3), (ConstantInt si_llvm_i32_ty, 0)),
//                                 (GetVal $sgpr4_7), (ConstantInt si_llvm_i32_ty, 1)),
//                                 (GetVal $sgpr8_11), (ConstantInt si_llvm_i32_ty, 2)),
//                                 (GetVal $sgpr12_15), (ConstantInt si_llvm_i32_ty, 3)),
//                                 (GetVal $sgpr16_19), (ConstantInt si_llvm_i32_ty, 4)),
//                                 (GetVal $sgpr20_23), (ConstantInt si_llvm_i32_ty, 5))),
//    (DefVal $csp_val, (LLVMExtractElement (GetVal $sgpr_vec), (GetVal $csp))),
//    (LLVMBranch (GetNamedOperand $simm16))
//  ];
//}
//
//def S_CBRANCH_I_FORK_vi_sem : InstSISemantic<S_CBRANCH_I_FORK_vi> {
//  let Semantic = [
//    (DefVal $current_pc, (LLVMIntrinsic si_llvm_i64_ty, int_amdgcn_s_getpc, []<dag>)),
//    (SetNamedOperand $sdst, (ImplicitUse EXEC)),
//    (DefVal $pass_mask, (LLVMAnd (ImplicitUse EXEC), (GetNamedOperand $sdst))),
//    (DefVal $fail_mask, (LLVMAnd (ImplicitUse EXEC),
//                               (LLVMXor (GetNamedOperand $sdst),
//                                        (ConstantInt si_llvm_i64_ty, -1)))),
//    (DefVal $csp, (LLVMIntrinsic si_llvm_i32_ty, int_amdgcn_s_getreg,
//      [(ConstantInt si_llvm_i16_ty, 5953)]<dag>)),
//    (DefVal $sgpr0_3, (LLVMBitCast (ImplicitUse SGPR0_SGPR1_SGPR2_SGPR3), si_llvm_i128_ty)),
//    (DefVal $sgpr4_7, (LLVMBitCast (ImplicitUse SGPR4_SGPR5_SGPR6_SGPR7), si_llvm_i128_ty)),
//    (DefVal $sgpr8_11, (LLVMBitCast (ImplicitUse SGPR8_SGPR9_SGPR10_SGPR11), si_llvm_i128_ty)),
//    (DefVal $sgpr12_15, (LLVMBitCast (ImplicitUse SGPR12_SGPR13_SGPR14_SGPR15), si_llvm_i128_ty)),
//    (DefVal $sgpr16_19, (LLVMBitCast (ImplicitUse SGPR16_SGPR17_SGPR18_SGPR19), si_llvm_i128_ty)),
//    (DefVal $sgpr20_23, (LLVMBitCast (ImplicitUse SGPR20_SGPR21_SGPR22_SGPR23), si_llvm_i128_ty)),
//    (DefVal $sgpr_vec, (LLVMInsertElement
//      (LLVMInsertElement
//        (LLVMInsertElement
//          (LLVMInsertElement
//            (LLVMInsertElement
//              (LLVMInsertElement (ConstantPoison si_llvm_v6i128_ty),
//                                 (GetVal $sgpr0_3), (ConstantInt si_llvm_i32_ty, 0)),
//                                 (GetVal $sgpr4_7), (ConstantInt si_llvm_i32_ty, 1)),
//                                 (GetVal $sgpr8_11), (ConstantInt si_llvm_i32_ty, 2)),
//                                 (GetVal $sgpr12_15), (ConstantInt si_llvm_i32_ty, 3)),
//                                 (GetVal $sgpr16_19), (ConstantInt si_llvm_i32_ty, 4)),
//                                 (GetVal $sgpr20_23), (ConstantInt si_llvm_i32_ty, 5))),
//    (DefVal $csp_val, (LLVMExtractElement (GetVal $sgpr_vec), (GetVal $csp))),
//    (LLVMBranch (GetNamedOperand $simm16))
//  ];
//}
