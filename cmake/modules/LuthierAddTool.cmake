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
#     invocation. The IR-compilation pass plugin (`-fpass-plugin=`) and
#     the CXX-compilation clang plugin (`-fplugin=`) are added
#     automatically. The CXX plugin is host-effective only and is a
#     no-op when the tool has no `LUTHIER_HOOK_*` annotations.
#   * HIPCC_HOST_FLAGS — extra flags forwarded to the host TU only.
#   * LIBRARIES — extra link libraries for the final shared object.
#
# Requirements:
#   * The consuming project must enable HIP (`project(... LANGUAGES HIP)`
#     or `enable_language(HIP)`); we read `CMAKE_HIP_COMPILER` /
#     `CMAKE_HIP_ARCHITECTURES` directly.
#   * It must have located Luthier (`find_package(luthier ...)` or be
#     building inside Luthier's tree) so $<TARGET_FILE:...> resolves the
#     IR compilation plugin.
#   * `find_package(hip REQUIRED)` for the imported `hip::host` link
#     target and the `hip_INCLUDE_DIR` lookup.
#===---------------------------------------------------------------------===#

include_guard(GLOBAL)

# Extract the gfx family major number from an arch string. Concrete archs
# are `gfx<major><minor>` where the minor is exactly two trailing
# chars — two digits or digit+letter for the CDNA stepping forms (gfx906
# → 9, gfx90a → 9, gfx942 → 9, gfx1030 → 10, gfx1153 → 11, gfx1200 →
# 12). Generic targets are `gfx<major>(-<sub>)?-generic` (gfx9-generic →
# 9, gfx10-1-generic → 10, gfx12-generic → 12).
function(_luthier_gfx_major arch out_var)
  if ("${arch}" MATCHES "^gfx([0-9]+)(-[0-9]+)?-generic$")
    set(${out_var} "${CMAKE_MATCH_1}" PARENT_SCOPE)
  elseif ("${arch}" MATCHES "^gfx([0-9]+)[0-9][0-9a-z]$")
    set(${out_var} "${CMAKE_MATCH_1}" PARENT_SCOPE)
  else ()
    message(FATAL_ERROR
            "luthier_add_tool: cannot extract gfx major from arch '${arch}'")
  endif ()
endfunction()

# Returns the default wave width for a single gfx target. We follow LLVM's
# AMDGPU default: gfx9-and-earlier are wave64, gfx10-and-later are wave32.
function(_luthier_default_wave_for_arch arch out_var)
  _luthier_gfx_major("${arch}" _major)
  if (_major LESS 10)
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

# `-mcumode` selects CU wavefront execution mode (vs. RDNA's default WGP
# mode). The flag is meaningful only on gfx10+ — on gfx9 it's silently
# no-op, and the `-mno-cumode` complement is rejected with
# `-Woption-ignored`. Compute instrumentation always wants CU mode for
# predictable per-CU scheduling, so we add `-mcumode` for any gfx10+
# arch. Users who explicitly want WGP mode can still pass `-mno-cumode`
# via `HIPCC_FLAGS` — it appears after our flag and wins.
function(_luthier_default_cumode_flag arch out_var)
  _luthier_gfx_major("${arch}" _major)
  if (_major LESS 10)
    set(${out_var} "" PARENT_SCOPE)
  else ()
    set(${out_var} "-mcumode" PARENT_SCOPE)
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
  # If the caller doesn't pin OFFLOAD_ARCHES, fall back to
  # CMAKE_HIP_ARCHITECTURES — `enable_language(HIP)` initializes it via
  # `rocm_agent_enumerator -t GPU`, so the tool tracks the rest of the
  # project's arch matrix automatically.
  if (NOT LAT_OFFLOAD_ARCHES)
    if (CMAKE_HIP_ARCHITECTURES)
      set(LAT_OFFLOAD_ARCHES ${CMAKE_HIP_ARCHITECTURES})
    else ()
      message(FATAL_ERROR
              "luthier_add_tool(${target}): OFFLOAD_ARCHES required "
              "(CMAKE_HIP_ARCHITECTURES is empty)")
    endif ()
  endif ()
  if (NOT LAT_WAVE_MODES)
    set(LAT_WAVE_MODES "auto")
  endif ()

  # Mirror CMAKE_HIP_STANDARD onto the device-side `--cuda-device-only`
  # command. The host TU goes through CMake's HIP language and picks up
  # `HIP_STANDARD` automatically; the device .co compile runs through
  # `add_custom_command`, which bypasses that machinery, so we splice
  # the flag in by hand. Accepted values track the HIP_STANDARD target
  # property (98/11/14/17/20/23/26). Default to 20 to preserve prior
  # hard-coded behavior.
  if (CMAKE_HIP_STANDARD)
    set(_hip_std_flag "-std=c++${CMAKE_HIP_STANDARD}")
  else ()
    set(_hip_std_flag "-std=c++20")
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
    set(_ir_plugin_target LuthierToolIRCompilationPlugin)
  elseif (TARGET luthier::LuthierToolIRCompilationPlugin)
    set(_ir_plugin "$<TARGET_FILE:luthier::LuthierToolIRCompilationPlugin>")
    set(_ir_plugin_target luthier::LuthierToolIRCompilationPlugin)
  else ()
    message(FATAL_ERROR
            "luthier_add_tool(${target}): LuthierToolIRCompilationPlugin not "
            "found. Did you find_package(luthier ...)?")
  endif ()

  # The CXX compilation plugin (clang -fplugin) is host-only — its
  # `__device__` host-handle synthesis + DeclRefExpr rewrite only fire
  # in `--cuda-host-only` mode. We wire it unconditionally: it's a
  # no-op for tools without `LUTHIER_HOOK_*` annotations (e.g.
  # LiftLaunchedKernels), so callers no longer have to thread it
  # through HIPCC_HOST_FLAGS.
  if (TARGET LuthierToolCXXCompilationPlugin)
    set(_cxx_plugin "$<TARGET_FILE:LuthierToolCXXCompilationPlugin>")
    set(_cxx_plugin_target LuthierToolCXXCompilationPlugin)
  elseif (TARGET luthier::LuthierToolCXXCompilationPlugin)
    set(_cxx_plugin "$<TARGET_FILE:luthier::LuthierToolCXXCompilationPlugin>")
    set(_cxx_plugin_target luthier::LuthierToolCXXCompilationPlugin)
  else ()
    message(FATAL_ERROR
            "luthier_add_tool(${target}): LuthierToolCXXCompilationPlugin not "
            "found. Did you find_package(luthier ...)?")
  endif ()

  # CMAKE_HIP_COMPILER is set by `enable_language(HIP)` — CMake's HIP
  # language scan resolves it through `hipconfig --hipclangpath`, so it
  # points at the same clang++ that backs find_package(hip)'s targets.
  # find_package(hip CONFIG) (the modern path) does NOT define
  # HIP_CLANG_PATH — that's a leftover from the deprecated FindHIP
  # module — so we go through the language-level variable instead.
  if (NOT CMAKE_HIP_COMPILER)
    message(FATAL_ERROR
            "luthier_add_tool(${target}): CMAKE_HIP_COMPILER not set — enable "
            "HIP via `project(... LANGUAGES HIP ...)` before calling this helper")
  endif ()
  set(_clang "${CMAKE_HIP_COMPILER}")

  # HIP headers location. Prefer find_package(hip)'s hip_INCLUDE_DIR
  # (every example does find_package(hip REQUIRED)); fall back to the
  # ROCm root CMake's HIP language scan discovered via hipconfig. Either
  # way, no `/opt/rocm` assumption.
  if (DEFINED hip_INCLUDE_DIR)
    set(_hip_include "${hip_INCLUDE_DIR}")
  elseif (DEFINED CMAKE_HIP_COMPILER_ROCM_ROOT)
    set(_hip_include "${CMAKE_HIP_COMPILER_ROCM_ROOT}/include")
  else ()
    message(FATAL_ERROR
            "luthier_add_tool(${target}): cannot locate HIP headers — call "
            "find_package(hip REQUIRED) or enable LANGUAGES HIP first")
  endif ()

  # Resolve LuthierTooling — in-tree target name or imported alias from
  # find_package(luthier ...). LuthierTooling is auto-linked to the
  # final shared module below; we also walk its interface properties
  # here to splice -isystem / -D flags into the device-side custom
  # command (which bypasses CMake's link-deps machinery entirely).
  if (TARGET LuthierTooling)
    set(_tooling_target LuthierTooling)
  elseif (TARGET luthier::LuthierTooling)
    set(_tooling_target luthier::LuthierTooling)
  else ()
    message(FATAL_ERROR
            "luthier_add_tool(${target}): LuthierTooling target not found — "
            "find_package(luthier ...) first, or build from the Luthier tree")
  endif ()

  # LuthierAMDGPU is an INTERFACE library that carries the tablegen
  # .inc dirs (`${CMAKE_BINARY_DIR}/src/lib/AMDGPU`) and the public
  # AMDGPU header copy (`${CMAKE_BINARY_DIR}/include/luthier/AMDGPU`).
  # LuthierTooling links it PUBLIClly but doesn't itself include those
  # dirs in INTERFACE_INCLUDE_DIRECTORIES — its own
  # `$<BUILD_INTERFACE:${AMDGPU_INCLUDE_DIR}>` entry resolves to an
  # empty string because AMDGPU_INCLUDE_DIR is set in a sibling
  # subdirectory's CMakeLists.txt that hasn't been processed yet when
  # the Tooling target is created. Walk it separately to recover the
  # paths.
  set(_tooling_aux_targets "")
  foreach (_aux LuthierAMDGPU luthier::LuthierAMDGPU)
    if (TARGET ${_aux})
      list(APPEND _tooling_aux_targets ${_aux})
      break ()
    endif ()
  endforeach ()

  # Collect interface include directories from LuthierTooling + its
  # public link deps that contribute Luthier-internal headers. Strip
  # the `$<BUILD_INTERFACE:...>` wrapper (we're always building from
  # source) and drop the `$<INSTALL_INTERFACE:...>` alternates. Empty
  # entries get filtered out by the IF below.
  set(_tooling_inc_dirs "")
  foreach (_tgt ${_tooling_target} ${_tooling_aux_targets})
    get_target_property(_inc ${_tgt} INTERFACE_INCLUDE_DIRECTORIES)
    if (_inc)
      foreach (_dir IN LISTS _inc)
        if (_dir MATCHES "^\\$<INSTALL_INTERFACE:")
          continue ()
        endif ()
        string(REGEX REPLACE "^\\$<BUILD_INTERFACE:(.*)>$" "\\1" _dir "${_dir}")
        if (_dir)
          list(APPEND _tooling_inc_dirs "${_dir}")
        endif ()
      endforeach ()
    endif ()
  endforeach ()
  list(REMOVE_DUPLICATES _tooling_inc_dirs)
  set(_tooling_isystem_args "")
  foreach (_dir IN LISTS _tooling_inc_dirs)
    list(APPEND _tooling_isystem_args "-isystem" "${_dir}")
  endforeach ()

  # Same dance for INTERFACE_COMPILE_DEFINITIONS. Skip entries that
  # contain whitespace or an embedded -D — LuthierTooling currently
  # bundles ${LLVM_DEFINITIONS} into a single property entry with `-D`
  # tokens still attached (a pre-existing CMakeLists.txt bug), which
  # would otherwise become one malformed shell arg here. Cleaner
  # definitions like AMD_INTERNAL_BUILD flow through unchanged.
  set(_tooling_def_args "")
  get_target_property(_defs ${_tooling_target} INTERFACE_COMPILE_DEFINITIONS)
  if (_defs)
    foreach (_def IN LISTS _defs)
      if (_def MATCHES "[ \t]" OR _def MATCHES "^-D")
        continue ()
      endif ()
      list(APPEND _tooling_def_args "-D${_def}")
    endforeach ()
  endif ()

  # Build the per-(arch, wave) device-compilation list.
  set(_co_files "")

  foreach (arch IN LISTS LAT_OFFLOAD_ARCHES)
    # Determine wave modes for this arch.
    if (LAT_WAVE_MODES STREQUAL "auto")
      _luthier_default_wave_for_arch("${arch}" _waves)
    else ()
      set(_waves ${LAT_WAVE_MODES})
    endif ()
    _luthier_default_cumode_flag("${arch}" _cumode_flag)

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
              ${_cumode_flag}
              ${_hip_std_flag}
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
              ${_tooling_isystem_args}
              ${_tooling_def_args}
              -idirafter "${_hip_include}"
              ${LAT_HIPCC_FLAGS}
              -c ${LAT_SOURCES}
              -o "${_co}"
              DEPENDS ${LAT_SOURCES} ${_ir_plugin}
              WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
              COMMENT "luthier_add_tool(${target}): compiling device .co for "
              "${arch} ${wave}"
              VERBATIM)
      list(APPEND _co_files "${_co}")
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

  # Keep CMake's host-side HIP language compile aligned with the device
  # `.co` set we just generated. The host TU runs `--cuda-host-only` so
  # this property only affects driver argument validation and the
  # __hipRegister* shape, but mismatches between target HIP_ARCHITECTURES
  # and the bundled fatbin slices have caused loader skew in the past.
  set_target_properties(${target} PROPERTIES
          HIP_ARCHITECTURES "${LAT_OFFLOAD_ARCHES}")

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
          $<$<COMPILE_LANGUAGE:HIP>:-fpass-plugin=${_ir_plugin};-fplugin=${_cxx_plugin};SHELL:-Xclang -fcuda-include-gpubinary -Xclang ${_fatbin};${LAT_HIPCC_FLAGS};${LAT_HIPCC_HOST_FLAGS}>)

  # LuthierTooling is auto-linked so callers don't have to thread its
  # include dirs + compile defs through the device-side custom command
  # (handled above via the same target's interface) AND link line. Any
  # caller-supplied LuthierTooling in LIBRARIES is a no-op duplicate.
  target_link_libraries(${target} PRIVATE
          hip::host ${_tooling_target} ${LAT_LIBRARIES})

  # The genexes above expand to file paths at build time, so CMake
  # can't auto-derive the plugin build-order. Add it explicitly.
  add_dependencies(${target}
          ${target}-fatbin-dep
          ${_ir_plugin_target}
          ${_cxx_plugin_target})
endfunction()
