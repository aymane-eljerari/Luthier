//===-- PrivateSpill.hip - Private/scratch load-store target ----------===//
//
// Large stack-allocated array indexed by a runtime value forces the
// AMDGPU backend to spill to private (scratch) memory: tests the
// scratch-buffer load/store paths along with ALU. No LDS, no special
// builtins.
//
//===----------------------------------------------------------------------===//
#include <hip/hip_runtime.h>

#define N 64

extern "C" __global__ void private_spill(const float *__restrict__ in,
                                         float *__restrict__ out,
                                         unsigned mask) {
  float local[N];
  unsigned tid = threadIdx.x;

  // Fill with runtime-dependent values so the compiler can't constant-fold.
  for (int i = 0; i < N; ++i)
    local[i] = in[tid * N + i] + (float)(i ^ (mask & 0x3F));

  // Force a runtime-indexed load: defeats SROA, drives the array to scratch.
  unsigned idx0 = mask & (N - 1);
  unsigned idx1 = (mask >> 8) & (N - 1);
  float acc = local[idx0] * local[idx1];

  // Second pass to read the array linearly so the body is interesting.
  for (int i = 0; i < N; ++i)
    acc += local[i];

  out[tid] = acc;
}
