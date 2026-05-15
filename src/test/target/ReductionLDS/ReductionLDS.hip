//===-- ReductionLDS.hip - LDS + global + ALU target ------------------===//
//
// Per-block sum reduction using __shared__ memory (LDS), with a classic
// log-step tree. Exercises LDS load/store, barriers, ALU, global load/store.
//
//===----------------------------------------------------------------------===//
#include <hip/hip_runtime.h>

extern "C" __global__ void reduce_sum_lds(const float *__restrict__ in,
                                          float *__restrict__ out, unsigned n) {
  __shared__ float scratch[256];
  unsigned tid = threadIdx.x;
  unsigned gid = blockIdx.x * blockDim.x + threadIdx.x;

  float v = (gid < n) ? in[gid] : 0.0f;
  scratch[tid] = v;
  __syncthreads();

  for (unsigned stride = blockDim.x / 2; stride > 0; stride >>= 1) {
    if (tid < stride)
      scratch[tid] += scratch[tid + stride];
    __syncthreads();
  }

  if (tid == 0)
    out[blockIdx.x] = scratch[0];
}
