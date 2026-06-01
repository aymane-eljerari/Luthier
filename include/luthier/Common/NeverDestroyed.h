//===-- NeverDestroyed.h ----------------------------------------*- C++ -*-===//
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
/// Defines the \c luthier::NeverDestroyed wrapper, which constructs an object
/// of type \c T once into never-reclaimed storage and intentionally never
/// runs its destructor.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_COMMON_NEVER_DESTROYED_H
#define LUTHIER_COMMON_NEVER_DESTROYED_H
#include <cstddef>
#include <new>
#include <utility>

namespace luthier {

/// \brief Owns a single \c T that is constructed in place and \b never
/// destroyed.
/// \details This is the same process-lifetime ownership trick used by
/// \c luthier::Singleton's owning slot. The object is placement-new'd into an
/// inline, trivially-destructible byte buffer; because every data member of
/// \c NeverDestroyed is trivially destructible and its destructor is defaulted,
/// the destructor is itself trivial. Consequently, when a \c NeverDestroyed is
/// used as a function-local \c static, the compiler registers \b no
/// \c __cxa_atexit handler for it and \c T simply leaks at process exit.
///
/// This is exactly what is wanted for objects that must outlive every other
/// teardown step — e.g. the standard streams in \c luthier::outs / \c errs /
/// \c dbgs, which a late destructor (ordered after \c llvm_shutdown) may still
/// touch. Unlike \c llvm::ManagedStatic, the held object is decoupled from
/// \c llvm_shutdown entirely and the accessor can never observe a null /
/// already-destroyed object.
/// \note \c T's destructor is never invoked. Only use this for objects whose
/// resources are reclaimed by process exit (file descriptors, memory). If \c T
/// buffers output that must reach its sink, arrange an explicit flush (e.g. via
/// \c std::atexit); see \c luthier::outs.
/// \tparam T the type of the owned, never-destroyed object
template <typename T> class NeverDestroyed {
  alignas(T) std::byte Storage[sizeof(T)];
  T *Ptr;

public:
  template <typename... Args>
  explicit NeverDestroyed(Args &&...VarArgs)
      : Ptr(::new (static_cast<void *>(Storage))
                T(std::forward<Args>(VarArgs)...)) {}

  /// Trivial on purpose: \c T::~T is deliberately \b never called.
  ~NeverDestroyed() = default;

  NeverDestroyed(const NeverDestroyed &) = delete;
  NeverDestroyed &operator=(const NeverDestroyed &) = delete;

  T &operator*() { return *Ptr; }
  T *operator->() { return Ptr; }
  const T &operator*() const { return *Ptr; }
  const T *operator->() const { return Ptr; }
};

} // namespace luthier

#endif // LUTHIER_COMMON_NEVER_DESTROYED_H
