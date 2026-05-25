; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; On wave64 targets (CDNA / older GCN), the indirection rewrite must not
; touch wave-size-baked patterns. Same checks as the wave32 test mirror,
; with the i64 ballot variant.

target triple = "amdgcn-amd-amdhsa"

define void @Foo() #0 {
  ret void
}

declare void @sink(ptr) #0

define i64 @Caller() #0 {
  ; wave64 ballot: result is i64.
  %b = call i64 @llvm.amdgcn.ballot.i64(i1 true)
  ; Address-take rewritten via the table.
  call void @sink(ptr @Foo)
  ret i64 %b
}

declare i64 @llvm.amdgcn.ballot.i64(i1) #1

attributes #0 = { "target-cpu"="gfx906" "target-features"="+wavefrontsize64" }
attributes #1 = { nounwind readnone willreturn }

; CHECK: @__luthier_function_table = addrspace(1) constant [1 x ptr] [ptr @Foo]
;
; CHECK-LABEL: define i64 @Caller()
; CHECK: call i64 @llvm.amdgcn.ballot.i64(i1 true)
; CHECK: %Foo.indirected = load ptr, ptr addrspace(1) @__luthier_function_table
; CHECK: call void @sink(ptr %Foo.indirected)
