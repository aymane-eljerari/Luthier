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

// Used to get the underlying data from an elemnt which is a ptr to a constant
// object void* getStructElementPtr(llvm::GlobalVariable* GV, unsigned Elt){
//   // If it is a constant global variable (as expected) we get the raw data of
//   this if(GV->isConstant()){
//     auto* Init = GV->getInitializer();
//     llvm::Constant* EltPtr = Init->getAggregateElement(Elt);
//     if(llvm::GlobalVariable* EltGV = dyn_cast<llvm::GlobalVariable>(EltPtr)){
//       if(EltGV->hasInitializer()){
//         // This means our element is not a direct value, but an aggregate
//         type llvm::Constant *EltInit= EltGV->getInitializer(); auto *CDS =
//         dyn_cast<llvm::ConstantDataSequential>(EltInit); llvm::StringRef
//         EltStrRef = CDS->getRawDataValues(); return
//         const_cast<char*>(EltStrRef.data());
//       }
//     }
//     else{
//       return nullptr;
//     }
//   }
//   else{
//     return nullptr;
//   }
// }
// // Used to get elements that are direct values
// unsigned int getStructElementDirect(llvm::GlobalVariable* GV, unsigned Elt) {
//   if (GV && GV->hasInitializer()) {
//       auto* Init = GV->getInitializer();
//       if (llvm::Constant* EltVal = Init->getAggregateElement(Elt)) {
//           if (auto* CI = llvm::dyn_cast<llvm::ConstantInt>(EltVal)) {
//               return (unsigned int)CI->getZExtValue();
//           }
//       }
//   }
//   return 0;
// }
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
    // TODO: Addd checks to ensure handling is correct
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

    llvm::Constant *FatBinWrapperArray = llvm::ConstantArray::get(
        llvm::ArrayType::get(FatBinTy, HipFatBinariesSize), FatBinWrappers);
    NameToVar["luthier.loader.hip_fat_binaries_ptr"]->setInitializer(
        FatBinWrapperArray);
    NameToVar["luthier.loader.hip_fat_binaries_size"]->setInitializer(
        llvm::ConstantInt::get(llvm::Type::getInt64Ty(C), HipFatBinariesSize));
  }
  llvm::Function *RFUN = M.getFunction("__hipRegisterFunction");
  if(RFUN){
    llvm::SmallVector<llvm::Constant*, 10> FunctionHandles{};
    unsigned long long FunctionHandlesSize{};
    for (llvm::User *U : RFB->users()) {
      if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
        llvm::Value *FunctionPtr = CB->getArgOperand(2);
        // We store the hip fat binaries in a small vector and make it a
        if (llvm::GlobalVariable::classof(FatBinWrapper)) {
          FunctionHandlesSize++;
          auto *GV = llvm::dyn_cast<llvm::GlobalVariable>(FatBinWrapper);
          FunctionHandles.push_back(GV);
        }
      }
    }
  }
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