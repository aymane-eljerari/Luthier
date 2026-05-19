; RUN: opt %luthier_tool_ir_compilation_plugin_path \
; RUN:     -passes=luthier-function-indirection -S %s | %tee_out FileCheck %s
;
; ID assignment is deterministic: sequential indices sorted by mangled
; name. Source order in this test is Foo / Bar / Baz; sorted order should
; be Bar (0) / Baz (1) / Foo (2). Table entries follow that order.

target triple = "amdgcn-amd-amdhsa"

define void @Foo() {
  ret void
}

define void @Bar() {
  ret void
}

define void @Baz() {
  ret void
}

@fp_foo = addrspace(1) global ptr @Foo
@fp_bar = addrspace(1) global ptr @Bar
@fp_baz = addrspace(1) global ptr @Baz

; Slots are ordered Bar, Baz, Foo.
; CHECK: @__luthier_function_table = internal addrspace(1) constant [3 x ptr] [ptr @Bar, ptr @Baz, ptr @Foo]
;
; And the attributes line up.
; CHECK-DAG: define void @Bar() #[[BAR_ATTRS:[0-9]+]]
; CHECK-DAG: define void @Baz() #[[BAZ_ATTRS:[0-9]+]]
; CHECK-DAG: define void @Foo() #[[FOO_ATTRS:[0-9]+]]
;
; CHECK-DAG: attributes #[[BAR_ATTRS]] = {{.*}}"luthier.function-id"="0"
; CHECK-DAG: attributes #[[BAZ_ATTRS]] = {{.*}}"luthier.function-id"="1"
; CHECK-DAG: attributes #[[FOO_ATTRS]] = {{.*}}"luthier.function-id"="2"
