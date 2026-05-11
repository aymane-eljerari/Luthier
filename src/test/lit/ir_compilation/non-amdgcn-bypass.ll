; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes=luthier-embed-imodule -S %s | FileCheck %s
; The orchestrator must be a no-op on non-amdgcn modules: no clone, no embed.

target triple = "x86_64-unknown-linux-gnu"

define i32 @host_fn() {
  ret i32 0
}

; CHECK-NOT: @llvm.embedded.object
; CHECK: define i32 @host_fn()
