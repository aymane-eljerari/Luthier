#include "LoadHIPFATBinaryInfoPass.hpp"

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
// returns a string map mapping annotated variables to llvm::GlobalVariable
// pointers for quick access
static llvm::Error
getAnnotatedValues(const llvm::Module &M,
                   llvm::StringMap<llvm::GlobalVariable *> &NameToVar) {
  const llvm::GlobalVariable *V =
      M.getGlobalVariable("llvm.global.annotations");
  if (V == nullptr)
    return llvm::Error::success();
  const llvm::ConstantArray *CA = cast<llvm::ConstantArray>(V->getOperand(0));
  for (llvm::Value *Op : CA->operands()) {
    auto *CS = cast<llvm::ConstantStruct>(Op);
    // The first field of the struct contains a pointer to the annotated
    // variable.
    llvm::Value *AnnotatedVal = CS->getOperand(0)->stripPointerCasts();
    if (auto *Var = llvm::dyn_cast<llvm::GlobalVariable>(AnnotatedVal)) {
      // The second field contains a pointer to a global annotation string.
      auto *GV =
          cast<llvm::GlobalVariable>(CS->getOperand(1)->stripPointerCasts());
      llvm::StringRef Content;
      llvm::getConstantStringInfo(GV, Content);
      if (Content.starts_with("luthier.loader.hip")) {
        NameToVar[Content] = Var;
      }
    }
  }
  return llvm::Error::success();
}

static llvm::Error replacePlaceholderVariable(
    llvm::StringRef name, llvm::StructType *Type, uint64_t Size,
    llvm::ArrayRef<llvm::Constant *> TempArr, llvm::Module &M,
    llvm::StringMap<llvm::GlobalVariable *> &NameToVar) {
  llvm::ArrayType *ArrayTy = llvm::ArrayType::get(Type, Size);
  llvm::Constant *Array =
      llvm::ConstantArray::get(ArrayTy, TempArr);
  // Replace old variable with the array
  auto *NewTable = new llvm::GlobalVariable(
      M, Array->getType(), true, llvm::GlobalValue::ExternalLinkage, Array, "");
  auto *OldVar = NameToVar[name];
  if (OldVar == nullptr) {
    return llvm::make_error<llvm::StringError>(
        llvm::formatv("Variable {0} is not in the NameToVar map", name),
        llvm::inconvertibleErrorCode());
  }
  NewTable->takeName(OldVar);
  OldVar->replaceAllUsesWith(
      llvm::ConstantExpr::getBitCast(NewTable, OldVar->getType()));

  OldVar->eraseFromParent();
  return llvm::Error::success();
}

// For Fat Binary we just store an opaque pointer
static llvm::Error replacePlaceholderVariable(
    llvm::StringRef name, llvm::PointerType *Type, uint64_t Size,
    llvm::ArrayRef<llvm::Constant *> TempArr, llvm::Module &M,
    llvm::StringMap<llvm::GlobalVariable *> &NameToVar) {
  llvm::Constant *Array =
      llvm::ConstantArray::get(llvm::ArrayType::get(Type, Size), TempArr);
  // Replace old variable with the array
  auto *NewTable = new llvm::GlobalVariable(
      M, Array->getType(), true, llvm::GlobalValue::ExternalLinkage, Array, "");
  auto *OldVar = NameToVar[name];
  if (OldVar == nullptr) {
    return llvm::make_error<llvm::StringError>(
        llvm::formatv("Variable {0} is not in the NameToVar map", name),
        llvm::inconvertibleErrorCode());
  }
  NewTable->takeName(OldVar);
  OldVar->replaceAllUsesWith(
      llvm::ConstantExpr::getBitCast(NewTable, OldVar->getType()));

  OldVar->eraseFromParent();
  return llvm::Error::success();
}

// We first search for the module ctor class and then we rebuild the array
// without it We need to delete the module_ctor from there because otherwise
// program crashes
static llvm::Error deleteModuleCtor(llvm::Module &M) {
  llvm::GlobalVariable *OldCtors = M.getGlobalVariable("llvm.global_ctors");

  if (!OldCtors)
    return llvm::Error::success();

  if (!OldCtors->hasInitializer())
    return llvm::make_error<llvm::StringError>("Missing initializer",
                                               llvm::inconvertibleErrorCode());

  auto *CtorArray =
      llvm::dyn_cast<llvm::ConstantArray>(OldCtors->getInitializer());
  if (!CtorArray)
    return llvm::make_error<llvm::StringError>("Not a ConstantArray",
                                               llvm::inconvertibleErrorCode());

  llvm::SmallVector<llvm::Constant *, 4> RemainingCtors;
  bool Found = false;

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

  if (Found) {
    llvm::ArrayType *NewATy = llvm::ArrayType::get(
        CtorArray->getType()->getElementType(), RemainingCtors.size());
    llvm::Constant *NewInit = llvm::ConstantArray::get(NewATy, RemainingCtors);

    llvm::GlobalVariable *NewCtors = new llvm::GlobalVariable(
        M, NewATy, OldCtors->isConstant(), OldCtors->getLinkage(), NewInit, "",
        nullptr, OldCtors->getThreadLocalMode(), OldCtors->getAddressSpace(),
        OldCtors->isExternallyInitialized());

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
  return llvm::Error::success();
}

static llvm::Error deleteFunction(llvm::Function *Fun) {
  Fun->dropAllReferences();
  Fun->eraseFromParent();
  return llvm::Error::success();
}

static llvm::Error deleteAllUses(llvm::Function *Fun) {
  for (auto *User : Fun->users()) {
    if (llvm::Instruction *Inst = llvm::dyn_cast<llvm::Instruction>(User)) {
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

llvm::PreservedAnalyses
LoadHIPFATBinaryInfoPass::run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM) {
  llvm::Triple T(M.getTargetTriple());
  // Only operate on host
  if (T.getArch() == llvm::Triple::ArchType::amdgcn)
    return llvm::PreservedAnalyses::all();
  llvm::LLVMContext &C = M.getContext();
  llvm::StringMap<llvm::GlobalVariable *> NameToVar{};
  LUTHIER_REPORT_FATAL_ON_ERROR(getAnnotatedValues(M, NameToVar));
  auto AnnotationGV = M.getGlobalVariable("llvm.global.annotations");
  if (AnnotationGV) {
    AnnotationGV->dropAllReferences();
    AnnotationGV->eraseFromParent();
  }

  // Remove the llvm.used and llvm.compiler.use variable list
  for (const auto &VarName : {"llvm.compiler.used", "llvm.used"}) {
    auto LLVMUsedVar = M.getGlobalVariable(VarName);
    if (LLVMUsedVar != nullptr) {
      LLVMUsedVar->dropAllReferences();
      LLVMUsedVar->eraseFromParent();
    }
  }
  // Start by processing __hipRegisterFatBinary
  llvm::Function *RFB = M.getFunction("__hipRegisterFatBinary");
  llvm::Function *RUFB = M.getFunction("__hipUnregisterFatBinary");
  llvm::Function *RFUN = M.getFunction("__hipRegisterFunction");
  llvm::Function *RMV = M.getFunction("__hipRegisterManagedVar");
  llvm::Function *RDV = M.getFunction("__hipRegisterVar");
  llvm::Function *RTX = M.getFunction("__hipRegisterTexture");
  llvm::Function *RSF = M.getFunction("__hipRegisterSurface");

  if (RFB) {
    llvm::SmallVector<llvm::Constant *, 4> FatBinWrappers{};
    unsigned long long HipFatBinariesSize{};
    // TODO: Add checks to ensure handling is correct
    for (llvm::User *U : RFB->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *FatBinWrapper = CB->getArgOperand(0);
        // We store the hip fat binaries in a small vector and make it a
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
    NameToVar["luthier.loader.hip_fat_binaries_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), HipFatBinariesSize));
  }

  if (RFUN) {
    // Small vector holding a pair of HostHandle and name
    llvm::SmallVector<llvm::Constant *, 10> FunctionHandles{};
    llvm::StructType *FunInfoTy =
        llvm::StructType::getTypeByName(C, "HipFunctionInfo");
    if (!FunInfoTy)
      FunInfoTy = llvm::StructType::create("HipFunctionInfo",
                                           llvm::PointerType::getUnqual(C),
                                           llvm::PointerType::getUnqual(C));
    unsigned long long FunctionHandlesSize{};
    for (llvm::User *U : RFUN->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *FunctionPtr = CB->getArgOperand(1);
        llvm::Value *DeviceName = CB->getArgOperand(3);
        // We store the hip fat binaries in a small vector and make it a
        // FIXME: Are they always Global and Constant????
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
    NameToVar["luthier.loader.hip_functions_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C),
        FunctionHandlesSize));
  }

  if (RMV) {
    llvm::StructType *ManagedVarTy =
        llvm::StructType::getTypeByName(C, "HipManagedVarInfo");
    if (!ManagedVarTy)
      ManagedVarTy = llvm::StructType::create(
          "HipManagedVarInfo", llvm::PointerType::getUnqual(C),
          llvm::PointerType::getUnqual(C), llvm::PointerType::getUnqual(C),
          llvm::IntegerType::getInt64Ty(C), llvm::IntegerType::getInt32Ty(C));
    // Small vector holding a pair of HostHandle and name
    llvm::SmallVector<llvm::Constant *, 10> ManagedVars{};
    unsigned long long ManagedVarSize{};
    for (llvm::User *U : RMV->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *Ptr = CB->getArgOperand(1);
        llvm::Value *InitValue = CB->getArgOperand(2);
        llvm::Value *Name = CB->getArgOperand(3);
        llvm::Value *Size = CB->getArgOperand(4);
        llvm::Value *Align = CB->getArgOperand(5);
        // Are they always constants???
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
    NameToVar["luthier.loader.hip_managed_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), ManagedVarSize));
  }

  if (RDV) {
    // Small vector holding a pair of HostHandle and name
    // FIXME: Change to vector from SmallVector?
    llvm::SmallVector<llvm::Constant *, 10> DeviceVars{};
    llvm::StructType *VarInfoTy =
        llvm::StructType::getTypeByName(C, "HipDeviceVarInfo");
    if (!VarInfoTy)
      VarInfoTy = llvm::StructType::create("HipDeviceVarInfo",
                                           llvm::PointerType::getUnqual(C),
                                           llvm::PointerType::getUnqual(C));
    unsigned long long DeviceVarsSize{};
    for (llvm::User *U : RDV->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *HostHandle = CB->getArgOperand(1);
        llvm::Value *Name = CB->getArgOperand(2);
        DeviceVarsSize++;
        // Are they constant???
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
    NameToVar["luthier.loader.hip_device_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), DeviceVarsSize));
  }

  if (RTX) {
    // Small vector holding a pair of HostHandle and name
    // FIXME: Change to vector from SmallVector?
    llvm::SmallVector<llvm::Constant *, 10> Textures{};
    llvm::StructType *TextureInfoTy =
        llvm::StructType::getTypeByName(C, "HipTextureInfo");
    if (!TextureInfoTy)
      TextureInfoTy = llvm::StructType::create("HipTextureInfo",
                                               llvm::PointerType::getUnqual(C),
                                               llvm::PointerType::getUnqual(C));
    unsigned long long TexturesSize{};
    for (llvm::User *U : RTX->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *HostHandle = CB->getArgOperand(1);
        llvm::Value *Name = CB->getArgOperand(2);
        TexturesSize++;
        // Are they constant???
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
    NameToVar["luthier.loader.hip_texture_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), TexturesSize));
  }

  if (RSF) {
    // Small vector holding a pair of HostHandle and name
    // FIXME: Change to vector from SmallVector?
    llvm::SmallVector<llvm::Constant *, 10> Surfaces{};
    llvm::StructType *SurfaceInfoTy =
        llvm::StructType::getTypeByName(C, "HipSurfaceInfo");
    if (!SurfaceInfoTy)
      SurfaceInfoTy = llvm::StructType::create("HipSurfaceInfo",
                                               llvm::PointerType::getUnqual(C),
                                               llvm::PointerType::getUnqual(C));
    unsigned long long SurfacesSize{};
    for (llvm::User *U : RSF->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *HostHandle = CB->getArgOperand(1);
        llvm::Value *Name = CB->getArgOperand(2);
        SurfacesSize++;
        // Are they constant???
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
    NameToVar["luthier.loader.hip_surface_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), SurfacesSize));
  }
  // Make sure we remove the hip module Ctor from  llvm.global_ctors, not doing
  // so results in an error
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteModuleCtor(M));
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(M.getFunction("__hip_module_ctor")));
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(M.getFunction("__hip_register_globals")));
  // FIXME: Guard this so nothing happns if all are null
  //  Delete all functions that call __hipRegisterFatBinary and then delete
  //  __hipRegisterFatBinary as well
  for (auto *user : RFB->users()) {
    if (auto *CallInst = llvm::dyn_cast<llvm::CallInst>(user)) {
      auto *Fun = CallInst->getParent()->getParent();
      LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(Fun));
    }
  }
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RFB));
  for (auto *user : RUFB->users()) {
    if (auto *CallInst = llvm::dyn_cast<llvm::CallInst>(user)) {
      auto *Fun = CallInst->getParent()->getParent();
      LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(Fun));
    }
  }
  LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RUFB));

  if (RMV) LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RMV));
  if (RDV) LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RDV));
  if (RTX) LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RTX));
  if (RSF) LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RSF));
  if (RFUN) LUTHIER_REPORT_FATAL_ON_ERROR(deleteAllUses(RFUN));

// 3. Now that they have ZERO users, safely erase them from the Module
  if (RMV) LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RMV));
  if (RDV) LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RDV));
  if (RTX) LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RTX));
  if (RSF) LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RSF));
  if (RFUN) LUTHIER_REPORT_FATAL_ON_ERROR(deleteFunction(RFUN));
  return llvm::PreservedAnalyses::none();
}

} // namespace luthier

llvm::PassPluginLibraryInfo getLuthierHIPFATBinaryPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, DEBUG_TYPE, LLVM_VERSION_STRING,
          [](llvm::PassBuilder &PB) {
            PB.registerPipelineStartEPCallback(
                [](llvm::ModulePassManager &MPM, llvm::OptimizationLevel Opt) {
                  MPM.addPass(luthier::LoadHIPFATBinaryInfoPass());
                });
            PB.registerPipelineParsingCallback(
                [](llvm::StringRef Name, llvm::ModulePassManager &MPM,
                   llvm::ArrayRef<llvm::PassBuilder::PipelineElement>) {
                  if (Name == DEBUG_TYPE) {
                    MPM.addPass(luthier::LoadHIPFATBinaryInfoPass());
                    return true;
                  }
                  return false;
                });
          }};
}

#ifndef LLVM_LUTHIERHIPFATBINARYPLUGIN_LINK_INTO_TOOLS
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getLuthierHIPFATBinaryPluginInfo();
}
#endif