//===- VOPCSem.td ------------------------------------------------*- tblgen -*-===//
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

//==============================================================================
// VOPC Instructions
//==============================================================================
//
// VOPC instructions perform per-lane comparisons and write the result to VCC
// (V_CMP) or EXEC (V_CMPX). Each lane gets a 1-bit comparison result.
//
// Variants:
//   V_CMP_*    : result → VCC
//   V_CMPS_*   : signaling float compare, result → VCC (GFX6/GFX7 only)
//   V_CMPX_*   : result → VCC and EXEC
//   V_CMPX_*_nosdst : result → EXEC only (GFX10+, HasNoSdstCMPX)
//   V_CMPSX_*  : signaling float compare, result → VCC and EXEC (GFX6/GFX7)
//   V_CMPSX_*_nosdst : signaling, result → EXEC only (GFX6/GFX7)
//   *_t16      : True16 encoding variant (same semantics)
//
// PDF sources for VOPC instructions (VCC = S0 <cmp> S1):
//   gcn3-instruction-set-architecture.pdf, pages 226-260.
//   vega-shader-instruction-set-architecture.pdf, pages 151-164.
//   vega-7nm-shader-instruction-set-architecture.pdf, pages 152-165.
//   instinct-mi100-cdna1-shader-instruction-set-architecture.pdf, pages 145-158.
//   instinct-mi200-cdna2-instruction-set-architecture.pdf, pages 145-158.
//   amd-instinct-mi300-cdna3-instruction-set-architecture.pdf, pages 216-260.
//   amd-instinct-cdna4-instruction-set-architecture.pdf, pages 230-274.
//   rdna-shader-instruction-set-architecture.pdf, pages 161-178.
//   rdna2-shader-instruction-set-architecture.pdf, pages 158-175.
//   rdna3-shader-instruction-set-architecture-feb-2023_0.pdf, pages 305-370.
//   rdna4-instruction-set-architecture.pdf, pages 347-410.

//------------------------------------------------------------------------------
// VOPC F32 Ordered Float Comparisons
//------------------------------------------------------------------------------

// VCC = S0.f <cmp> S1.f (ordered: both operands must not be NaN).
foreach i = 0-5 in {
  defvar cmpName = ["EQ", "LG", "GT", "GE", "LT", "LE"][i];
  defvar cmpPred = [LLVMFCmpOEQ, LLVMFCmpONE, LLVMFCmpOGT, LLVMFCmpOGE, LLVMFCmpOLT, LLVMFCmpOLE][i];

  // V_CMP → VCC
  def V_CMP_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  // V_CMPS → VCC (signaling, GFX6/GFX7 only, same semantics)
  def V_CMPS_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  // V_CMPX → VCC + EXEC
  def V_CMPX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }

  // V_CMPX_nosdst → EXEC only
  def V_CMPX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  // V_CMPSX → VCC + EXEC (signaling, GFX6/GFX7 only)
  def V_CMPSX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }

  // V_CMPSX_nosdst → EXEC only (signaling, GFX6/GFX7 only)
  def V_CMPSX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }
}

//------------------------------------------------------------------------------
// VOPC F32 Unordered Float Comparisons
//------------------------------------------------------------------------------

// VCC = !(S0.f <cmp> S1.f) (unordered: true if either operand is NaN).
foreach i = 0-5 in {
  defvar cmpName = ["NEQ", "NLG", "NGT", "NGE", "NLT", "NLE"][i];
  defvar cmpPred = [LLVMFCmpUNE, LLVMFCmpUEQ, LLVMFCmpULE, LLVMFCmpULT, LLVMFCmpUGE, LLVMFCmpUGT][i];

  def V_CMP_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  def V_CMPS_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  def V_CMPX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }

  def V_CMPX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  def V_CMPSX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }

  def V_CMPSX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }
}

//------------------------------------------------------------------------------
// VOPC F32 Special Float Comparisons (Ordered/Unordered/False/True)
//------------------------------------------------------------------------------

// O = ordered (both not NaN), U = unordered (either is NaN)
foreach i = 0-1 in {
  defvar cmpName = ["O", "U"][i];
  defvar cmpPred = [LLVMFCmpORD, LLVMFCmpUNO][i];

  def V_CMP_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  def V_CMPS_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  def V_CMPX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }

  def V_CMPX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }

  def V_CMPSX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }

  def V_CMPSX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_float_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_float_ty))>.ret)
    ];
  }
}

// F = always false, TRU = always true (F32)
// Constant wave mask: sext i1 const → iWaveSize (all-zeros / all-ones).
foreach i = 0-1 in {
  defvar cmpName = ["F", "TRU"][i];
  defvar constVal = [ConstantFalse, ConstantTrue][i];

  def V_CMP_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, (LLVMSExt (constVal si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize))))
    ];
  }
  def V_CMPS_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (ImplicitDef VCC, (LLVMSExt (constVal si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize))))
    ];
  }
  def V_CMPX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $r, (LLVMSExt (constVal si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)))),
      (ImplicitDef VCC, (GetVal $r)),
      (ImplicitDef EXEC, (GetVal $r))
    ];
  }
  def V_CMPX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, (LLVMSExt (constVal si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize))))
    ];
  }
  def V_CMPSX_#cmpName#_F32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_e32")> {
    let Semantic = [
      (DefVal $r, (LLVMSExt (constVal si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)))),
      (ImplicitDef VCC, (GetVal $r)),
      (ImplicitDef EXEC, (GetVal $r))
    ];
  }
  def V_CMPSX_#cmpName#_F32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F32_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, (LLVMSExt (constVal si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize))))
    ];
  }
}

//------------------------------------------------------------------------------
// VOPC F64 Float Comparisons (all predicates)
// Same patterns as F32 but with si_llvm_double_ty. No CMPS/CMPSX t16 variants.
//------------------------------------------------------------------------------

// F64 ordered comparisons
foreach i = 0-5 in {
  defvar cmpName = ["EQ", "LG", "GT", "GE", "LT", "LE"][i];
  defvar cmpPred = [LLVMFCmpOEQ, LLVMFCmpONE, LLVMFCmpOGT, LLVMFCmpOGE, LLVMFCmpOLT, LLVMFCmpOLE][i];

  def V_CMP_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
  def V_CMPS_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
  def V_CMPX_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }
  def V_CMPX_#cmpName#_F64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F64_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
  def V_CMPSX_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }
  def V_CMPSX_#cmpName#_F64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F64_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
}

// F64 unordered comparisons
foreach i = 0-5 in {
  defvar cmpName = ["NEQ", "NLG", "NGT", "NGE", "NLT", "NLE"][i];
  defvar cmpPred = [LLVMFCmpUNE, LLVMFCmpUEQ, LLVMFCmpULE, LLVMFCmpULT, LLVMFCmpUGE, LLVMFCmpUGT][i];

  def V_CMP_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
  def V_CMPS_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
  def V_CMPX_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }
  def V_CMPX_#cmpName#_F64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F64_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
  def V_CMPSX_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F64_e32")> {
    let Semantic = [
      (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
        (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty),
        (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret),
      (ImplicitDef VCC, (GetVal $result)),
      (ImplicitDef EXEC, (GetVal $result))
    ];
  }
  def V_CMPSX_#cmpName#_F64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F64_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty), (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret)
    ];
  }
}

// F64 special: O, U, F, TRU
foreach i = 0-3 in {
  defvar cmpName = ["O", "U", "F", "TRU"][i];
  // F: all-zeros wave mask. TRU: all-ones wave mask (sext i1 → iWaveSize).
  defvar f64FBallot = BallotWaveMask<(LLVMFCmp LLVMFCmpORD,
    (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty),
    (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret;
  defvar f64UBallot = BallotWaveMask<(LLVMFCmp LLVMFCmpUNO,
    (LLVMBitCast (GetNamedOperand $src0), si_llvm_double_ty),
    (LLVMBitCast (GetNamedOperand $src1), si_llvm_double_ty))>.ret;
  defvar f64FalseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar f64TrueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));

  defvar cmpSem = !cond(
    !eq(i, 0) : [(ImplicitDef VCC, f64FBallot)],
    !eq(i, 1) : [(ImplicitDef VCC, f64UBallot)],
    !eq(i, 2) : [(ImplicitDef VCC, f64FalseMask)],
    !eq(i, 3) : [(ImplicitDef VCC, f64TrueMask)]
  );

  def V_CMP_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_F64_e32"), cmpSem>;
  def V_CMPS_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPS_"#cmpName#"_F64_e32"), cmpSem>;

  defvar cmpxSemF64 = !cond(
    !eq(i, 0) : [(DefVal $r, f64FBallot),
                 (ImplicitDef VCC, (GetVal $r)),
                 (ImplicitDef EXEC, (GetVal $r))],
    !eq(i, 1) : [(DefVal $r, f64UBallot),
                 (ImplicitDef VCC, (GetVal $r)),
                 (ImplicitDef EXEC, (GetVal $r))],
    !eq(i, 2) : [(DefVal $r, f64FalseMask),
                 (ImplicitDef VCC, (GetVal $r)),
                 (ImplicitDef EXEC, (GetVal $r))],
    !eq(i, 3) : [(DefVal $r, f64TrueMask),
                 (ImplicitDef VCC, (GetVal $r)),
                 (ImplicitDef EXEC, (GetVal $r))]
  );
  defvar nosdstSemF64 = !cond(
    !eq(i, 0) : [(ImplicitDef EXEC, f64FBallot)],
    !eq(i, 1) : [(ImplicitDef EXEC, f64UBallot)],
    !eq(i, 2) : [(ImplicitDef EXEC, f64FalseMask)],
    !eq(i, 3) : [(ImplicitDef EXEC, f64TrueMask)]
  );

  def V_CMPX_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F64_e32"), cmpxSemF64>;
  def V_CMPX_#cmpName#_F64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_F64_nosdst_e32"), nosdstSemF64>;
  def V_CMPSX_#cmpName#_F64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F64_e32"), cmpxSemF64>;
  def V_CMPSX_#cmpName#_F64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPSX_"#cmpName#"_F64_nosdst_e32"), nosdstSemF64>;
}

//------------------------------------------------------------------------------
// VOPC F16 Float Comparisons
// F16 operands: trunc to i16, bitcast to half. No CMPS/CMPSX variants.
// Both base and t16 encoding variants.
//------------------------------------------------------------------------------

// F16 ordered comparisons
foreach i = 0-5 in {
  defvar cmpName = ["EQ", "LG", "GT", "GE", "LT", "LE"][i];
  defvar cmpPred = [LLVMFCmpOEQ, LLVMFCmpONE, LLVMFCmpOGT, LLVMFCmpOGE, LLVMFCmpOLT, LLVMFCmpOLE][i];

  foreach inst = ["V_CMP_"#cmpName#"_F16_e32",
                  "V_CMP_"#cmpName#"_F16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [
        (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), si_llvm_half_ty), (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty), si_llvm_half_ty))>.ret)
      ];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_F16_e32",
                  "V_CMPX_"#cmpName#"_F16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [
        (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
          (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty),
                       si_llvm_half_ty),
          (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty),
                       si_llvm_half_ty))>.ret),
        (ImplicitDef VCC, (GetVal $result)),
        (ImplicitDef EXEC, (GetVal $result))
      ];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_F16_nosdst_e32",
                  "V_CMPX_"#cmpName#"_F16_t16_nosdst_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [
        (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), si_llvm_half_ty), (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty), si_llvm_half_ty))>.ret)
      ];
    }
  }
}

// F16 unordered comparisons
foreach i = 0-5 in {
  defvar cmpName = ["NEQ", "NLG", "NGT", "NGE", "NLT", "NLE"][i];
  defvar cmpPred = [LLVMFCmpUNE, LLVMFCmpUEQ, LLVMFCmpULE, LLVMFCmpULT, LLVMFCmpUGE, LLVMFCmpUGT][i];

  foreach inst = ["V_CMP_"#cmpName#"_F16_e32",
                  "V_CMP_"#cmpName#"_F16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [
        (ImplicitDef VCC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), si_llvm_half_ty), (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty), si_llvm_half_ty))>.ret)
      ];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_F16_e32",
                  "V_CMPX_"#cmpName#"_F16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [
        (DefVal $result, BallotWaveMask<(LLVMFCmp cmpPred,
          (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty),
                       si_llvm_half_ty),
          (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty),
                       si_llvm_half_ty))>.ret),
        (ImplicitDef VCC, (GetVal $result)),
        (ImplicitDef EXEC, (GetVal $result))
      ];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_F16_nosdst_e32",
                  "V_CMPX_"#cmpName#"_F16_t16_nosdst_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [
        (ImplicitDef EXEC, BallotWaveMask<(LLVMFCmp cmpPred, (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), si_llvm_half_ty), (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty), si_llvm_half_ty))>.ret)
      ];
    }
  }
}

// F16 special: O, U, F, TRU
foreach i = 0-3 in {
  defvar cmpName = ["O", "U", "F", "TRU"][i];
  defvar f16OBallot = BallotWaveMask<(LLVMFCmp LLVMFCmpORD,
    (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), si_llvm_half_ty),
    (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty), si_llvm_half_ty))>.ret;
  defvar f16UBallot = BallotWaveMask<(LLVMFCmp LLVMFCmpUNO,
    (LLVMBitCast (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), si_llvm_half_ty),
    (LLVMBitCast (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty), si_llvm_half_ty))>.ret;
  defvar f16FalseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar f16TrueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));

  foreach inst = ["V_CMP_"#cmpName#"_F16_e32",
                  "V_CMP_"#cmpName#"_F16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = !cond(
        !eq(i, 0) : [(ImplicitDef VCC, f16OBallot)],
        !eq(i, 1) : [(ImplicitDef VCC, f16UBallot)],
        !eq(i, 2) : [(ImplicitDef VCC, f16FalseMask)],
        !eq(i, 3) : [(ImplicitDef VCC, f16TrueMask)]
      );
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_F16_e32",
                  "V_CMPX_"#cmpName#"_F16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = !cond(
        !eq(i, 0) : [(DefVal $r, f16OBallot),
                     (ImplicitDef VCC, (GetVal $r)),
                     (ImplicitDef EXEC, (GetVal $r))],
        !eq(i, 1) : [(DefVal $r, f16UBallot),
                     (ImplicitDef VCC, (GetVal $r)),
                     (ImplicitDef EXEC, (GetVal $r))],
        !eq(i, 2) : [(DefVal $r, f16FalseMask),
                     (ImplicitDef VCC, (GetVal $r)),
                     (ImplicitDef EXEC, (GetVal $r))],
        !eq(i, 3) : [(DefVal $r, f16TrueMask),
                     (ImplicitDef VCC, (GetVal $r)),
                     (ImplicitDef EXEC, (GetVal $r))]
      );
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_F16_nosdst_e32",
                  "V_CMPX_"#cmpName#"_F16_t16_nosdst_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = !cond(
        !eq(i, 0) : [(ImplicitDef EXEC, f16OBallot)],
        !eq(i, 1) : [(ImplicitDef EXEC, f16UBallot)],
        !eq(i, 2) : [(ImplicitDef EXEC, f16FalseMask)],
        !eq(i, 3) : [(ImplicitDef EXEC, f16TrueMask)]
      );
    }
  }
}

//------------------------------------------------------------------------------
// VOPC I32 Signed Integer Comparisons
//------------------------------------------------------------------------------

foreach i = 0-7 in {
  defvar cmpName = ["EQ", "NE", "GT", "GE", "LT", "LE", "F", "T"][i];
  defvar falseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar trueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar maskExpr = !cond(
    !eq(i, 0) : BallotWaveMask<(LLVMCmp LLVMICmpEQ, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 1) : BallotWaveMask<(LLVMCmp LLVMICmpNE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 2) : BallotWaveMask<(LLVMCmp LLVMICmpSGT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 3) : BallotWaveMask<(LLVMCmp LLVMICmpSGE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 4) : BallotWaveMask<(LLVMCmp LLVMICmpSLT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 5) : BallotWaveMask<(LLVMCmp LLVMICmpSLE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 6) : falseMask,
    !eq(i, 7) : trueMask
  );

  def V_CMP_#cmpName#_I32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_I32_e32")> {
    let Semantic = [(ImplicitDef VCC, maskExpr)];
  }

  def V_CMPX_#cmpName#_I32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_I32_e32")> {
    let Semantic = [(DefVal $r, maskExpr),
                    (ImplicitDef VCC, (GetVal $r)),
                    (ImplicitDef EXEC, (GetVal $r))];
  }

  def V_CMPX_#cmpName#_I32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_I32_nosdst_e32")> {
    let Semantic = [(ImplicitDef EXEC, maskExpr)];
  }
}

//------------------------------------------------------------------------------
// VOPC U32 Unsigned Integer Comparisons
//------------------------------------------------------------------------------

foreach i = 0-7 in {
  defvar cmpName = ["EQ", "NE", "GT", "GE", "LT", "LE", "F", "T"][i];
  defvar falseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar trueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar maskExpr = !cond(
    !eq(i, 0) : BallotWaveMask<(LLVMCmp LLVMICmpEQ, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 1) : BallotWaveMask<(LLVMCmp LLVMICmpNE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 2) : BallotWaveMask<(LLVMCmp LLVMICmpUGT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 3) : BallotWaveMask<(LLVMCmp LLVMICmpUGE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 4) : BallotWaveMask<(LLVMCmp LLVMICmpULT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 5) : BallotWaveMask<(LLVMCmp LLVMICmpULE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 6) : falseMask,
    !eq(i, 7) : trueMask
  );

  def V_CMP_#cmpName#_U32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_U32_e32")> {
    let Semantic = [(ImplicitDef VCC, maskExpr)];
  }

  def V_CMPX_#cmpName#_U32_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_U32_e32")> {
    let Semantic = [(DefVal $r, maskExpr),
                    (ImplicitDef VCC, (GetVal $r)),
                    (ImplicitDef EXEC, (GetVal $r))];
  }

  def V_CMPX_#cmpName#_U32_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_U32_nosdst_e32")> {
    let Semantic = [(ImplicitDef EXEC, maskExpr)];
  }
}

//------------------------------------------------------------------------------
// VOPC I64/U64 Integer Comparisons
//------------------------------------------------------------------------------

foreach i = 0-7 in {
  defvar cmpName = ["EQ", "NE", "GT", "GE", "LT", "LE", "F", "T"][i];
  defvar falseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar trueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar maskExpr = !cond(
    !eq(i, 0) : BallotWaveMask<(LLVMCmp LLVMICmpEQ, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 1) : BallotWaveMask<(LLVMCmp LLVMICmpNE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 2) : BallotWaveMask<(LLVMCmp LLVMICmpSGT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 3) : BallotWaveMask<(LLVMCmp LLVMICmpSGE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 4) : BallotWaveMask<(LLVMCmp LLVMICmpSLT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 5) : BallotWaveMask<(LLVMCmp LLVMICmpSLE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 6) : falseMask,
    !eq(i, 7) : trueMask
  );

  def V_CMP_#cmpName#_I64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_I64_e32")> {
    let Semantic = [(ImplicitDef VCC, maskExpr)];
  }

  def V_CMPX_#cmpName#_I64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_I64_e32")> {
    let Semantic = [(DefVal $r, maskExpr),
                    (ImplicitDef VCC, (GetVal $r)),
                    (ImplicitDef EXEC, (GetVal $r))];
  }

  def V_CMPX_#cmpName#_I64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_I64_nosdst_e32")> {
    let Semantic = [(ImplicitDef EXEC, maskExpr)];
  }
}

foreach i = 0-7 in {
  defvar cmpName = ["EQ", "NE", "GT", "GE", "LT", "LE", "F", "T"][i];
  defvar falseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar trueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar maskExpr = !cond(
    !eq(i, 0) : BallotWaveMask<(LLVMCmp LLVMICmpEQ, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 1) : BallotWaveMask<(LLVMCmp LLVMICmpNE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 2) : BallotWaveMask<(LLVMCmp LLVMICmpUGT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 3) : BallotWaveMask<(LLVMCmp LLVMICmpUGE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 4) : BallotWaveMask<(LLVMCmp LLVMICmpULT, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 5) : BallotWaveMask<(LLVMCmp LLVMICmpULE, (GetNamedOperand $src0), (GetNamedOperand $src1))>.ret,
    !eq(i, 6) : falseMask,
    !eq(i, 7) : trueMask
  );

  def V_CMP_#cmpName#_U64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_"#cmpName#"_U64_e32")> {
    let Semantic = [(ImplicitDef VCC, maskExpr)];
  }

  def V_CMPX_#cmpName#_U64_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_U64_e32")> {
    let Semantic = [(DefVal $r, maskExpr),
                    (ImplicitDef VCC, (GetVal $r)),
                    (ImplicitDef EXEC, (GetVal $r))];
  }

  def V_CMPX_#cmpName#_U64_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_"#cmpName#"_U64_nosdst_e32")> {
    let Semantic = [(ImplicitDef EXEC, maskExpr)];
  }
}

//------------------------------------------------------------------------------
// VOPC I16/U16 Integer Comparisons (with t16 variants)
//------------------------------------------------------------------------------

foreach i = 0-7 in {
  defvar cmpName = ["EQ", "NE", "GT", "GE", "LT", "LE", "F", "T"][i];
  defvar falseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar trueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar maskExpr = !cond(
    !eq(i, 0) : BallotWaveMask<(LLVMCmp LLVMICmpEQ, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 1) : BallotWaveMask<(LLVMCmp LLVMICmpNE, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 2) : BallotWaveMask<(LLVMCmp LLVMICmpSGT, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 3) : BallotWaveMask<(LLVMCmp LLVMICmpSGE, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 4) : BallotWaveMask<(LLVMCmp LLVMICmpSLT, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 5) : BallotWaveMask<(LLVMCmp LLVMICmpSLE, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 6) : falseMask,
    !eq(i, 7) : trueMask
  );

  foreach inst = ["V_CMP_"#cmpName#"_I16_e32",
                  "V_CMP_"#cmpName#"_I16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [(ImplicitDef VCC, maskExpr)];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_I16_e32",
                  "V_CMPX_"#cmpName#"_I16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [(DefVal $r, maskExpr),
                      (ImplicitDef VCC, (GetVal $r)),
                      (ImplicitDef EXEC, (GetVal $r))];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_I16_nosdst_e32",
                  "V_CMPX_"#cmpName#"_I16_t16_nosdst_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [(ImplicitDef EXEC, maskExpr)];
    }
  }
}

foreach i = 0-7 in {
  defvar cmpName = ["EQ", "NE", "GT", "GE", "LT", "LE", "F", "T"][i];
  defvar falseMask = (LLVMSExt (ConstantFalse si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar trueMask  = (LLVMSExt (ConstantTrue  si_llvm_i1_ty), (LLVMIntNTy (GetWavefrontSize)));
  defvar maskExpr = !cond(
    !eq(i, 0) : BallotWaveMask<(LLVMCmp LLVMICmpEQ, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 1) : BallotWaveMask<(LLVMCmp LLVMICmpNE, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 2) : BallotWaveMask<(LLVMCmp LLVMICmpUGT, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 3) : BallotWaveMask<(LLVMCmp LLVMICmpUGE, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 4) : BallotWaveMask<(LLVMCmp LLVMICmpULT, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 5) : BallotWaveMask<(LLVMCmp LLVMICmpULE, (LLVMTrunc (GetNamedOperand $src0), si_llvm_i16_ty), (LLVMTrunc (GetNamedOperand $src1), si_llvm_i16_ty))>.ret,
    !eq(i, 6) : falseMask,
    !eq(i, 7) : trueMask
  );

  foreach inst = ["V_CMP_"#cmpName#"_U16_e32",
                  "V_CMP_"#cmpName#"_U16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [(ImplicitDef VCC, maskExpr)];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_U16_e32",
                  "V_CMPX_"#cmpName#"_U16_t16_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [(DefVal $r, maskExpr),
                      (ImplicitDef VCC, (GetVal $r)),
                      (ImplicitDef EXEC, (GetVal $r))];
    }
  }

  foreach inst = ["V_CMPX_"#cmpName#"_U16_nosdst_e32",
                  "V_CMPX_"#cmpName#"_U16_t16_nosdst_e32"] in {
    def inst#_sem : InstSISemantic<!cast<InstSI>(inst)> {
      let Semantic = [(ImplicitDef EXEC, maskExpr)];
    }
  }
}

//------------------------------------------------------------------------------
// VOPC CLASS Instructions (float class test)
//------------------------------------------------------------------------------

// VCC[lane] = isClassOf(S0.f, S1.u). Tests float for NaN, Inf, zero, etc.
// S1 is a bitmask specifying which classes to test for.

// V_CMP_CLASS → VCC. int_amdgcn_class returns i1 from (anyfloat, i32 mask).
// Use BallotWaveMask to broadcast per-lane i1 → wave-wide VCC mask.
class ClassFloatTy<string suffix, SILLVMType ty> {
  string Suffix = suffix;
  SILLVMType Ty = ty;
}
foreach c = [ClassFloatTy<"F32", si_llvm_float_ty>,
             ClassFloatTy<"F64", si_llvm_double_ty>,
             ClassFloatTy<"F16", si_llvm_half_ty>] in {
  def V_CMP_CLASS_#c.Suffix#_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMP_CLASS_"#c.Suffix#"_e32")> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<
        (LLVMIntrinsic si_llvm_i1_ty, int_amdgcn_class,
          [(LLVMBitCast (GetNamedOperand $src0), c.Ty),
           (GetNamedOperand $src1, si_llvm_i32_ty)])>.ret)
    ];
  }

  def V_CMPX_CLASS_#c.Suffix#_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_CLASS_"#c.Suffix#"_e32")> {
    let Semantic = [
      (DefVal $r, BallotWaveMask<
        (LLVMIntrinsic si_llvm_i1_ty, int_amdgcn_class,
          [(LLVMBitCast (GetNamedOperand $src0), c.Ty),
           (GetNamedOperand $src1, si_llvm_i32_ty)])>.ret),
      (ImplicitDef VCC,  (GetVal $r)),
      (ImplicitDef EXEC, (GetVal $r))
    ];
  }

  def V_CMPX_CLASS_#c.Suffix#_nosdst_e32_sem
    : InstSISemantic<!cast<InstSI>("V_CMPX_CLASS_"#c.Suffix#"_nosdst_e32")> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<
        (LLVMIntrinsic si_llvm_i1_ty, int_amdgcn_class,
          [(LLVMBitCast (GetNamedOperand $src0), c.Ty),
           (GetNamedOperand $src1, si_llvm_i32_ty)])>.ret)
    ];
  }
}

// V_CMP_CLASS_F16_t16 variants (gfx11+): same semantics, separate def for
// the _t16 forms that exist alongside the legacy F16 forms.
foreach inst = [V_CMP_CLASS_F16_t16_e32] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
      (ImplicitDef VCC, BallotWaveMask<
        (LLVMIntrinsic si_llvm_i1_ty, int_amdgcn_class,
          [(LLVMBitCast (GetNamedOperand $src0), si_llvm_half_ty),
           (GetNamedOperand $src1, si_llvm_i32_ty)])>.ret)
    ];
  }
}
foreach inst = [V_CMPX_CLASS_F16_t16_e32] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
      (DefVal $r, BallotWaveMask<
        (LLVMIntrinsic si_llvm_i1_ty, int_amdgcn_class,
          [(LLVMBitCast (GetNamedOperand $src0), si_llvm_half_ty),
           (GetNamedOperand $src1, si_llvm_i32_ty)])>.ret),
      (ImplicitDef VCC,  (GetVal $r)),
      (ImplicitDef EXEC, (GetVal $r))
    ];
  }
}
foreach inst = [V_CMPX_CLASS_F16_t16_nosdst_e32] in {
  def inst#_sem : InstSISemantic<inst> {
    let Semantic = [
      (ImplicitDef EXEC, BallotWaveMask<
        (LLVMIntrinsic si_llvm_i1_ty, int_amdgcn_class,
          [(LLVMBitCast (GetNamedOperand $src0), si_llvm_half_ty),
           (GetNamedOperand $src1, si_llvm_i32_ty)])>.ret)
    ];
  }
}
