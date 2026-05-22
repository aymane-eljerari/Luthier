/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the host-side rewrite: &myHook is rewritten to point at the
/// synthesized kernel handle, and HIP runtime registration is generated for
/// the handle. The handle's symbol is the Itanium mangling of a plain C++
/// function named `__luthier_builtin_hook_handle_<original-mangled-name>`.

#include <hip/hip_runtime.h>

__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook() {}

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myHook);
}

/// Kernel handle host shadow + registration are generated. The base
/// identifier of the synth stub is `__luthier_builtin_hook_handle__Z6myHookv`
/// (30-char prefix + original Itanium mangled name `_Z6myHookv`).
/// CHECK-DAG: @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookvv = dso_local constant
/// CHECK-DAG: @_Z{{[0-9]+}}__device_stub____luthier_builtin_hook_handle__Z6myHookvv

/// Host code stores the kernel handle's address, not the host stub of myHook.
/// CHECK: define dso_local void @_Z12hostFunctionPPKv
/// CHECK: store ptr @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookvv

/// HIP registers the kernel handle with the runtime.
/// CHECK: __hipRegisterFunction({{.*}}@_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookvv
