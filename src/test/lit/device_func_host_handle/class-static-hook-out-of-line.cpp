/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies that the dual-overload synthesis fires once even when the
/// in-class declaration and the out-of-line definition both carry the
/// luthier_export_function_handle attribute. The plugin's
/// parent-scope lookup guard suppresses double-synthesis; exactly one
/// __host__ sibling is emitted with an empty body.

#include <hip/hip_runtime.h>

namespace {

struct Tool {
  __attribute__((device, used))
  __attribute__((luthier_export_function_handle)) static void
  hook();
};

__attribute__((device, used))
__attribute__((luthier_export_function_handle)) void
Tool::hook() {
  unsigned long long Exec = __builtin_amdgcn_read_exec();
  (void)Exec;
}

} // namespace

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&Tool::hook);
}

// clang-format off
/// Exactly one host-side definition of Tool::hook (the sibling).
/// CHECK-COUNT-1: define internal void @_ZN12_GLOBAL__N_14Tool4hookEv()
/// CHECK-NOT: define internal void @_ZN12_GLOBAL__N_14Tool4hookEv()

/// Host-side address-take resolves to the sibling.
/// CHECK: store ptr @_ZN12_GLOBAL__N_14Tool4hookEv

/// No AMDGCN intrinsic leaks to host emission.
/// CHECK-NOT: llvm.amdgcn.
// clang-format on
