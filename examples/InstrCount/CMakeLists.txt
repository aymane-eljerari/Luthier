cmake_minimum_required(VERSION 3.21)

project(LuthierInstrCount LANGUAGES HIP CXX ASM C)

set(CMAKE_HIP_STANDARD 20)

find_package(hip REQUIRED)
find_package(LLVM REQUIRED CONFIG)

# luthier_add_tool drives the supported split-compile: --cuda-device-only
# for each (arch, wave) tuple with the Luthier IR pass plugin, then a
# separate --cuda-host-only compile of the same .hip. Passing the CXX
# compilation plugin via HIPCC_FLAGS turns it on for both halves; in
# host-only mode the plugin's kernel-handle synthesis + DeclRefExpr
# rewrite generate the host stubs and the __hipRegisterFunction calls
# that drive fat-binary registration. In device-only mode it emits the
# matching kernel symbol the host registration binds to.
luthier_add_tool(LuthierInstrCount
        SOURCES InstrCount.hip
        OFFLOAD_ARCHES gfx908
        HIPCC_HOST_FLAGS
            -fplugin=$<TARGET_FILE:LuthierToolCXXCompilationPlugin>
        LIBRARIES LuthierTooling hip::device)
add_dependencies(LuthierInstrCount LuthierToolCXXCompilationPlugin)
set_property(TARGET LuthierInstrCount PROPERTY HIP_ARCHITECTURES gfx908)
set_property(TARGET LuthierInstrCount PROPERTY COMPILE_FLAGS "-fPIC")

luthier_add_clang_plugin(LuthierInstrCount LuthierToolCXXCompilationPlugin)
luthier_add_compiler_plugin(LuthierInstrCount LuthierToolIRCompilationPlugin)

target_link_libraries(LuthierInstrCount PRIVATE LuthierTooling hip::device)