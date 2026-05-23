/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the dual-overload synthesis when the tagged hook is a
/// static member of an anonymous-namespace class, with a non-trivial
/// body that uses AMDGCN intrinsics. The original __device__ member
/// stays pure __device__ (never enters host emission), so its body's
/// intrinsics never leak to x86 codegen; the synthesized __host__
/// sibling is the empty host-side shadow.

#include <hip/hip_runtime.h>

namespace {

struct Tool {
  __attribute__((device, used))
  __attribute__((luthier_export_function_handle)) static void
  hook() {
    unsigned long long Exec = __builtin_amdgcn_read_exec();
    (void)Exec;
  }
};

} // namespace

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&Tool::hook);
}

// clang-format off
/// The sibling is emitted with an empty body; the original's body
/// (with the AMDGCN intrinsic) is not in the host module.
/// CHECK: define internal void @_ZN12_GLOBAL__N_14Tool4hookEv()
/// CHECK-NEXT: entry:
/// CHECK-NEXT: ret void

/// Host-side address-take resolves to the sibling.
/// CHECK: store ptr @_ZN12_GLOBAL__N_14Tool4hookEv

/// No AMDGCN intrinsic leaks to host emission.
/// CHECK-NOT: llvm.amdgcn.
// clang-format on
