; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes=luthier-strip-kernels -S %s | %tee_out FileCheck %s
; Verifies that strip-kernels removes every AMDGPU_KERNEL function and leaves
; non-kernel functions intact.

target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @my_kernel() {
  ret void
}

define amdgpu_kernel void @another_kernel() {
  ret void
}

define void @device_helper() {
  ret void
}

; CHECK-NOT: @my_kernel
; CHECK-NOT: @another_kernel
; CHECK: define void @device_helper()
