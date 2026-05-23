/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the per-specialization handle synthesis when the tagged
/// hook is a function template that is also a static member of an
/// anonymous-namespace class, with a non-trivial body. Each
/// instantiation produces its own handle (distinct mangled-suffix
/// names) with the export-handle annotation, and no AMDGCN intrinsic
/// leaks into host emission.

#include <hip/hip_runtime.h>

namespace {

struct Tool {
  template <typename T>
  __attribute__((device, used)) __attribute__((luthier_export_function_handle))
  static void hook(T x) {
    unsigned long long Exec = __builtin_amdgcn_read_exec();
    (void)Exec;
    (void)x;
  }
};

} // namespace

void hostFunction(const void **out) {
  void (*pi)(int) = &Tool::hook<int>;
  void (*pf)(float) = &Tool::hook<float>;
  out[0] = reinterpret_cast<const void *>(pi);
  out[1] = reinterpret_cast<const void *>(pf);
}

// clang-format off
/// One per-specialization handle per instantiation, with distinct
/// mangled-suffix names.
/// CHECK-DAG: define dso_local void @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__ZN12_GLOBAL__N_14Tool4hookIiEEvT_i(i32
/// CHECK-DAG: define dso_local void @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__ZN12_GLOBAL__N_14Tool4hookIfEEvT_f(float

/// Host use-sites retargeted at the per-specialization handles.
/// CHECK-DAG: store ptr @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__ZN12_GLOBAL__N_14Tool4hookIiEEvT_i
/// CHECK-DAG: store ptr @_Z{{[0-9]+}}__luthier_builtin_dev_func_handle__ZN12_GLOBAL__N_14Tool4hookIfEEvT_f

/// No AMDGCN intrinsic leaks to host emission.
/// CHECK-NOT: llvm.amdgcn.
// clang-format on
