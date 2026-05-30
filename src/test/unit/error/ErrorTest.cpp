//===-- ErrorTest.cpp -----------------------------------------*- C++ -*-===//
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
/// Unit tests for Luthier's error hierarchy (\c LuthierError and its
/// subclasses) and the error-handling macros in ErrorCheck.h and the per-type
/// headers. Covers: RTTI (\c isA / \c dyn_cast), \c convertToErrorCode,
/// call-site source-location capture, log() formatting, stack-trace capture,
/// the error-making macros, and each check macro (including
/// \c LUTHIER_RETURN_ON_ERROR and the fatal handler).
//===----------------------------------------------------------------------===//
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/Common/LuthierError.h"
#include "luthier/HIP/HipError.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/LLVM/LLVMError.h"
#include "luthier/Rocprofiler/RocprofilerError.h"

#include <gtest/gtest.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <string>

namespace {

using luthier::GenericLuthierError;
using luthier::LLVMError;
using luthier::LuthierError;
using luthier::RocmLibraryError;
using luthier::hip::HipError;
using luthier::hsa::HsaError;
using luthier::rocprofiler::RocprofilerError;

//===----------------------------------------------------------------------===//
// Helpers
//===----------------------------------------------------------------------===//

/// Renders an error via its \c log() and consumes it.
std::string render(llvm::Error E) { return llvm::toString(std::move(E)); }

/// Asserts \p E holds no error (and consumes it).
void expectSuccess(llvm::Error E) { EXPECT_FALSE(static_cast<bool>(E)); }

/// The base-class fields of a Luthier error; extracted while consuming \p E.
struct ErrFields {
  std::string Msg, File, Func;
  unsigned Line = 0;
  bool Matched = false;
};
ErrFields fieldsOf(llvm::Error E) {
  ErrFields F;
  llvm::handleAllErrors(std::move(E), [&](const LuthierError &L) {
    F.Msg = std::string(L.getErrorMsg());
    F.File = L.getErrorLocation().file_name();
    F.Func = L.getErrorLocation().function_name();
    F.Line = L.getErrorLocation().line();
    F.Matched = true;
  });
  return F;
}

//===----------------------------------------------------------------------===//
// RTTI / class hierarchy
//===----------------------------------------------------------------------===//

TEST(ErrorTest, RTTIDistinguishesSubclasses) {
  {
    llvm::Error E = LUTHIER_MAKE_GENERIC_ERROR("g");
    EXPECT_TRUE(E.isA<GenericLuthierError>());
    EXPECT_TRUE(E.isA<LuthierError>());
    EXPECT_FALSE(E.isA<LLVMError>());
    EXPECT_FALSE(E.isA<HsaError>());
    EXPECT_FALSE(E.isA<RocmLibraryError>());
    llvm::consumeError(std::move(E));
  }
  {
    llvm::Error E = LUTHIER_MAKE_ERROR(LLVMError, "l");
    EXPECT_TRUE(E.isA<LLVMError>());
    EXPECT_TRUE(E.isA<LuthierError>());
    EXPECT_FALSE(E.isA<GenericLuthierError>());
    llvm::consumeError(std::move(E));
  }
  {
    llvm::Error E = LUTHIER_MAKE_HSA_ERROR("h");
    EXPECT_TRUE(E.isA<HsaError>());
    EXPECT_TRUE(E.isA<RocmLibraryError>());
    EXPECT_TRUE(E.isA<LuthierError>());
    EXPECT_FALSE(E.isA<HipError>());
    EXPECT_FALSE(E.isA<GenericLuthierError>());
    llvm::consumeError(std::move(E));
  }
  {
    llvm::Error E = LUTHIER_MAKE_ERROR(HipError, "h", std::nullopt);
    EXPECT_TRUE(E.isA<HipError>());
    EXPECT_TRUE(E.isA<RocmLibraryError>());
    EXPECT_FALSE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
  {
    llvm::Error E = LUTHIER_MAKE_ERROR(RocprofilerError, "r", std::nullopt);
    EXPECT_TRUE(E.isA<RocprofilerError>());
    EXPECT_TRUE(E.isA<RocmLibraryError>());
    EXPECT_FALSE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
}

//===----------------------------------------------------------------------===//
// convertToErrorCode must be inconvertible
//===----------------------------------------------------------------------===//

TEST(ErrorTest, ConvertToErrorCodeIsInconvertible) {
  // Call convertToErrorCode() directly (not via errorToErrorCode, which itself
  // report_fatal_error's on an inconvertible code): it must return
  // inconvertibleErrorCode()
  std::error_code Generic, Hsa;
  llvm::handleAllErrors(
      LUTHIER_MAKE_GENERIC_ERROR("g"),
      [&](const LuthierError &L) { Generic = L.convertToErrorCode(); });
  llvm::handleAllErrors(
      LUTHIER_MAKE_HSA_ERROR("h"),
      [&](const LuthierError &L) { Hsa = L.convertToErrorCode(); });
  EXPECT_EQ(Generic, llvm::inconvertibleErrorCode());
  EXPECT_EQ(Hsa, llvm::inconvertibleErrorCode());
}

//===----------------------------------------------------------------------===//
// Source location is captured at the macro call site
//===----------------------------------------------------------------------===//

TEST(ErrorTest, MakeMacroCapturesCallerSourceLocation) {
  unsigned Line = 0;
  llvm::Error E = (Line = __LINE__, LUTHIER_MAKE_GENERIC_ERROR("loc"));
  ErrFields F = fieldsOf(std::move(E));
  ASSERT_TRUE(F.Matched);
  EXPECT_EQ(F.Line, Line);
  EXPECT_TRUE(llvm::StringRef(F.File).ends_with("ErrorTest.cpp")) << F.File;
}

//===----------------------------------------------------------------------===//
// log() formatting per class
//===----------------------------------------------------------------------===//

TEST(ErrorTest, LogFormatGeneric) {
  std::string S = render(LUTHIER_MAKE_GENERIC_ERROR("generic-msg"));
  EXPECT_NE(S.find("Error encountered"), std::string::npos) << S;
  EXPECT_NE(S.find("ErrorTest.cpp"), std::string::npos) << S;
  EXPECT_NE(S.find("generic-msg"), std::string::npos) << S;
  EXPECT_NE(S.find("Stack trace"), std::string::npos) << S;
}

TEST(ErrorTest, LogFormatLLVM) {
  std::string S = render(LUTHIER_MAKE_ERROR(LLVMError, "llvm-msg"));
  EXPECT_NE(S.find("Call to LLVM library"), std::string::npos) << S;
  EXPECT_NE(S.find("llvm-msg"), std::string::npos) << S;
}

TEST(ErrorTest, LogFormatHsaWithAndWithoutStatus) {
  std::string WithStatus =
      render(LUTHIER_MAKE_HSA_ERROR_WITH_STATUS("oops", HSA_STATUS_ERROR));
  EXPECT_NE(WithStatus.find("HSA error code "), std::string::npos)
      << WithStatus;
  EXPECT_NE(WithStatus.find(std::to_string(static_cast<int>(HSA_STATUS_ERROR))),
            std::string::npos)
      << WithStatus;
  EXPECT_NE(WithStatus.find("oops"), std::string::npos) << WithStatus;
  // Without a status: prints "HSA error encountered", no "code".
  std::string NoStatus = render(LUTHIER_MAKE_HSA_ERROR("plain"));
  EXPECT_NE(NoStatus.find("HSA error encountered"), std::string::npos)
      << NoStatus;
  EXPECT_EQ(NoStatus.find("error code"), std::string::npos) << NoStatus;
}

TEST(ErrorTest, LogFormatHipAndRocprofiler) {
  std::string Hip =
      render(LUTHIER_MAKE_ERROR(HipError, "hip-msg", hipErrorUnknown));
  EXPECT_NE(Hip.find("HIP error code "), std::string::npos) << Hip;
  EXPECT_NE(Hip.find("hip-msg"), std::string::npos) << Hip;

  std::string Rocp = render(LUTHIER_MAKE_ERROR(RocprofilerError, "rocp-msg",
                                               ROCPROFILER_STATUS_ERROR));
  EXPECT_NE(Rocp.find("Rocprofiler SDK error code "), std::string::npos)
      << Rocp;
  EXPECT_NE(Rocp.find("rocp-msg"), std::string::npos) << Rocp;
}

//===----------------------------------------------------------------------===//
// Stack trace + formatv message
//===----------------------------------------------------------------------===//

TEST(ErrorTest, StackTraceIsCaptured) {
  bool Checked = false;
  llvm::handleAllErrors(LUTHIER_MAKE_GENERIC_ERROR("st"),
                        [&](const LuthierError &L) {
                          EXPECT_FALSE(L.getStackTrace().empty());
                          Checked = true;
                        });
  EXPECT_TRUE(Checked);
}

TEST(ErrorTest, FormatvMessage) {
  ErrFields F =
      fieldsOf(LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv("v={0},w={1}", 7, 8)));
  ASSERT_TRUE(F.Matched);
  EXPECT_EQ(F.Msg, "v=7,w=8");
}

//===----------------------------------------------------------------------===//
// Error-making macros
//===----------------------------------------------------------------------===//

TEST(ErrorTest, MakeErrorVariadicAndHsaWrappers) {
  // The universal maker, with and without a trailing status argument.
  {
    llvm::Error E = LUTHIER_MAKE_ERROR(GenericLuthierError, "x");
    EXPECT_TRUE(E.isA<GenericLuthierError>());
    llvm::consumeError(std::move(E));
  }
  {
    llvm::Error E = LUTHIER_MAKE_ERROR(HsaError, "x", HSA_STATUS_ERROR);
    EXPECT_TRUE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
  // The HSA convenience wrappers delegate to LUTHIER_MAKE_ERROR.
  {
    llvm::Error E = LUTHIER_MAKE_HSA_ERROR("x");
    EXPECT_TRUE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
  {
    llvm::Error E = LUTHIER_MAKE_HSA_ERROR_WITH_STATUS("x", HSA_STATUS_ERROR);
    EXPECT_TRUE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
}

//===----------------------------------------------------------------------===//
// Check macros
//===----------------------------------------------------------------------===//

TEST(ErrorTest, GenericErrorCheckPolarityAndSingleEval) {
  // Assertion polarity: error iff the condition does NOT hold.
  expectSuccess(LUTHIER_GENERIC_ERROR_CHECK(true, "should-not-fire"));
  {
    llvm::Error E = LUTHIER_GENERIC_ERROR_CHECK(false, "fired");
    EXPECT_TRUE(E.isA<GenericLuthierError>());
    llvm::consumeError(std::move(E));
  }
  // The condition is evaluated exactly once.
  int Evals = 0;
  auto Cond = [&]() {
    ++Evals;
    return true;
  };
  expectSuccess(LUTHIER_GENERIC_ERROR_CHECK(Cond(), "x"));
  EXPECT_EQ(Evals, 1);
}

TEST(ErrorTest, LLVMErrorCheckSuccessAndWrap) {
  expectSuccess(LUTHIER_LLVM_ERROR_CHECK(llvm::Error::success(), "ctx"));

  // A failing llvm::Error is consumed and wrapped (no "unhandled Error" abort),
  // with the context message prepended to the original.
  llvm::Error Src =
      llvm::createStringError(llvm::inconvertibleErrorCode(), "orig");
  std::string S = render(LUTHIER_LLVM_ERROR_CHECK(std::move(Src), "ctx"));
  EXPECT_NE(S.find("ctx"), std::string::npos) << S;
  EXPECT_NE(S.find("orig"), std::string::npos) << S;
  EXPECT_NE(S.find("Call to LLVM library"), std::string::npos) << S;
}

TEST(ErrorTest, HsaCallAndPredicateChecks) {
  expectSuccess(LUTHIER_HSA_CALL_ERROR_CHECK(HSA_STATUS_SUCCESS, "ok"));
  {
    llvm::Error E = LUTHIER_HSA_CALL_ERROR_CHECK(HSA_STATUS_ERROR, "bad");
    EXPECT_TRUE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
  // The status expression is evaluated exactly once. The local is named
  // `Status` on purpose: it would collide with the macro's internal local if
  // that local were still named `Status` (it is now `LuthierStatusCode`), so
  // this also guards against the shadowing regression.
  int Evals = 0;
  auto Status = [&]() {
    ++Evals;
    return HSA_STATUS_ERROR;
  };
  llvm::consumeError(LUTHIER_HSA_CALL_ERROR_CHECK(Status(), "x"));
  EXPECT_EQ(Evals, 1);
  // Predicate form: error iff the condition is false.
  expectSuccess(LUTHIER_HSA_ERROR_CHECK(true, "ok"));
  {
    llvm::Error E = LUTHIER_HSA_ERROR_CHECK(false, "bad");
    EXPECT_TRUE(E.isA<HsaError>());
    llvm::consumeError(std::move(E));
  }
}

TEST(ErrorTest, HipAndRocprofilerCallChecksCaptureCallerLocation) {
  expectSuccess(LUTHIER_HIP_CALL_ERROR_CHECK(hipSuccess, "ok"));
  expectSuccess(
      LUTHIER_ROCPROFILER_CALL_ERROR_CHECK(ROCPROFILER_STATUS_SUCCESS, "ok"));

  // On failure the error's location is the caller (this file), not LLVM's
  // Error.h
  ErrFields Hip =
      fieldsOf(LUTHIER_HIP_CALL_ERROR_CHECK(hipErrorUnknown, "hip"));
  ASSERT_TRUE(Hip.Matched);
  EXPECT_TRUE(llvm::StringRef(Hip.File).ends_with("ErrorTest.cpp")) << Hip.File;

  ErrFields Rocp = fieldsOf(
      LUTHIER_ROCPROFILER_CALL_ERROR_CHECK(ROCPROFILER_STATUS_ERROR, "rocp"));
  ASSERT_TRUE(Rocp.Matched);
  EXPECT_TRUE(llvm::StringRef(Rocp.File).ends_with("ErrorTest.cpp"))
      << Rocp.File;
}

//===----------------------------------------------------------------------===//
// LUTHIER_RETURN_ON_ERROR (works for Error- and Expected<T>-returning funcs)
//===----------------------------------------------------------------------===//

llvm::Expected<int> returnOnErrorHelper(bool Fail) {
  LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(!Fail, "helper-failed"));
  return 42;
}

TEST(ErrorTest, ReturnOnError) {
  llvm::Expected<int> Ok = returnOnErrorHelper(/*Fail=*/false);
  ASSERT_TRUE(static_cast<bool>(Ok));
  EXPECT_EQ(*Ok, 42);

  llvm::Expected<int> Err = returnOnErrorHelper(/*Fail=*/true);
  ASSERT_FALSE(static_cast<bool>(Err));
  std::string S = render(Err.takeError());
  EXPECT_NE(S.find("helper-failed"), std::string::npos) << S;
}

//===----------------------------------------------------------------------===//
// LUTHIER_REPORT_FATAL_ON_ERROR
//===----------------------------------------------------------------------===//

TEST(ErrorTest, ReportFatalOnErrorIgnoresSuccess) {
  // Success must NOT abort; control falls through.
  LUTHIER_REPORT_FATAL_ON_ERROR(llvm::Error::success());
  SUCCEED();
}

// Suite named *DeathTest so gtest schedules it before any threads exist.
TEST(ErrorDeathTest, ReportFatalOnErrorAbortsWithMessage) {
  EXPECT_DEATH(
      {
        LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_MAKE_GENERIC_ERROR("fatal-boom"));
      },
      "fatal-boom");
}

} // namespace
