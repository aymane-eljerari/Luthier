/// RUN: not %clangxx -x hip --offload-arch=gfx908 -std=c++20 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o /dev/null 2>&1 \
/// RUN:   | %tee_out FileCheck %s
/// Verifies that the export-handle attribute is rejected on consteval
/// functions. Two reasons motivate the gate:
/// 1. An immediate function's address cannot be taken at runtime
///    ([expr.const]/16), so an export handle has no operational use.
/// 2. Clang's CUDA overload-conflict detection treats
///    `__device__ consteval` as `__host__ __device__`; if the plugin
///    tried to synthesize a separate `__host__` sibling at the same
///    name, the user would see a cryptic
///    "`__host__` function cannot overload `__host__ __device__`
///    function" instead of the Luthier-specific diagnostic this gate
///    provides.

#include <hip/hip_runtime.h>

__attribute__((device)) [[luthier::export_function_handle]] consteval int
myConstevalHook(int x) {
  return x + 1;
}

// Address-take is the operation the export handle is meant to enable;
// without the gate the user would expect this to work, but consteval
// makes it ill-formed at the language level too. The plugin diag fires
// first.
void hostFunction(const void **out) {
  // The reference itself is also ill-formed (cannot take address of a
  // consteval function outside an immediate invocation), but the
  // attribute-level diag fires earlier.
  (void)out;
}

// clang-format off
/// CHECK: error: {{.*}}consteval{{.*}}immediate function's address cannot be taken at runtime
// clang-format on
