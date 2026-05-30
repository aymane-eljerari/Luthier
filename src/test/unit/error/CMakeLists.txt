set(LLVM_LINK_COMPONENTS Support Symbolize DebugInfoDWARF Object)

add_llvm_executable(ErrorTest
        ErrorTest.cpp
        ${CMAKE_SOURCE_DIR}/src/lib/LLVM/LLVMError.cpp
        ${CMAKE_SOURCE_DIR}/src/lib/HSA/HsaError.cpp
        ${CMAKE_SOURCE_DIR}/src/lib/HIP/HipError.cpp
        ${CMAKE_SOURCE_DIR}/src/lib/Rocprofiler/RocprofilerError.cpp)

target_compile_definitions(ErrorTest PRIVATE AMD_INTERNAL_BUILD ${LLVM_DEFINITIONS})

target_include_directories(ErrorTest PRIVATE
        ${CMAKE_SOURCE_DIR}/include
        ${LLVM_INCLUDE_DIRS}
        ${hsa-runtime64_INCLUDE_DIRS})

target_link_libraries(ErrorTest PRIVATE
        gtest gtest_main LuthierCommon ${CMAKE_DL_LIBS}
        hip::host hsa-runtime64::hsa-runtime64 rocprofiler-sdk::rocprofiler-sdk)

gtest_discover_tests(ErrorTest)
