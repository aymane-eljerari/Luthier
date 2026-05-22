/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies that templated hooks produce one kernel handle per concrete
/// instantiation, distinguished by the instantiation's mangled name
/// embedded in the synth stub's base identifier.

#include <hip/hip_runtime.h>

template <typename T>
__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook(T) {}

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myHook<int>);
  out[1] = reinterpret_cast<const void *>(&myHook<float>);
}

/// Two distinct handles, one per instantiation. The base identifiers are
/// `__luthier_builtin_hook_handle__Z6myHookIiEvT_` and
/// `__luthier_builtin_hook_handle__Z6myHookIfEvT_` (Itanium mangling of
/// the template parameter shows up as `T_`).
/// CHECK-DAG: @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookIiEvT_v = dso_local
/// CHECK-DAG: @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookIfEvT_v = dso_local

/// Use sites point at the instantiation-specific kernel handle.
/// CHECK: define dso_local void @_Z12hostFunctionPPKv
/// CHECK-DAG: store ptr @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookIiEvT_v
/// CHECK-DAG: store ptr @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookIfEvT_v
