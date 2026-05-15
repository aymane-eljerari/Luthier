if (${LLVM_LUTHIERMOCKINJECTIONPLUGIN_LINK_INTO_TOOLS})
    message(WARNING "Setting LLVM_LUTHIERMOCKINJECTIONPLUGIN_LINK_INTO_TOOLS=ON is not supported")
endif ()

add_llvm_library(LuthierMockInjectionPlugin MODULE
        MockInjectionPlugin.cpp
        MockInjectionPasses.cpp)

target_compile_definitions(LuthierMockInjectionPlugin
        PRIVATE AMD_INTERNAL_BUILD ${LLVM_DEFINITIONS})

target_include_directories(LuthierMockInjectionPlugin PRIVATE
        ${LLVM_INCLUDE_DIRS}
        "$<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>")

target_link_libraries(LuthierMockInjectionPlugin PRIVATE
        LuthierAMDGPU
        LLVMAMDGPUCodeGen LLVMAMDGPUInfo LLVMAMDGPUDesc LLVMCodeGen
        LLVMCore LLVMSupport LLVMTargetParser)
