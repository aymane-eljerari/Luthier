
set(LLVM_LINK_COMPONENTS Support Symbolize DebugInfoDWARF Object)

# luthier::Stacktrace resolves a frame from a module's DWARF (file:line) and/or
# its symbol table (function names). The same tests are built three ways to lock
# down behavior across build configurations, with -D flags telling each variant
# what it should be able to resolve:
#   StacktraceTest            : -g, not stripped     -> DWARF + symtab (names + file:line)
#   StacktraceTestNoDebugInfo : -g0, not stripped    -> symtab only   (names, no file:line)
#   StacktraceTestStripped    : -g0 + --strip-all    -> neither       (module+offset only)
# Each variant sets its own debug-info level so the tests are independent of
# CMAKE_BUILD_TYPE (which may be empty -> no -g by default). These options are
# appended AFTER CMake's build-type flags, and the last -g* on the command line
# wins, so they reliably override whatever the build type would supply.

# 1. Full debug info: explicit -g so DWARF (function names + file:line) exists
# regardless of build type. Default expectations (both kinds resolvable).
add_llvm_executable(StacktraceTest StacktraceTest.cpp)
target_compile_options(StacktraceTest PRIVATE -g)
target_include_directories(StacktraceTest PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})

target_link_libraries(StacktraceTest PRIVATE
        gtest gtest_main LuthierCommon
        #${CMAKE_DL_LIBS} provides dladdr (libdl), used to map PCs to modules.
        ${CMAKE_DL_LIBS})
gtest_discover_tests(StacktraceTest)

# 2. No debug info, not stripped: symbol table only (names, but no file:line).
add_llvm_executable(StacktraceTestNoDebugInfo StacktraceTest.cpp)
target_compile_options(StacktraceTestNoDebugInfo PRIVATE -g0)
target_compile_definitions(StacktraceTestNoDebugInfo PRIVATE
        LUTHIER_TEST_EXPECT_LINE_INFO=0)
target_include_directories(StacktraceTestNoDebugInfo PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})
target_link_libraries(StacktraceTestNoDebugInfo PRIVATE
        gtest gtest_main LuthierCommon ${CMAKE_DL_LIBS})
gtest_discover_tests(StacktraceTestNoDebugInfo TEST_PREFIX "nodebug.")

# 3. Stripped: neither names nor file:line (module+offset fallback only).
add_llvm_executable(StacktraceTestStripped StacktraceTest.cpp)
target_compile_options(StacktraceTestStripped PRIVATE -g0)
target_link_options(StacktraceTestStripped PRIVATE -Wl,--strip-all)
target_compile_definitions(StacktraceTestStripped PRIVATE
        LUTHIER_TEST_EXPECT_FUNCTION_NAMES=0
        LUTHIER_TEST_EXPECT_LINE_INFO=0)
target_include_directories(StacktraceTestStripped PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})
target_link_libraries(StacktraceTestStripped PRIVATE
        gtest gtest_main LuthierCommon ${CMAKE_DL_LIBS})
gtest_discover_tests(StacktraceTestStripped TEST_PREFIX "stripped.")
