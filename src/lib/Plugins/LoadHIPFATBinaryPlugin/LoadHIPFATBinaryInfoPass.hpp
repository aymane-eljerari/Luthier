#ifndef LUTHIER_COMPILE_PLUGINS_LOAD_HIP_FAT_BINARY_INFO_PASS_HPP
#define LUTHIER_COMPILE_PLUGINS_LOAD_HIP_FAT_BINARY_INFO_PASS_HPP
#include <llvm/IR/PassManager.h>    

namespace llvm {
class Module;
} // namespace llvm

namespace luthier {
    
class LoadHIPFATBinaryInfoPass
    : public llvm::PassInfoMixin<LoadHIPFATBinaryInfoPass> {

public:
  LoadHIPFATBinaryInfoPass() = default;
  struct __HipFatBinaryWrapper{
    unsigned int magic;
    unsigned int version;
    void* binary;
    void* dummy1;
  }
  llvm::PreservedAnalyses run(llvm::Module &M, llvm::ModuleAnalysisManager &MAM);

  static bool isRequired() { return true; }
};

} // namespace luthier


#endif 