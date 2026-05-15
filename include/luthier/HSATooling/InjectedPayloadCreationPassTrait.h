//===-- InjectedPayloadCreationPassTrait.h ----------------------*- C++ -*-===//
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
/// Header-only CRTP trait that exposes the tool-side API for declaring
/// injected payloads. Users reference payload functions by their host
/// shadow handle (\c void *). The trait resolves the handle to the
/// device-side name via \c Derived's \c ToolExecutableLoaderTrait, then
/// looks the function up inside the current instrumentation module.
///
/// Skeleton bodies are stubs; real wiring lands alongside the IModule
/// materialization path.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_INJECTED_PAYLOAD_CREATION_PASS_TRAIT_H
#define LUTHIER_TOOLING_INJECTED_PAYLOAD_CREATION_PASS_TRAIT_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include <llvm/IR/Function.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Error.h>

namespace luthier {

template <typename Derived> class InjectedPayloadCreationPassTrait {
public:
  InjectedPayloadCreationPassTrait() = default;

  /// Resolve a payload function's host shadow handle to the corresponding
  /// \c llvm::Function inside the given instrumentation module. Convenience
  /// over a two-step \c Derived::lookupNameByHandle / \c Module::getFunction.
  llvm::Expected<llvm::Function *>
  resolvePayloadHandle(const void *HostHandle,
                       llvm::Module &InstrumentationModule) {
    auto &Self = static_cast<Derived &>(*this);
    auto NameOrErr = Self.lookupNameByHandle(HostHandle);
    LUTHIER_RETURN_ON_ERROR(NameOrErr.takeError());
    llvm::Function *F = InstrumentationModule.getFunction(*NameOrErr);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        F != nullptr,
        "Payload function not present in the instrumentation module."));
    return F;
  }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_INJECTED_PAYLOAD_CREATION_PASS_TRAIT_H
