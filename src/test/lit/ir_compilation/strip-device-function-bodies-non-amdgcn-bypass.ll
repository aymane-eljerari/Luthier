; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-strip-device-function-bodies -S %s | %tee_out FileCheck %s
;
; Body-strip is gated on the amdgcn target triple. Host modules must pass
; through unchanged.

target triple = "x86_64-unknown-linux-gnu"

define void @keep_me() {
  %x = add i32 1, 2
  ret void
}

; CHECK-LABEL: define void @keep_me()
; CHECK-NEXT: %x = add i32 1, 2
; CHECK-NEXT: ret void
; CHECK-NOT: unreachable
