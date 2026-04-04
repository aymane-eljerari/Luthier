if (${LLVM_LUTHIERHIPFATBINARYPLUGIN_LINK_INTO_TOOLS})
    message(WARNING "Setting LLVM_LUTHIERHIPFATBINARYPLUGIN_LINK_INTO_TOOLS=ON is not supported")
endif ()

add_llvm_pass_plugin(LuthierHIPFATBinaryPlugin
        LoadHIPFATBinaryInfoPass.h
        LoadHIPFATBinaryInfoPass.cpp)

target_include_directories(LuthierHIPFATBinaryPlugin PRIVATE
        "$<BUILD_INTERFACE:${LLVM_INCLUDE_DIRS}>"
        "$<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>")