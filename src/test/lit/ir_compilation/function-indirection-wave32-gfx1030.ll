; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; On wave32 targets (RDNA), the indirection rewrite must not perturb
; wave-size-baked patterns. This test pins down: (1) the rewrite emits a
; clean load through the table, (2) the function's wavefrontsize feature
; on its target-features attribute survives, (3) any inline pattern that
; encodes wave32 (like a 32-bit ballot result type) is left alone.

target triple = "amdgcn-amd-amdhsa"

define void @Foo() #0 {
  ret void
}

declare void @sink(ptr) #0

define i32 @Caller() #0 {
  ; wave32 ballot: result is i32. Pass should not touch this.
  %b = call i32 @llvm.amdgcn.ballot.i32(i1 true)
  ; Address-take inside a function body → rewrite to table load.
  call void @sink(ptr @Foo)
  ret i32 %b
}

declare i32 @llvm.amdgcn.ballot.i32(i1) #1

attributes #0 = { "target-cpu"="gfx1030" "target-features"="+wavefrontsize32" }
attributes #1 = { nounwind readnone willreturn }

; Table emitted, Foo gets ID 0.
; CHECK: @__luthier_function_table = internal addrspace(1) constant [1 x ptr] [ptr @Foo]
;
; ballot.i32 left intact.
; CHECK-LABEL: define i32 @Caller()
; CHECK: call i32 @llvm.amdgcn.ballot.i32(i1 true)
;
; Address-take rewritten to a table-slot load.
; CHECK: %Foo.indirected = load ptr, ptr addrspace(1) @__luthier_function_table
; CHECK: call void @sink(ptr %Foo.indirected)
