//===-- WMMATile.hip - RDNA3+ WMMA accumulate target -------------------===//
//
// RDNA3-style 16x16x16 fp16 WMMA accumulate. Usable on gfx1100 and
// gfx1200 which support the __builtin_amdgcn_wmma_f32_16x16x16_f16_w32
// intrinsic.
//
//===----------------------------------------------------------------------===//
#include <hip/hip_runtime.h>

using v16f16 = __attribute__((__vector_size__(32))) _Float16;
using v8f = __attribute__((__vector_size__(32))) float;

extern "C" __global__ void wmma_tile(const v16f16 *__restrict__ a,
                                     const v16f16 *__restrict__ b,
                                     v8f *__restrict__ c) {
  unsigned tid = threadIdx.x + blockIdx.x * blockDim.x;
  v16f16 fa = a[tid];
  v16f16 fb = b[tid];
  v8f acc = {0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f};
  acc = __builtin_amdgcn_wmma_f32_16x16x16_f16_w32(fa, fb, acc);
  c[tid] = acc;
}
