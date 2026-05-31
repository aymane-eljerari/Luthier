//===-- ProviderTestAccess.h ------------------------------------*- C++ -*-===//
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
/// Test-only seam for invoking the rocprofiler registration callback directly,
/// so the snapshot/wrapper logic can be exercised with a fabricated API table
/// (no GPU, no rocprofiler-sdk runtime). The provider subclasses are \c final
/// and the callback entry point is \c protected, so we derive the (non-final)
/// base \c ApiTableRegistrationCallbackProvider to reach the protected static
/// \c apiRegistrationCallback, and pass the real provider object as the opaque
/// \c Data argument.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TEST_PROVIDER_TEST_ACCESS_H
#define LUTHIER_TEST_PROVIDER_TEST_ACCESS_H
#include "luthier/Rocprofiler/ApiTableRegistrationCallbackProvider.h"

namespace luthier::test {

template <rocprofiler_intercept_table_t TableType>
struct ProviderTestAccess
    : luthier::rocprofiler::ApiTableRegistrationCallbackProvider<TableType> {
  using Base =
      luthier::rocprofiler::ApiTableRegistrationCallbackProvider<TableType>;

  /// Drives the registration callback exactly as rocprofiler-sdk would, with
  /// \p Target standing in for the registered \c this pointer.
  static void deliver(Base *Target, rocprofiler_intercept_table_t Type,
                      uint64_t LibVersion, uint64_t LibInstance, void **Tables,
                      uint64_t NumTables) {
    Base::apiRegistrationCallback(Type, LibVersion, LibInstance, Tables,
                                  NumTables, Target);
  }

  // Only the static seam is used; never instantiated.
  ProviderTestAccess() = delete;
};

} // namespace luthier::test

#endif
