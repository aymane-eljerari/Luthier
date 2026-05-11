; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes=luthier-finalize-hooks -S %s | FileCheck %s
; Verifies that finalize-hooks:
;   - drops noinline / optnone from hook functions
;   - adds alwaysinline to hook functions
;   - leaves non-hook functions untouched

target triple = "amdgcn-amd-amdhsa"

define void @my_hook() #0 {
  ret void
}

define void @not_a_hook() #1 {
  ret void
}

attributes #0 = { noinline optnone "luthier.function.hook" }
attributes #1 = { noinline optnone }

; CHECK: define void @my_hook() #[[HOOK:[0-9]+]]
; CHECK: define void @not_a_hook() #[[OTHER:[0-9]+]]

; CHECK-DAG: attributes #[[HOOK]] = { alwaysinline "luthier.function.hook" }
; CHECK-DAG: attributes #[[OTHER]] = { noinline optnone }
