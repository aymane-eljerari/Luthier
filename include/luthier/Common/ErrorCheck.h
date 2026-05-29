//===-- ErrorCheck.h - Error Checking Macros  -------------------*- C++ -*-===//
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
/// Defines useful macros to check <tt>llvm::Error</tt>s.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_ERROR_CHECK_H
#define LUTHIER_COMMON_ERROR_CHECK_H

/// TODO: Rework these macros, and unify their uses across the project

/// \brief Reports a fatal usage error if the passed \p llvm::Error argument is
/// not in a success state
///
/// The argument is bound by forwarding reference (no move on capture) and the
/// error is consumed with a single move into \c llvm::toString, which is the
/// minimum possible for the move-only \c llvm::Error. The \c std::move is
/// required so the macro also accepts lvalue \c llvm::Error arguments.
#define LUTHIER_REPORT_FATAL_ON_ERROR(...)                                     \
  do {                                                                         \
    if (auto &&LuthierReportFatalOnErr = (__VA_ARGS__))                        \
      llvm::reportFatalUsageError(                                             \
          llvm::Twine(llvm::toString(std::move(LuthierReportFatalOnErr))));    \
  } while (false)

/// \brief returns from the current function if the passed \p llvm::Error
/// argument is not in a success state
///
/// The argument is bound by forwarding reference (no move on capture) and the
/// error is transferred out with a single move on the \c return path, which is
/// the minimum possible for the move-only \c llvm::Error. The \c std::move is
/// required so the macro also accepts lvalue \c llvm::Error arguments.
#define LUTHIER_RETURN_ON_ERROR(...)                                           \
  do {                                                                         \
    if (auto &&LuthierReturnOnErr = (__VA_ARGS__))                             \
      return std::move(LuthierReturnOnErr);                                    \
  } while (false)

#define LUTHIER_MAKE_ERROR(ErrorType, ErrorMsg)                                \
  llvm::make_error<ErrorType>(                                                 \
      ErrorMsg, std::source_location::current(),                               \
      luthier::GenericLuthierError::StackTraceInitializer())

#endif