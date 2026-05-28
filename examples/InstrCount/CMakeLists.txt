cmake_minimum_required(VERSION 3.21)

project(LuthierInstrCount LANGUAGES HIP)

set(CMAKE_HIP_STANDARD 20)

find_package(hip REQUIRED)
find_package(LLVM REQUIRED CONFIG)

luthier_add_tool(LuthierInstrCount
        SOURCES InstrCount.hip
        LIBRARIES hip::device)
