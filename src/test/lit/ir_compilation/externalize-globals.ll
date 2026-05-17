; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes=luthier-externalize-globals -S %s | %tee_out FileCheck %s
; Verifies that externalize-globals:
;   - removes any *.managed global
;   - removes the reserved managed marker variable
;   - removes globals in the "llvm.metadata" section
;   - preserves __hip_cuid_* globals untouched
;   - externalizes all other globals (no initializer, external linkage,
;     default visibility, not dso_local)

target triple = "amdgcn-amd-amdhsa"

@some_dev_var = internal global i32 42, align 4
@my_thing.managed = internal global i32 1, align 4
@__luthier_builtin_reserved = internal global i8 0, align 1
@__hip_cuid_abc = internal global i8 0, align 1
@discardme = internal constant [4 x i8] c"foo\00", section "llvm.metadata"

define ptr @use_some_dev_var() {
  ret ptr @some_dev_var
}

; CHECK-NOT: @my_thing.managed
; CHECK-NOT: @__luthier_builtin_reserved
; CHECK-NOT: @discardme

; CHECK-DAG: @__hip_cuid_abc = internal global
; CHECK-DAG: @some_dev_var = external global i32
