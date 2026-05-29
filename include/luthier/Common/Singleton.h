//===-- Singleton.h - Luthier Singleton Interface ---------------*- C++ -*-===//
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
/// An atomic reference-counted Singleton CRTP trait.
///
/// The \c Singleton instance's lifetime is managed explicitly via
/// \c createInstance() and  \c destroyInstance(). \c withInstance ensures the
/// \c Singleton instance remains alive while it is being operated on, making
/// it safe to use in static API table wrapper functions in multithreaded
/// environments. Internally, the singleton's lifetime is held by an atomic
/// reference count:
///   - \c createInstance() builds \c Derived with no lock held, then publishes
///   the instance to the outside world (fatal if one already exists).
///   - \c destroyInstance() unpublishes the instance, then drains any in-flight
///   references before running \c Derived::~Derived.
///   - \c withInstance() takes a counted reference and runs \p Fn with \b no
///   lock held, so it is reentrant and harmless to call during \c Singleton
///   construction (in which it observes "no instance" and returns \c false).
///
/// Internally, the \c Singleton's atomic reference counting capability is
/// implemented either via:
/// - An \c std::atomic<std::shared_ptr> if \c __cpp_lib_atomic_shared_ptr is
/// available (libstdc++ >= GCC 12, MSVC STL >= VS2019 16.9; \b not available
/// currently in libc++) or by defining the \c LUTHIER_SINGLETON_FORCE_INTRUSIVE
/// macro;
/// - Otherwise, an intrusive \c llvm::IntrusiveRefCntPtr held in a slot guarded
/// by a briefly held \c std::shared_mutex. The refcount hooks are \e private
/// and reached only through a friended, constrained
/// \c llvm::IntrusiveRefCntPtrInfo specialization, so \c Retain / \c Release
/// never appear on \c Derived's API.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_SINGLETON_H
#define LUTHIER_COMMON_SINGLETON_H
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include <cassert>
#include <cstddef>
#include <functional>
#include <new>
#include <optional>
#include <thread>
#include <type_traits>
#include <utility>
#include <version>

#if defined(__cpp_lib_atomic_shared_ptr) &&                                    \
    !defined(LUTHIER_SINGLETON_FORCE_INTRUSIVE)
#define LUTHIER_SINGLETON_USE_SHARED_PTR 1
#include <atomic>
#include <memory>
#else
#define LUTHIER_SINGLETON_USE_SHARED_PTR 0
#include "llvm/ADT/IntrusiveRefCntPtr.h"
#include <atomic>
#include <mutex>
#include <shared_mutex>
#endif

namespace luthier {

/// \brief An atomic reference-counted Singleton CRTP trait
/// \tparam Derived The concrete Singleton object itself
template <typename Derived> class Singleton {
private:
  //==========================================================================//
  // Implementation-specific storage primitives. The public API below is
  // written once against this private interface.
  //==========================================================================//
#if LUTHIER_SINGLETON_USE_SHARED_PTR
  using Ref = std::shared_ptr<Derived>;

  /// Process-lifetime owning slot, placement-new'd once and never destroyed so
  /// a late interceptor at process teardown can't touch a destroyed atomic.
  static std::atomic<Ref> &instance() {
    alignas(std::atomic<Ref>) static std::byte Buf[sizeof(std::atomic<Ref>)];
    static auto *const Slot = ::new (Buf) std::atomic<Ref>();
    return *Slot;
  }

  static Ref loadInstance() { return instance().load(); }

  static bool publish(Derived *Obj) {
    Ref New(Obj), Expected{nullptr};
    return instance().compare_exchange_strong(Expected, New);
  }

  static Ref unpublish() { return instance().exchange(nullptr); }

  static long instanceUseCount(const Ref &R) { return R.use_count(); }
#else
  /// Reference count for the live instance. Manipulated only through the
  /// friended \c IntrusiveRefCntPtrInfo specialization
  mutable std::atomic<int> RefCount{0};
  friend struct llvm::IntrusiveRefCntPtrInfo<Derived>;

  void retain() const { RefCount.fetch_add(1, std::memory_order_relaxed); }

  void release() const {
    int New = RefCount.fetch_sub(1, std::memory_order_acq_rel) - 1;
    assert(New >= 0 && "Singleton reference count went negative.");
    if (New == 0)
      delete static_cast<const Derived *>(this); // legal: public CRTP base
  }

  unsigned useCount() const { return RefCount.load(std::memory_order_relaxed); }

  using Ref = llvm::IntrusiveRefCntPtr<Derived>;

  /// Reader/writer lock guarding the brief load-and-retain of \c instance()
  /// (there is no atomic \c IntrusiveRefCntPtr). Never destroyed.
  static std::shared_mutex &liveMutex() {
    alignas(std::shared_mutex) static std::byte Buf[sizeof(std::shared_mutex)];
    static auto *const Mutex = ::new (Buf) std::shared_mutex();
    return *Mutex;
  }

  /// Process-lifetime owning slot, placement-new'd once and never destroyed.
  static Ref &instance() {
    alignas(Ref) static std::byte Buf[sizeof(Ref)];
    static auto *const Slot = ::new (Buf) Ref();
    return *Slot;
  }

  static Ref loadInstance() {
    std::shared_lock<std::shared_mutex> Lock(liveMutex());
    return instance(); // atomic retain under the briefly held shared lock
  }

  static bool publish(Derived *Obj) {
    Ref New(Obj); // adopt, so Obj is freed if publication loses the race
    std::unique_lock<std::shared_mutex> Lock(liveMutex());
    if (instance().get() != nullptr)
      return false;
    instance() = New;
    return true;
  }

  static Ref unpublish() {
    std::unique_lock<std::shared_mutex> Lock(liveMutex());
    Ref Old;
    Old.swap(instance());
    return Old;
  }

  static long instanceUseCount(const Ref &R) { return R.useCount(); }
#endif

#ifndef NDEBUG
  /// Per-thread recursion depth of \c withInstance() for this singleton. Used
  /// in debug builds to catch \c destroyInstance() calls from inside
  /// \c withInstance() on the same thread, which would leave the caller's own
  /// reference undropped and cause a forever spin
  inline static thread_local int WithInstanceDepth = 0;

  /// RAII bump of \c WithInstanceDepth around a \c withInstance() callback.
  struct DepthGuard {
    DepthGuard() { ++WithInstanceDepth; }
    ~DepthGuard() { --WithInstanceDepth; }
  };
#endif

protected:
  Singleton() = default;

  ~Singleton() = default;

public:
  /// Disallowed copy construction
  Singleton(const Singleton &) = delete;

  /// Disallowed assignment operation
  Singleton &operator=(const Singleton &) = delete;

  /// Passkey that gates construction of the singleton. Only \c createInstance()
  /// can mint one (its default constructor is private, only accessible by the
  /// \c Singleton), so a \c Derived constructor that takes a \c CreationKey is
  /// reachable only through \c createInstance() — a bare \c new \c Derived(...)
  /// will not compile
  class CreationKey {
    CreationKey() = default;
    friend class Singleton;
  };

  //==========================================================================//
  // Public-facing APIs: identical for both implementations.
  //==========================================================================//

  /// Run \p Fn against the live instance, holding it alive for the whole call
  /// via a counted reference rather than a held lock. \p Fn is invoked as
  /// <tt>Fn(Derived &)</tt>.
  /// \note This is safe to call recursively and during construction
  /// \warning Never call \c destroyInstance() from inside \c withInstance():
  /// the caller's own reference would never drop and would cause the
  /// destruction logic to spin forever.
  /// \return Depends on \p Fn's return type \c R:
  ///   - \c void: \c true if an instance existed and \p Fn was invoked,
  ///     \c false otherwise.
  ///   - a reference type \c T&: \c std::optional<std::reference_wrapper<T>>
  ///     holding \p Fn's result, or \c std::nullopt if there was no instance.
  ///   - any other value type \c R: \c std::optional<R> holding \p Fn's result,
  ///     or \c std::nullopt if there was no instance.
  template <typename FnT> static auto withInstance(FnT &&Fn) {
    using R = std::invoke_result_t<FnT, Derived &>;
    Ref Held = loadInstance();
    if constexpr (std::is_void_v<R>) {
      if (!Held)
        return false;
#ifndef NDEBUG
      DepthGuard Guard;
#endif
      std::forward<FnT>(Fn)(*Held);
      return true;
    } else if constexpr (std::is_reference_v<R>) {
      // std::optional cannot hold a reference; wrap it so a reference-returning
      // callback still composes.
      using Result = std::optional<std::reference_wrapper<std::remove_reference_t<R>>>;
      if (!Held)
        return Result{};
#ifndef NDEBUG
      DepthGuard Guard;
#endif
      return Result(std::forward<FnT>(Fn)(*Held));
    } else {
      if (!Held)
        return std::optional<R>{};
#ifndef NDEBUG
      DepthGuard Guard;
#endif
      return std::optional<R>(std::forward<FnT>(Fn)(*Held));
    }
  }

  /// Construct the instance and publish it; Fatal if an instance is
  /// already published. The published instance can be accessed via
  /// \c withInstance()
  /// \note \c Derived's constructor must accept a \c CreationKey as its first
  /// parameter (see \c CreationKey).
  template <typename... Args>
  static void createInstance(Args &&...Arguments) {
    auto *Obj = ::new Derived(CreationKey{}, std::forward<Args>(Arguments)...);
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        publish(Obj), "Called createInstance() twice."));
  }

  /// Unpublishes the instance, then blocks until all in-flight
  /// \c withInstance() references drop before releasing the final one,
  /// effectively destroying it.
  /// \note This is safe to call when no instances of the singleton have been
  /// created previously
  static void destroyInstance() {
#ifndef NDEBUG
    assert(WithInstanceDepth == 0 &&
           "destroyInstance() called from inside withInstance() on the same "
           "thread.");
#endif
    Ref Doomed = unpublish();
    if (!Doomed)
      return;
    while (instanceUseCount(Doomed) > 1)
      std::this_thread::yield();
    Doomed.reset();
  }
};

} // namespace luthier

#if !LUTHIER_SINGLETON_USE_SHARED_PTR
namespace llvm {

/// Routes \c IntrusiveRefCntPtr's retain/release/useCount to the \e private
/// hooks on \c luthier::Singleton (friended above), keeping them off
/// \c Derived's public API. Constrained so it applies only to Singleton-derived
/// types; all others use the primary template.
template <typename Derived>
  requires std::is_base_of_v<luthier::Singleton<Derived>, Derived>
struct IntrusiveRefCntPtrInfo<Derived> {
  static void retain(Derived *Obj) { Obj->retain(); }

  static void release(Derived *Obj) { Obj->release(); }

  static unsigned useCount(const Derived *Obj) { return Obj->useCount(); }
};
} // namespace llvm
#endif

#endif
