//===-- GpuAvailability.h ---------------------------------------*- C++ -*-===//
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
///
/// \file
/// Helpers for unit tests that require a real AMD GPU. Tests gate on these and
/// \c GTEST_SKIP() when no GPU / runtime is available (e.g. CI without a
/// device, or HSA/HIP failing to initialize because there is no \c /dev/kfd).
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TEST_GPU_AVAILABILITY_H
#define LUTHIER_TEST_GPU_AVAILABILITY_H
#include <gtest/gtest.h>
#include <hip/hip_runtime.h>
#include <hsa/hsa.h>

namespace luthier::test {

/// \returns \c true iff the HSA runtime initializes successfully AND exposes at
/// least one GPU agent. The result is computed once and cached. A standalone
/// \c hsa_init/hsa_shut_down cycle is used so this is safe to call from a test
/// binary that is not itself a rocprofiler tool.
inline bool hsaGpuAvailable() {
  static const bool Available = []() -> bool {
    if (hsa_init() != HSA_STATUS_SUCCESS)
      return false;
    bool FoundGpu = false;
    (void)hsa_iterate_agents(
        [](hsa_agent_t Agent, void *Data) -> hsa_status_t {
          hsa_device_type_t Type{};
          if (hsa_agent_get_info(Agent, HSA_AGENT_INFO_DEVICE, &Type) ==
                  HSA_STATUS_SUCCESS &&
              Type == HSA_DEVICE_TYPE_GPU) {
            *static_cast<bool *>(Data) = true;
            return HSA_STATUS_INFO_BREAK;
          }
          return HSA_STATUS_SUCCESS;
        },
        &FoundGpu);
    (void)hsa_shut_down();
    return FoundGpu;
  }();
  return Available;
}

/// \returns \c true iff HIP reports at least one device. Cached.
inline bool hipGpuAvailable() {
  static const bool Available = []() -> bool {
    int Count = 0;
    return hipGetDeviceCount(&Count) == hipSuccess && Count > 0;
  }();
  return Available;
}

} // namespace luthier::test

/// Skips the current test if no HSA-capable AMD GPU is available.
#define LUTHIER_SKIP_IF_NO_HSA_GPU()                                           \
  do {                                                                         \
    if (!::luthier::test::hsaGpuAvailable())                                   \
      GTEST_SKIP() << "no AMD GPU / HSA runtime failed to initialize";         \
  } while (false)

/// Skips the current test if no HIP-capable AMD GPU is available.
#define LUTHIER_SKIP_IF_NO_HIP_GPU()                                           \
  do {                                                                         \
    if (!::luthier::test::hipGpuAvailable())                                   \
      GTEST_SKIP() << "no AMD GPU / HIP reported no devices";                  \
  } while (false)

#endif
