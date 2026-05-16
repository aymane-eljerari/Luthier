//===-- LLVMUserTrait.h - HSATool LLVM-init trait ---------------*- C++ -*-===//
// Copyright @ Northeastern University Computer Architecture Lab
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
///
/// \file
/// Header-only CRTP trait that initializes the LLVM AMDGPU target and caches
/// \c TargetInfo / \c GCNTargetMachine constructs for each \c hsa_isa_t the
/// tool encounters. The trait owns its slice of LLVM-init lifetime: the
/// AMDGPU target is initialized in its constructor and LLVM is shut down in
/// its destructor.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOLING_LLVM_USER_TRAIT_H
#define LUTHIER_TOOLING_LLVM_USER_TRAIT_H

#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include "luthier/HSA/ISA.h"
#include "luthier/Rocprofiler/ApiTableSnapshot.h"
#include <AMDGPUTargetMachine.h>
#include <llvm/MC/MCAsmInfo.h>
#include <llvm/MC/MCInstPrinter.h>
#include <llvm/MC/MCInstrAnalysis.h>
#include <llvm/MC/MCInstrInfo.h>
#include <llvm/MC/MCRegisterInfo.h>
#include <llvm/MC/MCSubtargetInfo.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/ManagedStatic.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>
#include <memory>
#include <string>
#include <unordered_map>

namespace luthier {

template <typename Derived> class LLVMUserTrait;

/// \brief Per-ISA bundle of LLVM MC-level constructs cached by
/// \c LLVMUserTrait.
struct TargetInfo {
  template <typename Derived> friend class LLVMUserTrait;

private:
  const llvm::Target *Target{nullptr};
  const llvm::MCRegisterInfo *MRI{nullptr};
  const llvm::MCAsmInfo *MAI{nullptr};
  const llvm::MCInstrInfo *MII{nullptr};
  const llvm::MCInstrAnalysis *MIA{nullptr};
  const llvm::MCSubtargetInfo *STI{nullptr};
  llvm::MCInstPrinter *IP{nullptr};
  llvm::TargetOptions *TargetOptions{nullptr};

public:
  [[nodiscard]] const llvm::Target *getTarget() const { return Target; }

  [[nodiscard]] const llvm::MCRegisterInfo *getMCRegisterInfo() const {
    return MRI;
  }

  [[nodiscard]] const llvm::MCAsmInfo *getMCAsmInfo() const { return MAI; }

  [[nodiscard]] const llvm::MCInstrInfo *getMCInstrInfo() const { return MII; }

  [[nodiscard]] const llvm::MCInstrAnalysis *getMCInstrAnalysis() const {
    return MIA;
  }

  [[nodiscard]] const llvm::MCSubtargetInfo *getMCSubTargetInfo() const {
    return STI;
  }

  [[nodiscard]] llvm::MCInstPrinter *getMCInstPrinter() const { return IP; }

  [[nodiscard]] const llvm::TargetOptions &getTargetOptions() const {
    return *TargetOptions;
  }
};

/// \brief CRTP trait that hosts LLVM AMDGPU target / TargetMachine / MC*
/// lifetime for a static Luthier tool.
///
/// AMDGPU target is initialized in the trait ctor; LLVM is shut down in the
/// trait dtor. \c getTargetInfo and \c createTargetMachine are lazy per ISA
/// and cached.
template <typename Derived> class LLVMUserTrait {
private:
  mutable std::unordered_map<hsa_isa_t, TargetInfo> LLVMTargetInfo;

  const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApiTableSnapshot;

public:
  explicit LLVMUserTrait(
      const rocprofiler::HsaApiTableSnapshot<::CoreApiTable> &CoreApi)
      : CoreApiTableSnapshot(CoreApi) {
    LLVMInitializeAMDGPUTarget();
    LLVMInitializeAMDGPUTargetInfo();
    LLVMInitializeAMDGPUTargetMC();
    LLVMInitializeAMDGPUDisassembler();
    LLVMInitializeAMDGPUAsmParser();
    LLVMInitializeAMDGPUAsmPrinter();
    LLVMInitializeAMDGPUTargetMCA();
  }

  ~LLVMUserTrait() {
    for (auto &It : LLVMTargetInfo) {
      delete It.second.MRI;
      delete It.second.MAI;
      delete It.second.MII;
      delete It.second.MIA;
      delete It.second.STI;
      delete It.second.IP;
      delete It.second.TargetOptions;
    }
    LLVMTargetInfo.clear();
    llvm::llvm_shutdown();
  }

  LLVMUserTrait(const LLVMUserTrait &) = delete;
  LLVMUserTrait &operator=(const LLVMUserTrait &) = delete;

  llvm::Expected<const TargetInfo &> getTargetInfo(hsa_isa_t Isa) const {
    auto It = LLVMTargetInfo.find(Isa);
    if (It != LLVMTargetInfo.end())
      return It->second;

    auto Info = LLVMTargetInfo.insert({Isa, TargetInfo()}).first;
    const auto HsaApiTable = CoreApiTableSnapshot.getTable();

    auto TT = hsa::isaGetTargetTriple(HsaApiTable, Isa);
    LUTHIER_RETURN_ON_ERROR(TT.takeError());

    std::string Error;
    auto *Target = llvm::TargetRegistry::lookupTarget(*TT, Error);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        Target, llvm::formatv("Failed to lookup target {0} in LLVM. Reason "
                              "according to LLVM: {1}.",
                              TT->normalize(), Error)));

    auto *MRI = Target->createMCRegInfo(*TT);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        MRI, llvm::formatv("Failed to create machine register info for {0}.",
                           TT->getTriple())));

    auto *TargetOptions = new llvm::TargetOptions();
    TargetOptions->MCOptions.AsmVerbose = true;

    auto *MAI = Target->createMCAsmInfo(*MRI, *TT, TargetOptions->MCOptions);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        MAI,
        llvm::formatv(
            "Failed to create MCAsmInfo from target {0} for Target Triple {1}.",
            Target, TT->getTriple())));

    auto *MII = Target->createMCInstrInfo();
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        MII,
        llvm::formatv("Failed to create MCInstrInfo from target {0}", Target)));

    auto *MIA = Target->createMCInstrAnalysis(MII);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        MIA, llvm::formatv("Failed to create MCInstrAnalysis for target {0}.",
                           Target)));

    auto CPU = hsa::isaGetGPUName(HsaApiTable, Isa);
    LUTHIER_RETURN_ON_ERROR(CPU.takeError());

    auto FeatureString = hsa::isaGetSubTargetFeatures(HsaApiTable, Isa);
    LUTHIER_RETURN_ON_ERROR(FeatureString.takeError());

    auto *STI =
        Target->createMCSubtargetInfo(*TT, *CPU, FeatureString->getString());
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        STI, llvm::formatv("Failed to create MCSubTargetInfo from target {0} "
                           "for triple {1}, CPU {2}, with feature string {3}",
                           Target, TT->getTriple(), *CPU,
                           FeatureString->getString())));

    auto *IP = Target->createMCInstPrinter(llvm::Triple(*TT),
                                           MAI->getAssemblerDialect(), *MAI,
                                           *MII, *MRI);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        IP,
        llvm::formatv(
            "Failed to create MCInstPrinter from Target {0} for Triple {1}.",
            Target, TT->getTriple())));

    Info->second.Target = Target;
    Info->second.MRI = MRI;
    Info->second.MAI = MAI;
    Info->second.MII = MII;
    Info->second.MIA = MIA;
    Info->second.STI = STI;
    Info->second.IP = IP;
    Info->second.TargetOptions = TargetOptions;
    return Info->second;
  }

  llvm::Expected<std::unique_ptr<llvm::GCNTargetMachine>>
  createTargetMachine(hsa_isa_t Isa,
                      const llvm::TargetOptions &TargetOptions = {}) const {
    const auto HsaApiTable = CoreApiTableSnapshot.getTable();
    auto TT = hsa::isaGetTargetTriple(HsaApiTable, Isa);
    LUTHIER_RETURN_ON_ERROR(TT.takeError());
    std::string Error;
    auto *Target = llvm::TargetRegistry::lookupTarget(*TT, Error);
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        Target,
        llvm::formatv(
            "Failed to get target {0} from LLVM. Error according to LLVM: {1}.",
            TT->normalize(), Error)));
    auto CPU = hsa::isaGetGPUName(HsaApiTable, Isa);
    LUTHIER_RETURN_ON_ERROR(CPU.takeError());
    auto FeatureString = hsa::isaGetSubTargetFeatures(HsaApiTable, Isa);
    LUTHIER_RETURN_ON_ERROR(FeatureString.takeError());
    return std::unique_ptr<llvm::GCNTargetMachine>(
        reinterpret_cast<llvm::GCNTargetMachine *>(Target->createTargetMachine(
            llvm::Triple(*TT), *CPU, FeatureString->getString(), TargetOptions,
            llvm::Reloc::PIC_)));
  }
};

} // namespace luthier

#endif // LUTHIER_TOOLING_LLVM_USER_TRAIT_H
