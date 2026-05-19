; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; A function whose address is never taken — only called directly — must
; not be registered in the table and must not have its call site rewritten.

target triple = "amdgcn-amd-amdhsa"

define void @Foo() {
  ret void
}

define void @Bar() {
  call void @Foo()
  ret void
}

; CHECK-NOT: @__luthier_function_table
; CHECK-NOT: "luthier.function-id"
; CHECK: define void @Bar()
; CHECK: call void @Foo()
