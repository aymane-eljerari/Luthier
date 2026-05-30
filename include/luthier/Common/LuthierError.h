//===-- LuthierError.h ------------------------------------------*- C++ -*-===//
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
/// Defines \c LuthierError, containing the common part among all
/// \c llvm::ErrorInfo classes defined by Luthier, as well as RTTI mechanism
/// for checking whether a given \c llvm::Error originated from Luthier.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_LUTHIER_ERROR_H
#define LUTHIER_COMMON_LUTHIER_ERROR_H
#include "luthier/Common/Stacktrace.h"
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <source_location>

namespace luthier {

class LuthierError : public llvm::ErrorInfo<LuthierError> {
public:
  using StackTraceType = luthier::Stacktrace;

  /// Captures the call stack at the point of error construction. Symbolization
  /// is deferred until the trace is printed (see \c luthier::Stacktrace), so
  /// errors that are created and then handled never pay for it.
  static auto constexpr StackTraceInitializer = []() {
    return Stacktrace::current();
  };

protected:
  /// Source location where the error occurred
  std::source_location ErrorLocation;
  /// Stack trace of where the error occurred
  StackTraceType StackTrace;
  /// Message of the error
  std::string ErrorMsg;

  explicit LuthierError(std::string ErrorMsg,
                        const std::source_location ErrorLocation =
                            std::source_location::current(),
                        StackTraceType StackTrace = StackTraceInitializer())
      : ErrorLocation(ErrorLocation), StackTrace(std::move(StackTrace)),
        ErrorMsg(std::move(ErrorMsg)) {};

  explicit LuthierError(const llvm::formatv_object_base &ErrorMsg,
                        const std::source_location ErrorLocation =
                            std::source_location::current(),
                        StackTraceType StackTrace = StackTraceInitializer())
      : ErrorLocation(ErrorLocation), StackTrace(std::move(StackTrace)),
        ErrorMsg(ErrorMsg.str()) {};

  /// \brief Writes the common error context among all subclasses (source
  /// location, message, and the stack trace) to \p OS.
  ///
  /// Subclasses call this from \c log() right after writing their type-specific
  /// lead phrase
  void logErrorContext(llvm::raw_ostream &OS) const {
    OS << " in file " << ErrorLocation.file_name() << ", function "
       << ErrorLocation.function_name() << ", at " << ErrorLocation.line()
       << ": " << ErrorMsg << ".\n";
    OS << "Stack trace: \n";
    StackTrace.print(OS);
    OS << "\n";
  }

public:
  static char ID;

  [[nodiscard]] std::source_location getErrorLocation() const {
    return ErrorLocation;
  }

  [[nodiscard]] const StackTraceType &getStackTrace() const {
    return StackTrace;
  }

  [[nodiscard]] llvm::StringRef getErrorMsg() const { return ErrorMsg; }

  [[nodiscard]] std::error_code convertToErrorCode() const override {
    return llvm::inconvertibleErrorCode();
  }
};

} // namespace luthier

#endif