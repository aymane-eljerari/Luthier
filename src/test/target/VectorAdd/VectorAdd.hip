//===-- VectorAdd.hip - SAXPY-style global load/store target ----------===//
//
// Derived from the saxpy-class kernels in HeCBench. Pure global load + ALU
// + global store mix, no LDS or special builtins. Useful as the smallest
// non-trivial target for payload injection tests.
//
//===----------------------------------------------------------------------===//
#include <hip/hip_runtime.h>

extern "C" __global__ void vector_add(const float *__restrict__ a,
                                      const float *__restrict__ b,
                                      float *__restrict__ c, unsigned n,
                                      float alpha) {
  unsigned i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n)
    return;
  float ai = a[i];
  float bi = b[i];
  c[i] = alpha * ai + bi;
}
