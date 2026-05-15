; Verifies that RemoveUnusedHooksPass eliminates hook Functions in the
; IModule that are not transitively reachable from any injected payload, and
; preserves hooks that ARE reachable.
;
; RUN: llvm-mc --triple amdgcn-amd-amdhsa -mcpu=gfx908 -filetype=obj %intrinsic_mir_lowering_target_stub -o %t.o && \
; RUN: ld.lld -shared --unresolved-symbols=ignore-all -o %t %t.o && \
; RUN: luthier-llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx908 \
; RUN:    %luthier_tool_code_gen_plugin \
; RUN:    -passes=luthier-mock-load-amdgpu-code-objects,luthier-code-discovery,luthier-apply-instrumentation \
; RUN:    -code-object-paths=%t \
; RUN:    -initial-entrypoint=0:stub_kernel.kd \
; RUN:    -initial-execution-point=0:stub_kernel.kd \
; RUN:    -imodule-path=%s \
; RUN:    -imodule-output=%t.luthier \
; RUN:    -imodule-mir-passes= \
; RUN:    -imodule-ir-passes=luthier-remove-unused-hooks \
; RUN:    -o /dev/null && \
; RUN: FileCheck %s < %t.luthier

; The reachable hook's helper, then the reachable hook itself, then the
; payload entry must all remain (in IR-declaration order, which matches the
; source order below). Pass 1 only prunes Functions carrying HookAttribute;
; non-hook orphans (like orphan_helper) survive — global DCE later will
; clean those up.
; CHECK: define{{.*}}@reachable_helper
; CHECK: define{{.*}}@reachable_hook
; CHECK: define{{.*}}@luthier.payload.unused_hook

; The orphan hook itself must be gone (helper without HookAttribute is left
; for downstream DCE — see Pass 1 design note in CLAUDE.md).
; CHECK-NOT: define{{.*}}@orphan_hook(

target datalayout = "e-m:e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

define void @reachable_helper() #2 {
  ret void
}

define void @reachable_hook() #1 {
  call void @reachable_helper()
  ret void
}

define void @orphan_helper() #2 {
  ret void
}

define void @orphan_hook() #1 {
  call void @orphan_helper()
  ret void
}

define void @luthier.payload.unused_hook() #0 {
  call void @reachable_hook()
  ret void
}

attributes #0 = { noinline "luthier.function.injected_payload" "target-cpu"="gfx908" "target-features"="+wavefrontsize64" }
attributes #1 = { noinline "luthier.function.hook" "target-cpu"="gfx908" }
attributes #2 = { noinline "target-cpu"="gfx908" }
