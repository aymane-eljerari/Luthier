; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; Address-take in a constant initializer (a __device__ global function
; pointer) must be LEFT ALONE — the initializer keeps the symbolic
; reference so LLVM's Use machinery threads JIT-time renames through it.
; Foo still gets a function-id attribute and an entry in the table.

target triple = "amdgcn-amd-amdhsa"

define void @Foo() {
  ret void
}

; Constant-context address-take.
@fp = addrspace(1) global ptr @Foo

; CHECK-DAG: @__luthier_function_table = internal addrspace(1) constant [1 x ptr] [ptr @Foo]
; CHECK-DAG: @fp = addrspace(1) global ptr @Foo
; CHECK: define void @Foo() #[[FN_ATTRS:[0-9]+]]
; CHECK: attributes #[[FN_ATTRS]] = {{.*}}"luthier.function-id"="0"
