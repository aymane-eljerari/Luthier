/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the dual-overload synthesis for a non-templated tagged
/// device function. The CXX plugin creates a sibling __host__ overload
/// with the same name and an empty body; Sema's CUDA overload
/// resolution routes &myHook from host context to the sibling.

#include <hip/hip_runtime.h>

__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook() {}

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myHook);
}

// clang-format off
/// The sibling carries the export-handle annotation; the IR pass will
/// later harvest this from @llvm.global.annotations.
/// CHECK: @llvm.global.annotations {{.*}}@_Z6myHookv

/// The sibling is emitted host-side with an empty body.
/// CHECK: define dso_local void @_Z6myHookv()
/// CHECK-NEXT: entry:
/// CHECK-NEXT: ret void

/// Host code's address-take resolves to the sibling.
/// CHECK: define dso_local void @_Z12hostFunctionPPKv
/// CHECK: store ptr @_Z6myHookv
// clang-format on
