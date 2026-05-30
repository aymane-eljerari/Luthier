set(LLVM_LINK_COMPONENTS Support)

add_llvm_executable(DenseMapInfoTest DenseMapInfoTest.cpp)
target_include_directories(DenseMapInfoTest PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS})
target_link_libraries(DenseMapInfoTest PRIVATE gtest gtest_main LuthierCommon)
gtest_discover_tests(DenseMapInfoTest)
