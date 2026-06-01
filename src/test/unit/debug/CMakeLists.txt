set(LLVM_LINK_COMPONENTS Support)

# The same LLVM_DEBUG site is compiled twice — once with assertions (no NDEBUG,
# debug logic present) and once with NDEBUG (debug logic compiled out) — to
# verify that Luthier's reuse of LLVM_DEBUG is gated purely on the consumer
# translation unit's NDEBUG, independent of the project's build type. The
# -U/-DNDEBUG and -g/-g0 flags are appended after the build-type flags, so the
# result is deterministic regardless of CMAKE_BUILD_TYPE.
add_library(LuthierDebugEmitOn OBJECT DebugEmit.cpp)
target_compile_options(LuthierDebugEmitOn PRIVATE -UNDEBUG -g)
target_compile_definitions(LuthierDebugEmitOn PRIVATE LT_EMIT_NAME=luthierTestEmitDebugOn)
target_include_directories(LuthierDebugEmitOn PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})

add_library(LuthierDebugEmitOff OBJECT DebugEmit.cpp)
target_compile_options(LuthierDebugEmitOff PRIVATE -DNDEBUG -g0)
target_compile_definitions(LuthierDebugEmitOff PRIVATE LT_EMIT_NAME=luthierTestEmitDebugOff)
target_include_directories(LuthierDebugEmitOff PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})

add_llvm_executable(DebugLoggingTest DebugLoggingTest.cpp
        $<TARGET_OBJECTS:LuthierDebugEmitOn>
        $<TARGET_OBJECTS:LuthierDebugEmitOff>
        PARTIAL_SOURCES_INTENDED)
target_include_directories(DebugLoggingTest PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})
target_link_libraries(DebugLoggingTest PRIVATE gtest gtest_main)
gtest_discover_tests(DebugLoggingTest)
