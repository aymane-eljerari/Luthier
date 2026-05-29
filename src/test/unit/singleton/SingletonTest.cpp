//===-- SingletonTest.cpp -------------------------------------*- C++ -*-===//
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
/// Unit tests for \c luthier::Singleton. This source is backend-agnostic and is
/// compiled into two executables: one against the default backend
/// (\c std::atomic<std::shared_ptr> where available) and one with
/// \c LUTHIER_SINGLETON_FORCE_INTRUSIVE so the intrusive
/// \c llvm::IntrusiveRefCntPtr backend is exercised too.
//===----------------------------------------------------------------------===//
#include "luthier/Common/Singleton.h"
#include <atomic>
#include <chrono>
#include <gtest/gtest.h>
#include <optional>
#include <thread>
#include <type_traits>
#include <vector>

namespace {

/// Basic singleton used by most tests. Tracks live-object count so tests can
/// assert the instance is actually destroyed.
struct Counter : luthier::Singleton<Counter> {
  int Value;
  static inline std::atomic<int> Live{0};
  explicit Counter(CreationKey, int V) : Value(V) { Live.fetch_add(1); }
  ~Counter() { Live.fetch_sub(1); }
};

//===----------------------------------------------------------------------===//
// Compile-time checks for the CreationKey passkey (A3).
//===----------------------------------------------------------------------===//

// Cannot be built from the plain user argument list: construction is gated by
// the passkey, so only createInstance() (which can mint a CreationKey) reaches
// the constructor.
static_assert(!std::is_constructible_v<Counter, int>,
              "Counter must not be constructible without the CreationKey");

// The constructor shape is (CreationKey, Args...): is_constructible only needs
// a hypothetical CreationKey value (declval), so this holds even though the key
// cannot actually be minted outside Singleton.
static_assert(std::is_constructible_v<Counter, Counter::CreationKey, int>,
              "Counter must be constructible with the passkey + args");

// The key itself cannot be default-constructed from outside Singleton (its
// constructor is private), so callers cannot forge one to bypass the gate.
static_assert(!std::is_default_constructible_v<Counter::CreationKey>,
              "CreationKey must not be mintable outside Singleton");

// Singletons are neither copyable nor movable.
static_assert(!std::is_copy_constructible_v<Counter>);
static_assert(!std::is_move_constructible_v<Counter>);

//===----------------------------------------------------------------------===//
// Fixtures. The published instance is a process-global static, and gtest runs
// tests sequentially in one process, so every test must leave the slot empty.
//===----------------------------------------------------------------------===//

class SingletonTest : public ::testing::Test {
protected:
  void SetUp() override {
    Counter::destroyInstance(); // clear any leftover from a previous test
    Counter::Live.store(0);
  }
  void TearDown() override { Counter::destroyInstance(); }
};

// Distinct suite name (gtest convention groups death tests under *DeathTest).
class SingletonDeathTest : public SingletonTest {};

//===----------------------------------------------------------------------===//
// Functional tests.
//===----------------------------------------------------------------------===//

TEST_F(SingletonTest, NoInstanceInitially) {
  bool Invoked = false;
  EXPECT_FALSE(Counter::withInstance([&](Counter &) { Invoked = true; }));
  EXPECT_FALSE(Invoked);
  EXPECT_FALSE(
      Counter::withInstance([](Counter &C) { return C.Value; }).has_value());
}

TEST_F(SingletonTest, CreateThenWithInstance) {
  Counter::createInstance(7);
  int Seen = -1;
  EXPECT_TRUE(Counter::withInstance([&](Counter &C) { Seen = C.Value; }));
  EXPECT_EQ(Seen, 7);
  EXPECT_EQ(Counter::Live.load(), 1);
}

TEST_F(SingletonTest, CreateReturnsLiveRef) {
  Counter &Ref = Counter::createInstance(3);
  Counter *Seen = nullptr;
  Counter::withInstance([&](Counter &C) { Seen = &C; });
  EXPECT_EQ(&Ref, Seen);
}

TEST_F(SingletonTest, ArgForwarding) {
  Counter::createInstance(123);
  auto V = Counter::withInstance([](Counter &C) { return C.Value; });
  ASSERT_TRUE(V.has_value());
  EXPECT_EQ(*V, 123);
}

TEST_F(SingletonTest, DestroyEndsAccessAndRunsDtor) {
  Counter::createInstance(1);
  ASSERT_EQ(Counter::Live.load(), 1);
  Counter::destroyInstance();
  EXPECT_EQ(Counter::Live.load(), 0);
  bool Invoked = false;
  EXPECT_FALSE(Counter::withInstance([&](Counter &) { Invoked = true; }));
  EXPECT_FALSE(Invoked);
}

TEST_F(SingletonTest, DestroyIsIdempotent) {
  // No instance: no-op, no crash.
  Counter::destroyInstance();
  Counter::createInstance(1);
  Counter::destroyInstance();
  // Double destroy is safe.
  Counter::destroyInstance();
  EXPECT_EQ(Counter::Live.load(), 0);
}

TEST_F(SingletonTest, RecreateAfterDestroy) {
  Counter::createInstance(10);
  Counter::destroyInstance();
  Counter::createInstance(20);
  auto V = Counter::withInstance([](Counter &C) { return C.Value; });
  ASSERT_TRUE(V.has_value());
  EXPECT_EQ(*V, 20);
}

// WithInstance returns bool for void callbacks, std::optional<R> otherwise.
TEST_F(SingletonTest, ReturnValueTypesAndValues) {
  static_assert(
      std::is_same_v<decltype(Counter::withInstance([](Counter &) {})), bool>);
  static_assert(std::is_same_v<decltype(Counter::withInstance(
                                   [](Counter &) { return 0; })),
                               std::optional<int>>);

  // Without an instance.
  EXPECT_FALSE(Counter::withInstance([](Counter &) {}));
  EXPECT_FALSE(
      Counter::withInstance([](Counter &C) { return C.Value; }).has_value());

  // With an instance.
  Counter::createInstance(21);
  EXPECT_TRUE(Counter::withInstance([](Counter &) {}));
  auto V = Counter::withInstance([](Counter &C) { return C.Value * 2; });
  ASSERT_TRUE(V.has_value());
  EXPECT_EQ(*V, 42);
}

// withInstance is reentrant: calling it from inside its own callback works and
// yields the same instance.
TEST_F(SingletonTest, ReentrantWithInstance) {
  Counter::createInstance(5);
  int Inner = -1;
  bool Outer = Counter::withInstance([&](Counter &C) {
    bool R = Counter::withInstance([&](Counter &C2) {
      Inner = C2.Value;
      EXPECT_EQ(&C, &C2);
    });
    EXPECT_TRUE(R);
  });
  EXPECT_TRUE(Outer);
  EXPECT_EQ(Inner, 5);
}

namespace {
/// A singleton whose constructor calls withInstance() on itself. Because
/// createInstance() publishes only after construction completes, the callback
/// must observe "no instance" and return false (no half-built observation, no
/// deadlock).
struct DuringCtor : luthier::Singleton<DuringCtor> {
  static inline bool CallbackRan = false;
  static inline bool WithInstanceReturn = true;
  explicit DuringCtor(CreationKey) {
    WithInstanceReturn =
        DuringCtor::withInstance([](DuringCtor &) { CallbackRan = true; });
  }
};
} // namespace

TEST(SingletonConstruction, WithInstanceDuringConstruction) {
  DuringCtor::CallbackRan = false;
  DuringCtor::WithInstanceReturn = true;
  DuringCtor::createInstance();
  EXPECT_FALSE(DuringCtor::WithInstanceReturn);
  EXPECT_FALSE(DuringCtor::CallbackRan);
  DuringCtor::destroyInstance();
}

//===----------------------------------------------------------------------===//
// Death tests.
//===----------------------------------------------------------------------===//

TEST_F(SingletonDeathTest, DoubleCreateIsFatal) {
  Counter::createInstance(1);
  EXPECT_DEATH(Counter::createInstance(2), "twice");
  // The parent process still owns the instance; the fixture tears it down.
}

#ifndef NDEBUG
// The reentrancy guard. Calling destroyInstance() from inside
// withInstance() on the same thread is forbidden — the caller's own reference
// would never drop, hanging the drain. In debug builds this aborts via assert
// rather than hanging. Skipped in release (the guard is compiled out).
TEST_F(SingletonDeathTest, DestroyInsideWithInstanceAborts) {
  Counter::createInstance(1);
  EXPECT_DEATH(
      Counter::withInstance([](Counter &) { Counter::destroyInstance(); }),
      "withInstance");
}
#endif

//===----------------------------------------------------------------------===//
// Stress test: many threads call withInstance() while another destroys the
// instance. Validates that destroyInstance() drains in-flight callbacks before
// running the destructor (no destruction mid-callback), and that access ends
// cleanly afterward. (Run under a thread sanitizer for full race coverage.)
//===----------------------------------------------------------------------===//

namespace {
struct StressTool : luthier::Singleton<StressTool> {
  static inline std::atomic<int> Active{0};
  static inline std::atomic<bool> DestroyedWhileActive{false};
  static inline std::atomic<int> Live{0};
  explicit StressTool(CreationKey) { Live.fetch_add(1); }
  ~StressTool() {
    // If the drain worked, no callback body is executing when we are destroyed.
    if (Active.load(std::memory_order_acquire) != 0)
      DestroyedWhileActive.store(true, std::memory_order_release);
    Live.fetch_sub(1);
  }
};
} // namespace

TEST(SingletonStressTest, ConcurrentWithInstanceVsDestroy) {
  StressTool::Active.store(0);
  StressTool::DestroyedWhileActive.store(false);
  StressTool::Live.store(0);

  StressTool::createInstance();

  constexpr int NumThreads = 8;
  std::atomic<bool> Go{false};
  std::vector<std::thread> Workers;
  Workers.reserve(NumThreads);
  for (int I = 0; I < NumThreads; ++I) {
    Workers.emplace_back([&Go] {
      while (!Go.load(std::memory_order_acquire))
        std::this_thread::yield();
      // Loop until the instance is destroyed (withInstance then returns false).
      while (StressTool::withInstance([](StressTool &) {
        StressTool::Active.fetch_add(1, std::memory_order_acq_rel);
        // Widen the overlap window with destroyInstance().
        std::this_thread::yield();
        StressTool::Active.fetch_sub(1, std::memory_order_acq_rel);
      })) {
      }
    });
  }

  Go.store(true, std::memory_order_release);
  // Let callbacks ramp up so the destroy lands mid-flight.
  std::this_thread::sleep_for(std::chrono::milliseconds(5));
  StressTool::destroyInstance();

  for (auto &T : Workers)
    T.join();

  EXPECT_FALSE(StressTool::DestroyedWhileActive.load())
      << "destructor ran while a withInstance() callback was in flight";
  EXPECT_EQ(StressTool::Live.load(), 0);
  EXPECT_FALSE(StressTool::withInstance([](StressTool &) {}));
}

} // namespace
