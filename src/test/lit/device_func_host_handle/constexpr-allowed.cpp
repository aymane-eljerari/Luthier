/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s --check-prefix=HOST
/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include --cuda-device-only -nogpulib -emit-llvm \
/// RUN:   -S %s -o - 2>&1 | %tee_out FileCheck %s --check-prefix=DEVICE
/// Verifies that constexpr (non-consteval) tagged device functions are
/// accepted by the plugin and behave correctly across all axes:
/// 1. Host-side address-take resolves to the synthesized __host__
///    sibling (no constexpr semantics, but a usable runtime pointer).
/// 2. Device-side call from a __global__ kernel goes to the original
///    constexpr __device__ function — must NOT trigger the
///    host-call-of-tagged diagnostic, because the visitor's
///    enclosing-function check sees a Global caller, not Host.
/// 3. The original constexpr function is emitted on device under its
///    natural Itanium mangling for IModule extraction.

#include <hip/hip_runtime.h>

__attribute__((device, used))
__attribute__((luthier_export_function_handle)) constexpr int
myAdd(int a) {
  return a + 1;
}

__global__ void square(int *array, int n) {
  int tid = blockDim.x * blockIdx.x + threadIdx.x;
  if (tid < n)
    // Device→device call; the visitor's caller-context check
    // (SemaCUDA::IdentifyTarget on the enclosing __global__) must skip
    // this site and not emit the host-call diagnostic.
    array[tid] = array[tid] * array[tid] + myAdd(2);
}

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myAdd);
}

// clang-format off
/// Host-side sibling: same Itanium mangling as the natural device
/// function (the dual-overload uses the original's source name).
/// HOST: define dso_local noundef i32 @_Z5myAddi(i32 noundef %{{[A-Za-z0-9_]+}})

/// Host-side address-take retargets at the sibling.
/// HOST: store ptr @_Z5myAddi

/// No AMDGCN intrinsic leaks to host emission.
/// HOST-NOT: llvm.amdgcn.

/// Device-side: the constexpr device function is emitted with its
/// natural mangling; the __global__ kernel is emitted as amdgpu_kernel.
/// DEVICE: define {{.*}}i32 @_Z5myAddi(i32 noundef %{{[A-Za-z0-9_]+}})
/// DEVICE: define {{.*}}amdgpu_kernel void @_Z6squarePii
// clang-format on
