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
/// Defines the CRTP trait inherited by all Singleton objects in Luthier.
/// It was inspired by OGRE's Singleton implementation:
/// https://github.com/OGRECave/ogre/blob/master/OgreMain/include/OgreSingleton.h
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_SINGLETON_H
#define LUTHIER_COMMON_SINGLETON_H
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include <cstddef>
#include <mutex>
#include <new>
#include <shared_mutex>
#include <utility>

namespace luthier {

/// \brief CRTP trait inherited by all Singleton objects in Luthier
/// \tparam Derived The concrete Singleton object itself
///
/// \par Lifetime and threading contract
/// The object is meant to be managed explicitly with \c createInstance() and
/// torn down via \c destroyInstance() (no static-storage instance) for precise
/// control over its lifetime. Every access to the instance is mediated by a
/// process-lifetime reader/writer lock so that accessors may run on threads
/// other than the one performing construction/destruction.
///
/// - \b Construction goes through \c createInstance(), which acquires the
///   exclusive lock around the whole \c new. Holding it across the entire
///   construction (base, traits, and \c Derived members) means no
///   \c withInstance() reader can observe the instance until it is fully
///   built./// - \b Access goes through \c withInstance(), which runs the
///   supplied callable under a \e shared lock and thereby holds the instance
///   alive for the whole call.
/// - \b Teardown goes through \c destroyInstance(), which acquires the matching
///   \e exclusive lock around the whole \c delete. This blocks until every
///   in-flight \c withInstance() call has finished and prevents new ones from
///   starting; Therefore, no callback can observe a half-destroyed object.
///
///
/// \note Lock-ordering invariant: \c liveMutex is the outermost lock. Code
/// running inside a \c withInstance() callable may acquire other (e.g.
/// per-trait) locks, but nothing that already holds such a lock may call
/// \c withInstance() / \c destroyInstance(); doing so would invert the order
/// and risk deadlock.
/// \note A bare \c new or \delete bypasses the locking access mechanism of the
/// singleton; Make sure to construct the singleton only via
/// \c createInstance().
template <typename Derived> class Singleton {
private:
  /// The single live instance, or \c nullptr. Guarded by \c liveMutex():
  /// read under a shared lock, written under the exclusive lock.
  inline static Derived *Instance{nullptr};

  /// Process-lifetime reader/writer lock guarding the instance against
  /// destruction while \c withInstance() callables run. It must outlive every
  /// possible use (e.g. a late HSA wrapper callback firing during process
  /// teardown), so it is \b never destroyed to avoid the static initialization
  /// ordering fiasco
  ///
  /// Rather than \c new (a heap leak that trips leak sanitizers), the lock is
  /// placement-new'd once into a buffer with static storage duration — the
  /// idiom \c rocprofiler-sdk uses for its \c static_object. The object lives
  /// in the binary image (no allocation), and because placement \c new
  /// schedules no destruction, \c ~shared_mutex() is simply never called. This
  /// is well-defined (skipping a destructor is legal; the storage is reclaimed
  /// at process exit). It also works regardless of \c std::shared_mutex being
  /// trivially destructible
  static std::shared_mutex &liveMutex() {
    alignas(std::shared_mutex) static std::byte Buf[sizeof(std::shared_mutex)];
    static auto *const Mutex = ::new (Buf) std::shared_mutex();
    return *Mutex;
  }

protected:
  /// Publishes \c this as the singleton instance. Fatal if an instance already
  /// exists.
  ///
  /// Does \b not lock: it is meant to run inside \c createInstance(), which
  /// holds the exclusive lock across the entire \c new (mirroring how
  /// \c ~Singleton() runs inside \c destroyInstance()'s \c delete). It must
  /// not re-acquire the lock — that would self-deadlock. Constructing a
  /// singleton with a bare \c new (outside \c createInstance()) bypasses the
  /// lock and is not recommended in threaded scenarios
  Singleton() {
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        Instance == nullptr, "Called the Singleton constructor twice."));
    Instance = static_cast<Derived *>(this);
  }

  /// Clears the published instance pointer. Runs during the \c delete issued
  /// by \c destroyInstance(), i.e. while the caller already holds the
  /// exclusive lock; Which is why it must \b not re-acquire it.
  ~Singleton() { Instance = nullptr; }

public:
  /// Disallowed copy construction
  Singleton(const Singleton &) = delete;

  /// Disallowed assignment operation
  Singleton &operator=(const Singleton &) = delete;

  /// Run \p Fn against the live instance while keeping it alive for the whole
  /// call. \p Fn is invoked as <tt>Fn(T &)</tt> under a shared lock; the
  /// matching exclusive lock taken by \c destroyInstance() guarantees the
  /// instance (and its trait subobjects) are not destroyed for the duration
  /// of \p Fn, and that \p Fn does not begin once teardown has started.
  ///
  /// \return \c true if the instance existed and \p Fn was invoked, \c false
  /// if there was no live instance (in which case \p Fn is not called).
  ///
  /// \warning \p Fn must not call \c destroyInstance() (it would deadlock
  /// against its own shared lock) nor call \c withInstance() reentrantly on
  /// the same thread (recursive shared locking is undefined).
  template <typename FnT> static bool withInstance(FnT &&Fn) {
    std::shared_lock<std::shared_mutex> Lock(liveMutex());
    if (Instance == nullptr)
      return false;
    std::forward<FnT>(Fn)(*Instance);
    return true;
  }

  /// Construct the singleton instance under the exclusive lock, forwarding
  /// \p Args to \c Derived's constructor. Holding the lock across the whole
  /// \c new means the \e entire object — the \c Singleton base, every trait
  /// subobject, and \c Derived's own members — is built before any
  /// \c withInstance() reader can acquire the shared lock and observe it. This
  /// mirrors \c destroyInstance(): together they make the lock (not just the
  /// single-threaded construction convention) carry the "no reader ever sees
  /// /// a partially-(de)constructed instance" guarantee.
  ///
  /// If \c Derived's constructor throws, the partially built subobjects
  /// (including the \c Singleton base) are destroyed during unwinding —
  /// \c ~Singleton() clears \c Instance — all still under the exclusive lock,
  /// so the failure leaves no instance published. Fatal if an instance
  /// already exists. Construct only via this function, never a bare \c new.
  template <typename... Args>
  static Derived &createInstance(Args &&...Arguments) {
    std::unique_lock<std::shared_mutex> Lock(liveMutex());
    return *::new Derived(std::forward<Args>(Arguments)...);
  }

  /// Destroy the singleton instance (created via \c createInstance()) under the
  /// exclusive lock, blocking until all in-flight \c withInstance() calls
  /// complete and preventing new ones from starting. This is the only teardown
  /// path that preserves the \c withInstance() liveness guarantee; a bare
  /// \c delete on the instance pointer does not. Safe to call when no instance
  /// exists (no-op). The owner does not need to also \c delete the pointer.
  static void destroyInstance() {
    std::unique_lock<std::shared_mutex> Lock(liveMutex());
    /// \c ~Singleton() clears \c Instance during this \c delete.
    delete Instance;
  }
};

} // namespace luthier

#endif
