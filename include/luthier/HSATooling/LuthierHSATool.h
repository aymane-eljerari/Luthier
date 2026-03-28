#include "luthier/HSATooling/ToolExecutableLoader.h"
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
class LuthierHSATool {
public:
  LuthierHSATool(ToolExecutableLoader *TEL) : TEL(TEL) {}
	// Delete default constructor, A tool inhereting from this has no reason to exist without a TEL
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
  ToolExecutableLoader *TEL;

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