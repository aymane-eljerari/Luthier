macro(luthier_add_clang_plugin target clang_plugin)
    add_dependencies(${target} ${clang_plugin})
    target_compile_options(${target}
            PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fplugin=$<TARGET_FILE:${clang_plugin}>>
    )
endmacro()
