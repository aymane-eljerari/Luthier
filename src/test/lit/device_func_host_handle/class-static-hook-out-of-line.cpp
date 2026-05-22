/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Same class-static-hook setup but with the body defined out-of-line.
/// The attribute lives on the in-class declaration; the body lives on a
/// separate FunctionDecl. The plugin must canonicalize on the canonical
/// decl so the in-class declaration and the out-of-line definition share
/// one synthesized handle, and must strip UsedAttr/AnnotateAttr from the
/// definition (not just the declaration) so the IR-level
/// @llvm.compiler.used / @llvm.global.annotations references don't pin
/// a function whose body has been cleared.

#include <hip/hip_runtime.h>

namespace {

struct Tool {
  __attribute__((device, used, annotate("luthier.function.hook")))
  __attribute__((luthier_export_function_handle)) static void
  hook();
};

__attribute__((device, used, annotate("luthier.function.hook")))
__attribute__((luthier_export_function_handle)) void
Tool::hook() {
  unsigned long long Exec = __builtin_amdgcn_read_exec();
  (void)Exec;
}

} // namespace

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&Tool::hook);
}

// clang-format off
/// One handle, irrespective of in-class vs. out-of-line definition.
/// CHECK-COUNT-1: @_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv = dso_local
/// CHECK-NOT: @_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv = dso_local

/// Host rewrite + registration still happen.
/// CHECK: store ptr @_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv
/// CHECK: __hipRegisterFunction({{.*}}@_Z{{[0-9]+}}__luthier_builtin_hook_handle__ZN{{[A-Za-z0-9_]*}}Tool4hookEvv

/// And the body still doesn't leak.
/// CHECK-NOT: llvm.amdgcn.
// clang-format on