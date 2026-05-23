/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies that multiple host references to the same tagged device
/// function all resolve to the single synthesized __host__ sibling
/// (Sema's overload resolution naturally dedupes).

#include <hip/hip_runtime.h>

__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook() {}

void useThrice(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myHook);
  out[1] = reinterpret_cast<const void *>(&myHook);
  out[2] = reinterpret_cast<const void *>(&myHook);
}

// clang-format off
/// Exactly one host sibling for myHook, with one annotation entry.
/// CHECK-COUNT-1: define dso_local void @_Z6myHookv()
/// CHECK-NOT: define dso_local void @_Z6myHookv()
// clang-format on
