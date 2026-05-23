/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies that templated tagged hooks produce one per-specialization
/// handle each, distinguished by the embedded Itanium mangling. The
/// dual-overload trick is ambiguous for explicit-template-id
/// address-takes, so the consumer synthesizes a distinct handle (with
/// a mangled-suffix name) per specialization at use sites and
/// retargets the DeclRefExpr.

#include <hip/hip_runtime.h>

template <typename T>
__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook(T) {}

void hostFunction(const void **out) {
  void (*pi)(int) = &myHook<int>;
  void (*pf)(float) = &myHook<float>;
  out[0] = reinterpret_cast<const void *>(pi);
  out[1] = reinterpret_cast<const void *>(pf);
}

// clang-format off
/// One handle per concrete specialization.
/// CHECK-DAG: define dso_local void @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__Z6myHookIiEvT_i(i32
/// CHECK-DAG: define dso_local void @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__Z6myHookIfEvT_f(float

/// Host use-sites are retargeted at the handles.
/// CHECK-DAG: store ptr @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__Z6myHookIiEvT_i
/// CHECK-DAG: store ptr @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__Z6myHookIfEvT_f
// clang-format on
