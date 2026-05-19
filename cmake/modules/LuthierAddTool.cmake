#===- LuthierAddTool.cmake -----------------------------------------------===#
# Copyright @ Northeastern University Computer Architecture Lab
#
# Licensed under the Apache License, Version 2.0 (the "License").
#===---------------------------------------------------------------------===#
#
# luthier_add_tool: build a Luthier-instrumentation host shared object from
# one HIP source. Compiles the device side once per (arch, wave-mode) tuple
# with the Luthier IR-compilation plugin enabled, bundles all .co outputs
# into a single Clang offload bundle, wraps that bundle in HIP's
# `__CudaFatBinaryWrapper` shape, compiles the host TU with
# `--cuda-host-only`, and links the result as a shared library.
#
# Synopsis:
#
#   luthier_add_tool(<target>
#     SOURCES        <files...>
#     OFFLOAD_ARCHES <gfx...>
#     [WAVE_MODES    auto | wave32 | wave64 | "wave32 wave64"]
#     [HIPCC_FLAGS   <flags...>]
#     [LIBRARIES     <libs...>])
#
# Behaviour:
#   * SOURCES — one or more HIP source files. The same source is compiled
#     both host-only and device-only. (Multi-source tools work the same way;
#     each source is compiled both ways.)
#   * OFFLOAD_ARCHES — list of `gfx*` targets to ship code objects for. For
#     each arch we emit one device compilation per wave mode.
#   * WAVE_MODES — which wave widths to include per arch:
#       auto    → wave64 on gfx9*, wave32 on gfx10+ (RDNA's default). Single
#                 .co per arch.
#       wave32  → force wave32 (`-mno-wavefrontsize64`).
#       wave64  → force wave64 (`-mwavefrontsize64`).
#       "wave32 wave64" → ship both. Each becomes its own .co; the loader
#         picks one per agent via specificity-aware matching.
#     Default: auto.
#   * HIPCC_FLAGS — extra flags forwarded to every device + host clang
#     invocation. The Luthier IR-plugin -fpass-plugin is added automatically.
#   * LIBRARIES — extra link libraries for the final shared object.
#
# Requirements:
#   * The CMake host project must have already located Luthier
#     (find_package(luthier ...)) so $<TARGET_FILE:luthier::...> targets
#     are available, or the helper must be invoked from inside Luthier's
#     own build tree.
#   * clang, clang-offload-bundler and clang's HIP front end visible via
#     the imported `hip::host` target / HIP_CLANG_PATH.
#===---------------------------------------------------------------------===#

include_guard(GLOBAL)

# Returns the default wave width for a single gfx target. We follow LLVM's
# AMDGPU default: gfx9-and-earlier are wave64, gfx10-and-later are wave32.
function(_luthier_default_wave_for_arch arch out_var)
  string(REGEX MATCH "gfx([0-9]+)" _ "${arch}")
  if (NOT CMAKE_MATCH_1)
    # Generic targets (e.g. gfx9-generic). Strip "generic" suffix and
    # re-extract the major number — generic targets are conventionally
    # named after their family (gfx9-generic, gfx10-1-generic, …).
    string(REGEX MATCH "gfx([0-9]+)" _ "${arch}")
  endif ()
  set(_mach "${CMAKE_MATCH_1}")
  if (_mach LESS 1000)
    set(${out_var} "wave64" PARENT_SCOPE)
  else ()
    set(${out_var} "wave32" PARENT_SCOPE)
  endif ()
endfunction()

# Translate a wave-mode keyword into the matching clang flag.
function(_luthier_wave_mode_flag mode out_var)
  if (mode STREQUAL "wave32")
    set(${out_var} "-mno-wavefrontsize64" PARENT_SCOPE)
  elseif (mode STREQUAL "wave64")
    set(${out_var} "-mwavefrontsize64" PARENT_SCOPE)
  else ()
    message(FATAL_ERROR "luthier_add_tool: unknown wave mode '${mode}'")
  endif ()
endfunction()

function(luthier_add_tool target)
  cmake_parse_arguments(LAT ""
    ""
    "SOURCES;OFFLOAD_ARCHES;WAVE_MODES;HIPCC_FLAGS;LIBRARIES"
    ${ARGN})

  if (NOT LAT_SOURCES)
    message(FATAL_ERROR "luthier_add_tool(${target}): SOURCES required")
  endif ()
  if (NOT LAT_OFFLOAD_ARCHES)
    message(FATAL_ERROR
      "luthier_add_tool(${target}): OFFLOAD_ARCHES required")
  endif ()
  if (NOT LAT_WAVE_MODES)
    set(LAT_WAVE_MODES "auto")
  endif ()

  # Tool authors usually have one source file; we still support multiple by
  # compiling each (host + device-per-variant) and linking everything.
  # First source's basename is used as the file prefix for intermediates.
  list(GET LAT_SOURCES 0 _first_source)
  get_filename_component(_prefix "${_first_source}" NAME_WE)

  # Discover the Luthier IR-compilation plugin. If we're inside Luthier's
  # own tree, the target's TARGET_FILE generator expression works. If
  # consumed from an install, the same expression resolves through the
  # exported target alias.
  if (TARGET LuthierToolIRCompilationPlugin)
    set(_ir_plugin "$<TARGET_FILE:LuthierToolIRCompilationPlugin>")
  elseif (TARGET luthier::LuthierToolIRCompilationPlugin)
    set(_ir_plugin "$<TARGET_FILE:luthier::LuthierToolIRCompilationPlugin>")
  else ()
    message(FATAL_ERROR
      "luthier_add_tool(${target}): LuthierToolIRCompilationPlugin not "
      "found. Did you find_package(luthier ...)?")
  endif ()

  # Locate clang + clang-offload-bundler. HIP_CLANG_PATH is set by
  # find_package(hip). Fall back to PATH-search.
  if (DEFINED HIP_CLANG_PATH)
    set(_clang "${HIP_CLANG_PATH}/clang++")
    set(_bundler "${HIP_CLANG_PATH}/clang-offload-bundler")
  else ()
    find_program(_clang clang++ REQUIRED)
    find_program(_bundler clang-offload-bundler REQUIRED)
  endif ()

  # Build the per-(arch, wave) device-compilation list.
  set(_co_files "")
  set(_bundler_targets "host-${CMAKE_SYSTEM_PROCESSOR}-unknown-linux-gnu")
  set(_bundler_inputs "/dev/null")

  foreach (arch IN LISTS LAT_OFFLOAD_ARCHES)
    # Determine wave modes for this arch.
    if (LAT_WAVE_MODES STREQUAL "auto")
      _luthier_default_wave_for_arch("${arch}" _waves)
    else ()
      set(_waves ${LAT_WAVE_MODES})
    endif ()

    foreach (wave IN LISTS _waves)
      _luthier_wave_mode_flag("${wave}" _wave_flag)

      set(_co
        "${CMAKE_CURRENT_BINARY_DIR}/${target}.${_prefix}.${arch}.${wave}.co")
      add_custom_command(
        OUTPUT "${_co}"
        COMMAND "${_clang}"
          -x hip
          --cuda-device-only
          --offload-arch=${arch}
          ${_wave_flag}
          -fpass-plugin=${_ir_plugin}
          ${LAT_HIPCC_FLAGS}
          -c ${LAT_SOURCES}
          -o "${_co}"
        DEPENDS ${LAT_SOURCES} ${_ir_plugin}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "luthier_add_tool(${target}): compiling device .co for "
                "${arch} ${wave}"
        VERBATIM)
      list(APPEND _co_files "${_co}")
      list(APPEND _bundler_targets
        "hipv4-amdgcn-amd-amdhsa--${arch}")
      list(APPEND _bundler_inputs "${_co}")
    endforeach ()
  endforeach ()

  # Bundle the .co files. clang-offload-bundler stores the target-id
  # strings verbatim; per the ELF-derived-ISA design in the loader, the
  # entry id text is not consulted at runtime, so the simple bare-arch
  # form here is sufficient.
  string(REPLACE ";" "," _targets_csv "${_bundler_targets}")
  set(_inputs_args "")
  foreach (in IN LISTS _bundler_inputs)
    list(APPEND _inputs_args "--input=${in}")
  endforeach ()

  set(_fatbin "${CMAKE_CURRENT_BINARY_DIR}/${target}.${_prefix}.hipfb")
  add_custom_command(
    OUTPUT "${_fatbin}"
    COMMAND "${_bundler}"
      --type=o
      --targets=${_targets_csv}
      ${_inputs_args}
      --output="${_fatbin}"
    DEPENDS ${_co_files}
    COMMENT "luthier_add_tool(${target}): bundling ${_prefix}.hipfb"
    VERBATIM)

  # Wrap the bundle in HIP's __CudaFatBinaryWrapper shape. We emit a
  # small assembly file that pulls in the bundle bytes via .incbin and
  # exposes the wrapper as @__hip_fatbin_wrapper, which the host
  # compilation's __hipRegisterFatBinary call references at link time.
  set(_fatbin_asm
    "${CMAKE_CURRENT_BINARY_DIR}/${target}.${_prefix}.fatbin.S")
  add_custom_command(
    OUTPUT "${_fatbin_asm}"
    COMMAND ${CMAKE_COMMAND} -E echo
      "// Generated by luthier_add_tool"
      "    .section .hip_fatbin, \"a\""
      "    .globl __hip_fatbin"
      "    .align 4096"
      "__hip_fatbin:"
      "    .incbin \"${_fatbin}\""
      ""
      "    .section .data"
      "    .globl __hip_fatbin_wrapper"
      "    .align 8"
      "__hip_fatbin_wrapper:"
      "    .long 0x48495046    // 'HIPF'"
      "    .long 1              // version"
      "    .quad __hip_fatbin   // binary"
      "    .quad 0              // dummy"
      > "${_fatbin_asm}"
    DEPENDS "${_fatbin}"
    COMMENT "luthier_add_tool(${target}): emitting fatbin wrapper .S"
    VERBATIM)

  # Final shared library target. Sources are:
  #   * The host TU(s), built host-only with the HIP front end.
  #   * The .S file that embeds the fat-bin and the wrapper struct.
  add_library(${target} MODULE ${LAT_SOURCES} "${_fatbin_asm}")

  # The host TU must NOT do its own device compilation — `--cuda-host-only`
  # makes Clang emit only the host stubs + register calls + extern
  # reference to __hip_fatbin_wrapper, which our .S supplies.
  set_source_files_properties(${LAT_SOURCES} PROPERTIES
    LANGUAGE HIP
    COMPILE_OPTIONS "--cuda-host-only;-fno-gpu-rdc")

  # The fatbin .S goes through the assembler.
  set_source_files_properties("${_fatbin_asm}" PROPERTIES
    LANGUAGE ASM)

  target_compile_options(${target} PRIVATE
    $<$<COMPILE_LANGUAGE:HIP>:${LAT_HIPCC_FLAGS}>)

  target_link_libraries(${target} PRIVATE hip::host ${LAT_LIBRARIES})

  # Make the .S file's generation depend on the fat-bin existing.
  add_custom_target(${target}-fatbin DEPENDS "${_fatbin_asm}")
  add_dependencies(${target} ${target}-fatbin)
endfunction()
