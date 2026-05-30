add_executable(luthier-link luthier-link.cpp)

target_include_directories(luthier-link PRIVATE
        ${CMAKE_SOURCE_DIR}/src/include
        ${LLVM_INCLUDE_DIRS})

target_link_libraries(luthier-link
        LuthierLinker
        LuthierCommon
        LuthierObject
        LLVMSymbolize
        LLVMDebugInfoDWARF
        LLVMObject
        LLVMBinaryFormat
        LLVMTargetParser
        LLVMSupport)

