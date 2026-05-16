//===-- FunctionAnnotations.h -------------------------------------*-C++-*-===//
// Copyright @ Northeastern University Computer Architecture Lab
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//
/// \file FunctionAnnotations.h
/// Defines a set of function annotations, prefixes and suffixes used throughout
/// the code generation process, as well as methods to set/extract information
/// related to them from the IR function.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_FUNCTION_ANNOTATIONS_H
#define LUTHIER_TOOL_CODE_GEN_FUNCTION_ANNOTATIONS_H
#include "luthier/ToolCodeGen/EntryPoint.h"
#include <llvm/ADT/StringRef.h>
#include <optional>

namespace llvm {

class Function;

}

namespace luthier {

//===----------------------------------------------------------------------===//
// Utility macros (see https://github.com/pfultz2/Cloak)
//===----------------------------------------------------------------------===//
#define LUTHIER_STRINGIFY(S) LUTHIER_PRIMITIVE_STR(S)
#define LUTHIER_PRIMITIVE_STR(S) #S

#define LUTHIER_CAT(a, ...) LUTHIER_PRIMITIVE_CAT(a, __VA_ARGS__)
#define LUTHIER_PRIMITIVE_CAT(a, ...) a##__VA_ARGS__

/// Prefix appended to all host-accessible device functions' handle kernels
#define LUTHIER_DEVICE_FUNCTION_HANDLE_PREFIX __luthier_builtin_dev_func_handle_

/// All hooks in instrumentation modules must have this attribute
#define LUTHIER_HOOK_ATTRIBUTE luthier.function.hook

/// All bindings to Luthier intrinsics must have this attribute. The
/// value of this attribute must be the base name of the intrinsic e.g.
/// \c luthier::readReg
#define LUTHIER_INTRINSIC_ATTRIBUTE luthier.intrinsic

/// Prefix of the CUID symbol inside a HIP module
#define LUTHIER_HIP_CUID_PREFIX __hip_cuid_

/// All injected payload functions during instrumentation (i.e. functions that
/// their machine code will be inserted before an instrumentation point) must
/// have this attribute
#define LUTHIER_INJECTED_PAYLOAD_ATTRIBUTE luthier.function.injected_payload

static constexpr llvm::StringLiteral DevFuncHandlePrefix{
    LUTHIER_STRINGIFY(LUTHIER_DEVICE_FUNCTION_HANDLE_PREFIX)};

static constexpr llvm::StringLiteral HipCUIDPrefix{
    LUTHIER_STRINGIFY(LUTHIER_HIP_CUID_PREFIX)};

static constexpr llvm::StringLiteral IntrinsicAttribute{
    LUTHIER_STRINGIFY(LUTHIER_INTRINSIC_ATTRIBUTE)};

static constexpr llvm::StringLiteral InjectedPayloadAttribute{
    LUTHIER_STRINGIFY(LUTHIER_INJECTED_PAYLOAD_ATTRIBUTE)};

#define EntryPointAddrAttr      "luthier.function.entrypoint.addr"

#define InitialEntryPointAttr   "luthier.function.initial_entrypoint"

#define HipFatBinariesPtrAttr   "luthier.loader.hip_fat_binaries_ptr"

#define HipFatBinariesSizeAttr  "luthier.loader.hip_fat_binaries_size"

#define HipFunctionsPtrAttr     "luthier.loader.hip_functions_ptr"

#define HipFunctionsSizeAttr    "luthier.loader.hip_functions_size"

#define HipDeviceVarsPtrAttr    "luthier.loader.hip_device_vars_ptr"

#define HipDeviceVarsSizeAttr   "luthier.loader.hip_device_vars_size"

#define HipManagedVarsPtrAttr   "luthier.loader.hip_managed_vars_ptr"

#define HipManagedVarsSizeAttr  "luthier.loader.hip_managed_vars_size"

#define HipTextureVarsPtrAttr   "luthier.loader.hip_texture_vars_ptr"

#define HipTextureVarsSizeAttr  "luthier.loader.hip_texture_vars_size"

#define HipSurfaceVarsPtrAttr   "luthier.loader.hip_surface_vars_ptr"

#define HipSurfaceVarsSizeAttr  "luthier.loader.hip_surface_vars_size"

static constexpr const char *InitialExecutionPointAttr =
    "luthier.function.initial_execution_point";

static constexpr const char *TargetInstrPointAttr =
    "luthier.target_instr_point";

/// \brief If a tool contains an instrumentation hook it \b must
/// use this macro once. Luthier hooks are annotated via the
/// \p LUTHIER_HOOK_CREATE macro. \n
///
/// \p MARK_LUTHIER_DEVICE_MODULE macro defines a managed variable of
/// type \p char named \p __luthier_reserved in the tool device code.
/// This managed variable ensures that: \n
/// 1. <b>The HIP runtime is forced to load the tool code object before the
/// first HIP kernel is launched on the device, without requiring eager binary
/// loading to be enabled</b>: The Clang compiler embeds the device code of a
/// Luthier tool and its bitcode into a static HIP FAT binary bundled within the
/// tool's shared object. During runtime, the tool's FAT binary gets
/// registered with the HIP runtime; However, by default, the HIP runtime loads
/// FAT binaries in a lazy fashion, only loading it onto a device if:
/// a. a kernel is launched from it on the said device, or
/// b. it contains a managed variable. \n
/// Including a managed variable is the only way to ensure the tool's FAT binary
/// is loaded in time without interfering with the loading mechanism of HIP
/// runtime.
/// \n
/// 2. <b>Luthier can easily identify a tool's code object by a constant time
/// symbol hash lookup</b>.
/// \n
/// If the target application is not using the HIP runtime, then no kernel is
/// launched by the HIP runtime, meaning that the tool FAT binary does not ever
/// get loaded. In that scenario, as the HIP runtime is present solely for
/// Luthier's function, the `HIP_ENABLE_DEFERRED_LOADING` environment
/// variable must be set to zero to ensure Luthier tool code objects get loaded
/// right away on all devices.
/// \sa LUTHIER_HOOK_ANNOTATE
#define MARK_LUTHIER_DEVICE_MODULE                                             \
  __attribute__((managed, used)) char LUTHIER_RESERVED_MANAGED_VAR = 0;

/// \brief Tags a \c __device__ function to be accessed by the tool's
/// host code
#define LUTHIER_EXPORT_FUNCTION_HANDLE_ATTR                                    \
  __attribute__((luthier_export_function_handle))

#define LUTHIER_HOOK_ANNOTATE                                                  \
  __attribute__((device, used,                                                 \
                 annotate(LUTHIER_STRINGIFY(LUTHIER_HOOK_ATTRIBUTE))))         \
  LUTHIER_EXPORT_FUNCTION_HANDLE_ATTR extern "C" void

/// Marks a non-hook \c __device__ function as host-addressable. Use this
/// when host code needs the address of a device function that is not a
/// Luthier hook (e.g. a helper invoked indirectly).
#define LUTHIER_HOST_VISIBLE_DEVICE_FN                                         \
  __attribute__((device)) LUTHIER_EXPORT_FUNCTION_HANDLE_ATTR

#define LUTHIER_ANNOTATE_VARIABLE(AnnotationString) \
__attribute__((annotate(AnnotationString)))

void setFunctionEntryPoint(llvm::Function &F, EntryPoint EP);

std::optional<EntryPoint> getFunctionEntryPoint(llvm::Function &F);

} // namespace luthier

#endif