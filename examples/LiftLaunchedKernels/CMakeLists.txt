cmake_minimum_required(VERSION 3.21)

project(LiftLaunchedKernels LANGUAGES HIP)

set(CMAKE_HIP_STANDARD 20)

find_package(hip REQUIRED CONFIG)
find_package(LLVM REQUIRED CONFIG)

# This example has no hooks (it only lifts + prints), so it doesn't need
# the CXX compilation plugin for host-handle synthesis. But the device
# .hip still goes through the IR compilation plugin — luthier_add_tool
# wires that up automatically.
luthier_add_tool(LiftLaunchedKernels
        SOURCES LiftLaunchedKernels.hip)
