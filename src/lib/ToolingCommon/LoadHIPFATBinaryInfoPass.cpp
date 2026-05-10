//===-- LoadHIPFATBinaryInfo.cpp --------------------------------*- C++ -*-===//
// Copyright 2026 @ Northeastern University Computer Architecture Lab
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//
/// This plugin removes all __hip_register functions from the IR and stores the
/// information inside the annotated variables. This is done so we can delegate
/// the registering of functions, fat bin wrappers, variables etc. to the Tool
/// Executable Loader instead of using HIP for it, whcih has proven to be
/// unreliable
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/LoadHIPFATBinaryInfoPass.h"
#include "luthier/Common/ErrorCheck.h"
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/Analysis/ValueTracking.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Plugins/PassPlugin.h>
#include <llvm/Support/FormatVariadic.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-load-hip-fat-binary-info-pass"

namespace luthier {
/// \brief Fills out a StringMap with all annotated variables, we do this so we
/// can access them later without needing to search again.
/// \param M Module of the IR
/// \param NameToVar StringMap which we will fill out
static llvm::Error getAnnotatedValues(
    const llvm::Module &M,
    llvm::StringMap<llvm::SmallVector<llvm::GlobalVariable *, 4>> &NameToVar) {
  const llvm::GlobalVariable *V =
      M.getGlobalVariable("llvm.global.annotations");
  if (V == nullptr)
    return llvm::Error::success();
  const llvm::ConstantArray *CA = cast<llvm::ConstantArray>(V->getOperand(0));
  for (llvm::Value *Op : CA->operands()) {
    auto *CS = cast<llvm::ConstantStruct>(Op);
    /// The first field of the struct contains a pointer to the annotated
    /// variable.
    llvm::Value *AnnotatedVal = CS->getOperand(0)->stripPointerCasts();
    if (auto *Var = llvm::dyn_cast<llvm::GlobalVariable>(AnnotatedVal)) {
      /// The second field contains a pointer to a global annotation string.
      auto *GV =
          cast<llvm::GlobalVariable>(CS->getOperand(1)->stripPointerCasts());
      llvm::StringRef Content;
      llvm::getConstantStringInfo(GV, Content);
      if (Content.starts_with("luthier.loader.hip")) {
        NameToVar[Content].push_back(Var);
      }
    }
  }
  return llvm::Error::success();
}
/// \brief Replaces the null annotated variable with actual data, setInitializer
/// doesn't work because constants can't change their type, as a workaround we
/// reconstruct the variable with the correct type and delete the old one
/// \note We keep annotations and do not delete them, they hold a pointer to the
/// array, so a GEP is needed to access the struct
/// \param name Name of the annotated variable we are replacing
/// \param Type The type of the struct the variable array will hold
/// \param Size The size of the array
/// \param TempArr The array holding the structs
/// \param M IR Module
/// \param NameToVar StringMap containing all annotated variables
static llvm::Error replacePlaceholderVariable(
    llvm::StringRef Name, llvm::StructType *Type, uint64_t Size,
    llvm::ArrayRef<llvm::Constant *> TempArr, llvm::Module &M,
    llvm::StringMap<llvm::SmallVector<llvm::GlobalVariable *, 4>> &NameToVar) {
  if (NameToVar[Name].empty()) {
    return llvm::createStringError(llvm::inconvertibleErrorCode(),
                                   "There is no annotated variable for " +
                                       Name);
  }
  llvm::ArrayType *ArrayTy = llvm::ArrayType::get(Type, Size);
  llvm::Constant *Array = llvm::ConstantArray::get(ArrayTy, TempArr);
  /// Replace old variable with the array
  for (auto *OldVar : NameToVar[Name]) {
    auto *NewTable =
        new llvm::GlobalVariable(M, Array->getType(), true,
                                 llvm::GlobalValue::ExternalLinkage, Array, "");
    NewTable->takeName(OldVar);
    /// RAUW the new variable. We do a bitcast in case the type is different
    OldVar->replaceAllUsesWith(
        llvm::ConstantExpr::getBitCast(NewTable, OldVar->getType()));

    OldVar->eraseFromParent();
  }
  return llvm::Error::success();
}

/// \brief Same function as the other one, but this is specifically for the fat
/// bin wrapper, since it is not stored in a struct we store an array of opaque
/// pointers to the hip fat binaries
static llvm::Error replacePlaceholderVariable(
    llvm::StringRef Name, llvm::PointerType *Type, uint64_t Size,
    llvm::ArrayRef<llvm::Constant *> TempArr, llvm::Module &M,
    llvm::StringMap<llvm::SmallVector<llvm::GlobalVariable *, 4>> &NameToVar) {
  if (NameToVar[Name].empty()) {
    return llvm::createStringError(llvm::inconvertibleErrorCode(),
                                   "There is no annotated variable for " +
                                       Name);
  }
  llvm::Constant *Array =
      llvm::ConstantArray::get(llvm::ArrayType::get(Type, Size), TempArr);
  /// Replace old variable with the array

  for (auto *OldVar : NameToVar[Name]) {
    auto *NewTable =
        new llvm::GlobalVariable(M, Array->getType(), true,
                                 llvm::GlobalValue::ExternalLinkage, Array, "");
    NewTable->takeName(OldVar);
    OldVar->replaceAllUsesWith(
        llvm::ConstantExpr::getBitCast(NewTable, OldVar->getType()));

    OldVar->eraseFromParent();
  }
  return llvm::Error::success();
}

/// \brief Removed __hip_module_ctor function from the llvm.global_ctors array.
/// This array is constant so we have to reconstruct it exactly as it was but
/// without the __hip_module_ctor, so we can delete it after
static llvm::Error deleteModuleCtor(llvm::Module &M) {
  llvm::GlobalVariable *OldCtors = M.getGlobalVariable("llvm.global_ctors");
  /// If there are no global constructors there is nothing we should do
  if (!OldCtors)
    return llvm::createStringError(
        llvm::inconvertibleErrorCode(),
        "llvm.global_ctors is not present in this file");

  if (!OldCtors->hasInitializer())
    return llvm::createStringError(
        llvm::inconvertibleErrorCode(),
        "llvm.global_ctors is missing the initializer");

  auto *CtorArray =
      llvm::dyn_cast<llvm::ConstantArray>(OldCtors->getInitializer());

  if (!CtorArray)
    return llvm::createStringError(
        llvm::inconvertibleErrorCode(),
        "llvm.global_ctors initializer is not a ConstantArray!");
  llvm::SmallVector<llvm::Constant *, 4> RemainingCtors;
  bool Found = false;
  /// We loop through all elements of the global ctor array and store them in a
  /// temporary array except __hip_module_ctor. We use this array to replace
  /// global_ctors with the new one which doesn't contain __hip_module_ctor. If
  /// it isn't in the array we do nothing
  for (auto &Op : CtorArray->operands()) {
    auto *CS = llvm::dyn_cast<llvm::ConstantStruct>(Op);
    if (!CS || CS->getNumOperands() < 2)
      continue;

    auto *F =
        llvm::dyn_cast<llvm::Function>(CS->getOperand(1)->stripPointerCasts());
    if (F && F->getName().contains("__hip_module_ctor")) {
      Found = true;
    } else {
      RemainingCtors.push_back(CS);
    }
  }
  /// If __hip_module_ctor is in the global_ctors, we reconstruct the array
  /// without it inside, we make sure it is the exact same in every other aspect
  /// to avoid errors
  if (Found) {
    if (RemainingCtors.empty()) {
      OldCtors->eraseFromParent();
    } else {

      llvm::ArrayType *NewATy = llvm::ArrayType::get(
          CtorArray->getType()->getElementType(), RemainingCtors.size());
      llvm::Constant *NewInit =
          llvm::ConstantArray::get(NewATy, RemainingCtors);

      auto *NewCtors = new llvm::GlobalVariable(
          M, NewATy, OldCtors->isConstant(), OldCtors->getLinkage(), NewInit,
          "", nullptr, OldCtors->getThreadLocalMode(),
          OldCtors->getAddressSpace(), OldCtors->isExternallyInitialized());

      NewCtors->copyAttributesFrom(OldCtors);

      if (OldCtors->getType() != NewCtors->getType()) {
        llvm::Constant *BitCast =
            llvm::ConstantExpr::getBitCast(NewCtors, OldCtors->getType());
        OldCtors->replaceAllUsesWith(BitCast);
      } else {
        OldCtors->replaceAllUsesWith(NewCtors);
      }
      OldCtors->eraseFromParent();
      NewCtors->setName("llvm.global_ctors");
    }
  }
  return llvm::Error::success();
}
/// \brief Deletes a function, this assumes there are no uses
static llvm::Error deleteFunction(llvm::Function *Fun) {
  Fun->dropAllReferences();
  Fun->eraseFromParent();
  return llvm::Error::success();
}
/// \brief Deletes all uses of a function, so we can safely delete it after
static llvm::Error deleteAllUses(llvm::Function *Fun) {
  for (auto *User : Fun->users()) {
    if (auto *Inst = llvm::dyn_cast<llvm::Instruction>(User)) {
      // If the call returns a value, we must "defuse" it first
      if (!Inst->use_empty()) {
        Inst->replaceAllUsesWith(llvm::UndefValue::get(Inst->getType()));
      }
      Inst->eraseFromParent(); // Delete the call line
    } else {
      // Handle ConstantExpr or GlobalAliases
      User->dropAllReferences();
    }
  }
  return llvm::Error::success();
}
/// \brief This pass first finds all instances of __hip_register functions and
/// fills out the annotated variables that will hold all the information the
/// Tool Executable Loader needs to register them with hip. After that it
/// deletes all functions that called __hipRegisterFatBinary and all
/// __hip_register functions
llvm::PreservedAnalyses
LoadHIPFATBinaryInfoPass::run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM) {
  llvm::Triple T(M.getTargetTriple());
  bool Changed = false;
  // Only operate on host
  if (T.getArch() == llvm::Triple::ArchType::amdgcn)
    return llvm::PreservedAnalyses::all();
  llvm::LLVMContext &C = M.getContext();
  llvm::StringMap<llvm::SmallVector<llvm::GlobalVariable *, 4>> NameToVar{};
  LUTHIER_REPORT_FATAL_ON_ERROR(getAnnotatedValues(M, NameToVar));

  /// We get all the functions we need to process, for each one we loop over the
  /// uses finding the call instances, and for each one we construct a struct
  /// holding all the information necessary to register the hip object with hip
  /// through the TEL
  llvm::Function *RFB = M.getFunction("__hipRegisterFatBinary");
  llvm::Function *RUFB = M.getFunction("__hipUnregisterFatBinary");
  llvm::Function *RFUN = M.getFunction("__hipRegisterFunction");
  llvm::Function *RMV = M.getFunction("__hipRegisterManagedVar");
  llvm::Function *RDV = M.getFunction("__hipRegisterVar");
  llvm::Function *RTX = M.getFunction("__hipRegisterTexture");
  llvm::Function *RSF = M.getFunction("__hipRegisterSurface");
  /// If there is no __hipRegisterFatBinary function, there is no point looking
  /// at the others
  if (!RFB) {
    return llvm::PreservedAnalyses::all();
  }
  /// There should only be one hip binary, but we generalize to assume there
  /// could be more than one
  llvm::SmallVector<llvm::Constant *, 4> FatBinWrappers{};
  unsigned long long HipFatBinariesSize{};
  for (llvm::User *U : RFB->users()) {
    if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
      llvm::Value *FatBinWrapper = CB->getArgOperand(0);
      // We store the hip fat binaries in a small vector.
      if (llvm::GlobalVariable::classof(FatBinWrapper)) {
        HipFatBinariesSize++;
        auto *GV = llvm::dyn_cast<llvm::GlobalVariable>(FatBinWrapper);
        FatBinWrappers.push_back(GV);
      }
    }
  }
  // Replace nullptr variable with actual value
  LUTHIER_REPORT_FATAL_ON_ERROR(replacePlaceholderVariable(
      "luthier.loader.hip_fat_binaries_ptr", llvm::PointerType::getUnqual(C),
      HipFatBinariesSize, FatBinWrappers, M, NameToVar));
  for (auto *SizeVariable : NameToVar["luthier.loader.hip_fat_binaries_size"]) {
    SizeVariable->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), HipFatBinariesSize));
  }

  if (RFUN) {
    /// Small vector holding the ConstantStructs we will use to construct the
    /// ConstantArray holding them.
    llvm::SmallVector<llvm::Constant *, 10> FunctionHandles{};
    /// We get the type of the info, if it doesn't exist (which it should) we
    /// construct it.
    llvm::StructType *FunInfoTy =
        llvm::StructType::getTypeByName(C, "struct.luthier::HipFunctionInfo");
    if (!FunInfoTy)
      FunInfoTy = llvm::StructType::create("struct.luthier::HipFunctionInfo",
                                           llvm::PointerType::getUnqual(C),
                                           llvm::PointerType::getUnqual(C));
    unsigned long long FunctionHandlesSize{};
    /// Loop through all uses and get the necessary operands
    for (llvm::User *U : RFUN->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *FunctionPtr = CB->getArgOperand(1);
        llvm::Value *DeviceName = CB->getArgOperand(3);
        if (llvm::GlobalVariable::classof(FunctionPtr) &&
            llvm::GlobalVariable::classof(DeviceName)) {
          FunctionHandlesSize++;
          auto *Ptr = llvm::dyn_cast<llvm::Constant>(FunctionPtr);
          auto *Name = llvm::dyn_cast<llvm::Constant>(DeviceName);
          llvm::Constant *FunInfoStruct =
              llvm::ConstantStruct::get(FunInfoTy, {Ptr, Name});
          FunctionHandles.push_back(FunInfoStruct);
        }
      }
    }
    LUTHIER_REPORT_FATAL_ON_ERROR(replacePlaceholderVariable(
        "luthier.loader.hip_functions_ptr", FunInfoTy, FunctionHandlesSize,
        FunctionHandles, M, NameToVar));
    for (auto *FunctionsSize : NameToVar["luthier.loader.hip_functions_size"]) {
      FunctionsSize->setInitializer(llvm::ConstantInt::get(
          llvm::Type::getInt64Ty(C), FunctionHandlesSize));
    }
  }

  if (RMV) {
    llvm::StructType *ManagedVarTy =
        llvm::StructType::getTypeByName(C, "struct.luthier::HipManagedVarInfo");
    if (!ManagedVarTy)
      ManagedVarTy = llvm::StructType::create(
          "struct.luthier::HipManagedVarInfo", llvm::PointerType::getUnqual(C),
          llvm::PointerType::getUnqual(C), llvm::PointerType::getUnqual(C),
          llvm::IntegerType::getInt64Ty(C), llvm::IntegerType::getInt32Ty(C));
    llvm::SmallVector<llvm::Constant *, 10> ManagedVars{};
    unsigned long long ManagedVarSize{};
    for (llvm::User *U : RMV->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *Ptr = CB->getArgOperand(1);
        llvm::Value *InitValue = CB->getArgOperand(2);
        llvm::Value *Name = CB->getArgOperand(3);
        llvm::Value *Size = CB->getArgOperand(4);
        llvm::Value *Align = CB->getArgOperand(5);
        ManagedVarSize++;
        auto *ConstPtr = llvm::dyn_cast<llvm::Constant>(Ptr);
        auto *ConstInitValue = llvm::dyn_cast<llvm::Constant>(InitValue);
        auto *ConstName = llvm::dyn_cast<llvm::Constant>(Name);
        auto *ConstSize = llvm::dyn_cast<llvm::Constant>(Size);
        auto *ConstAlign = llvm::dyn_cast<llvm::Constant>(Align);
        llvm::Constant *ManagedVarStruct = llvm::ConstantStruct::get(
            ManagedVarTy,
            {ConstPtr, ConstInitValue, ConstName, ConstSize, ConstAlign});
        ManagedVars.push_back(ManagedVarStruct);
      }
    }
    LUTHIER_REPORT_FATAL_ON_ERROR(replacePlaceholderVariable(
        "luthier.loader.hip_managed_vars_ptr", ManagedVarTy, ManagedVarSize,
        ManagedVars, M, NameToVar));
    for (auto *ManagedSize :
         NameToVar["luthier.loader.hip_managed_vars_size"]) {
      ManagedSize->setInitializer(
          llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), ManagedVarSize));
    }
  }

  if (RDV) {
    /// FIXME: Should this be a normal vector?
    llvm::SmallVector<llvm::Constant *, 10> DeviceVars{};
    llvm::StructType *VarInfoTy =
        llvm::StructType::getTypeByName(C, "struct.luthier::HipDeviceVarInfo");
    if (!VarInfoTy)
      VarInfoTy = llvm::StructType::create("struct.luthier::HipDeviceVarInfo",
                                           llvm::PointerType::getUnqual(C),
                                           llvm::PointerType::getUnqual(C));
    unsigned long long DeviceVarsSize{};
    for (llvm::User *U : RDV->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *HostHandle = CB->getArgOperand(1);
        llvm::Value *Name = CB->getArgOperand(2);
        DeviceVarsSize++;
        auto *Ptr = llvm::dyn_cast<llvm::Constant>(HostHandle);
        auto *ConstName = llvm::dyn_cast<llvm::Constant>(Name);
        llvm::Constant *FunInfoStruct =
            llvm::ConstantStruct::get(VarInfoTy, {Ptr, ConstName});
        DeviceVars.push_back(FunInfoStruct);
      }
    }
    LUTHIER_REPORT_FATAL_ON_ERROR(replacePlaceholderVariable(
        "luthier.loader.hip_device_vars_ptr", VarInfoTy, DeviceVarsSize,
        DeviceVars, M, NameToVar));
    for (auto *DeviceVarSize :
         NameToVar["luthier.loader.hip_device_vars_size"]) {
      DeviceVarSize->setInitializer(
          llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), DeviceVarsSize));
    }
  }

  if (RTX) {
    /// FIXME: Should this be a normal vector?
    llvm::SmallVector<llvm::Constant *, 10> Textures{};
    llvm::StructType *TextureInfoTy =
        llvm::StructType::getTypeByName(C, "struct.luthier::HipTextureInfo");
    if (!TextureInfoTy)
      TextureInfoTy = llvm::StructType::create("struct.luthier::HipTextureInfo",
                                               llvm::PointerType::getUnqual(C),
                                               llvm::PointerType::getUnqual(C));
    unsigned long long TexturesSize{};
    for (llvm::User *U : RTX->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *HostHandle = CB->getArgOperand(1);
        llvm::Value *Name = CB->getArgOperand(2);
        TexturesSize++;
        auto *Ptr = llvm::dyn_cast<llvm::Constant>(HostHandle);
        auto *ConstName = llvm::dyn_cast<llvm::Constant>(Name);
        llvm::Constant *FunInfoStruct =
            llvm::ConstantStruct::get(TextureInfoTy, {Ptr, ConstName});
        Textures.push_back(FunInfoStruct);
      }
    }
    LUTHIER_REPORT_FATAL_ON_ERROR(replacePlaceholderVariable(
        "luthier.loader.hip_texture_vars_ptr", TextureInfoTy, TexturesSize,
        Textures, M, NameToVar));
    for (auto *TextureVarsSize :
         NameToVar["luthier.loader.hip_texture_vars_size"]) {
      TextureVarsSize->setInitializer(
          llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), TexturesSize));
    }
  }

  if (RSF) {
    /// FIXME: Should this be a normal vector?
    llvm::SmallVector<llvm::Constant *, 10> Surfaces{};
    llvm::StructType *SurfaceInfoTy =
        llvm::StructType::getTypeByName(C, "struct.luthier::HipSurfaceInfo");
    if (!SurfaceInfoTy)
      SurfaceInfoTy = llvm::StructType::create("struct.luthier::HipSurfaceInfo",
                                               llvm::PointerType::getUnqual(C),
                                               llvm::PointerType::getUnqual(C));
    unsigned long long SurfacesSize{};
    for (llvm::User *U : RSF->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *HostHandle = CB->getArgOperand(1);
        llvm::Value *Name = CB->getArgOperand(2);
        SurfacesSize++;
        auto *Ptr = llvm::dyn_cast<llvm::Constant>(HostHandle);
        auto *ConstName = llvm::dyn_cast<llvm::Constant>(Name);
        llvm::Constant *FunInfoStruct =
            llvm::ConstantStruct::get(SurfaceInfoTy, {Ptr, ConstName});
        Surfaces.push_back(FunInfoStruct);
      }
    }
    LUTHIER_REPORT_FATAL_ON_ERROR(replacePlaceholderVariable(
        "luthier.loader.hip_surface_vars_ptr", SurfaceInfoTy, SurfacesSize,
        Surfaces, M, NameToVar));
    for (auto *SurfaceVarsSize :
         NameToVar["luthier.loader.hip_surface_vars_size"]) {
      SurfaceVarsSize->setInitializer(
          llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), SurfacesSize));
    }
  }
  /// Make sure we remove the hip module Ctor from  llvm.global_ctors, not doing
  /// so the function cannot be deleted since it still would have a use
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteModuleCtor(M));
  LUTHIER_REPORT_FATAL_ON_ERROR(
      deleteFunction(M.getFunction("__hip_module_ctor")));
  LUTHIER_REPORT_FATAL_ON_ERROR(
      deleteFunction(M.getFunction("__hip_register_globals")));
  ///  Delete all functions that call __hipRegisterFatBinary and then delete
  /// __hipRegisterFatBinary as well, we do the same for
  /// __hipUnregisterFatBinary as well below
  for (auto *User : RFB->users()) {
    if (auto *CallInst = llvm::dyn_cast<llvm::CallInst>(User)) {
      auto *Fun = CallInst->getParent()->getParent();
      LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(Fun));
    }
  }
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RFB));
  for (auto *User : RUFB->users()) {
    if (auto *CallInst = llvm::dyn_cast<llvm::CallInst>(User)) {
      auto *Fun = CallInst->getParent()->getParent();
      LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(Fun));
    }
  }
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RUFB));
  /// Delete all uses of these functions so we can safely delete them
  if (RMV)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RMV));
  if (RDV)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RDV));
  if (RTX)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RTX));
  if (RSF)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RSF));
  if (RFUN)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RFUN));

  /// Now that they have ZERO users, safely erase them from the Module
  if (RMV)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RMV));
  if (RDV)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RDV));
  if (RTX)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RTX));
  if (RSF)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RSF));
  if (RFUN)
    LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RFUN));
  return llvm::PreservedAnalyses::none();
}

} // namespace luthier