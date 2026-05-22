/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path  \
/// RUN:   -I/opt/rocm/include --cuda-device-only -nogpulib -emit-llvm \
/// RUN:   -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the device-side compile produces the actual kernel symbol that
/// HIP runtime will bind to the host stub.

__attribute__((device)) __attribute__((luthier_export_function_handle)) void
myHook() {}

/// CHECK: define {{.*}}amdgpu_kernel void @_Z{{[0-9]+}}__luthier_builtin_hook_handle__Z6myHookvv
/// CHECK: define {{.*}}void @_Z6myHookv
