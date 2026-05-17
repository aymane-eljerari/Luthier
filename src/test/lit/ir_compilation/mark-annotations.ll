; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes=luthier-mark-annotations -S %s | %tee_out FileCheck %s
; Verifies that:
;   - functions annotated with luthier.function.hook get the matching fn-attr
;   - functions annotated with luthier.intrinsic get the matching fn-attr
;   - llvm.global.annotations / llvm.used / llvm.compiler.used are removed

target triple = "amdgcn-amd-amdhsa"

@.str.hook = private unnamed_addr constant [22 x i8] c"luthier.function.hook\00", section "llvm.metadata"
@.str.intr = private unnamed_addr constant [18 x i8] c"luthier.intrinsic\00", section "llvm.metadata"
@.str.file = private unnamed_addr constant [4 x i8] c"f.c\00", section "llvm.metadata"

@llvm.global.annotations = appending global [1 x { ptr, ptr, ptr, i32, ptr }] [
  { ptr, ptr, ptr, i32, ptr } { ptr @my_intrinsic, ptr @.str.intr, ptr @.str.file, i32 2, ptr null }
], section "llvm.metadata"

@llvm.used = appending global [2 x ptr] [ptr @my_hook, ptr @my_intrinsic], section "llvm.metadata"
@llvm.compiler.used = appending global [1 x ptr] [ptr @my_hook], section "llvm.metadata"

define void @my_hook() {
  ret void
}

define i32 @my_intrinsic() {
  ret i32 0
}

; CHECK-NOT: @llvm.global.annotations
; CHECK-NOT: @llvm.used
; CHECK-NOT: @llvm.compiler.used

; CHECK: define i32 @my_intrinsic() #[[INTR:[0-9]+]]

; CHECK-DAG: attributes #[[INTR]] = {{.*}}"luthier.intrinsic"
