//===-- ToolCXXCompilationPlugin.cpp --------------------------------------===//
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
/// \file ToolCXXCompilationPlugin.cpp
/// Clang plugin for running frontend actions and attributes required for
/// processing Luthier tool source code.
//===----------------------------------------------------------------------===//
#include "luthier/ToolingCXXCompilation/Attributes.h"
#include "luthier/ToolingCXXCompilation/Consumers.h"
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Frontend/FrontendPluginRegistry.h>
#include <memory>
#include <string>
#include <vector>

namespace {

class Action : public clang::PluginASTAction {
public:
  std::unique_ptr<clang::ASTConsumer>
  CreateASTConsumer(clang::CompilerInstance &, llvm::StringRef) override {
    return std::make_unique<luthier::HostHandleSynthConsumer>();
  }

  bool ParseArgs(const clang::CompilerInstance &,
                 const std::vector<std::string> &) override {
    return true;
  }

  ActionType getActionType() override { return AddBeforeMainAction; }
};

} // namespace

static clang::FrontendPluginRegistry::Add<Action>
    XAction("luthier-export-device-function-host-handle",
            "Exports host-side kernel handles for tagged device functions");

static clang::ParsedAttrInfoRegistry::Add<
    luthier::LuthierExportFunctionHandleAttrInfo>
    XAttr("luthier_export_function_handle",
          "Marks a __device__ function as host-accessible; the Luthier "
          "host-handle synthesis plugin will generate a __global__ kernel "
          "stub for each ODR-use of the function from host code");
