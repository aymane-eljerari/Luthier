; RUN: opt %luthier_opt -passes="luthier-load-hip-fat-binary-info-pass" %s -S | FileCheck %s
target triple = "x86_64-unknown-linux-gnu"

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
@llvm.global_ctors = appending global [2 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @_GLOBAL__sub_I_BinomialOption.cpp, ptr null }, { i32, ptr, ptr } { i32 65535, ptr @__hip_module_ctor, ptr null }]
@_ZN6appsdkL9sdkVerStrE = internal global %"struct.appsdk::sdkVersionStr" zeroinitializer, align 4
@_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_ = dso_local constant ptr @_Z31__device_stub__binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, align 8
@.str.12 = private unnamed_addr constant [44 x i8] c"Failed to allocate host memory. (randArray)\00", align 1
@_ZSt4cout = external dso_local global %"class.std::basic_ostream", align 8
@.str.1.13 = private unnamed_addr constant [12 x i8] c"Location : \00", align 1
@.str.2.14 = private unnamed_addr constant [100 x i8] c"/home/iasonaskrpr/Projects/HIP-Examples/HIP-Examples-Applications/BinomialOption/BinomialOption.cpp\00", align 1
@.str.3.15 = private unnamed_addr constant [2 x i8] c":\00", align 1
@.str.4.16 = private unnamed_addr constant [41 x i8] c"Failed to allocate host memory. (output)\00", align 1
@.str.5.17 = private unnamed_addr constant [15 x i8] c" System minor \00", align 1
@.str.6.18 = private unnamed_addr constant [15 x i8] c" System major \00", align 1
@.str.7.19 = private unnamed_addr constant [18 x i8] c" agent prop name \00", align 1
@.str.8.20 = private unnamed_addr constant [44 x i8] c"kernel_time (hipEventElapsedTime) =%6.3fms\0A\00", align 1
@.str.9.21 = private unnamed_addr constant [44 x i8] c"Failed to allocate host memory. (refOutput)\00", align 1
@.str.10.22 = private unnamed_addr constant [45 x i8] c"Failed to allocate host memory. (stepsArray)\00", align 1
@.str.11.23 = private unnamed_addr constant [30 x i8] c" Resource Intilization failed\00", align 1
@.str.12.24 = private unnamed_addr constant [48 x i8] c"Error. Failed to allocate memory (num_samples)\0A\00", align 1
@.str.13 = private unnamed_addr constant [2 x i8] c"x\00", align 1
@.str.14 = private unnamed_addr constant [8 x i8] c"samples\00", align 1
@.str.15 = private unnamed_addr constant [35 x i8] c"Number of samples to be calculated\00", align 1
@.str.16 = private unnamed_addr constant [51 x i8] c"Error. Failed to allocate memory (num_iterations)\0A\00", align 1
@.str.17 = private unnamed_addr constant [2 x i8] c"i\00", align 1
@.str.18 = private unnamed_addr constant [11 x i8] c"iterations\00", align 1
@.str.19 = private unnamed_addr constant [42 x i8] c"Number of iterations for kernel execution\00", align 1
@.str.20 = private unnamed_addr constant [22 x i8] c"Executing kernel for \00", align 1
@.str.21 = private unnamed_addr constant [12 x i8] c" iterations\00", align 1
@.str.22 = private unnamed_addr constant [44 x i8] c"-------------------------------------------\00", align 1
@.str.23 = private unnamed_addr constant [6 x i8] c"input\00", align 1
@.str.24 = private unnamed_addr constant [7 x i8] c"Output\00", align 1
@.str.25 = private unnamed_addr constant [23 x i8] c" verifyResults  failed\00", align 1
@.str.26 = private unnamed_addr constant [9 x i8] c"Passed!\0A\00", align 1
@.str.27 = private unnamed_addr constant [9 x i8] c" Failed\0A\00", align 1
@.str.28 = private unnamed_addr constant [52 x i8] c"\0A\0A\0ANo. Output Output(hex) Refoutput Refoutput(hex)\0A\00", align 1
@.str.29 = private unnamed_addr constant [14 x i8] c" [%d] %f %#x \00", align 1
@.str.30 = private unnamed_addr constant [11 x i8] c" %f %#x, \0A\00", align 1
@.str.31 = private unnamed_addr constant [15 x i8] c"Option Samples\00", align 1
@.str.32 = private unnamed_addr constant [10 x i8] c"Time(sec)\00", align 1
@.str.33 = private unnamed_addr constant [21 x i8] c"Transfer+kernel(sec)\00", align 1
@.str.34 = private unnamed_addr constant [12 x i8] c"Options/sec\00", align 1
@.str.35 = private unnamed_addr constant [8 x i8] c"Error: \00", align 1
@.str.36 = private unnamed_addr constant [47 x i8] c"Error. Failed to allocate memory (optionList)\0A\00", align 1
@.str.37 = private unnamed_addr constant [104 x i8] c"/home/iasonaskrpr/Projects/HIP-Examples/HIP-Examples-Applications/BinomialOption/../include/HIPUtil.hpp\00", align 1
@.str.38 = private unnamed_addr constant [2 x i8] c"q\00", align 1
@.str.39 = private unnamed_addr constant [6 x i8] c"quiet\00", align 1
@.str.40 = private unnamed_addr constant [38 x i8] c"Quiet mode. Suppress all text output.\00", align 1
@.str.41 = private unnamed_addr constant [2 x i8] c"e\00", align 1
@.str.42 = private unnamed_addr constant [7 x i8] c"verify\00", align 1
@.str.43 = private unnamed_addr constant [49 x i8] c"Verify results against reference implementation.\00", align 1
@.str.44 = private unnamed_addr constant [2 x i8] c"t\00", align 1
@.str.45 = private unnamed_addr constant [7 x i8] c"timing\00", align 1
@.str.46 = private unnamed_addr constant [14 x i8] c"Print timing.\00", align 1
@.str.47 = private unnamed_addr constant [2 x i8] c"v\00", align 1
@.str.48 = private unnamed_addr constant [8 x i8] c"version\00", align 1
@.str.49 = private unnamed_addr constant [28 x i8] c"AMD APP SDK version string.\00", align 1
@.str.50 = private unnamed_addr constant [2 x i8] c"d\00", align 1
@.str.51 = private unnamed_addr constant [9 x i8] c"deviceId\00", align 1
@.str.52 = private unnamed_addr constant [74 x i8] c"Select deviceId to be used[0 to N-1 where N is number devices available].\00", align 1
@.str.53 = private unnamed_addr constant [37 x i8] c"Error. Cannot add option, NULL input\00", align 1
@.str.54 = private unnamed_addr constant [26 x i8] c"Error. Cannot add option \00", align 1
@.str.55 = private unnamed_addr constant [27 x i8] c". Memory allocation error\0A\00", align 1
@.str.56 = private unnamed_addr constant [26 x i8] c"vector::_M_realloc_insert\00", align 1
@.str.57 = private unnamed_addr constant [36 x i8] c"Cannot reset timer. Invalid handle.\00", align 1
@.str.58 = private unnamed_addr constant [35 x i8] c"Cannot read timer. Invalid handle.\00", align 1
@.str.59 = private unnamed_addr constant [2 x i8] c"|\00", align 1
@.str.60 = private unnamed_addr constant [2 x i8] c" \00", align 1
@.str.61 = private unnamed_addr constant [2 x i8] c"-\00", align 1
@.str.62 = private unnamed_addr constant [31 x i8] c"HIP-Examples-Applications-v1.0\00", align 1
@_ZTVN6appsdk14HIPCommandArgsE = linkonce_odr dso_local unnamed_addr constant { [5 x ptr] } { [5 x ptr] [ptr null, ptr @_ZTIN6appsdk14HIPCommandArgsE, ptr @_ZN6appsdk14HIPCommandArgs16parseCommandLineEiPPc, ptr @_ZN6appsdk14HIPCommandArgsD2Ev, ptr @_ZN6appsdk14HIPCommandArgsD0Ev] }, comdat, align 8
@_ZTIN6appsdk14HIPCommandArgsE = linkonce_odr dso_local constant { ptr, ptr, ptr } { ptr getelementptr inbounds (ptr, ptr @_ZTVN10__cxxabiv120__si_class_type_infoE, i64 2), ptr @_ZTSN6appsdk14HIPCommandArgsE, ptr @_ZTIN6appsdk16SDKCmdArgsParserE }, comdat, align 8
@_ZTVN10__cxxabiv120__si_class_type_infoE = external dso_local global [0 x ptr]
@_ZTSN6appsdk14HIPCommandArgsE = linkonce_odr dso_local constant [26 x i8] c"N6appsdk14HIPCommandArgsE\00", comdat, align 1
@_ZTIN6appsdk16SDKCmdArgsParserE = linkonce_odr dso_local constant { ptr, ptr } { ptr getelementptr inbounds (ptr, ptr @_ZTVN10__cxxabiv117__class_type_infoE, i64 2), ptr @_ZTSN6appsdk16SDKCmdArgsParserE }, comdat, align 8
@_ZTVN10__cxxabiv117__class_type_infoE = external dso_local global [0 x ptr]
@_ZTSN6appsdk16SDKCmdArgsParserE = linkonce_odr dso_local constant [28 x i8] c"N6appsdk16SDKCmdArgsParserE\00", comdat, align 1
@_ZTVN6appsdk16SDKCmdArgsParserE = linkonce_odr dso_local unnamed_addr constant { [3 x ptr] } { [3 x ptr] [ptr null, ptr @_ZTIN6appsdk16SDKCmdArgsParserE, ptr @__cxa_pure_virtual] }, comdat, align 8
@.str.63 = private unnamed_addr constant [2 x i8] c"h\00", align 1
@.str.64 = private unnamed_addr constant [15 x i8] c"SDK version : \00", align 1
@.str.65 = private unnamed_addr constant [3 x i8] c"%f\00", align 1
@.str.66 = private unnamed_addr constant [30 x i8] c"Error. Missing argument for \22\00", align 1
@.str.67 = private unnamed_addr constant [3 x i8] c"\22\0A\00", align 1
@.str.68 = private unnamed_addr constant [4 x i8] c"%lf\00", align 1
@.str.69 = private unnamed_addr constant [3 x i8] c"%d\00", align 1
@.str.70 = private unnamed_addr constant [7 x i8] c"Usage\0A\00", align 1
@.str.71 = private unnamed_addr constant [5 x i8] c"-h, \00", align 1
@.str.72 = private unnamed_addr constant [7 x i8] c"--help\00", align 1
@.str.73 = private unnamed_addr constant [26 x i8] c"Display this information\0A\00", align 1
@.str.74 = private unnamed_addr constant [3 x i8] c", \00", align 1
@.str.75 = private unnamed_addr constant [5 x i8] c"    \00", align 1
@.str.76 = private unnamed_addr constant [3 x i8] c"--\00", align 1
@.str.77 = private unnamed_addr constant [1 x i8] zeroinitializer, align 1
@.str.78 = private unnamed_addr constant [2 x i8] c"\0A\00", align 1
@.str.79 = private unnamed_addr constant [50 x i8] c"basic_string: construction from null is not valid\00", align 1
@0 = private unnamed_addr constant [52 x i8] c"_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_\00", align 1
@__hip_fatbin_60997337ce9624a2 = external constant i8, section ".hip_fatbin"
@__hip_fatbin_wrapper = internal constant { i32, i32, ptr, ptr } { i32 1212764230, i32 1, ptr @__hip_fatbin_60997337ce9624a2, ptr null }, section ".hipFatBinSegment", align 8
@__hip_gpubin_handle_60997337ce9624a2 = internal global ptr null, align 8
@__hip_cuid_60997337ce9624a2 = global i8 0

@_ZN14BinomialOptionD1Ev = dso_local unnamed_addr alias void (ptr), ptr @_ZN14BinomialOptionD2Ev

; Function Attrs: mustprogress noinline norecurse optnone uwtable
define dso_local void @_Z31__device_stub__binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_(i32 noundef %numSteps, ptr noundef %randArray, ptr noundef %out) #0 {
entry:
  %numSteps.addr = alloca i32, align 4
  %randArray.addr = alloca ptr, align 8
  %out.addr = alloca ptr, align 8
  %grid_dim = alloca %struct.dim3, align 8
  %block_dim = alloca %struct.dim3, align 8
  %shmem_size = alloca i64, align 8
  %stream = alloca ptr, align 8
  %grid_dim.coerce = alloca { i64, i32 }, align 8
  %block_dim.coerce = alloca { i64, i32 }, align 8
  store i32 %numSteps, ptr %numSteps.addr, align 4
  store ptr %randArray, ptr %randArray.addr, align 8
  store ptr %out, ptr %out.addr, align 8
  %kernel_args = alloca ptr, i64 3, align 16
  %0 = getelementptr ptr, ptr %kernel_args, i32 0
  store ptr %numSteps.addr, ptr %0, align 8
  %1 = getelementptr ptr, ptr %kernel_args, i32 1
  store ptr %randArray.addr, ptr %1, align 8
  %2 = getelementptr ptr, ptr %kernel_args, i32 2
  store ptr %out.addr, ptr %2, align 8
  %3 = call i32 @__hipPopCallConfiguration(ptr %grid_dim, ptr %block_dim, ptr %shmem_size, ptr %stream)
  %4 = load i64, ptr %shmem_size, align 8
  %5 = load ptr, ptr %stream, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %grid_dim.coerce, ptr align 8 %grid_dim, i64 12, i1 false)
  %6 = getelementptr inbounds nuw { i64, i32 }, ptr %grid_dim.coerce, i32 0, i32 0
  %7 = load i64, ptr %6, align 8
  %8 = getelementptr inbounds nuw { i64, i32 }, ptr %grid_dim.coerce, i32 0, i32 1
  %9 = load i32, ptr %8, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %block_dim.coerce, ptr align 8 %block_dim, i64 12, i1 false)
  %10 = getelementptr inbounds nuw { i64, i32 }, ptr %block_dim.coerce, i32 0, i32 0
  %11 = load i64, ptr %10, align 8
  %12 = getelementptr inbounds nuw { i64, i32 }, ptr %block_dim.coerce, i32 0, i32 1
  %13 = load i32, ptr %12, align 8
  %call = call noundef i32 @hipLaunchKernel(ptr noundef @_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, i64 %7, i32 %9, i64 %11, i32 %13, ptr noundef %kernel_args, i64 noundef %4, ptr noundef %5)
  br label %setup.end

setup.end:                                        ; preds = %entry
  ret void
}

declare dso_local i32 @__hipPopCallConfiguration(ptr, ptr, ptr, ptr)

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #1

declare dso_local i32 @hipLaunchKernel(ptr, i64, i32, i64, i32, ptr, i64, ptr)

; Function Attrs: noinline uwtable
define internal void @_GLOBAL__sub_I_BinomialOption.cpp() #2 section ".text.startup" {
entry:
  call void @__cxx_global_var_init()
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

declare dso_local ptr @__hipRegisterFatBinary(ptr)

define internal void @__hip_register_globals(ptr %0) {
entry:
  %1 = call i32 @__hipRegisterFunction(ptr %0, ptr @_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, ptr @0, ptr @0, i32 -1, ptr null, ptr null, ptr null, ptr null, ptr null)
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

declare dso_local i32 @atexit(ptr)

declare dso_local void @__hipUnregisterFatBinary(ptr)

declare dso_local i32 @__hipRegisterFunction(ptr, ptr, ptr, ptr, i32, ptr, ptr, ptr, ptr, ptr)
