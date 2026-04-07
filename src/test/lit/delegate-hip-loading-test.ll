; RUN: opt %luthier_opt -passes="luthier-load-hip-fat-binary-info-pass" %s -S | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"

; --- Verify that hip functions of interest are gone ---
; CHECK-NOT: define internal void @__hip_module_ctor
; CHECK-NOT: define internal void @__hip_register_globals
; CHECK-NOT: define internal void @__hip_module_dtor
; CHECK-NOT: declare dso_local ptr @__hipRegisterFatBinary
; CHECK-NOT: declare dso_local i32 @__hipRegisterFunction
; CHECK-NOT: declare dso_local void @__hipUnregisterFatBinary

; --- VERIFY TYPE REGISTRATION ---
; CHECK: %HipFunctionInfo = type { ptr, ptr }

; --- VERIFY PROMOTED GLOBALS ---

; CHECK: @HipFatBinariesSize = dso_local global i64 1
@HipFatBinariesSize = dso_local global i64 0

; CHECK: @HipFunctionsSize = dso_local global i64 1
@HipFunctionsSize = dso_local global i64 0

; CHECK: @HipFatBinaries = constant [1 x ptr] [ptr @__hip_fatbin_wrapper]
@HipFatBinaries = dso_local global ptr null

; CHECK: @HipFunctions = constant [1 x %HipFunctionInfo] [%HipFunctionInfo { ptr @_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_, ptr @0 }]
@HipFunctions = dso_local global ptr null

; --- VERIFY CONSTRUCTOR MODIFICATION ---

; CHECK: @llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @_GLOBAL__sub_I_BinomialOption.cpp, ptr null }]
; CHECK-NOT: @__hip_module_ctor
@llvm.global_ctors = appending global [2 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @_GLOBAL__sub_I_BinomialOption.cpp, ptr null }, { i32, ptr, ptr } { i32 65535, ptr @__hip_module_ctor, ptr null }]

; --- UNTOUCHED CODE ---

@__hip_fatbin_wrapper = internal constant { i32, i32, ptr, ptr } { i32 1212764230, i32 1, ptr null, ptr null }
@0 = private unnamed_addr constant [52 x i8] c"_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_\00"

define dso_local void @_Z16binomial_optionsiPK15HIP_vector_typeIfLj4EEPS0_() {
  ret void
}

define internal void @_GLOBAL__sub_I_BinomialOption.cpp() {
  ret void
}