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
    "SOURCES;OFFLOAD_ARCHES;WAVE_MODES;HIPCC_FLAGS;HIPCC_HOST_FLAGS;LIBRARIES"
    ${ARGN})
  # HIPCC_FLAGS applies to both halves; HIPCC_HOST_FLAGS is host-only.
  # The CXX compilation plugin lives in HIPCC_HOST_FLAGS because its
  # synthesis logic targets the host AST and the lit tests (and design
  # intent) exercise it under `--cuda-host-only` only.

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

  # HIP-Clang emits per-TU symbols named `__hip_fatbin_<CUID>` and
  # `__hip_gpubin_handle_<CUID>` where CUID defaults to a content hash
  # (`-fuse-cuid=hash`). The host compile and our generated .S file
  # have to agree on the suffix; the explicit `-cuid=` flag is silently
  # ignored on host-only HIP compiles, so we use `-fuse-cuid=none` to
  # strip the suffix entirely and emit plain `__hip_fatbin` /
  # `__hip_gpubin_handle` symbols on both sides. This restricts a tool
  # to one HIP TU's worth of fat binary (multiple TUs would collide on
  # the unsuffixed name) — which is the single-source design
  # `luthier_add_tool` already assumes.

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
      # The device-side custom command runs outside the target-property
      # system (no PUBLIC INCLUDE_DIRECTORIES propagation), so we splice
      # Luthier's standard header roots in by hand. The same set is what
      # `LuthierTooling`'s target_include_directories exports, and what
      # the test/imodule fixtures use.
      add_custom_command(
        OUTPUT "${_co}"
        COMMAND "${_clang}"
          -x hip
          --cuda-device-only
          --offload-arch=${arch}
          ${_wave_flag}
          -std=c++20
          # -O3 is non-optional, not a perf knob. Without it HIP-Clang
          # leaves out-of-line device functions like `__assert_fail`,
          # `__ockl_fprintf_*`, the lane/popcount intrinsics, and the
          # `__cxa_*` glue as separate post-ISel pre-RA bodies in the
          # embedded `.llvmbc`. `TargetModulePatcherPass::cloneIModuleIntoTarget`
          # then drags those bodies into the target MIR module, where
          # the AsmPrinter's `AMDGPUResourceUsageAnalysisImpl::analyzeResourceUsage`
          # asserts on the first virtual register (it indexes
          # `getPhysRegBaseClass` directly, no `isPhysical()` guard).
          # -O3 inlines the helpers into the hooks and DCEs any
          # unreachable helpers, so the patcher only ever clones the
          # hooks' merged bodies — which are exactly what runs through
          # the rest of the codegen chain anyway.
          -O3
          -fpass-plugin=${_ir_plugin}
          # LuthierTooling exports `AMD_INTERNAL_BUILD` as a public
          # compile-definition, which switches the bundled HSA headers
          # to the direct-include form (`#include "hsa_ext_*.h"` rather
          # than `#include "inc/hsa_ext_*.h"`). The macro's custom
          # command doesn't pick up that PUBLIC define from the linked
          # target, so we set it here.
          -DAMD_INTERNAL_BUILD
          # `hip_api_trace.hpp` (pulled in by `luthier/Rocprofiler/...`)
          # references GLuint / hipGraphicsResource / hipDeviceProp_tR0000
          # / hipGLDeviceList unconditionally. The first two come from
          # `hip_gl_interop.h`; the last two from `hip_deprecated.h`; the
          # base types come from `hip_runtime.h`. Pre-include all three so
          # `luthier/HIP/ApiTable.h` can name those API entries in its
          # `ApiInfo<HipFunc>` specializations.
          -include hip/hip_runtime.h
          -include hip/hip_deprecated.h
          -include hip/hip_gl_interop.h
          -isystem "${CMAKE_SOURCE_DIR}/include"
          -isystem "${CMAKE_BINARY_DIR}/include"
          -isystem "${CMAKE_BINARY_DIR}/include/luthier/AMDGPU"
          -isystem "${CMAKE_BINARY_DIR}/src/lib/AMDGPU"
          -isystem "${LLVM_INCLUDE_DIRS}"
          -idirafter /opt/rocm/include
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

  # `clang --cuda-device-only -c file.hip -o file.co` already emits an
  # offload bundle in the same shape the HIP runtime + loader expect
  # (`[host-x86_64..., hipv4-amdgcn-amd-amdhsa--<arch>]`). Running
  # `clang-offload-bundler` again would double-bundle and the inner
  # bundle's "AMDGCN slice" would itself start with the offload-bundle
  # magic, which `ObjectFile::createObjectFile` rejects.
  # Single-arch path: use the .co directly.
  list(LENGTH _co_files _num_cos)
  set(_fatbin "${CMAKE_CURRENT_BINARY_DIR}/${target}.${_prefix}.hipfb")
  if (_num_cos EQUAL 1)
    list(GET _co_files 0 _the_co)
    add_custom_command(
      OUTPUT "${_fatbin}"
      COMMAND ${CMAKE_COMMAND} -E copy "${_the_co}" "${_fatbin}"
      DEPENDS "${_the_co}"
      COMMENT "luthier_add_tool(${target}): reusing single-arch .co as fatbin"
      VERBATIM)
  else ()
    # Multi-arch path: each .co is itself a [host, gfxN] bundle; merging
    # them into one [host, gfxA, gfxB, ...] bundle requires
    # extract-then-rebundle. clang-offload-bundler concatenation isn't
    # the right tool for that. This is a TODO; until then, refuse to
    # generate an incorrect fat binary.
    message(FATAL_ERROR
      "luthier_add_tool(${target}): multi-arch (${_num_cos} arches) bundling "
      "is not yet supported by this helper. Use one OFFLOAD_ARCHES entry per "
      "tool, or extend the helper to extract-then-rebundle the per-arch .co "
      "files.")
  endif ()

  # Hand the bundle to the host compile via Clang's internal -cc1 flag
  # `-fcuda-include-gpubinary=<path>`. This is the same mechanism the
  # HIP driver uses internally for normal HIP builds: Clang emits
  # `__hip_fatbin` as `[N x i8]` in section `.hip_fatbin` (typed
  # initializer — exactly what `LoadHIPFATBinaryInfoPass` needs to
  # read the bundle size from `ArrayType::getNumElements()`), the
  # matching `__hip_fatbin_wrapper` in `.hipFatBinSegment`, and the
  # `__hipRegisterFatBinary` call. No separate bin2c step, no
  # ad-hoc `.S`/`.c` source containing the bytes.
  #
  # CMake doesn't see the bundle as a source dependency of the host TU
  # (it's threaded in via a compile flag), so we expose it through a
  # custom target + `OBJECT_DEPENDS` on the source. The custom target
  # gives ninja a build-order edge; `OBJECT_DEPENDS` forces the host
  # `.o` to rebuild when the bundle bytes change.
  add_custom_target(${target}-fatbin-dep DEPENDS "${_fatbin}")

  # Final shared library target. The bundle bytes are spliced into
  # the host TU by Clang via `-fcuda-include-gpubinary`, so the only
  # source slot is the user's HIP TU(s).
  add_library(${target} MODULE ${LAT_SOURCES})

  # The host TU must NOT do its own device compilation — `--cuda-host-only`
  # makes Clang emit only the host stubs + register calls + extern
  # references to __hip_fatbin / __hip_gpubin_handle, all of which are
  # then resolved by the bytes Clang itself splices in via
  # `-fcuda-include-gpubinary`. `-fuse-cuid=none` strips the per-TU
  # CUID suffix so the symbols are the unsuffixed `__hip_fatbin` /
  # `__hip_gpubin_handle` the loader (and IR plugin) expect.
  set_source_files_properties(${LAT_SOURCES} PROPERTIES
    LANGUAGE HIP
    COMPILE_OPTIONS "--cuda-host-only;-fno-gpu-rdc;-fuse-cuid=none"
    OBJECT_DEPENDS "${_fatbin}")

  # The IR compilation plugin (LoadHIPFATBinaryInfoPass etc.) must run on
  # the host TU too — it's what populates the per-tool `HipFatBinaries` /
  # `HipFunctions` / `HipDeviceVars` / etc. annotated slots from the
  # `__hipRegister*` call sites HIP-Clang emits there. Without it on the
  # host side the loader sees an empty `HipFatBinaries` and can't find
  # the embedded bundle bytes (the device-side plugin run wouldn't help —
  # `__hipRegisterFatBinary` calls only exist in the host TU).
  #
  # `-Xclang -fcuda-include-gpubinary -Xclang <path>` is the `-cc1`
  # flag pair that asks Clang's host compilation to embed the bundle.
  # cc1's `-fcuda-include-gpubinary` takes the path as a *separate*
  # argument (not joined with `=`), so the flag and the path each
  # need their own `-Xclang` wrapper. The flag isn't exposed as a
  # driver-level option, which is why `-Xclang` is required at all.
  #
  # `SHELL:` is mandatory here. Without it CMake de-duplicates
  # adjacent identical option tokens, and `-Xclang;-Xclang` collapses
  # to a single `-Xclang` — which would consume the bundle path as
  # the cc1 arg and leave `-fcuda-include-gpubinary` orphaned at the
  # driver level. `SHELL:` opts out of de-dup and keeps each pair as
  # one unit.
  target_compile_options(${target} PRIVATE
    $<$<COMPILE_LANGUAGE:HIP>:-fpass-plugin=${_ir_plugin};SHELL:-Xclang -fcuda-include-gpubinary -Xclang ${_fatbin};${LAT_HIPCC_FLAGS};${LAT_HIPCC_HOST_FLAGS}>)

  target_link_libraries(${target} PRIVATE hip::host ${LAT_LIBRARIES})

  add_dependencies(${target} ${target}-fatbin-dep)
endfunction()
