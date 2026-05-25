; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-subtarget-marker -S %s | %tee_out FileCheck %s
;
; Same plugin runs on the host TU under --cuda-host-only, where the
; module is x86_64 and the marker is meaningless. The pass must be a
; no-op on non-amdgcn modules.

target triple = "x86_64-unknown-linux-gnu"

define i32 @host_fn() {
  ret i32 0
}

; CHECK-NOT: __luthier_subtarget
; CHECK-NOT: .luthier.subtarget
; CHECK: define i32 @host_fn()
