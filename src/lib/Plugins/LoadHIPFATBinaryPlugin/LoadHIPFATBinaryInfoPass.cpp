#include "LoadHIPFATBinaryInfoPass.hpp"
#include <llvm/IR/Module.h>
#include <llvm/IR/GlobalVariable.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Plugins/PassPlugin.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-load-hip-fat-binary-info-pass"

namespace luthier{
  // Used to get the underlying data from an elemnt which is a ptr to a constant object
  void* getStructElementPtr(llvm::GlobalVariable* GV, unsigned Elt){
    // If it is a constant global variable (as expected) we get the raw data of this
    if(GV->isConstant()){
      auto* Init = GV->getInitializer();
      llvm::Constant* EltPtr = Init->getAggregateElement(Elt);
      if(llvm::GlobalVariable* EltGV = dyn_cast<llvm::GlobalVariable>(EltPtr)){
        if(EltGV->hasInitializer()){
          // This means our element is not a direct value, but an aggregate type
          llvm::Constant *EltInit= EltGV->getInitializer();
          auto *CDS = dyn_cast<llvm::ConstantDataSequential>(EltInit);
          llvm::StringRef EltStrRef = CDS->getRawDataValues();
          return const_cast<char*>(EltStrRef.data());
        }
      }
      else{
        return nullptr;
      }
    }
    else{
      return nullptr;
    }
  }
  // Used to get elements that are direct values
  unsigned int getStructElementDirect(llvm::GlobalVariable* GV, unsigned Elt) {
    if (GV && GV->hasInitializer()) {
        auto* Init = GV->getInitializer();
        if (llvm::Constant* EltVal = Init->getAggregateElement(Elt)) {
            if (auto* CI = llvm::dyn_cast<llvm::ConstantInt>(EltVal)) {
                return (unsigned int)CI->getZExtValue();
            }
        }
    }
    return 0; 
  }
  llvm::PreservedAnalyses LoadHIPFATBinaryInfoPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM){
    llvm::Triple T(M.getTargetTriple());
    // Only operate on host
    if (T.getArch() == llvm::Triple::ArchType::amdgcn)
      return llvm::PreservedAnalyses::all();
    // Start by processing __hipRegisterFatBinary
    // TODO: Is name always unmangled??? also are there any guarantees about 1 function call per FATBIN???
    llvm::Function* RFB = M.getFunction("__hipRegisterFatBinary");
    if(RFB){
      __HipFatBinaryWrapper* FatBinWrapper = new __HipFatBinaryWrapper{};
      //TODO: Addd checks to ensure handling is correct
      for(llvm::User *U : RFB->users()){
        if (auto *CB = llvm::dyn_cast<llvm::CallBase>(U)) {
          llvm::Value* FatBinWrapper = CB->getArgOperand(0);
          // Reconstruct the FatBinWrapper in a struct that can be passed to __hipRegisterFatBinary
          if(llvm::GlobalVariable::classof(FatBinWrapper)){
            auto* GV = llvm::dyn_cast<llvm::GlobalVariable>(FatBinWrapper);
            FatBinWrapper->magic = getStructElementDirect(GV, 0);
            FatBinWrapper->version = getStructElementDirect(GV, 1);
            FatBinWrapper->binary = getStructElementPtr(GV, 2);
            //FIXME: This might be wrong and need removal
            FatBinWrapper->dummy1 = getStructElementPtr(GV, 3);
          }
          // Handle cases where we don't see what we expect for some reason
          // else{

          // }
          // Store in annotated variable
        }
      }
    }
  llvm::Function* RFUN = M.getFunction("__hipRegisterFunction");
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