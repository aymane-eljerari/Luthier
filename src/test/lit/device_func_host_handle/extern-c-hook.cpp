/// RUN: %clangxx -x hip --offload-arch=gfx908 \
/// RUN:   -fplugin=%luthier_tool_cxx_compilation_plugin_path \
/// RUN:   -I/opt/rocm/include \
/// RUN:   --cuda-host-only -emit-llvm -S %s -o - 2>&1 | %tee_out FileCheck %s
/// Verifies the dual-overload synthesis for a tagged device function
/// declared inside an `extern "C"` linkage block. The sibling inherits
/// C linkage (it's added to the same DeclContext as the original), so
/// its IR symbol is the source identifier verbatim — no Itanium
/// mangling. This exercises the IR-pass code path that falls back to
/// using the AnnotatedFn's IR symbol directly when partialDemangle
/// fails on a non-Itanium-mangled name.

#include <hip/hip_runtime.h>

extern "C" {

__attribute__((device, used))
__attribute__((luthier_export_function_handle))
void myCHook() {}

} // extern "C"

void hostFunction(const void **out) {
  out[0] = reinterpret_cast<const void *>(&myCHook);
}

// clang-format off
/// The sibling has C linkage; its host symbol is the source identifier
/// verbatim (no _Z<len>... Itanium prefix).
/// CHECK: @llvm.global.annotations {{.*}}@myCHook
/// CHECK: define dso_local void @myCHook()
/// CHECK-NEXT: entry:
/// CHECK-NEXT: ret void

/// Host code's address-take resolves to the C-linkage sibling.
/// CHECK: store ptr @myCHook
// clang-format on
