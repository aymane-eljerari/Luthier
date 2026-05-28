cmake_minimum_required(VERSION 3.21)

project(LuthierLDSBankConflict LANGUAGES HIP)

set(CMAKE_HIP_STANDARD 20)

find_package(hip REQUIRED)
find_package(LLVM REQUIRED)

luthier_add_tool(LuthierLDSBankConflict
        SOURCES LDSBankConflict.hip
        LIBRARIES LLVMDemangle hip::device hip::host)
