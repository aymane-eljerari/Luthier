#include "LoadHIPFATBinaryInfoPass.hpp"
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Plugins/PassPlugin.h>

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
      if (Content.start_with("luthier.loader.hip")) {
        NameToVar[Content] = Var;
      }
    }
  }
  return llvm::Error::success();
}
static llvm::Error replacePlaceholderVariable(
    llvm::StringRef name, llvm::StructType *Type, uint64_t Size,
    llvm::ArrayRef<llvm::Constant *> TempArr, llvm::Module *M,
    llvm::StringMap<llvm::Constant *> &NameToVar) {
  llvm::Constant *Array =
      llvm::ConstantArray::get(llvm::ArrayType::get(Type, Size), TempArr);
  // Replace old variable with the array
  auto *NewTable =
      new llvm::GlobalVariable(*M, Array->getType(), true,
                               llvm::GlobalValue::ExternalLinkage, Array, "");
  auto *OldVar = NameToVar[name];

  NewTable->takeNameFrom(OldVar);
  OldVar->replaceAllUsesWith(
      llvm::ConstantExpr::getBitCast(NewTable, OldVar->getType()));

  OldVar->eraseFromParent();
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
  if (auto Err = getAnnotatedVars(M, NameToVar))
    llvm::reportFatalInternalError(std::move(Err));

  // Start by processing __hipRegisterFatBinary
  // TODO: Is name always unmangled??? also are there any guarantees about 1
  // function call per FATBIN???
  llvm::Function *RFB = M.getFunction("__hipRegisterFatBinary");

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
    llvm::StructType *FatbinTy =
        llvm::StructType::getTypeByName(C, "HipFatBinaryWrapper");
    if (!FatbinTy)
      FatbinTy = llvm::StructType::create(
          "HipFatBinaryWrapper", llvm::Type::getInt32Ty(C),
          llvm::Type::getInt32Ty(C), llvm::PointerType::getUnqual(C),
          llvm::PointerType::getUnqual(C));
    // Replace nullptr variable with actual value
    replacePlaceholderVariable("luthier.loader.hip_fat_binaries_ptr", FatBinTy,
                               HipFatBinariesSize, FatBinWrappers, M,
                               NameToVar);
    NameToVar["luthier.loader.hip_fat_binaries_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), HipFatBinariesSize));
  }
  llvm::Function *RFUN = M.getFunction("__hipRegisterFunction");
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
        //FIXME: Are they always Global and Constant????
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
    replacePlaceholderVariable("luthier.loader.hip_functions_ptr", FunInfoTy,
                               FunctionHandlesSize, FunctionHandles, M,
                               NameToVar);
    NameToVar["luthier.loader.hip_functions_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), FunctionHandlesSize));
  }

  llvm::Function *RMV = M.getFunction("__hipRegisterManagedVar");
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
        llvm::Constant *ManagedVarStruct =
              llvm::ConstantStruct::get(ManagedVarTy, {ConstPtr, ConstInitValue, ConstName, ConstSize, ConstAlign});
        FunctionHandles.push_back(ManagedVarStruct);
      }
    }
    replacePlaceholderVariable("luthier.loader.hip_managed_vars_ptr", ManagedVarTy,
                               ManagedVarSize, ManagedVars, M,
                               NameToVar);
    NameToVar["luthier.loader.hip_managed_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), ManagedVarSize));
  }
  llvm::Function *RDV = M.getFunction("__hipRegisterVar");
  if (RDV) {
    // Small vector holding a pair of HostHandle and name
    //FIXME: Change to vector from SmallVector?
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
        auto *Name = llvm::dyn_cast<llvm::Constant>(Name);
        llvm::Constant *FunInfoStruct =
            llvm::ConstantStruct::get(VarInfoTy, {Ptr, Name});
        DeviceVars.push_back(FunInfoStruct);        
      }
    }
    replacePlaceholderVariable("luthier.loader.hip_device_vars_ptr", VarInfoTy,
                               DeviceVarsSize, DeviceVars, M,
                               NameToVar);
    NameToVar["luthier.loader.hip_device_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), DeviceVarsSize));
  }
  llvm::Function *RTX = M.getFunction("__hipRegisterTexture");
  if (RTX) {
    // Small vector holding a pair of HostHandle and name
    //FIXME: Change to vector from SmallVector?
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
        auto *Name = llvm::dyn_cast<llvm::Constant>(Name);
        llvm::Constant *FunInfoStruct =
            llvm::ConstantStruct::get(TextureInfoTy, {Ptr, Name});
        Textures.push_back(FunInfoStruct);        
      }
    }
    replacePlaceholderVariable("luthier.loader.hip_texture_vars_ptr", TextureInfoTy,
                               TexturesSize, Textures, M,
                               NameToVar);
    NameToVar["luthier.loader.hip_texture_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), TexturesSize));
  }
  llvm::Function *RSF = M.getFunction("__hipRegisterSurface");
  if (RSF) {
    // Small vector holding a pair of HostHandle and name
    //FIXME: Change to vector from SmallVector?
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
        auto *Name = llvm::dyn_cast<llvm::Constant>(Name);
        llvm::Constant *FunInfoStruct =
            llvm::ConstantStruct::get(SurfaceInfoTy, {Ptr, Name});
        Surfaces.push_back(FunInfoStruct);        
      }
    }
    replacePlaceholderVariable("luthier.loader.hip_surface_vars_ptr", SurfaceInfoTy,
                               SurfacesSize, Surfaces, M,
                               NameToVar);
    NameToVar["luthier.loader.hip_surface_vars_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), SurfacesSize));
  }
  // TODO: Remove all hip register functions now and clean up code

}

} // namespace luthier

llvm::PassPluginLibraryInfo getLuthierHIPFATBinaryPluginInfo() {
  const auto Callback = [](llvm::PassBuilder &PB) {
    PB.registerPipelineStartEPCallback(
        [](llvm::ModulePassManager &MPM, llvm::OptimizationLevel Opt
#if LLVM_VERSION_MAJOR >= 20
           ,
           llvm::ThinOrFullLTOPhase
#endif
        ) { MPM.addPass(luthier::LoadHIPFATBinaryInfoPass()); });
  };

  return {LLVM_PLUGIN_API_VERSION, DEBUG_TYPE, LLVM_VERSION_STRING, Callback};
}

#ifndef LLVM_LUTHIERHIPFATBINARYPLUGIN_LINK_INTO_TOOLS
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getLuthierHIPFATBinaryPluginInfo();
}
#endif