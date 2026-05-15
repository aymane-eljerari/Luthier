//===-- MFMATile.hip - CDNA1+ MFMA accumulate target -------------------===//
//
// 16x16x4 fp32 MFMA accumulate as found in CDNA matrix-multiply kernels.
// Only usable on gfx908 / gfx90a / gfx942 (the CDNA generations with the
// __builtin_amdgcn_mfma_f32_16x16x4f32 intrinsic).
//
//===----------------------------------------------------------------------===//
#include <hip/hip_runtime.h>

using v4f = __attribute__((__vector_size__(16))) float;

extern "C" __global__ void mfma_tile(const float *__restrict__ a,
                                     const float *__restrict__ b,
                                     v4f *__restrict__ c) {
  unsigned tid = threadIdx.x + blockIdx.x * blockDim.x;
  float ai = a[tid];
  float bi = b[tid];
  v4f acc = {0.f, 0.f, 0.f, 0.f};
  acc = __builtin_amdgcn_mfma_f32_16x16x4f32(ai, bi, acc, 0, 0, 0);
  c[tid] = acc;
}
