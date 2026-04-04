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
#include "luthier/Tooling/FunctionAnnotations.h"
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
  __attribute__((used)) unsigned long long TOOLNAME::HipSurfaceVarsSize{0};

namespace luthier {
/// \brief Base class for all static HSA tools. This class provides the
/// necessary structs that have to be filled by LoadHIPFATBinaryInfo plugin so
/// the static tool registers with the Tool Executable Loader. Variables are
/// annotated to avoid name demangling, and should not be changed by the tool,
/// as their contents will be changed by the plugin. This is an abstract class
/// because it is not useful if not inhereted from by a static tool
template <typename StaticTool> class LuthierHSATool {
public:
  LuthierHSATool() : TEL(ToolExecutableLoader::instance()) {}
  explicit LuthierHSATool(ToolExecutableLoader& Loader) : TEL(Loader) {}
  virtual ~LuthierHSATool() = default;
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
    unsigned Align{0};
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
  /// \brief Tool Executable Loader, used to register and load HIP code objects
  ToolExecutableLoader &TEL;

  /// \brief Annotated variables that will hold the information we need to
  /// register everything
  static LUTHIER_ANNOTATE_VARIABLE(HipFatBinariesPtrAttr) void **HipFatBinaries;

  static LUTHIER_ANNOTATE_VARIABLE(
      HipFatBinariesSizeAttr) unsigned long long HipFatBinariesSize;

  static LUTHIER_ANNOTATE_VARIABLE(HipFunctionsPtrAttr)
      HipFunctionInfo *HipFunctions;

  static LUTHIER_ANNOTATE_VARIABLE(
      HipFunctionsSizeAttr) unsigned long long HipFunctionsSize;

  static LUTHIER_ANNOTATE_VARIABLE(HipDeviceVarsPtrAttr)
      HipDeviceVarInfo *HipDeviceVars;

  static LUTHIER_ANNOTATE_VARIABLE(
      HipDeviceVarsSizeAttr) unsigned long long HipDeviceVarsSize;

  static LUTHIER_ANNOTATE_VARIABLE(HipManagedVarsPtrAttr)
      HipManagedVarInfo *HipManagedVars;

  static LUTHIER_ANNOTATE_VARIABLE(
      HipManagedVarsSizeAttr) unsigned long long HipManagedVarsSize;

  static LUTHIER_ANNOTATE_VARIABLE(HipTextureVarsPtrAttr)
      HipTextureInfo *HipTextureVars;

  static LUTHIER_ANNOTATE_VARIABLE(
      HipTextureVarsSizeAttr) unsigned long long HipTextureVarsSize;

  static LUTHIER_ANNOTATE_VARIABLE(HipSurfaceVarsPtrAttr)
      HipSurfaceInfo *HipSurfaceVars;

  static LUTHIER_ANNOTATE_VARIABLE(
      HipSurfaceVarsSizeAttr) unsigned long long HipSurfaceVarsSize;
};

#ifdef __clang__
// Template definition of the Instance pointer to suppress clang warnings
// regarding translation units
template <typename T> T *luthier::LuthierHSATool<T>::Instance{nullptr};
#endif

} // namespace luthier