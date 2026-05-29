set(LLVM_LINK_COMPONENTS Support)

# The Singleton backend is a compile-time switch, so the same source is built
# twice: once against the default backend (std::atomic<std::shared_ptr> where
# available) and once forced onto the intrusive llvm::IntrusiveRefCntPtr path.

add_llvm_executable(SingletonTest SingletonTest.cpp)
target_include_directories(SingletonTest PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})
target_link_libraries(SingletonTest PRIVATE gtest gtest_main LuthierCommon)
gtest_discover_tests(SingletonTest)

add_llvm_executable(SingletonTestIntrusive SingletonTest.cpp)
target_compile_definitions(SingletonTestIntrusive PRIVATE
        LUTHIER_SINGLETON_FORCE_INTRUSIVE)
target_include_directories(SingletonTestIntrusive PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})
target_link_libraries(SingletonTestIntrusive PRIVATE gtest gtest_main LuthierCommon)
gtest_discover_tests(SingletonTestIntrusive)
