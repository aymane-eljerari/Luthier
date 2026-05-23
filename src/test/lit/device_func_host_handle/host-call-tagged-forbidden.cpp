/// RUN: not %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o /dev/null 2>&1 \
/// RUN:   | %tee_out FileCheck %s
/// Verifies that the export-handle attribute does NOT promote a tagged
/// device function to a generally host-callable one — direct host
/// calls still produce a diagnostic. Only taking the function's
/// address from host is allowed (which produces a runtime pointer
/// usable as a Luthier hook identifier).

#include <hip/hip_runtime.h>

__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook() {}

void hostFunction() {
  myHook(); // direct call from host context — must error
}

// clang-format off
/// CHECK: error: calling a device function tagged with {{\[\[luthier::export_function_handle\]\]}} from host context is not supported
// clang-format on
