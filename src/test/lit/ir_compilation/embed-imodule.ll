; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes=luthier-embed-imodule -S %s | %tee_out FileCheck %s
; End-to-end smoke test of the orchestrator: one hook + one intrinsic + one
; kernel + one .managed global. The orchestrator must clone the module, run
; the worker chain on the clone, and embed the bitcode into the original
; under the .llvmbc section. The original module's IR is otherwise
; preserved.

target triple = "amdgcn-amd-amdhsa"

@.str.hook = private unnamed_addr constant [22 x i8] c"luthier.function.hook\00", section "llvm.metadata"
@.str.intr = private unnamed_addr constant [18 x i8] c"luthier.intrinsic\00", section "llvm.metadata"
@.str.file = private unnamed_addr constant [4 x i8] c"f.c\00", section "llvm.metadata"

@llvm.global.annotations = appending global [2 x { ptr, ptr, ptr, i32, ptr }] [
  { ptr, ptr, ptr, i32, ptr } { ptr @my_hook, ptr @.str.hook, ptr @.str.file, i32 1, ptr null },
  { ptr, ptr, ptr, i32, ptr } { ptr @_ZN7luthier7readRegIjEET_N4llvm10MCRegisterE, ptr @.str.intr, ptr @.str.file, i32 2, ptr null }
], section "llvm.metadata"

@my_thing.managed = internal global i32 1, align 4

define void @my_hook() {
  ret void
}

define internal i32 @_ZN7luthier7readRegIjEET_N4llvm10MCRegisterE(i32 %r) {
  ret i32 0
}

define amdgpu_kernel void @my_kernel() {
  ret void
}

; The original module keeps its hook + kernel + intrinsic body for normal
; HIP device code generation. Only the embedded clone is preprocessed.
; CHECK-DAG: @llvm.embedded.object{{.*}}section ".llvmbc"
; CHECK-DAG: @my_thing.managed
; CHECK-DAG: define void @my_hook()
; CHECK-DAG: define internal i32 @_ZN7luthier7readRegIjEET_N4llvm10MCRegisterE
; CHECK-DAG: define amdgpu_kernel void @my_kernel()
