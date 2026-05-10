/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | FileCheck %s
/// Verifies that multiple references to the same hook produce a single
/// kernel handle (deduplication).

#include <hip/hip_runtime.h>

__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook() {}

void useThrice(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myHook);
  out[1] = reinterpret_cast<const void *>(&myHook);
  out[2] = reinterpret_cast<const void *>(&myHook);
}

/// Exactly one host shadow constant for the kernel handle.
/// CHECK-COUNT-1: @__luthier_builtin_hook_handle__Z6myHookv = dso_local constant
/// CHECK-NOT: @__luthier_builtin_hook_handle__Z6myHookv = dso_local constant
