//===-- ApiTableRegistrationCallbackProvider.h -------------------*- C++-*-===//
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
/// Defines the \c ApiTableRegistrationCallbackProvider class which provide
/// a callback to its user or sub-classes when an API table is registered with
/// rocprofiler-sdk.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_ROCPROFILER_API_TABLE_REGISTRATION_CALLBACK_PROVIDER_H
#define LUTHIER_ROCPROFILER_API_TABLE_REGISTRATION_CALLBACK_PROVIDER_H
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/ApiTable.h"
#include "luthier/HSA/HsaError.h"
#include "luthier/Rocprofiler/RocprofilerError.h"
#include <atomic>
#include <exception>
#include <mutex>
/// hip_api_trace.hpp declares typedefs for the *entire* HIP API surface —
/// including the R0000-suffixed deprecated entries and the GL interop
/// entries — but doesn't itself include the headers that define those
/// types; Pull them in here
#include <hip/hip_runtime.h>
#include <hip/hip_deprecated.h>
#include <hip/hip_gl_interop.h>

#include <hip/amd_detail/hip_api_trace.hpp>
#include <rocprofiler-sdk/intercept_table.h>
#include <rocprofiler-sdk/registration.h>

namespace luthier::rocprofiler {

/// \brief Struct providing static information regarding the
/// \c rocprofiler_intercept_table_t enum, including its table type
/// and the number of tables that are registered with rocprofiler-sdk
template <rocprofiler_intercept_table_t TableType> struct ApiTableEnumInfo;

template <> struct ApiTableEnumInfo<ROCPROFILER_HSA_TABLE> {
  using ApiTableType = ::HsaApiTable;
  constexpr static auto NumApiTables = 1;
  constexpr static auto ApiTableName = "HSA";
};

template <> struct ApiTableEnumInfo<ROCPROFILER_HIP_COMPILER_TABLE> {
  using ApiTableType = ::HipCompilerDispatchTable;
  constexpr static auto NumApiTables = 1;
  constexpr static auto ApiTableName = "HIP Compiler";
};

template <> struct ApiTableEnumInfo<ROCPROFILER_HIP_RUNTIME_TABLE> {
  using ApiTableType = ::HipDispatchTable;
  constexpr static auto NumApiTables = 1;
  constexpr static auto ApiTableName = "HIP Runtime";
};

/// \brief a generic class used to safely request a callback to be invoked when
/// an Api table is registered with rocprofiler-sdk. Can be either used as is
/// or inherited by a sub-class
template <rocprofiler_intercept_table_t TableType>
class ApiTableRegistrationCallbackProvider {
private:
  /// Set to \c true the first time \c std::terminate fires after
  /// \c installHostAbortedSentinelOnce runs. Read by the destructor to
  /// distinguish "the host aborted before rocprofiler could call our
  /// callback" (warning-worthy) from "rocprofiler is up but never called
  /// us" (programming bug). We need a side channel because by the time
  /// the destructor runs, the C++ runtime has cleared the in-flight
  /// exception (LLVM's signal handler intercepts \c SIGABRT and exits
  /// cleanly, triggering normal static-destructor unwind — so
  /// \c std::uncaught_exceptions() returns 0).
  ///
  /// Each template instantiation has its own copy; that's fine because
  /// the chained terminate handlers below set every instantiation's
  /// flag in order, so all destructors observe the abort regardless of
  /// which one's handler was the outermost.
  inline static std::atomic<bool> HostAbortedDuringExecution{false};
  /// Previous terminate handler captured at install time so this
  /// instantiation's handler can chain to it. \c std::set_terminate
  /// takes a plain function pointer (not a \c std::function), so the
  /// handler can't close over this — it has to be a static field the
  /// handler reads directly.
  inline static std::atomic<std::terminate_handler> PrevTerminateHandler{
      nullptr};

  static void hostAbortedTerminateHandler() noexcept {
    HostAbortedDuringExecution.store(true);
    if (auto Prev = PrevTerminateHandler.load())
      Prev();
    std::abort();
  }

  static void installHostAbortedSentinelOnce() {
    static std::once_flag Installed;
    std::call_once(Installed, [] {
      /// Chain to whatever terminate handler is currently installed so
      /// we don't suppress LLVM's stack-trace dump or another
      /// instantiation's sentinel — we just observe and pass through.
      PrevTerminateHandler.store(
          std::set_terminate(hostAbortedTerminateHandler));
    });
  }

protected:
  /// Keeps track of whether the registration callback has been invoked by
  /// rocprofiler-sdk
  std::atomic<bool> WasRegistrationInvoked{false};

  using CallbackType = std::function<void(
      llvm::ArrayRef<typename ApiTableEnumInfo<TableType>::ApiTableType *>
          Tables,
      uint64_t LibVersion, uint64_t LibInstance)>;

  /// Callback invoked inside the registration callback
  const CallbackType Callback;

  /// API table registration callback for used by rocprofiler-sdk
  static void apiRegistrationCallback(rocprofiler_intercept_table_t Type,
                                      uint64_t LibVersion, uint64_t LibInstance,
                                      void **Tables, uint64_t NumTables,
                                      void *Data) {
    /// Check for errors
    if (NumTables != ApiTableEnumInfo<TableType>::NumApiTables) {
      LUTHIER_REPORT_FATAL_ON_ERROR(
          llvm::make_error<rocprofiler::RocprofilerError>(llvm::formatv(
              "Expected rocprofiler to register {0} API table(s), "
              "instead got {1}",
              ApiTableEnumInfo<TableType>::NumApiTables, NumTables)));
    }
    if (Type != TableType) {
      LUTHIER_REPORT_FATAL_ON_ERROR(
          llvm::make_error<rocprofiler::RocprofilerError>(llvm::formatv(
              "Expected to get API table of type {0}, but instead got "
              "{1}",
              TableType, Type)));
    }
    if (Tables == nullptr) {
      LUTHIER_REPORT_FATAL_ON_ERROR(
          llvm::make_error<rocprofiler::RocprofilerError>(
              "API tables passed by rocprofiler is nullptr"));
    }

    auto &RegProvider =
        *static_cast<ApiTableRegistrationCallbackProvider *>(Data);

    llvm::ArrayRef TablesAsArrayRef(
        reinterpret_cast<typename ApiTableEnumInfo<TableType>::ApiTableType **>(
            Tables),
        NumTables);

    for (const auto *Table : TablesAsArrayRef) {
      if (!Table) {
        LUTHIER_REPORT_FATAL_ON_ERROR(
            llvm::make_error<rocprofiler::RocprofilerError>(
                "API table passed by rocprofiler is nullptr"));
      }
    }

    RegProvider.Callback(TablesAsArrayRef, LibVersion, LibInstance);
    RegProvider.WasRegistrationInvoked.store(true);
  }

public:
  /// Constructor
  /// \note Must only be invoked before rocprofiler-sdk has been
  /// fully configured (i.e, inside the \c rocprofiler_configure function)
  /// \param CB The callback to be invoked once rocprofiler-sdk has reported
  /// back with the requested API table. The callback provides the following
  /// arguments: a) A list of pointers of the API tables passed by
  /// rocprofiler-sdk; These pointers are checked to not be \c nullptr before
  /// they are passed to the client. b)\c uint64_t version of the library as
  /// passed by rocprofiler-sdk; and c) \c uint64_t indicating the number of
  /// times this library has registered itself with rocprofiler-sdk before. The
  /// class also checks if rocprofiler-sdk has passed the correct number of
  /// tables expected for the library of choice, as described in the \c
  /// ApiTableEnumInfo of the \c TableType before invoking the \p CB
  /// \param Err an externally initialized \c llvm::Error that will report
  /// back any errors encountered by this constructor
  ApiTableRegistrationCallbackProvider(CallbackType CB, llvm::Error &Err)
      : Callback(std::move(CB)) {
    llvm::ErrorAsOutParameter EAO(Err);
    /// Install once on first construction so the destructor can later
    /// distinguish a host-side abort from a real "rocprofiler never
    /// called us" bug.
    installHostAbortedSentinelOnce();
    Err = std::move(LUTHIER_ROCPROFILER_CALL_ERROR_CHECK(
        rocprofiler_at_intercept_table_registration(
            ApiTableRegistrationCallbackProvider::apiRegistrationCallback,
            TableType, this),
        llvm::formatv("Failed to request a callback on {0} API table "
                      "initialization from "
                      "rocprofiler-sdk",
                      ApiTableEnumInfo<TableType>::ApiTableName)));
  };

  /// Destructor
  /// \note The object must only be destroyed only if: a) rocprofiler is in the
  /// process of being finalized; or b) rocprofiler has performed the scheduled
  /// callback by this object, which can be checked via \c
  /// wasRegistrationCallbackInvoked; or c) rocprofiler-sdk was never
  /// initialized in the first place (the host aborted before any HSA/HIP
  /// call could pull rocprofiler in); or d) the destructor is running
  /// during stack unwinding from an in-flight host-side exception
  /// (the application is mid-abort, so an unfulfilled callback is a
  /// symptom of the abort, not a Luthier bug).
  ///
  /// Cases (c) and (d) cover the early-abort scenario — e.g. the
  /// application throws an unhandled \c std::exception from a CImg load
  /// or a file open before dispatching any kernel. In (c) rocprofiler
  /// hasn't been initialized at all; in (d) rocprofiler initialized
  /// (often during static-init or the first ROCm symbol touched on the
  /// way to the throw) but the host never got around to issuing a HIP
  /// dispatch. Fataling in either case would escalate an unrelated
  /// host-side crash into a LUTHIER-FAIL. We distinguish them from a
  /// genuine "rocprofiler ran but never told us" bug by checking
  /// \c rocprofiler_is_initialized and \c std::uncaught_exceptions().
  virtual ~ApiTableRegistrationCallbackProvider() {
    /// Case (b): the registration callback already fired — our job is
    /// done, regardless of rocprofiler's lifecycle state.
    if (WasRegistrationInvoked.load())
      return;

    int RocprofilerInitStatus = 0;
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_ROCPROFILER_CALL_ERROR_CHECK(
        rocprofiler_is_initialized(&RocprofilerInitStatus),
        "Failed to check rocprofiler's initialization status."));
    /// Case (c): rocprofiler-sdk was never initialized. Nothing to
    /// reconcile — the host aborted before any HSA/HIP call brought
    /// rocprofiler up.
    if (RocprofilerInitStatus == 0)
      return;

    int RocprofilerFiniStatus = 0;
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_ROCPROFILER_CALL_ERROR_CHECK(
        rocprofiler_is_finalized(&RocprofilerFiniStatus),
        "Failed to check rocprofiler's finalization status."));
    /// Case (a): rocprofiler is finalizing or finalized — expected
    /// shutdown path, regardless of whether our callback fired.
    if (RocprofilerFiniStatus != 0)
      return;

    /// Case (d): the host called \c std::terminate (typically via an
    /// uncaught exception, a noexcept violation, or an unhandled
    /// signal that the runtime translated into a terminate). The
    /// program is on its way out via abort; an unfulfilled callback in
    /// that path is a consequence of the host crashing, not a Luthier
    /// bug. We can't rely on \c std::uncaught_exceptions() here
    /// because by the time our destructor runs (via static-destructor
    /// unwind from LLVM's signal handler's exit path) the exception
    /// state has already been cleared — so we use a side-channel flag
    /// recorded by a chained \c std::set_terminate handler.
    if (HostAbortedDuringExecution.load()) {
      llvm::errs() << "[ApiTableRegistrationCallbackProvider] warning: "
                   << "destroyed after host-side std::terminate; "
                   << "rocprofiler-sdk had not invoked the registration "
                   << "callback yet\n";
      return;
    }

    /// Rocprofiler is up and not finalizing, no in-flight exception, but
    /// the callback was never invoked — that is a genuine programming
    /// error.
    LUTHIER_REPORT_FATAL_ON_ERROR(llvm::make_error<llvm::StringError>(
        "ApiTableRegistrationCallbackProvider destroyed while "
        "rocprofiler-sdk is initialized and not finalizing, but the "
        "registration callback was never invoked.",
        llvm::inconvertibleErrorCode()));
  }

  /// Checks whether rocprofiler-sdk has invoked the registration callback and
  /// the requested user callback has been invoked
  [[nodiscard]] bool wasRegistrationCallbackInvoked() const {
    return WasRegistrationInvoked.load();
  }

  /// If the API table is not registered by the application with
  /// rocprofiler-sdk, forces its initialization by directly calling a
  /// "harmless" library function directly
  /// \note Only use when absolutely sure the underlying library is not going to
  /// be initialized otherwise
  template <rocprofiler_intercept_table_t T = TableType,
            typename = std::enable_if_t<T == ROCPROFILER_HSA_TABLE ||
                                        T == ROCPROFILER_HIP_RUNTIME_TABLE>>
  void forceTriggerApiTableCallback() {
    if (!WasRegistrationInvoked.load()) {
      if constexpr (TableType == ROCPROFILER_HSA_TABLE)
        (void)hsa_status_string(HSA_STATUS_SUCCESS, nullptr);
      else
        (void)hipApiName(0);
    }
  }
};

} // namespace luthier::rocprofiler

#endif