set(LLVM_LINK_COMPONENTS
        Support
)

add_llvm_tool(luthier-split-test
        luthier-split-test.cpp
)

target_include_directories(luthier-split-test PRIVATE ${LLVM_INCLUDE_DIRS})
