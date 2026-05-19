; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; Non-amdgcn modules must pass through unchanged (the IR pass is gated on
; the target triple).

target triple = "x86_64-unknown-linux-gnu"

define void @Foo() {
  ret void
}

@fp = global ptr @Foo

; CHECK-NOT: @__luthier_function_table
; CHECK-NOT: "luthier.function-id"
; CHECK: @fp = global ptr @Foo
