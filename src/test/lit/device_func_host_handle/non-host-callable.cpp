/// RUN: not %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o /dev/null 2>&1 | %tee_out FileCheck %s

/// Verifies that a __device__ function WITHOUT the marker still gets the
/// normal err_ref_bad_target diagnostic. The plugin only opts in tagged
/// declarations; untagged ones behave exactly like upstream clang.

#include <hip/hip_runtime.h>

__attribute__((device)) void notTagged() {}

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&notTagged);
}

/// CHECK: error: reference to __device__ function 'notTagged'
