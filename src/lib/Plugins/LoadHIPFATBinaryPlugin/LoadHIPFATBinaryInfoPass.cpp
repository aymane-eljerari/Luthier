#include "LoadHIPFATBinaryInfoPass.hpp"
#include <llvm/IR/Module.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Plugins/PassPlugin.h>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-load-hip-fat-binary-info-pass"

namespace luthier{

  llvm::PreservedAnalyses LoadHIPFATBinaryInfoPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM){
     llvm::Triple T(M.getTargetTriple());
    // Only operate on host
    if (T.getArch() == llvm::Triple::ArchType::amdgcn)
      return llvm::PreservedAnalyses::all();
    // Start by processing __hipRegisterFatBinary
    // TODO: Is name always unmangled??? also are there any guarantees about 1 function call per FATBIN???
    llvm::Function* RFB = M.getFunction("__hipRegisterFatBinary");
    llvm::Value* FatBinWrapper = nullptr;
    if(RFB){
      for(llvm::User &U : RFB->users()){
        if (auto &CB = llvm::dyn_cast<llvm::CallBase>(U)) {
          FatBinWrapper = CB.getArgOperand(0);
          // TODO: Store this FatBinWrapper now to attributed variable, this is just a llvm::value we need to get the contents somehow
        }
      }
    }

  }
  llvm::Function* RFUN = M.getFunction("__hipRegisterFunction");
  
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