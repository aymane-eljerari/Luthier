/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path  \
/// RUN:   -I/opt/rocm/include --cuda-device-only -nogpulib -emit-llvm \
/// RUN:   -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies that the device-side compile produces the original
/// __device__ function under its natural Itanium-mangled name (the
/// IModule extraction path will consume it).

__attribute__((device, used))
__attribute__((luthier_export_function_handle)) void
myHook() {}

// clang-format off
/// CHECK: define {{.*}}void @_Z6myHookv()
// clang-format on
