; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-subtarget-marker -S %s | %tee_out FileCheck %s
;
; wave64 on gfx906 (no -mcumode flag). gfx9 family has no WGP mode, so
; the default-CU rule fires and bit 1 is set. Expected encoding: 0b11 = 3.

target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define void @donor() #0 {
  ret void
}

attributes #0 = { "target-cpu"="gfx906" "target-features"="+wavefrontsize64" }

; CHECK-DAG: @__luthier_subtarget = protected addrspace(1) constant i32 3
; CHECK-DAG: section ".luthier.subtarget"
; The marker must also be pinned via llvm.used so later strip passes
; can't drop it.
; CHECK-DAG: @llvm.used {{.*}}@__luthier_subtarget
