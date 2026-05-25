; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; Address-take in a function body must be rewritten to a load from
; @__luthier_function_table[ID]. Foo's "luthier.function-id" attribute
; must be present.

target triple = "amdgcn-amd-amdhsa"

define void @Foo() {
  ret void
}

declare void @sink(ptr)

define void @Caller() {
  call void @sink(ptr @Foo)
  ret void
}

; The table is emitted with internal-constant linkage (in addrspace 1 —
; AMDGPU's default global address space) and points at @Foo.
; CHECK: @__luthier_function_table = addrspace(1) constant [1 x ptr] [ptr @Foo]
;
; Foo is stamped with its assigned ID (0, since it's the only address-taken
; function).
; CHECK: define void @Foo() #[[FN_ATTRS:[0-9]+]]
;
; Caller's address-take is rewritten to a load through the table slot
; and threaded into the call as the sink's argument. LLVM's IR printer
; elides the trivial-index GEP (index 0,0) so the load reads directly
; from the table base.
; CHECK-LABEL: define void @Caller()
; CHECK: %Foo.indirected = load ptr, ptr addrspace(1) @__luthier_function_table
; CHECK: call void @sink(ptr %Foo.indirected)
;
; CHECK: attributes #[[FN_ATTRS]] = {{.*}}"luthier.function-id"="0"
