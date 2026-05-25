cmake_minimum_required(VERSION 3.21)

project(LuthierKernelArgumentIntrinsic LANGUAGES HIP)

set(CMAKE_HIP_STANDARD 20)

find_package(hip REQUIRED)
find_package(LLVM REQUIRED)

luthier_add_tool(LuthierKernelArgumentIntrinsic
        SOURCES KernelArgumentIntrinsic.hip
        OFFLOAD_ARCHES gfx908
        LIBRARIES LLVMDemangle hip::device hip::host)
