//===-- ApiTableSnapshot.h ---------------------------------------*- C++-*-===//
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
/// \file
/// Umbrella header pulling in both the HSA and HIP API table snapshot classes.
/// \note Consumers that only need one library should include the
/// library-specific header (\c HsaApiTableSnapshot.h or
/// \c HipApiTableSnapshot.h) directly to avoid pulling in the other library's
/// headers.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_ROCPROFILER_API_TABLE_SNAPSHOT_H
#define LUTHIER_ROCPROFILER_API_TABLE_SNAPSHOT_H
#include "luthier/Rocprofiler/HipApiTableSnapshot.h"
#include "luthier/Rocprofiler/HsaApiTableSnapshot.h"

#endif
