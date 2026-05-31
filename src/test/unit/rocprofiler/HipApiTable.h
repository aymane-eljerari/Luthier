//===-- HipApiTable.h -------------------------------------------*- C++ -*-===//
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
/// Helpers to fabricate HIP dispatch tables for unit tests that exercise the
/// HIP snapshot/wrapper logic without a GPU.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TEST_HIP_API_TABLE_H
#define LUTHIER_TEST_HIP_API_TABLE_H
#include <hip/amd_detail/hip_api_trace.hpp>
#include <hip/hip_deprecated.h>
#include <hip/hip_gl_interop.h>
#include <hip/hip_runtime.h>

namespace luthier::test {

/// Builds a \c HipDispatchTable whose \c size advertises the full compiled
/// struct and with \c hipApiName_fn set to a recognizable value.
inline ::HipDispatchTable buildHipDispatchTable() {
  ::HipDispatchTable T{};
  T.size = sizeof(::HipDispatchTable);
  T.hipApiName_fn = &hipApiName;
  return T;
}

} // namespace luthier::test

#endif
