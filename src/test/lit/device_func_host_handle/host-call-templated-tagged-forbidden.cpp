/// RUN: not %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o /dev/null 2>&1 \
/// RUN:   | %tee_out FileCheck %s
/// Same as host-call-tagged-forbidden.cpp but for a templated hook:
/// a direct host call to an explicit instantiation must still error.
/// (Without the gate, the call would silently dispatch to the
/// __host__ __device__-promoted original whose body uses
/// device-only intrinsics.)

#include <hip/hip_runtime.h>

template <typename T>
__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook(T) {}

void hostFunction() {
  myHook<int>(0); // direct call to an explicit template instantiation
}

// clang-format off
/// CHECK: error: calling a device function tagged with {{\[\[luthier::export_function_handle\]\]}} from host context is not supported
// clang-format on
