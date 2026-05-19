; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-strip-device-function-bodies -S %s | %tee_out FileCheck %s
;
; Body-strip leaves each function symbol present but replaces its body
; with a single `unreachable`. Declarations and intrinsics are untouched.
; Globals stay intact.

target triple = "amdgcn-amd-amdhsa"

@global_data = addrspace(1) global i32 42

declare void @external_declaration()

define void @stub_me() {
entry:
  %x = add i32 1, 2
  ret void
}

define amdgpu_kernel void @stub_kernel(ptr %p) {
  store i32 7, ptr %p
  ret void
}

; Symbols preserved.
; CHECK: @global_data = addrspace(1) global i32 42
; CHECK: declare void @external_declaration()
;
; @stub_me: body replaced with a single unreachable.
; CHECK-LABEL: define void @stub_me()
; CHECK-NEXT: stub:
; CHECK-NEXT: unreachable
;
; @stub_kernel: same treatment, kernel calling conv preserved.
; CHECK-LABEL: define amdgpu_kernel void @stub_kernel(ptr %p)
; CHECK-NEXT: stub:
; CHECK-NEXT: unreachable
