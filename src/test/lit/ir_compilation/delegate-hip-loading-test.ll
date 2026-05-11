; RUN: opt %luthier_tool_ir_compilation_plugin_path -passes="luthier-load-hip-fat-binary-info-pass" %s -S | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"

@TexName = private unnamed_addr constant [12 x i8] c"TextureName\00", align 1
@TexName2 = private unnamed_addr constant [13 x i8] c"TextureName2\00", align 1
@DevTexName = private unnamed_addr constant [18 x i8] c"DeviceTextureName\00", align 1
@DevTexName2 = private unnamed_addr constant [19 x i8] c"DeviceTextureName2\00", align 1
@SurName = private unnamed_addr constant [12 x i8] c"SurfaceName\00", align 1
@DevSurName = private unnamed_addr constant [18 x i8] c"DeviceSurfaceName\00", align 1
@VarName = private unnamed_addr constant [8 x i8] c"VarName\00", align 1
@DeviceVarName = private unnamed_addr constant [14 x i8] c"DeviceVarName\00", align 1
@VarManaged = global i64 0, align 8
@SurfaceAddr = global i64 0, align 8
@TextureAddr = global i64 0, align 8
@TextureAddr2 = global i64 0, align 8
@__hip_cuid_60997337ce9624a2 = global i8 0
@__hip_gpubin_handle_60997337ce9624a2 = internal global ptr null, align 8
@DummyVar = dso_local global i64 0
@DummyManagedVariable = dso_local global i64 0
; --- Verify that hip functions of interest are gone ---
; CHECK-NOT: define internal void @__hip_module_ctor
; CHECK-NOT: define internal void @__hip_register_globals
; CHECK-NOT: define internal void @__hip_module_dtor
; CHECK-NOT: declare dso_local ptr @__hipRegisterFatBinary
; CHECK-NOT: declare dso_local i32 @__hipRegisterFunction
; CHECK-NOT: declare dso_local void @__hipRegisterTexture
; CHECK-NOT: declare dso_local void @__hipRegisterSurface
; CHECK-NOT: declare dso_local void @__hipRegisterVar
; CHECK-NOT: declare dso_local void @__hipRegisterManagedVar
; CHECK-NOT: declare dso_local void @__hipUnregisterFatBinary

declare dso_local i32 @__hipRegisterFunction(ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr)

declare dso_local void @__hipRegisterVar(ptr, ptr, ptr, ptr, i32, i64, i32, i32)

declare dso_local void @__hipRegisterManagedVar(ptr, ptr, ptr, ptr, i64, i32)

declare dso_local void @__hipRegisterSurface(ptr, ptr, ptr, ptr, i32, i32)

declare dso_local void @__hipRegisterTexture(ptr, ptr, ptr, ptr, i32, i32, i32)

declare dso_local ptr @__hipRegisterFatBinary(ptr)

declare dso_local void @__hipUnregisterFatBinary(ptr)

declare dso_local i32 @atexit(ptr)
; CHECK-DAG: %"struct.luthier::HipFunctionInfo" = type { ptr, ptr }
; CHECK-DAG: %"struct.luthier::HipManagedVarInfo" = type { ptr, ptr, ptr, i64, i32 }
; CHECK-DAG: %"struct.luthier::HipDeviceVarInfo" = type { ptr, ptr }
; CHECK-DAG: %"struct.luthier::HipTextureInfo" = type { ptr, ptr }
; CHECK-DAG: %"struct.luthier::HipSurfaceInfo" = type { ptr, ptr }
; CHECK: @llvm.global.annotations = appending global [12 x { ptr, ptr, ptr, i32, ptr }] [{ ptr, ptr, ptr, i32, ptr } { ptr @HipFatBinaries, ptr @.str, ptr @.str.1, i32 63, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipFatBinariesSize, ptr @.str.2, ptr @.str.1, i32 65, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipFunctions, ptr @.str.3, ptr @.str.1, i32 67, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipFunctionsSize, ptr @.str.functions_size, ptr @.str.1, i32 69, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipDeviceVars, ptr @.str.4, ptr @.str.1, i32 71, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipDeviceVarsSize, ptr @.str.5, ptr @.str.1, i32 73, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipManagedVars, ptr @.str.6, ptr @.str.1, i32 75, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipManagedVarsSize, ptr @.str.7, ptr @.str.1, i32 77, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipTextureVars, ptr @.str.8, ptr @.str.1, i32 79, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipTextureVarsSize, ptr @.str.9, ptr @.str.1, i32 81, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipSurfaceVars, ptr @.str.10, ptr @.str.1, i32 83, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipSurfaceVarsSize, ptr @.str.11, ptr @.str.1, i32 85, ptr null }], section "llvm.metadata"
; CHECK: @llvm.compiler.used = appending global [13 x ptr] [ptr @HipFunctionsSize, ptr @HipFunctions, ptr @HipDeviceVars, ptr @HipFatBinaries, ptr @HipManagedVars, ptr @HipSurfaceVars, ptr @HipTextureVars, ptr @HipDeviceVarsSize, ptr @HipFatBinariesSize, ptr @HipManagedVarsSize, ptr @HipSurfaceVarsSize, ptr @HipTextureVarsSize, ptr @__hip_cuid_60997337ce9624a2]
@llvm.global.annotations = appending global [12 x { ptr, ptr, ptr, i32, ptr }] [{ ptr, ptr, ptr, i32, ptr } { ptr @HipFatBinaries, ptr @.str, ptr @.str.1, i32 63, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipFatBinariesSize, ptr @.str.2, ptr @.str.1, i32 65, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipFunctions, ptr @.str.3, ptr @.str.1, i32 67, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipFunctionsSize, ptr @.str.functions_size, ptr @.str.1, i32 69, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipDeviceVars, ptr @.str.4, ptr @.str.1, i32 71, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipDeviceVarsSize, ptr @.str.5, ptr @.str.1, i32 73, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipManagedVars, ptr @.str.6, ptr @.str.1, i32 75, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipManagedVarsSize, ptr @.str.7, ptr @.str.1, i32 77, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipTextureVars, ptr @.str.8, ptr @.str.1, i32 79, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipTextureVarsSize, ptr @.str.9, ptr @.str.1, i32 81, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipSurfaceVars, ptr @.str.10, ptr @.str.1, i32 83, ptr null }, { ptr, ptr, ptr, i32, ptr } { ptr @HipSurfaceVarsSize, ptr @.str.11, ptr @.str.1, i32 85, ptr null }], section "llvm.metadata"
@llvm.compiler.used = appending global [13 x ptr] [ptr @HipFunctionsSize, ptr @HipFunctions, ptr @HipDeviceVars, ptr @HipFatBinaries, ptr @HipManagedVars, ptr @HipSurfaceVars, ptr @HipTextureVars, ptr @HipDeviceVarsSize, ptr @HipFatBinariesSize, ptr @HipManagedVarsSize, ptr @HipSurfaceVarsSize, ptr @HipTextureVarsSize, ptr @__hip_cuid_60997337ce9624a2], section "llvm.metadata"
@HipFatBinaries = dso_local global ptr null, align 8
@.str = private unnamed_addr constant [36 x i8] c"luthier.loader.hip_fat_binaries_ptr\00", section "llvm.metadata"
@.str.1 = private unnamed_addr constant [17 x i8] c"/app/example.cpp\00", section "llvm.metadata"
@HipFatBinariesSize = dso_local global i64 0, align 8
@.str.2 = private unnamed_addr constant [37 x i8] c"luthier.loader.hip_fat_binaries_size\00", section "llvm.metadata"
@HipFunctions = dso_local global ptr null, align 8
@.str.3 = private unnamed_addr constant [33 x i8] c"luthier.loader.hip_functions_ptr\00", section "llvm.metadata"
@HipFunctionsSize = dso_local global i64 0, align 8
@.str.functions_size = private unnamed_addr constant [34 x i8] c"luthier.loader.hip_functions_size\00", section "llvm.metadata"
@HipDeviceVars = dso_local global ptr null, align 8
@.str.4 = private unnamed_addr constant [35 x i8] c"luthier.loader.hip_device_vars_ptr\00", section "llvm.metadata"
@HipDeviceVarsSize = dso_local global i64 0, align 8
@.str.5 = private unnamed_addr constant [36 x i8] c"luthier.loader.hip_device_vars_size\00", section "llvm.metadata"
@HipManagedVars = dso_local global ptr null, align 8
@.str.6 = private unnamed_addr constant [36 x i8] c"luthier.loader.hip_managed_vars_ptr\00", section "llvm.metadata"
@HipManagedVarsSize = dso_local global i64 0, align 8
@.str.7 = private unnamed_addr constant [37 x i8] c"luthier.loader.hip_managed_vars_size\00", section "llvm.metadata"
@HipTextureVars = dso_local global ptr null, align 8
@.str.8 = private unnamed_addr constant [36 x i8] c"luthier.loader.hip_texture_vars_ptr\00", section "llvm.metadata"
@HipTextureVarsSize = dso_local global i64 0, align 8
@.str.9 = private unnamed_addr constant [37 x i8] c"luthier.loader.hip_texture_vars_size\00", section "llvm.metadata"
@HipSurfaceVars = dso_local global ptr null, align 8
@.str.10 = private unnamed_addr constant [36 x i8] c"luthier.loader.hip_surface_vars_ptr\00", section "llvm.metadata"
@HipSurfaceVarsSize = dso_local global i64 0, align 8
@.str.11 = private unnamed_addr constant [37 x i8] c"luthier.loader.hip_surface_vars_size\00", section "llvm.metadata"
; --- VERIFY PROMOTED GLOBALS ---
; CHECK-DAG: @HipFatBinaries = constant [1 x ptr] [ptr @__hip_fatbin_wrapper]
; CHECK-DAG: @HipFunctions = constant [2 x %"struct.luthier::HipFunctionInfo"] [%"struct.luthier::HipFunctionInfo" { ptr @add_numbers_ptr, ptr @1 }, %"struct.luthier::HipFunctionInfo" { ptr @_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, ptr @0 }]
; CHECK-DAG: @HipManagedVars = constant [1 x %"struct.luthier::HipManagedVarInfo"] [%"struct.luthier::HipManagedVarInfo" { ptr @VarManaged, ptr @DummyManagedVariable, ptr @VarName, i64 0, i32 0 }]
; CHECK-DAG: @HipDeviceVars = constant [1 x %"struct.luthier::HipDeviceVarInfo"] [%"struct.luthier::HipDeviceVarInfo" { ptr @DummyVar, ptr @VarName }]
; CHECK-DAG: @HipTextureVars = constant [2 x %"struct.luthier::HipTextureInfo"] [%"struct.luthier::HipTextureInfo" { ptr @TextureAddr2, ptr @TexName2 }, %"struct.luthier::HipTextureInfo" { ptr @TextureAddr, ptr @TexName }]
; CHECK-DAG: @HipSurfaceVars = constant [1 x %"struct.luthier::HipSurfaceInfo"] [%"struct.luthier::HipSurfaceInfo" { ptr @SurfaceAddr, ptr @SurName }]
; CHECK-DAG: @HipFatBinariesSize = dso_local global i64 1, align 8
; CHECK-DAG: @HipFunctionsSize = dso_local global i64 2, align 8
; CHECK-DAG: @HipDeviceVarsSize = dso_local global i64 1, align 8
; CHECK-DAG: @HipManagedVarsSize = dso_local global i64 1, align 8
; CHECK-DAG: @HipTextureVarsSize = dso_local global i64 2, align 8
; CHECK-DAG: @HipSurfaceVarsSize = dso_local global i64 1, align 8

; --- VERIFY CONSTRUCTOR MODIFICATION ---

; CHECK: @llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @_GLOBAL__sub_I_BinomialOption.cpp, ptr null }]
@llvm.global_ctors = appending global [2 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @_GLOBAL__sub_I_BinomialOption.cpp, ptr null }, { i32, ptr, ptr } { i32 65535, ptr @__hip_module_ctor, ptr null }]

define internal void @__hip_register_globals(ptr %0) {
entry:
  %1 = call i32 @__hipRegisterFunction(ptr %0, ptr @_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, ptr @0, ptr @0, i32 -1, ptr null, ptr null, ptr null, ptr null, ptr null)
  %2 = call i32 @__hipRegisterFunction(ptr %0, ptr @add_numbers_ptr, ptr @1, ptr @1, i32 -1, ptr null, ptr null, ptr null, ptr null, ptr null)
  call void @__hipRegisterVar(ptr %0, ptr @DummyVar, ptr @VarName, ptr @DeviceVarName, i32 0, i64 0, i32 0, i32 0)
  call void @__hipRegisterManagedVar(ptr %0, ptr @VarManaged, ptr @DummyManagedVariable, ptr @VarName, i64 0, i32 0)
  call void @__hipRegisterSurface(ptr %0, ptr @SurfaceAddr, ptr @SurName, ptr @DevSurName, i32 0, i32 0)
  call void @__hipRegisterTexture(ptr %0, ptr @TextureAddr, ptr @TexName, ptr @DevTexName, i32 0, i32 0, i32 0)
  call void @__hipRegisterTexture(ptr %0, ptr @TextureAddr2, ptr @TexName2, ptr @DevTexName2, i32 0, i32 0, i32 0)
  ret void
}

define internal void @__hip_module_dtor() {
entry:
  %0 = load ptr, ptr @__hip_gpubin_handle_60997337ce9624a2, align 8
  %1 = icmp ne ptr %0, null
  br i1 %1, label %if, label %exit

if:                                               ; preds = %entry
  call void @__hipUnregisterFatBinary(ptr %0)
  store ptr null, ptr @__hip_gpubin_handle_60997337ce9624a2, align 8
  br label %exit

exit:                                             ; preds = %if, %entry
  ret void
}

define internal void @__hip_module_ctor() {
entry:
  %0 = load ptr, ptr @__hip_gpubin_handle_60997337ce9624a2, align 8
  %1 = icmp eq ptr %0, null
  br i1 %1, label %if, label %exit

if:                                               ; preds = %entry
  %2 = call ptr @__hipRegisterFatBinary(ptr @__hip_fatbin_wrapper)
  store ptr %2, ptr @__hip_gpubin_handle_60997337ce9624a2, align 8
  br label %exit

exit:                                             ; preds = %if, %entry
  %3 = load ptr, ptr @__hip_gpubin_handle_60997337ce9624a2, align 8
  call void @__hip_register_globals(ptr %3)
  %4 = call i32 @atexit(ptr @__hip_module_dtor)
  ret void
}

; --- UNTOUCHED CODE ---
@_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_ = dso_local constant ptr @_Z31__device_stub__binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, align 8
@add_numbers_ptr = dso_local constant ptr @add_numbers, align 8
@__hip_fatbin_wrapper = internal constant { i32, i32, ptr, ptr } { i32 1212764230, i32 1, ptr null, ptr null }
@0 = private unnamed_addr constant [52 x i8] c"_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_\00"
@1 = private unnamed_addr constant [12 x i8] c"add_numbers\00"

define internal void @_GLOBAL__sub_I_BinomialOption.cpp() {
  ret void
}

define dso_local void @_Z31__device_stub__binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_(i32 noundef %numSteps, ptr noundef %randArray, ptr noundef %out) #0 {
  ret void
}

define i32 @add_numbers(i32 %0, i32 %1) {
entry:
  %2 = add i32 %0, %1
  ret i32 %2
}