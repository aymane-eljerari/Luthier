//===-- HSAToolCompileCheck.cpp ---------------------------------*- C++ -*-===//
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
/// Compile-only verification that \c HSATool<Derived> and all of its trait
/// bases parse and instantiate. Forces explicit instantiation against a
/// dummy \c Derived so trait method bodies are concretely typed.
//===----------------------------------------------------------------------===//
#include "luthier/HSATooling/HSATool.h"

namespace luthier::detail {

struct CompileCheckTool : public luthier::HSATool<CompileCheckTool> {
  using HSATool::HSATool;

  /// Required by \c PacketMonitorTrait.
  void onPackets(const hsa_queue_t &, uint64_t,
                 llvm::ArrayRef<luthier::hsa::AqlPacket>,
                 hsa_amd_queue_intercept_packet_writer) {}
};

/// Trivial singleton used only to force-instantiate \c Singleton::createInstance
/// — a member template the explicit \c HSATool instantiation does not reach,
/// and which \c CompileCheckTool cannot exercise here (its constructor needs a
/// live HSA API table).
struct CreateCheckSingleton : luthier::Singleton<CreateCheckSingleton> {
  explicit CreateCheckSingleton(CreationKey, int) {}
};

/// Force instantiation of the \c Singleton lifetime/access helpers that no
/// library code odr-uses (tools call them from their init/fini/packet paths).
[[maybe_unused]] static void forceSingletonHelperInstantiation() {
  (void)&CompileCheckTool::destroyInstance;
  CompileCheckTool::withInstance([](CompileCheckTool &) {});
  CompileCheckTool::withInstance([](const CompileCheckTool &) {});
  CreateCheckSingleton::createInstance(0);
  CreateCheckSingleton::destroyInstance();
}

} // namespace luthier::detail

template class luthier::HSATool<luthier::detail::CompileCheckTool>;
