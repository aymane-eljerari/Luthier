cmake_minimum_required(VERSION 3.21)

project(LuthierOpcodeHistogram LANGUAGES HIP)

set(CMAKE_HIP_STANDARD 20)

find_package(hip REQUIRED)
find_package(LLVM REQUIRED)

luthier_add_tool(LuthierOpcodeHistogram
        SOURCES OpcodeHistogram.hip
        OFFLOAD_ARCHES gfx908
        HIPCC_HOST_FLAGS
            -fplugin=$<TARGET_FILE:LuthierToolCXXCompilationPlugin>
        LIBRARIES LuthierTooling LLVMDemangle hip::device hip::host)
add_dependencies(LuthierOpcodeHistogram LuthierToolCXXCompilationPlugin)
