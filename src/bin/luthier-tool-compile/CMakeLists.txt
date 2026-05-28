set(LLVM_LINK_COMPONENTS
        Support
        TargetParser
)

add_llvm_tool(luthier-tool-compile
        luthier-tool-compile.cpp
)

target_include_directories(luthier-tool-compile PRIVATE
        ${LLVM_INCLUDE_DIRS}
)
