//===-- BufferOps.hip - Buffer/flat load-store target ------------------===//
//
// Mix of pointer-based loads/stores via volatile + atomics to drive flat
// and buffer addressing modes. The volatile reads prevent vectorization,
// keeping individual instructions present in the lifted MIR for
// instrumentation tests.
//
//===----------------------------------------------------------------------===//
#include <hip/hip_runtime.h>

extern "C" __global__ void buffer_ops(volatile int *__restrict__ in,
                                      volatile int *__restrict__ out,
                                      unsigned n) {
  unsigned i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n)
    return;
  int a = in[i];
  int b = in[(i + 1) % n];
  int c = a + b;
  out[i] = c;
  atomicAdd(const_cast<int *>(out) + (i % 16), c);
}
