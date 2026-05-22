/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the host-side rewrite when the tagged device function is
/// a `static` member of a class living inside an anonymous namespace, and
/// has a real body that calls `__builtin_amdgcn_*` builtins. This is the
/// HSATool-singleton design pattern: hooks are nested in the tool class,
/// and their bodies do non-trivial device work.

#include <hip/hip_runtime.h>

namespace {

struct Tool {
  __attribute__((device, used, annotate("luthier.function.hook")))
  __attribute__((luthier_export_function_handle)) static void
  hook() {
    // A real hook does AMDGPU-specific work — exercises the path that
    // crashed before this fix when the body leaked into host IR.
    unsigned long long Exec = __builtin_amdgcn_read_exec();
    (void)Exec;
  }
};

} // namespace

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&Tool::hook);
}

/// The synthesized kernel handle host shadow is generated regardless of
/// scope: the embedded original Itanium-mangled name carries the
/// anonymous-namespace + class scope.
/// CHECK:
/// @_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv
/// = dso_local

/// The host stub for the kernel handle is also emitted (HIP launch stub).
/// CHECK:
/// @_Z{{[0-9]+}}__device_stub____luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv

/// The host-side address-take is rewritten to point at the kernel handle,
/// not at the host stub of the (now bodyless) device function.
/// CHECK: define dso_local void @_Z12hostFunctionPPKv
/// CHECK: store ptr
/// @_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv

/// HIP runtime registers the kernel handle.
/// CHECK:
/// __hipRegisterFunction({{.*}}@_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv

/// Critically: the original device function's body must NOT have leaked
/// into host IR. The plugin clears it; any `amdgcn` intrinsic surviving
/// to the host module would mean the leak is back.
/// CHECK-NOT: llvm.amdgcn.