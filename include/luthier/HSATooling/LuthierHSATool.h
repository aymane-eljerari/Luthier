//===-- LuthierHSATool.h ----------------------------------------*- C++ -*-===//
// Copyright 2026 @ Northeastern University Computer Architecture Lab
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
/// Implements the base calss of all Luthier static tools. This is necessary for
/// registering a static tool with the Tool Executable Loader
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/ToolExecutableLoader.h"
/// This Macro needs to be called in the static tool, with the name of the class
/// inhereting from LuthierHSATool. Variables are marked as used so compiler
/// doesn't delete them, since this info will be filled out by the
/// LoadHIPFATBinaryInfo plugin during IR
#define REGISTER_STRUCTS(TOOLNAME)                                             \
  __attribute__((used)) void **TOOLNAME::HipFatBinaries{nullptr};              \
  __attribute__((used)) unsigned long long TOOLNAME::HipFatBinariesSize{0};    \
  __attribute__((used)) TOOLNAME::HipFunctionInfo *TOOLNAME::HipFunctions{     \
      nullptr};                                                                \
  __attribute__((used)) unsigned long long TOOLNAME::HipFunctionsSize{0};      \
  __attribute__((used)) TOOLNAME::HipDeviceVarInfo *TOOLNAME::HipDeviceVars{   \
      nullptr};                                                                \
  __attribute__((used)) unsigned long long TOOLNAME::HipDeviceVarsSize{0};     \
  __attribute__((used)) TOOLNAME::HipManagedVarInfo *TOOLNAME::HipManagedVars{ \
      nullptr};                                                                \
  __attribute__((used)) unsigned long long TOOLNAME::HipManagedVarsSize{0};    \
  __attribute__((used)) TOOLNAME::HipTextureInfo *TOOLNAME::HipTextureVars{    \
      nullptr};                                                                \
  __attribute__((used)) unsigned long long TOOLNAME::HipTextureVarsSize{0};    \
  __attribute__((used)) TOOLNAME::HipSurfaceInfo *TOOLNAME::HipSurfaceVars{    \
      nullptr};                                                                \
  __attribute__((used)) unsigned long long TOOLNAME::HipSurfaceVarsSize{0};    \
  inline LuthierHSATool::~LuthierHSATool() {}

namespace luthier {
/// @brief Base class for all static HSA tools. This class provides the
/// necessary structs that have to be filled by LoadHIPFATBinaryInfo plugin so
/// the static tool registers with the Tool Executable Loader. Variables are
/// annotated to avoid name demangling, and should not be changed by the tool,
/// as their contents will be changed by the plugin. This is an abstract class
/// because it is not useful if not inhereted from by a static tool
class LuthierHSATool {
public:
  LuthierHSATool(ToolExecutableLoader *TEL) : TEL(TEL) {}
  // Delete default constructor, A tool inhereting from this has no reason to
  // exist without a TEL
  LuthierHSATool() = delete;
  virtual ~LuthierHSATool() = 0;
  struct HipFunctionInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  struct HipDeviceVarInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  struct HipManagedVarInfo {
    void **Pointer{nullptr};
    void *InitValue{nullptr};
    const char *Name{nullptr};
    unsigned long long Size{0};
    unsigned align{0};
  };

  struct HipTextureInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

  struct HipSurfaceInfo {
    void *HostHandle{nullptr};
    const char *DeviceName{nullptr};
  };

private:
  /// @brief Tool Executable Loader, used to register and load HIP code objects
  ToolExecutableLoader *TEL;
  /// @brief Annotated variables that will hold the information we need to
  /// register everything
  static __attribute__((
      annotate("luthier.loader.hip_fat_binaries_ptr"))) void **HipFatBinaries;

  static __attribute__((
      annotate("luthier.loader.hip_fat_binaries_size"))) unsigned long long
      HipFatBinariesSize;

  static __attribute__((annotate("luthier.loader.hip_functions_ptr")))
  HipFunctionInfo *HipFunctions;

  static __attribute__((
      annotate("luthier.loader.hip_functions_size"))) unsigned long long
      HipFunctionsSize;

  static __attribute__((annotate("luthier.loader.hip_device_vars_ptr")))
  HipDeviceVarInfo *HipDeviceVars;

  static __attribute__((
      annotate("luthier.loader.hip_device_vars_size"))) unsigned long long
      HipDeviceVarsSize;

  static __attribute__((annotate("luthier.loader.hip_managed_vars_ptr")))
  HipManagedVarInfo *HipManagedVars;

  static __attribute__((
      annotate("luthier.loader.hip_managed_vars_size"))) unsigned long long
      HipManagedVarsSize;

  static __attribute__((annotate("luthier.loader.hip_texture_vars_ptr")))
  HipTextureInfo *HipTextureVars;

  static __attribute__((
      annotate("luthier.loader.hip_texture_vars_size"))) unsigned long long
      HipTextureVarsSize;

  static __attribute__((annotate("luthier.loader.hip_surface_vars_ptr")))
  HipSurfaceInfo *HipSurfaceVars;

  static __attribute__((
      annotate("luthier.loader.hip_surface_vars_size"))) unsigned long long
      HipSurfaceVarsSize;
};
} // namespace luthier