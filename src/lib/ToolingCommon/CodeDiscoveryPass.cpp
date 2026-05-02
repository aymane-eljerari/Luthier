//===-- CodeDiscoveryPass.cpp ---------------------------------------------===//
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
/// \file CodeDiscoveryPass.cpp
/// Implements the \c CodeDiscoveryPass class.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/CodeDiscoveryPass.h"
#include "AMDGPUTargetMachine.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Tooling/EntryPoint.h"
#include "luthier/Tooling/FunctionAnnotations.h"
#include "luthier/Tooling/InitialEntryPointAnalysis.h"
#include "luthier/Tooling/InstructionTracesAnalysis.h"
#include "luthier/Tooling/MemoryAllocationAccessor.h"
#include "luthier/Tooling/PseudoOpcodeAndRegMapper.h"
#include "luthier/Tooling/TargetMachineInstrMDNode.h"
#include <MCTargetDesc/AMDGPUMCExpr.h>
#include <SIMachineFunctionInfo.h>
#include <SIRegisterInfo.h>
#include <llvm/CodeGen/MachineFrameInfo.h>
#include <llvm/CodeGen/MachineFunctionAnalysis.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/ReachingDefAnalysis.h>
#include <llvm/IR/InstIterator.h>
#include <llvm/IR/IntrinsicsAMDGPU.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/MDBuilder.h>
#include <llvm/IR/Module.h>
#include <llvm/MC/MCAsmInfo.h>
#include <llvm/MC/MCDisassembler/MCDisassembler.h>
#include <llvm/MC/MCInstPrinter.h>
#include <llvm/MC/TargetRegistry.h>
// #include <luthier/Tooling/IPVectorRegLiveness.h>
// #include <luthier/Tooling/IndirectBranchResolverAnalysis.h>
// #include <luthier/Tooling/MachineFunctionEntryPoint.h>
#include "luthier/Tooling/InitialExecutionPointAnalysis.h"
#include "luthier/Tooling/MIRToIRTranslator.h"
#include <llvm/Analysis/ConstantFolding.h>
#include <llvm/Analysis/TargetLibraryInfo.h>
#include <llvm/IR/IntrinsicInst.h>
#include <llvm/Transforms/InstCombine/InstCombine.h>
#include <unordered_set>

#undef DEBUG_TYPE

#define DEBUG_TYPE "luthier-code-discovery"

namespace luthier {

static inline llvm::Error
parseKDRsrc1(const llvm::amdhsa::kernel_descriptor_t &KD,
             const llvm::GCNTargetMachine &TM, llvm::Function &F) {
  auto &ST = TM.getSubtarget<llvm::GCNSubtarget>(F);
  /// GRANULATED_WORKITEM_VGPR_COUNT is automatically calculated via the
  /// resource usage analysis pass, but we add its count as an attribute
  /// to the function for later use
  uint32_t GranulatedWorkitemVGPRCount = AMDHSA_BITS_GET(
      KD.compute_pgm_rsrc1,
      llvm::amdhsa::COMPUTE_PGM_RSRC1_GRANULATED_WORKITEM_VGPR_COUNT);
  uint32_t NextFreeVGPR =
      (GranulatedWorkitemVGPRCount + 1) * ST.getVGPREncodingGranule();
  F.addFnAttr("amdgpu-num-vgpr", llvm::formatv("{0}", NextFreeVGPR).str());

  /// PRIORITY is set by the CP automatically

  /// FLOAT_ROUND_MODE_32, FLOAT_ROUND_MODE_16_64 fields are set to
  /// FP_ROUND_ROUND_TO_NEAREST no matter what, so we will fix it once we
  /// have printed the relocatable of the instrumented object

  /// Lift FLOAT_DENORM_MODE_32 field
  auto Float32Denorm =
      AMDHSA_BITS_GET(KD.compute_pgm_rsrc1,
                      llvm::amdhsa::COMPUTE_PGM_RSRC1_FLOAT_DENORM_MODE_32);
  std::string Denorm32Val;
  switch (Float32Denorm) {
  case FP_DENORM_FLUSH_IN_FLUSH_OUT:
    Denorm32Val = "preserve-sign,preserve-sign";
    break;
  case FP_DENORM_FLUSH_OUT:
    Denorm32Val = "preserve-sign,";
    break;
  case FP_DENORM_FLUSH_IN:
    Denorm32Val = ",preserve-sign";
    break;
  case FP_DENORM_FLUSH_NONE:
    Denorm32Val = ",";
    break;
  default:
    return llvm::make_error<GenericLuthierError>(
        "Invalid FP 32 denorm field " + llvm::to_string(Float32Denorm) + ".");
  }
  F.addFnAttr("denormal-fp-math-f32", Denorm32Val);
  /// Lift FLOAT_DENORM_MODE_16_64 field
  auto Float1664Denorm =
      AMDHSA_BITS_GET(KD.compute_pgm_rsrc1,
                      llvm::amdhsa::COMPUTE_PGM_RSRC1_FLOAT_DENORM_MODE_16_64);
  std::string Denorm1664Val;
  switch (Float1664Denorm) {
  case FP_DENORM_FLUSH_IN_FLUSH_OUT:
    Denorm1664Val = "preserve-sign,preserve-sign";
    break;
  case FP_DENORM_FLUSH_OUT:
    Denorm1664Val = "preserve-sign,";
    break;
  case FP_DENORM_FLUSH_IN:
    Denorm1664Val = ",preserve-sign";
    break;
  case FP_DENORM_FLUSH_NONE:
    Denorm1664Val = ",";
    break;
  default:
    return llvm::make_error<GenericLuthierError>(
        "Invalid FP 16/64 denorm field " + llvm::to_string(Float32Denorm) +
        ".");
  }
  F.addFnAttr("denormal-fp-math", Denorm1664Val);
  /// Lift ENABLE_DX10_CLAMP if gfx11-; Otherwise lift WG_RR_EN
  if (ST.hasRrWGMode()) {
    /// WG_RR_EN is set to zero by the backend; must be fixed after the assembly
    /// is printed

  } else {
    F.addFnAttr(
        "amdgpu-dx10-clamp",
        AMDHSA_BITS_GET(
            KD.compute_pgm_rsrc1,
            llvm::amdhsa::COMPUTE_PGM_RSRC1_GFX6_GFX11_ENABLE_DX10_CLAMP)
            ? "true"
            : "false");
  }

  /// DEBUG_MODE is set by the CP

  /// Lift ENABLE_IEEE_MODE if gfx11-; DISABLE_PERF is reserved and must be set
  /// to zero
  if (ST.hasIEEEMode()) {
    F.addFnAttr("amdgpu-ieee",
                AMDHSA_BITS_GET(
                    KD.compute_pgm_rsrc1,
                    llvm::amdhsa::COMPUTE_PGM_RSRC1_GFX6_GFX11_ENABLE_IEEE_MODE)
                    ? "true"
                    : "false");
  }

  /// BULKY is set by CP

  /// CDBG_USER is set by CP

  /// FP16_OVFL can be queried on device code, but there's no place to set it
  /// at the MIR level

  /// WGP_MODE is set by the cumode feature in the subtarget

  /// MEM_ORDERED is always set to 1 for GFX10+ in the backend, so we will fix
  /// it once we have printed the relocatable of the instrumented object

  /// FWD_PROGRESS is always set to 1 for GFX10+, so we will fix it once we
  /// have printed the relocatable of the instrumented object

  return llvm::Error::success();
}

static inline llvm::Error
parseKDRsrc2(const llvm::amdhsa::kernel_descriptor_t &KD,
             const llvm::GCNTargetMachine &TM, llvm::Function &F) {
  /// ENABLE_PRIVATE_SEGMENT is set if the stack size of the kernel is set to
  /// non-zero value

  /// USER_SGPR_COUNT is automatically set based on the user sgprs requested
  /// from the MFI

  /// ENABLE_TRAP_HANDLER is not set in HSA; For other OSes, it should be set
  /// when creating the target

  /// ENABLE_DYNAMIC_VGPR does not seem to have a handle neither in MIR or MC

  /// Lift ENABLE_SGPR_WORKGROUP_ID_X, Y and Z
  if (AMDHSA_BITS_GET(
          KD.compute_pgm_rsrc2,
          llvm::amdhsa::COMPUTE_PGM_RSRC2_ENABLE_SGPR_WORKGROUP_ID_X) == 0) {
    F.addFnAttr("amdgpu-no-workgroup-id-x");
  }

  if (AMDHSA_BITS_GET(
          KD.compute_pgm_rsrc2,
          llvm::amdhsa::COMPUTE_PGM_RSRC2_ENABLE_SGPR_WORKGROUP_ID_Y) == 0) {
    F.addFnAttr("amdgpu-no-workgroup-id-y");
  }
  if (AMDHSA_BITS_GET(
          KD.compute_pgm_rsrc2,
          llvm::amdhsa::COMPUTE_PGM_RSRC2_ENABLE_SGPR_WORKGROUP_ID_Z) == 0) {
    F.addFnAttr("amdgpu-no-workgroup-id-z");
  }
  /// ENABLE_SGPR_WORKGROUP_INFO is represented in MFI, but it is always set to
  /// false and there is no way to set it

  /// Lift ENABLE_VGPR_WORKITEM_ID
  switch (AMDHSA_BITS_GET(
      KD.compute_pgm_rsrc2,
      llvm::amdhsa::COMPUTE_PGM_RSRC2_ENABLE_VGPR_WORKITEM_ID)) {
  case 0:
    F.addFnAttr("amdgpu-no-workitem-id-y");
  case 1:
    F.addFnAttr("amdgpu-no-workitem-id-z");
  case 2:
    break;
  default:
    return llvm::make_error<GenericLuthierError>(
        "KD's VGPR workitem ID is not valid");
  }
  /// ENABLE_EXCEPTION_ADDRESS_WATCH is always set to zero

  /// ENABLE_EXCEPTION_MEMORY is always set to zero

  /// GRANULATED_LDS_SIZE is automatically set via the lds-size attribute

  /// ENABLE_EXCEPTION_IEEE_754_FP_INVALID_OPERATION,
  /// ENABLE_EXCEPTION_FP_DENORMAL_SOURCE,
  /// ENABLE_EXCEPTION_IEEE_754_FP_DIVISION_BY_ZERO,
  /// ENABLE_EXCEPTION_IEEE_754_FP_OVERFLOW,
  /// ENABLE_EXCEPTION_IEEE_754_FP_UNDERFLOW
  /// ENABLE_EXCEPTION_IEEE_754_FP_INEXACT
  /// ENABLE_EXCEPTION_INT_DIVIDE_BY_ZERO are all set to zero; Must be fixed
  /// after printing the assembly

  return llvm::Error::success();
}

// static llvm::Error parseKDRsrc3(const llvm::amdhsa::kernel_descriptor_t &KD,
//                                 const llvm::GCNTargetMachine &TM,
//                                 llvm::Function &F) {
//   auto &ST = TM.getSubtarget<llvm::GCNSubtarget>(F);
//   auto Generation = ST.getGeneration();
/// Rsrc3 for GFX90A and GFX942 ==============================================

/// ACCUM_OFFSET is automatically calculated based off of vgpr and agpr usage
/// of the MF

/// TG_SPLIT is set by the TM cumode feature

/// Rsrc3 for GFX10 and 11 ===================================================

/// SHARED_VGPR_COUNT is not set by the backend; Must be manually fixed
/// after the assembly is printed

/// INST_PREF_SIZE is automatically calculated according to the size of the
/// code of the kernel

/// TRAP_ON_START and TRAP_ON_END are filled in by the CP

/// IMAGE_OP is not set by the backend; Must be manually fixed after the
/// assembly is printed

/// Rsrc3 for GFX12 ==========================================================

/// INST_PREF_SIZE is automatically calculated according to the size of the
/// code of the kernel

/// GLG_EN is not set either by the backend or MC

/// IMAGE_OP is not set by the backend; Must be manually fixed after the
/// assembly is printed
// }

inline llvm::Error
parseKDKernelCode(const llvm::amdhsa::kernel_descriptor_t &KD,
                  const llvm::GCNTargetMachine &TM, llvm::MachineFunction &MF) {
  llvm::Function &F = MF.getFunction();
  auto MFI = MF.getInfo<llvm::SIMachineFunctionInfo>();
  auto TRI = reinterpret_cast<const llvm::SIRegisterInfo *>(
      TM.getSubtargetImpl(F)->getRegisterInfo());
  auto &ST = TM.getSubtarget<llvm::GCNSubtarget>(F);

  if (!ST.flatScratchIsArchitected()) {
    if (AMDHSA_BITS_GET(
            KD.kernel_code_properties,
            llvm::amdhsa::
                KERNEL_CODE_PROPERTY_ENABLE_SGPR_PRIVATE_SEGMENT_BUFFER) == 1) {
      MFI->addPrivateSegmentBuffer(*TRI);
    }
  }

  if (AMDHSA_BITS_GET(
          KD.kernel_code_properties,
          llvm::amdhsa::KERNEL_CODE_PROPERTY_ENABLE_SGPR_DISPATCH_PTR) == 1) {
    MFI->addDispatchPtr(*TRI);
  }

  if (AMDHSA_BITS_GET(
          KD.kernel_code_properties,
          llvm::amdhsa::KERNEL_CODE_PROPERTY_ENABLE_SGPR_QUEUE_PTR) == 1) {
    MFI->addQueuePtr(*TRI);
  }

  if (AMDHSA_BITS_GET(
          KD.kernel_code_properties,
          llvm::amdhsa::KERNEL_CODE_PROPERTY_ENABLE_SGPR_KERNARG_SEGMENT_PTR) ==
      1) {
    MFI->addKernargSegmentPtr(*TRI);
  }

  if (AMDHSA_BITS_GET(
          KD.kernel_code_properties,
          llvm::amdhsa::KERNEL_CODE_PROPERTY_ENABLE_SGPR_DISPATCH_ID) == 1) {
    MFI->addDispatchID(*TRI);
  }

  if (ST.flatScratchIsArchitected()) {
    if (AMDHSA_BITS_GET(
            KD.kernel_code_properties,
            llvm::amdhsa::KERNEL_CODE_PROPERTY_ENABLE_SGPR_FLAT_SCRATCH_INIT) ==
        1) {
      MFI->addFlatScratchInit(*TRI);
    }
  }
  if (AMDHSA_BITS_GET(
          KD.kernel_code_properties,
          llvm::amdhsa::
              KERNEL_CODE_PROPERTY_ENABLE_SGPR_PRIVATE_SEGMENT_SIZE) == 1) {
    MFI->addPrivateSegmentSize(*TRI);
  }

  /// Wavefront32 should be taken care of when creating the target machine

  /// Set the size of the stack based on whether we have a dynamic stack or not
  if (KD.private_segment_fixed_size != 0) {
    llvm::MachineFrameInfo &FrameInfo = MF.getFrameInfo();
    FrameInfo.CreateFixedObject(KD.private_segment_fixed_size, 0, true);
    FrameInfo.setStackSize(KD.private_segment_fixed_size);
    if (AMDHSA_BITS_GET(
            KD.kernel_code_properties,
            llvm::amdhsa::KERNEL_CODE_PROPERTY_USES_DYNAMIC_STACK)) {
      FrameInfo.CreateVariableSizedObject(llvm::Align(4), nullptr);
    }
  }

  return llvm::Error::success();
};

/// Initializes the \c llvm::Function and \c llvm::MachineFunction for the
/// entry point for the \p KD
static llvm::Expected<std::pair<llvm::MachineFunction &,
                                std::optional<object::AMDGCNElfSymbolRef>>>
initKernelEntryPointFunction(const llvm::amdhsa::kernel_descriptor_t &KD,
                             const MemoryAllocationAccessor &SegAccessor,
                             llvm::Module &TargetModule,
                             const llvm::GCNTargetMachine &TM,
                             llvm::FunctionAnalysisManager &FAM) {
  llvm::LLVMContext &LLVMContext = TargetModule.getContext();
  /// Get the memory allocation associated with the kernel descriptor
  auto KDLoadAddr = reinterpret_cast<uint64_t>(&KD);
  auto SegmentOrErr = SegAccessor.getAllocationDescriptor(KDLoadAddr);
  LUTHIER_RETURN_ON_ERROR(SegmentOrErr.takeError());

  if (SegmentOrErr->empty())
    return LUTHIER_MAKE_GENERIC_ERROR(
        llvm::formatv("Failed to find the memory allocation descriptor "
                      "associated with KD {0:x}.",
                      KDLoadAddr));

  uint64_t KDLoadOffset =
      KDLoadAddr -
      reinterpret_cast<uint64_t>(SegmentOrErr->getDeviceAllocation().data());

  std::optional<object::AMDGCNKernelDescSymbolRef> KDSymbolIfPresent{
      std::nullopt};

  auto *ObjFile = SegmentOrErr->getAllocationCodeObject();

  /// If the KD allocation has a code object associated with it,
  /// locate the KD's symbol
  if (ObjFile) {
    /// Lambda is used instead of a plain loop for easier break/error checking
    llvm::Expected<object::AMDGCNKernelDescSymbolRef> KDSymbolOrErr =
        [&]() -> llvm::Expected<object::AMDGCNKernelDescSymbolRef> {
      llvm::Error Err = llvm::Error::success();
      for (object::AMDGCNKernelDescSymbolRef CurrentKD :
           ObjFile->kernel_descriptors(Err)) {
        LUTHIER_RETURN_ON_ERROR(Err);
        llvm::Expected<uint64_t> CurrentKDLoadAddrOrErr =
            CurrentKD.getAddress();
        LUTHIER_RETURN_ON_ERROR(CurrentKDLoadAddrOrErr.takeError());
        if (*CurrentKDLoadAddrOrErr == KDLoadOffset) {
          return CurrentKD;
          LUTHIER_RETURN_ON_ERROR(Err);
        }
      }
      LUTHIER_RETURN_ON_ERROR(Err);
      return llvm::make_error<GenericLuthierError>(llvm::formatv(
          "Failed to get the KD associated with address {0:x}", KDLoadOffset));
    }();
    LUTHIER_RETURN_ON_ERROR(KDSymbolOrErr.takeError());

    KDSymbolIfPresent = *KDSymbolOrErr;
  }

  /// If we have an object symbol associated with the kernel descriptor, then
  /// we find its name from its kernel symbol; Otherwise, give it a name
  /// based on its load address
  std::string KernelName;
  if (KDSymbolIfPresent.has_value()) {
    llvm::Expected<llvm::StringRef> KernelNameOrErr =
        KDSymbolIfPresent->getName();
    LUTHIER_RETURN_ON_ERROR(KernelNameOrErr.takeError());
    KernelName = KernelNameOrErr->substr(0, KernelNameOrErr->rfind(".kd"));
  } else {
    KernelName = llvm::formatv("kernel-{0:x}", KDLoadAddr);
  }

  /// Kernel's return type is always void
  /// We also do not attempt to recover the kernel's prototype from the metadata
  /// because the raised LLVM IR version of the kernel has to translate
  /// low-level argument buffer loading instructions not present in the
  /// high-level prototype of the original kernel (assuming the kernel was
  /// written in a high-level language); For example, if the kernarg buffer is
  /// passed in s[4:5], the raised IR instruction of s_load_dword s[4:5], s[4:5]
  /// 0x0 will be raised to a load, not "read from the first kernel function's
  /// argument"
  /// Also there is no guarantee if a kernel written in assembly tries
  /// to conform with the LLVM IR convention of "explicit args first, implicit
  /// arg after" i.e. it might mix implicit and explicit arguments together
  llvm::Type *const ReturnType = llvm::Type::getVoidTy(LLVMContext);

  llvm::FunctionType *FunctionType =
      llvm::FunctionType::get(ReturnType, {}, false);

  llvm::Function *F =
      llvm::Function::Create(FunctionType, llvm::GlobalValue::WeakAnyLinkage,
                             KernelName, TargetModule);
  F->setVisibility(llvm::GlobalValue::ProtectedVisibility);

  // Populate the Attributes =================================================

  F->setCallingConv(llvm::CallingConv::AMDGPU_KERNEL);

  // Construct the attributes of the Function, which will result in the MF
  // attributes getting populated

  auto &KDOnHost = *reinterpret_cast<const llvm::amdhsa::kernel_descriptor_t *>(
      &SegmentOrErr->getHostAllocation()[KDLoadOffset]);

  F->addFnAttr("amdgpu-lds-size",
               llvm::to_string(KDOnHost.group_segment_fixed_size));

  /// Lift Rsrc1-Rsrc2; Rsrc3 is mostly automatically computed so we don't
  /// lift it
  LUTHIER_RETURN_ON_ERROR(parseKDRsrc1(KDOnHost, TM, *F));
  LUTHIER_RETURN_ON_ERROR(parseKDRsrc2(KDOnHost, TM, *F));

  // Populate the MFI ==========================================================

  llvm::MachineFunction &MF =
      FAM.getResult<llvm::MachineFunctionAnalysis>(*F).getMF();

  /// Parse the kernel code field of the kernel
  LUTHIER_RETURN_ON_ERROR(parseKDKernelCode(KDOnHost, TM, MF));

  auto *MFI = MF.getInfo<llvm::SIMachineFunctionInfo>();
  auto &ST = TM.getSubtarget<llvm::GCNSubtarget>(*F);

  /// Set pre-loaded kernel argument field for targets that support it
  if (ST.hasKernargPreload()) {
    /// TODO: It seems the AMDGPU backend doesn't support the offset field of
    /// kernarg_preload for now. Fix it once it is added to LLVM upstream
    MFI->getUserSGPRInfo().allocKernargPreloadSGPRs(KDOnHost.kernarg_preload);
  }

  /// Fix up some of the MFI fields that have a direct IR attribute but doesn't
  /// get populated on creating the machine function

  /// Workitem argument values
  constexpr unsigned PackedMask = 0x3ff;
  bool HasPackedTID = ST.hasFeature(llvm::AMDGPU::FeaturePackedTID);

  if (!F->hasFnAttribute("amdgpu-no-workitem-id-x")) {
    unsigned WorkItemXMask = HasPackedTID ? PackedMask : ~0u;
    MFI->setWorkItemIDX(llvm::ArgDescriptor::createRegister(llvm::AMDGPU::VGPR0,
                                                            WorkItemXMask));
  }
  if (!F->hasFnAttribute("amdgpu-no-workitem-id-y")) {
    llvm::MCRegister WorkItemYReg =
        HasPackedTID ? llvm::AMDGPU::VGPR0 : llvm::AMDGPU::VGPR1;
    unsigned WorkItemYMask = HasPackedTID ? PackedMask << 10 : ~0u;
    MFI->setWorkItemIDY(
        llvm::ArgDescriptor::createRegister(WorkItemYReg, WorkItemYMask));
  }

  if (!F->hasFnAttribute("amdgpu-no-workitem-id-z")) {
    llvm::MCRegister WorkItemZReg =
        HasPackedTID ? llvm::AMDGPU::VGPR0 : llvm::AMDGPU::VGPR2;
    unsigned WorkItemZMask = HasPackedTID ? PackedMask << 20 : ~0u;
    MFI->setWorkItemIDZ(
        llvm::ArgDescriptor::createRegister(WorkItemZReg, WorkItemZMask));
  }

  /// Workgroup IDs
  if (!F->hasFnAttribute("amdgpu-no-workgroup-id-x"))
    MFI->addWorkGroupIDX();
  if (!F->hasFnAttribute("amdgpu-no-workgroup-id-y"))
    MFI->addWorkGroupIDY();
  if (!F->hasFnAttribute("amdgpu-no-workgroup-id-z"))
    MFI->addWorkGroupIDZ();

  /// Kernel functions are 2^8 byte aligned
  MF.setAlignment(llvm::Align(256));

  /// We do not define any implicit arguments to be present since at the binary
  /// level we don't care whether an argument is implicit or explicit and we
  /// treat them the same
  F->addFnAttr("amdgpu-implicitarg-num-bytes", "0");

  /// GRANULATED_WAVEFRONT_SGPR_COUNT is automatically calculated via the
  /// resouce usage analysis pass, but we add its count as an attribute
  /// to the function for later use
  uint32_t NextFreeSGPR = [&] {
    if (!llvm::AMDGPU::isGFX10Plus(ST)) {
      uint32_t GranulatedWavefrontSGPRCount = AMDHSA_BITS_GET(
          KD.compute_pgm_rsrc1,
          llvm::amdhsa::COMPUTE_PGM_RSRC1_GRANULATED_WAVEFRONT_SGPR_COUNT);
      return (GranulatedWavefrontSGPRCount + 1) * ST.getSGPREncodingGranule();
    } else {
      return ST.getAddressableNumSGPRs();
    }
  }();
  F->addFnAttr("amdgpu-num-sgpr", llvm::formatv("{0}", NextFreeSGPR).str());

  return std::make_pair(std::ref(MF), KDSymbolIfPresent);
}

llvm::Expected<std::pair<llvm::MachineFunction &,
                         std::optional<object::AMDGCNElfSymbolRef>>>
initLiftedDeviceFunctionEntry(uint64_t DeviceEntryPointAddr,
                              const MemoryAllocationAccessor &SegAccessor,
                              llvm::Module &TargetModule,
                              const llvm::Function &InitialExecutionPoint,
                              llvm::FunctionAnalysisManager &FAM) {

  llvm::LLVMContext &LLVMContext = TargetModule.getContext();
  auto SegmentOrErr = SegAccessor.getAllocationDescriptor(DeviceEntryPointAddr);
  LUTHIER_RETURN_ON_ERROR(SegmentOrErr.takeError());
  if (SegmentOrErr->empty())
    return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
        "Failed to find the allocation associated with address {0:x}",
        DeviceEntryPointAddr));

  uint64_t DevFuncLoadOffset =
      DeviceEntryPointAddr -
      reinterpret_cast<uint64_t>(SegmentOrErr->getDeviceAllocation().data());

  /// Locate the symbol this entry address is part of
  std::optional<object::AMDGCNElfSymbolRef> FuncSymRef{std::nullopt};
  uint64_t EntryFromStartOfSymbol{0};

  if (auto *ObjFile = SegmentOrErr->getAllocationCodeObject()) {
    for (object::AMDGCNElfSymbolRef Symbol : ObjFile->symbols()) {
      if (Symbol.getELFType() == llvm::ELF::STT_FUNC) {
        llvm::Expected<uint64_t> SymbolAddrOrErr = Symbol.getAddress();
        LUTHIER_RETURN_ON_ERROR(SymbolAddrOrErr.takeError());
        uint64_t SymbolSize = Symbol.getSize();
        if (*SymbolAddrOrErr <= DevFuncLoadOffset &&
            DevFuncLoadOffset <= (*SymbolAddrOrErr + SymbolSize)) {
          FuncSymRef = Symbol;
          EntryFromStartOfSymbol = DevFuncLoadOffset - *SymbolAddrOrErr;
        }
      }
    }
  }

  std::string FuncName;
  if (FuncSymRef.has_value()) {
    LUTHIER_RETURN_ON_ERROR(FuncSymRef->getName().moveInto(FuncName));
    FuncName += llvm::formatv("x{0:x}", EntryFromStartOfSymbol);
  } else {
    FuncName = llvm::formatv("x{0:x}", DeviceEntryPointAddr);
  }

  llvm::FunctionType *FunctionType = InitialExecutionPoint.getFunctionType();

  llvm::Function *F = llvm::Function::Create(
      FunctionType, llvm::GlobalValue::PrivateLinkage, FuncName, TargetModule);
  F->setCallingConv(llvm::CallingConv::C);
  /// Inherit \c amdgpu-num-vgpr / \c amdgpu-num-sgpr from the initial
  /// execution point handle
  assert(InitialExecutionPoint.getCallingConv() !=
             llvm::CallingConv::AMDGPU_KERNEL &&
         "initial execution point is not a kernel");
  unsigned NumVGPRs =
      InitialExecutionPoint.getFnAttributeAsParsedInteger("amdgpu-num-vgpr");
  unsigned NumSGPRs =
      InitialExecutionPoint.getFnAttributeAsParsedInteger("amdgpu-num-sgpr");
  F->addFnAttr("amdgpu-num-vgpr", llvm::formatv("{0}", NumVGPRs).str());
  F->addFnAttr("amdgpu-num-sgpr", llvm::formatv("{0}", NumSGPRs).str());

  llvm::MachineFunction &MF =
      FAM.getResult<llvm::MachineFunctionAnalysis>(*F).getMF();

  MF.setAlignment(llvm::Align(4));
  return std::make_pair(std::ref(MF), FuncSymRef);
}

/// Recursively walk \p V (interpreted at lane \p LaneIdx for vector
/// values, or \c -1 for scalar / whole-value access) and collect every
/// distinct constant address that flows into the requested position.
///
/// Resolved patterns:
///   - \c ConstantInt leaf — the address itself;
///   - \c ConstantExpr wrapping a \c ConstantInt via \c inttoptr /
///     \c ptrtoint / \c bitcast — unwraps;
///   - \c PHINode / \c SelectInst — every incoming value / arm
///     contributes recursively at the same lane;
///   - \c InsertElementInst with constant index — picks the inserted
///     scalar when its lane matches our \p LaneIdx, else falls
///     through to the previous vector;
///   - \c ExtractElementInst with constant index — recurses on the
///     source vector with the extracted lane index;
///   - same-shape \c BitCast — recurses on operand 0 with the same
///     \p LaneIdx;
///   - scalar-pass-through \c CastInst (\c IntToPtr / \c PtrToInt /
///     \c Trunc / \c ZExt / \c SExt) — recurses with \c LaneIdx == -1;
///   - \c Argument — walks every call site of the parent function and
///     recurses on the matching call-arg operand (inter-procedural
///     tracking).
///
/// Unhandled (returns \c false): scalar↔vector bitcasts (would need
/// bit-window tracking), loads, arbitrary arithmetic, opaque
/// inline-asm values, function pointers stored in memory, etc.
///
/// Returns \c true iff every path terminates at a recognized constant
/// leaf. \p Visited breaks cycles introduced by PHIs and recursive
/// argument chains.
static constexpr unsigned kCollectMaxDepth = 64;

static bool collectConstantTargets(
    llvm::Value *V, int LaneIdx, llvm::SmallSetVector<uint64_t, 8> &Targets,
    llvm::SmallPtrSetImpl<llvm::Value *> &Visited, unsigned Depth = 0) {
  if (!V)
    return false;
  if (Depth >= kCollectMaxDepth)
    return false;
  if (!Visited.insert(V).second)
    return true;

  if (auto *CI = llvm::dyn_cast<llvm::ConstantInt>(V)) {
    if (LaneIdx == -1) {
      Targets.insert(CI->getZExtValue());
      return true;
    }
    return false;
  }

  if (auto *CDV = llvm::dyn_cast<llvm::ConstantDataVector>(V)) {
    if (LaneIdx >= 0 &&
        static_cast<unsigned>(LaneIdx) < CDV->getNumElements()) {
      if (auto *CI = llvm::dyn_cast<llvm::ConstantInt>(
              CDV->getElementAsConstant(static_cast<unsigned>(LaneIdx)))) {
        Targets.insert(CI->getZExtValue());
        return true;
      }
    }
    return false;
  }

  if (auto *CE = llvm::dyn_cast<llvm::ConstantExpr>(V)) {
    if (LaneIdx == -1 && (CE->getOpcode() == llvm::Instruction::IntToPtr ||
                          CE->getOpcode() == llvm::Instruction::PtrToInt ||
                          CE->getOpcode() == llvm::Instruction::BitCast)) {
      if (auto *Inner = llvm::dyn_cast<llvm::ConstantInt>(CE->getOperand(0))) {
        Targets.insert(Inner->getZExtValue());
        return true;
      }
    }
    return false;
  }

  if (auto *Phi = llvm::dyn_cast<llvm::PHINode>(V)) {
    bool AllResolved = true;
    for (llvm::Value *In : Phi->incoming_values())
      AllResolved &=
          collectConstantTargets(In, LaneIdx, Targets, Visited, Depth + 1);
    return AllResolved;
  }

  if (auto *Sel = llvm::dyn_cast<llvm::SelectInst>(V)) {
    bool A = collectConstantTargets(Sel->getTrueValue(), LaneIdx, Targets,
                                    Visited, Depth + 1);
    bool B = collectConstantTargets(Sel->getFalseValue(), LaneIdx, Targets,
                                    Visited, Depth + 1);
    return A && B;
  }

  if (auto *EE = llvm::dyn_cast<llvm::ExtractElementInst>(V)) {
    if (LaneIdx != -1)
      return false;
    if (auto *Idx = llvm::dyn_cast<llvm::ConstantInt>(EE->getIndexOperand()))
      return collectConstantTargets(EE->getVectorOperand(),
                                    static_cast<int>(Idx->getZExtValue()),
                                    Targets, Visited, Depth + 1);
    return false;
  }

  if (auto *IE = llvm::dyn_cast<llvm::InsertElementInst>(V)) {
    if (LaneIdx == -1)
      return false;
    auto *Idx = llvm::dyn_cast<llvm::ConstantInt>(IE->getOperand(2));
    if (!Idx)
      return false;
    if (static_cast<int>(Idx->getZExtValue()) == LaneIdx)
      return collectConstantTargets(IE->getOperand(1), -1, Targets, Visited,
                                    Depth + 1);
    return collectConstantTargets(IE->getOperand(0), LaneIdx, Targets, Visited,
                                  Depth + 1);
  }

  if (auto *BC = llvm::dyn_cast<llvm::BitCastInst>(V)) {
    llvm::Type *SrcTy = BC->getSrcTy();
    llvm::Type *DstTy = BC->getDestTy();
    auto *SrcVec = llvm::dyn_cast<llvm::FixedVectorType>(SrcTy);
    auto *DstVec = llvm::dyn_cast<llvm::FixedVectorType>(DstTy);
    if (SrcVec && DstVec &&
        SrcVec->getNumElements() == DstVec->getNumElements())
      return collectConstantTargets(BC->getOperand(0), LaneIdx, Targets,
                                    Visited, Depth + 1);
    if (LaneIdx == -1 && !SrcTy->isVectorTy() && !DstTy->isVectorTy())
      return collectConstantTargets(BC->getOperand(0), -1, Targets, Visited,
                                    Depth + 1);
    return false;
  }

  if (auto *Cast = llvm::dyn_cast<llvm::CastInst>(V)) {
    if (LaneIdx != -1)
      return false;
    return collectConstantTargets(Cast->getOperand(0), -1, Targets, Visited,
                                  Depth + 1);
  }

  if (auto *Arg = llvm::dyn_cast<llvm::Argument>(V)) {
    /// Inter-procedural step: trace into every direct call site of the
    /// argument's parent function. The \c Visited set already has \p V
    /// (this Argument), so a callee → caller → callee cycle through
    /// the same arg is broken on the second visit. We additionally cap
    /// the size of \p Visited as a defensive bound — extremely deep
    /// argument chains (e.g. through long insertelement sequences in
    /// callers) are bounded by \p Depth, but \p Visited size guards
    /// against pathological-fanout call graphs.
    if (Visited.size() > 4096)
      return false;
    llvm::Function *F = Arg->getParent();
    unsigned ArgNo = Arg->getArgNo();
    bool AllResolved = true;
    for (llvm::User *U : F->users()) {
      auto *Call = llvm::dyn_cast<llvm::CallBase>(U);
      if (!Call || Call->getCalledFunction() != F ||
          ArgNo >= Call->arg_size()) {
        AllResolved = false;
        continue;
      }
      AllResolved &= collectConstantTargets(Call->getArgOperand(ArgNo), LaneIdx,
                                            Targets, Visited, Depth + 1);
    }
    return AllResolved;
  }

  return false;
}

static bool shouldImplicitReadExec(const llvm::MachineInstr &MI) {
  if (llvm::SIInstrInfo::isVALU(MI)) {
    switch (MI.getOpcode()) {
    case llvm::AMDGPU::V_READLANE_B32:
    case llvm::AMDGPU::SI_RESTORE_S32_FROM_VGPR:
    case llvm::AMDGPU::V_WRITELANE_B32:
    case llvm::AMDGPU::SI_SPILL_S32_TO_VGPR:
      return false;
    default:
      return true;
    }
  }

  if (llvm::SIInstrInfo::isSALU(MI) || llvm::SIInstrInfo::isSMRD(MI))
    return false;

  return true;
}

/// Walks over the \p MCOperands and converts them to \c llvm::MachineOperand
/// instances before adding them to the \c llvm::MachineInstr managed
/// by the \p MIBuilder
/// \note Does not convert direct branch target immediate operands to a machine
/// basic block
/// \return \c llvm::Error indicating the success or failure of the operation
static llvm::Error
convertAndAddMCOperandsToMI(llvm::ArrayRef<llvm::MCOperand> MCOperands,
                            llvm::MachineInstrBuilder &MIBuilder) {
  const unsigned Opcode = MIBuilder->getOpcode();
  const llvm::MCInstrDesc &MCID = MIBuilder->getDesc();
  llvm::MachineBasicBlock *MBB = MIBuilder->getParent();
  assert(MBB && "MI is not part of a machine basic block");
  llvm::MachineFunction *MF = MBB->getParent();
  assert(MF && "MI is not part of a machine function");
  const bool IsDirectBranch =
      MIBuilder->isBranch() && !MIBuilder->isIndirectBranch();
  for (auto [MCOpIdx, MCOp] : llvm::enumerate(MCOperands)) {
    if (MCOp.isReg()) {
      LLVM_DEBUG(llvm::dbgs()
                 << "[CodeDiscoveryPass] Converting MC register operand "
                 << llvm::printReg(MCOp.getReg(),
                                   MF->getSubtarget().getRegisterInfo())
                 << "\n");
      unsigned RegNum = RealToPseudoRegisterMapTable(MCOp.getReg());
      const bool IsDef = MCOpIdx < MCID.getNumDefs();
      auto Flags = 0x0;
      const llvm::MCOperandInfo &OpInfo = MCID.operands().begin()[MCOpIdx];
      if (IsDef && !OpInfo.isOptionalDef()) {
        Flags |= llvm::RegState::Define;
      }
      LLVM_DEBUG(llvm::dbgs()
                     << "[CodeDiscoveryPass] Adding pseudo register "
                     << llvm::printReg(RegNum,
                                       MF->getSubtarget().getRegisterInfo())
                     << llvm::formatv(" with flags 0x{0:X}\n", Flags););
      (void)MIBuilder.addReg(RegNum, Flags);
    } else if (MCOp.isImm()) {
      LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                     "[CodeDiscoveryPass] Resolving immediate operand: {0}\n",
                     MCOp.getImm()));

      if (!IsDirectBranch) {
        LLVM_DEBUG(
            llvm::dbgs()
            << "[CodeDiscoveryPass] Not a direct branch, adding immediate "
               "directly to instruction\n");
        /// SOPK needs some special attention to be converted correctly
        if (llvm::SIInstrInfo::isSOPK(*MIBuilder)) {
          LLVM_DEBUG(llvm::dbgs()
                     << "[CodeDiscoveryPass] Instruction is in SOPK format\n");
          if (llvm::SIInstrInfo::sopkIsZext(MIBuilder->getOpcode())) {
            auto Imm = static_cast<uint16_t>(MCOp.getImm());
            LLVM_DEBUG(
                llvm::dbgs() << llvm::formatv(
                    "[CodeDiscoveryPass] Adding truncated imm (zext): {0}\n",
                    Imm));
            (void)MIBuilder.addImm(Imm);
          } else {
            auto Imm = static_cast<int16_t>(MCOp.getImm());
            LLVM_DEBUG(
                llvm::dbgs() << llvm::formatv(
                    "[CodeDiscoveryPass] Adding truncated imm (sex): {0}\n",
                    Imm));
            (void)MIBuilder.addImm(Imm);
          }
        } else {
          LLVM_DEBUG(llvm::dbgs()
                     << llvm::formatv("[CodeDiscoveryPass] Adding Imm: {0}\n",
                                      MCOp.getImm()));
          (void)MIBuilder.addImm(MCOp.getImm());
        }
      }
    } else if (MCOp.isExpr() && llvm::isa<llvm::AMDGPUMCExpr>(MCOp.getExpr())) {
      const auto *TargetExpr = llvm::cast<llvm::AMDGPUMCExpr>(MCOp.getExpr());

      switch (TargetExpr->getKind()) {
      case llvm::AMDGPUMCExpr::AGVK_Lit:
      case llvm::AMDGPUMCExpr::AGVK_Lit64:
        LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
            TargetExpr->getArgs().size() == 1 &&
                llvm::isa<llvm::MCConstantExpr>(TargetExpr->getSubExpr(0)),
            "Literal expr operands should only have one constant sub "
            "expression"));
        (void)MIBuilder.addImm(
            llvm::cast<llvm::MCConstantExpr>(TargetExpr->getSubExpr(0))
                ->getValue());
        break;
      default:
        return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
            "Unexpected expression type: {0}", TargetExpr->getKind()));
      }
    } else {
      return LUTHIER_MAKE_GENERIC_ERROR(
          llvm::formatv("Unexpected MC operand: ", MCOp));
    }
  }
  // Create a (fake) memory operand to keep the machine verifier happy
  // when encountering image instructions
  if (llvm::SIInstrInfo::isImage(*MIBuilder)) {
    llvm::MachinePointerInfo PtrInfo =
        llvm::MachinePointerInfo::getConstantPool(*MF);
    llvm::MachineMemOperand *MMO = MF->getMachineMemOperand(
        PtrInfo,
        MCID.mayLoad() ? llvm::MachineMemOperand::MOLoad
                       : llvm::MachineMemOperand::MOStore,
        16, llvm::Align(8));
    MIBuilder->addMemOperand(*MF, MMO);
  }

  if (size_t NumMCOps = MCOperands.size(); NumMCOps < MCID.NumOperands) {
    LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Must fixup instruction ";
               MIBuilder->print(llvm::dbgs()); llvm::dbgs() << "\n";
               llvm::dbgs()
               << "[CodeDiscoveryPass] Num explicit operands added: "
               << NumMCOps << ", "
               << "expected: " << MCID.NumOperands << "\n");
    // Loop over missing explicit operands (if any) and fixup any missing
    // immediate operands; We ignore any other missing operand kinds here and
    // fix it later
    for (unsigned int MissingExpOpIdx = NumMCOps;
         MissingExpOpIdx < MCID.NumOperands; MissingExpOpIdx++) {
      LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                     "[CodeDiscoveryPass] Fixing up operand index {0}\n",
                     MissingExpOpIdx));
      auto OpType = MCID.operands()[MissingExpOpIdx].OperandType;
      if (OpType == llvm::MCOI::OPERAND_IMMEDIATE ||
          OpType == llvm::AMDGPU::OPERAND_KIMM32) {
        LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Adding 0-immediate for "
                                   "missing operand\n";);
        (void)MIBuilder.addImm(0);
      }
    }
  }

  if (Opcode == llvm::AMDGPU::S_BITSET0_B32 ||
      Opcode == llvm::AMDGPU::S_BITSET0_B64 ||
      Opcode == llvm::AMDGPU::S_BITSET1_B32 ||
      Opcode == llvm::AMDGPU::S_BITSET1_B64) {
    // bitset instructions have a tied def/use that is not reflected in the
    // MC version
    if (MIBuilder->getNumOperands() < MIBuilder->getNumExplicitOperands()) {
      const llvm::MachineOperand &DefMachineOp = MIBuilder->getOperand(0);
      // Check if the first operand is a register
      LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
          DefMachineOp.isReg(),
          "The first operand of a bitset instruction is not a register."));
      // Add the output reg also as the first input, and tie the first and
      // second operands together
      MIBuilder->addOperand(
          llvm::MachineOperand::CreateReg(DefMachineOp.getReg(), false));
      MIBuilder->tieOperands(0, 2);
    }
  }

  /// Add implicit use of the execute mask if it's not already reflected in
  /// the machine instruction
  if (MCID.hasImplicitUseOfPhysReg(llvm::AMDGPU::EXEC) &&
      !MIBuilder->hasRegisterImplicitUseOperand(llvm::AMDGPU::EXEC)) {
    MIBuilder->addOperand(
        llvm::MachineOperand::CreateReg(llvm::AMDGPU::EXEC, false, true));
  }

  return llvm::Error::success();
}

static llvm::Error
populateMF(const InstructionTraces &MFTrace, llvm::MachineFunction &MF,
           llvm::SmallVector<llvm::MachineInstr *> &UnresolvedReturnInsts) {
  llvm::LLVMContext &Ctx = MF.getFunction().getContext();
  llvm::MachineBasicBlock *CurrentMBB = MF.CreateMachineBasicBlock();

  const auto &TM =
      *reinterpret_cast<const llvm::GCNTargetMachine *>(&MF.getTarget());

  MF.push_back(CurrentMBB);

  const llvm::MCRegisterInfo &MRI = *TM.getMCRegisterInfo();

  std::unique_ptr<llvm::MCInstPrinter> IP(TM.getTarget().createMCInstPrinter(
      TM.getTargetTriple(), TM.getMCAsmInfo()->getAssemblerDialect(),
      *TM.getMCAsmInfo(), *TM.getMCInstrInfo(), MRI));

  llvm::MCContext &MCContext = MF.getContext();

  const llvm::MCInstrInfo &MCInstInfo = *TM.getMCInstrInfo();
  std::unique_ptr<llvm::MCInstrAnalysis> MIA(
      TM.getTarget().createMCInstrAnalysis(&MCInstInfo));

  llvm::DenseMap<uint64_t,
                 llvm::SmallVector<llvm::MachineInstr *>>
      UnresolvedBranchMIs; // < Set of branch instructions located at a
                           // device address waiting for their
                           // target to be resolved after MBBs and MIs
                           // are created
  llvm::DenseMap<uint64_t, llvm::MachineBasicBlock *>
      BranchTargetMBBs; // < Set of MBBs that will be the target of the
                        // UnresolvedBranchMIs

  /// The start address of the first trace
  const uint64_t FirstTraceStartAddr = MFTrace.traces_begin()->first.first;
  /// The end address of the last trace
  const uint64_t LastTraceEndAddr = MFTrace.traces_rbegin()->first.second;

  const llvm::TargetRegisterInfo *TRI = MF.getSubtarget().getRegisterInfo();

  llvm::MachineInstr *EntryInst{nullptr};

  for (const auto &[TraceStartEndAddr, Trace] : MFTrace.traces()) {
    uint64_t CurrentInstrAddr = TraceStartEndAddr.first;
    uint64_t LastTraceInstrAddr = TraceStartEndAddr.second;
    LLVM_DEBUG(llvm::dbgs()
               << llvm::formatv(
                      "\n[CodeDiscoveryPass] Processing trace [{0:x}, {1:x}]",
                      TraceStartEndAddr.first, TraceStartEndAddr.second)
               << " with " << Trace->size() << " instructions\n");

    while (CurrentInstrAddr <= LastTraceInstrAddr) {
      const TraceInstr &Inst = Trace->at(CurrentInstrAddr);
      auto MCInst = Inst.getMCInst();
      const unsigned Opcode = getPseudoOpcodeFromReal(MCInst.getOpcode());
      const llvm::MCInstrDesc &MCID = MCInstInfo.get(Opcode);
      bool IsIndirectBranch = MCID.isIndirectBranch();
      bool IsDirectBranch = MCID.isBranch() && !IsIndirectBranch;
      bool IsDirectBranchTarget =
          MFTrace.isAddressDirectBranchTarget(Inst.getLoadedDeviceAddress());
      LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Processing MCInst at "
                              << llvm::formatv("{0:x}:\n",
                                               Inst.getLoadedDeviceAddress());
                 MCInst.dump_pretty(llvm::dbgs(), IP.get(), " ", &MCContext);
                 llvm::dbgs() << llvm::formatv(
                     "\n  Opcode: {0:x}, IsBranch={1}, IsIndirectBranch={2}\n",
                     Opcode, MCID.isBranch(), IsIndirectBranch););

      if (IsDirectBranchTarget) {
        LLVM_DEBUG(llvm::dbgs()
                   << "[CodeDiscoveryPass] Instruction is a branch target\n");
        if (!CurrentMBB->empty()) {
          LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Current MBB is not "
                                     "empty, creating new MBB\n");
          llvm::MachineBasicBlock *OldMBB = CurrentMBB;
          CurrentMBB = MF.CreateMachineBasicBlock();
          MF.push_back(CurrentMBB);
          OldMBB->addSuccessor(CurrentMBB);

        } else {
          LLVM_DEBUG(
              llvm::dbgs()
              << "[CodeDiscoveryPass] Current MBB is empty, using existing\n");
        }
        BranchTargetMBBs.insert({Inst.getLoadedDeviceAddress(), CurrentMBB});
        LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                       "[CodeDiscoveryPass] New MBB created at "
                       "address {0:x}, MBB idx {1}\n",
                       Inst.getLoadedDeviceAddress(), CurrentMBB->getNumber()));
      }
      llvm::MachineInstrBuilder Builder =
          llvm::BuildMI(CurrentMBB, llvm::DebugLoc(), MCID);
      auto MDNodeOrErr = TargetMachineInstrMDNode::initializeMDNode(*Builder);
      LUTHIER_RETURN_ON_ERROR(MDNodeOrErr.takeError());
      MDNodeOrErr->setTraceInstrAddress(Ctx, CurrentInstrAddr);

      LLVM_DEBUG(
          llvm::dbgs() << llvm::formatv(
              "[CodeDiscoveryPass] Populating {0} operands for instruction\n",
              MCID.operands().size()));
      LUTHIER_RETURN_ON_ERROR(
          convertAndAddMCOperandsToMI(MCInst.getOperands(), Builder));

      LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Built instruction: ";
                 Builder->print(llvm::dbgs()); llvm::dbgs() << "\n");
      if (Inst.getLoadedDeviceAddress() ==
          MFTrace.getInitialEntryPoint().getEntryPointAddress()) {
        EntryInst = Builder.getInstr();
      }
      // Basic Block resolving; We also split blocks further down to "vector"
      // and scalar block to make it easier to deal with predication calculation
      if (MCID.isTerminator()) {
        LLVM_DEBUG(llvm::dbgs()
                   << "[CodeDiscoveryPass] Instruction is a terminator\n");
        if (IsDirectBranch) {
          LLVM_DEBUG(llvm::dbgs()
                     << "[CodeDiscoveryPass] Direct branch terminator\n");
          uint64_t BranchTarget;
          LUTHIER_RETURN_ON_ERROR(
              InstructionTracesAnalysis::evaluateDirectBranchOrCall(
                  MCInst, Inst.getLoadedDeviceAddress())
                  .moveInto(BranchTarget));
          LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                         "[CodeDiscoveryPass] Branch target resolved: {0:x}\n",
                         BranchTarget));
          if (!UnresolvedBranchMIs.contains(BranchTarget)) {
            UnresolvedBranchMIs.insert({BranchTarget, {Builder.getInstr()}});
          } else {
            UnresolvedBranchMIs[BranchTarget].push_back(Builder.getInstr());
          }
        }
        // if this is the last instruction in the trace group, no need for
        // creating a new basic block
        if (CurrentInstrAddr != LastTraceEndAddr) {
          LLVM_DEBUG(
              llvm::dbgs()
              << "[CodeDiscoveryPass] Creating new MBB after terminator\n");
          llvm::MachineBasicBlock *OldMBB = CurrentMBB;
          CurrentMBB = MF.CreateMachineBasicBlock();
          MF.push_back(CurrentMBB);
          // Don't add the next block to the list of successors if the
          // terminator is an unconditional branch
          if (!MCID.isUnconditionalBranch())
            OldMBB->addSuccessor(CurrentMBB);
          LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                         "[CodeDiscoveryPass] New MBB idx {0} created\n",
                         CurrentMBB->getNumber()));
        }
      } else if (llvm::MachineInstr *PrevMI = Builder->getPrevNode()) {
        bool IsCurrentMIVector = shouldImplicitReadExec(*Builder);
        bool IsFormerMIVector = shouldImplicitReadExec(*PrevMI);
        bool CurrentMIWritesExecMask =
            Builder->modifiesRegister(llvm::AMDGPU::EXEC, TRI);
        bool ShouldSplitCurrentMBB =
            CurrentMIWritesExecMask || IsCurrentMIVector ^ IsFormerMIVector;
        if (ShouldSplitCurrentMBB) {
          LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Splitting MBB for "
                                     "vector/scalar transition\n");
          llvm::MachineBasicBlock *OldMBB = CurrentMBB;
          CurrentMBB = OldMBB->splitAt(*PrevMI, false);
        }
      }
      /// Indirect branch and all call targets require further processing so
      /// we return them to the code discovery pass
      if (Builder->isIndirectBranch() || Builder->isCall()) {
        UnresolvedReturnInsts.push_back(Builder.getInstr());
      }

      CurrentInstrAddr += Inst.getSize();
    }
  }
  // Resolve the direct branch and target MIs/MBBs
  LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Resolving "
                          << UnresolvedBranchMIs.size()
                          << " direct branch MIs\n");
  for (auto &[TargetAddress, BranchMIs] : UnresolvedBranchMIs) {
    LLVM_DEBUG(
        llvm::dbgs() << llvm::formatv(
            "[CodeDiscoveryPass] Resolving {0} branches to target {1:x}\n",
            BranchMIs.size(), TargetAddress));
    CurrentMBB = BranchTargetMBBs[TargetAddress];
    LUTHIER_RETURN_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        CurrentMBB != nullptr,
        llvm::formatv("Failed to find the MachineBasicBlock associated with "
                      "the branch target address {0:x}.",
                      TargetAddress)));
    for (auto &MI : BranchMIs) {
      LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Resolving branch: ";
                 MI->print(llvm::dbgs()); llvm::dbgs() << "\n");
      MI->addOperand(llvm::MachineOperand::CreateMBB(CurrentMBB));
      MI->getParent()->addSuccessor(CurrentMBB);
      LLVM_DEBUG(llvm::dbgs() << llvm::formatv(
                     "[CodeDiscoveryPass] MBB {0} set as branch target\n",
                     CurrentMBB->getNumber()));
    }
  }

  /// If the entry address of the trace group is not equal to the address of the
  /// first trace then add a new basic block in the beginning of the MF,
  /// put a jump to the entry instruction
  if (MFTrace.getInitialEntryPoint().getEntryPointAddress() !=
      FirstTraceStartAddr) {
    assert(EntryInst != nullptr && "the entry instruction is nullptr");
    llvm::MachineBasicBlock *EntryMBB = MF.CreateMachineBasicBlock();
    MF.push_front(EntryMBB);

    llvm::MachineInstrBuilder Builder = llvm::BuildMI(
        EntryMBB, llvm::DebugLoc(), MCInstInfo.get(llvm::AMDGPU::S_BRANCH));
    auto MDNodeOrErr = TargetMachineInstrMDNode::initializeMDNode(*Builder);
    LUTHIER_RETURN_ON_ERROR(MDNodeOrErr.takeError());
    MDNodeOrErr->setCanRelaxDirectBranch(Ctx, true);
    Builder->addOperand(
        llvm::MachineOperand::CreateMBB(EntryInst->getParent()));
    EntryMBB->addSuccessor(EntryInst->getParent());
  }

  /// Freeze the set of reserved register because we will not do any register
  /// allocations here
  MF.getRegInfo().freezeReservedRegs();

  /// Populate the properties of MF
  llvm::MachineFunctionProperties &Properties = MF.getProperties();
  Properties.set(llvm::MachineFunctionProperties::Property::NoVRegs);
  Properties.reset(llvm::MachineFunctionProperties::Property::IsSSA);
  Properties.set(llvm::MachineFunctionProperties::Property::NoPHIs);
  Properties.reset(llvm::MachineFunctionProperties::Property::TracksLiveness);
  Properties.set(llvm::MachineFunctionProperties::Property::Selected);

  LLVM_DEBUG(llvm::dbgs() << "\n[CodeDiscoveryPass] Machine function '"
                          << MF.getName() << "' created with " << MF.size()
                          << " MBBs\n";);

  return llvm::Error::success();
}

llvm::PreservedAnalyses
CodeDiscoveryPass::run(llvm::Module &TargetModule,
                       llvm::ModuleAnalysisManager &TargetMAM) {
  llvm::LLVMContext &Ctx = TargetModule.getContext();

  LLVM_DEBUG(
      llvm::dbgs() << "[CodeDiscoveryPass] Running code discovery pass\n";);

  llvm::MachineModuleInfo &TargetMMI =
      TargetMAM.getResult<llvm::MachineModuleAnalysis>(TargetModule).getMMI();
  auto &TM =
      *reinterpret_cast<const llvm::GCNTargetMachine *>(&TargetMMI.getTarget());

  const MemoryAllocationAccessor &SegAccessor =
      TargetMAM.getResult<MemoryAllocationAnalysis>(TargetModule).getAccessor();

  llvm::MachineFunctionAnalysisManager &MFAM =
      TargetMAM
          .getResult<llvm::MachineFunctionAnalysisManagerModuleProxy>(
              TargetModule)
          .getManager();
  llvm::FunctionAnalysisManager &FAM =
      TargetMAM
          .getResult<llvm::FunctionAnalysisManagerModuleProxy>(TargetModule)
          .getManager();

  EntryPoint InitialEntryPoint =
      TargetMAM.getResult<InitialEntryPointAnalysis>(TargetModule)
          .getInitialEntryPoint();

  const llvm::amdhsa::kernel_descriptor_t &InitialExecutionPoint =
      TargetMAM.getResult<InitialExecutionPointAnalysis>(TargetModule)
          .getInitialExecutionPoint();

  auto InitialExecPointMFAndSymbol = initKernelEntryPointFunction(
      InitialExecutionPoint, SegAccessor, TargetModule, TM, FAM);
  LUTHIER_CTX_EMIT_ON_ERROR(Ctx, InitialExecPointMFAndSymbol.takeError());

  InitialExecPointMFAndSymbol->first.getFunction().addFnAttr(
      InitialEntryPointAttr);

  llvm::SmallDenseSet<EntryPoint> UnvisitedPointsOfEntry{InitialEntryPoint};

  llvm::SmallDenseSet<EntryPoint> VisitedPointsOfEntry{};

  while (!UnvisitedPointsOfEntry.empty()) {
    EntryPoint CurrentEntryPoint = *UnvisitedPointsOfEntry.begin();
    if (VisitedPointsOfEntry.contains(CurrentEntryPoint))
      continue;

    LLVM_DEBUG(llvm::dbgs()
               << "\n[CodeDiscoveryPass] Processing entry point at address "
               << llvm::formatv("{0:x}\n",
                                CurrentEntryPoint.getEntryPointAddress()));

    const auto *KDOnDevice = CurrentEntryPoint.getKernelDescriptor();
    auto [MF, FuncSymRef] =
        [&]() -> std::pair<llvm::MachineFunction &,
                           std::optional<object::AMDGCNElfSymbolRef>> {
      /// Initialize the function handle associated with the entry point
      if (KDOnDevice) {
        return *InitialExecPointMFAndSymbol;
      } else {
        auto MFOrAndSymOrErr = initLiftedDeviceFunctionEntry(
            CurrentEntryPoint.getEntryPointAddress(), SegAccessor, TargetModule,
            InitialExecPointMFAndSymbol->first.getFunction(), FAM);
        LUTHIER_CTX_EMIT_ON_ERROR(Ctx, MFOrAndSymOrErr.takeError());
        return *MFOrAndSymOrErr;
      }
    }();
    /// Set the function's entry point as an attribute
    setFunctionEntryPoint(MF.getFunction(), CurrentEntryPoint);
    if (CurrentEntryPoint == InitialEntryPoint) {
      MF.getFunction().addFnAttr(InitialEntryPointAttr);
    }

    /// Add the newly created MF's entry point
    /// Ask for the trace of the instructions for this machine function
    auto &TraceResults = MFAM.getResult<InstructionTracesAnalysis>(MF);
    if (!TraceResults.getTraces()) {
      LUTHIER_CTX_EMIT_ON_ERROR(
          Ctx,
          LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
              "Failed to get trace results for function {0}", MF.getName())));
    }
    llvm::SmallVector<llvm::MachineInstr *> UnresolvedTraceTermInstructions{};
    /// Populate the current machine function using the trace info we just
    /// obtained
    LUTHIER_CTX_EMIT_ON_ERROR(Ctx, populateMF(*TraceResults.getTraces(), MF,
                                              UnresolvedTraceTermInstructions));

    /// Invalidate all module-level analysis not related to Functions and
    /// Machine Functions proxies because we just added a new machine function
    /// and they are now stale
    llvm::PreservedAnalyses PA = llvm::PreservedAnalyses::none();
    PA.preserve<llvm::MachineFunctionAnalysisManagerModuleProxy>();
    PA.preserve<llvm::FunctionAnalysisManagerModuleProxy>();
    TargetMAM.invalidate(TargetModule, PA);

    llvm::SmallDenseSet<llvm::MachineInstr *> UnresolvedShortCallInsts{};

    /// TODO: IR translation and indirect branch/call analysis goes here
    llvm::Error Err = llvm::Error::success();
    MIRToIRTranslator Translator{MF, Err};

    LUTHIER_CTX_EMIT_ON_ERROR(Ctx, Err);

    Translator.translate();

    for (llvm::Instruction &I :
         llvm::make_early_inc_range(llvm::instructions(MF.getFunction()))) {
      if (auto *IntrinsicCall = llvm::dyn_cast<llvm::IntrinsicInst>(&I);
          IntrinsicCall &&
          IntrinsicCall->getIntrinsicID() == llvm::Intrinsic::amdgcn_s_getpc) {
        if (llvm::MDNode *PCSections =
                IntrinsicCall->getMetadata(llvm::LLVMContext::MD_pcsections)) {
          std::optional<uint64_t> InstAddr =
              llvm::cast<TargetMachineInstrMDNode>(PCSections)
                  ->getTraceInstrAddress();
          if (InstAddr.has_value()) {
            auto *GetPCResult = llvm::ConstantInt::get(
                llvm::IntegerType::getInt64Ty(Ctx), *InstAddr + 4, false);
            I.replaceAllUsesWith(GetPCResult);
            I.eraseFromParent();
          }
        }
      }
    }

    llvm::InstCombinePass{}.run(MF.getFunction(), FAM);

    llvm::TargetLibraryInfoImpl TLII(llvm::Triple(TM.getTargetTriple()));
    llvm::TargetLibraryInfo TLI(TLII, &MF.getFunction());
    for (llvm::Instruction &I :
         llvm::make_early_inc_range(llvm::instructions(MF.getFunction()))) {
      auto *CallInst = llvm::dyn_cast<llvm::CallInst>(&I);
      if (!CallInst)
        continue;
      llvm::Value *Callee = CallInst->getCalledOperand();
      if (llvm::isa<llvm::Function>(Callee) ||
          llvm::isa<llvm::InlineAsm>(Callee))
        continue;
      llvm::SmallSetVector<uint64_t, 8> Targets;
      llvm::SmallPtrSet<llvm::Value *, 16> Visited;
      bool Complete =
          collectConstantTargets(Callee, /*LaneIdx=*/-1, Targets, Visited);
      for (uint64_t Addr : Targets) {
        llvm::outs() << "indirect target: 0x" << llvm::utohexstr(Addr) << " in "
                     << MF.getFunction().getName()
                     << (Complete ? "" : " (incomplete)") << "\n";
        UnvisitedPointsOfEntry.insert(EntryPoint{Addr});
      }
    }

    /// Go over all unresolved trace terminator instructions and process
    /// them accordingly
    LLVM_DEBUG(llvm::dbgs() << "[CodeDiscoveryPass] Processing "
                            << UnresolvedTraceTermInstructions.size()
                            << " unresolved trace terminators\n");
    for (llvm::MachineInstr *TraceTermMI : UnresolvedTraceTermInstructions) {
      /// If a terminator is a call, then it is likely that the instruction
      /// after the call is reachable. Add it to the list of unvisited entry
      /// points
      if (TraceTermMI->isCall()) {
        TargetMachineInstrMDNode *TraceTermMD =
            TargetMachineInstrMDNode::getInstrMDNodeIfExists(*TraceTermMI);
        assert(TraceTermMD &&
               "The terminator instruction's MD has not been initialized");
        std::optional<uint64_t> TraceTermAddr =
            TraceTermMD->getTraceInstrAddress();
        assert(TraceTermAddr.has_value() &&
               "The terminator instruction doesn't have an address");
        UnvisitedPointsOfEntry.insert(EntryPoint{*TraceTermAddr + 4});

        if (TraceTermMI->getOpcode() == llvm::AMDGPU::S_CALL_B64) {
          uint64_t CallTarget =
              InstructionTracesAnalysis::evaluateDirectBranchOrCall(
                  TraceTermMI->getOperand(1).getImm(), *TraceTermAddr);
          UnvisitedPointsOfEntry.insert(EntryPoint{CallTarget});
          UnresolvedShortCallInsts.insert(TraceTermMI);
          LLVM_DEBUG(llvm::dbgs()
                     << "[CodeDiscoveryPass] Direct call found, target: "
                     << llvm::formatv("{0:x}\n", CallTarget));
        } else {
          LLVM_DEBUG(
              llvm::dbgs()
              << "[CodeDiscoveryPass] Call instruction target not recovered\n");
          TargetModule.addModuleFlag(llvm::Module::Warning,
                                     "luthier.cg.not_recovered", false);
        }
      } else if (TraceTermMI->isIndirectBranch()) {
        LLVM_DEBUG(
            llvm::dbgs()
            << "[CodeDiscoveryPass] Indirect branch target not recovered\n");
        TargetModule.addModuleFlag(llvm::Module::Warning,
                                   "luthier.cg.not_recovered", false);
      }
    }

    UnvisitedPointsOfEntry.erase(CurrentEntryPoint);
    VisitedPointsOfEntry.insert(CurrentEntryPoint);
  }

  llvm::PreservedAnalyses PA = llvm::PreservedAnalyses::none();
  PA.preserve<llvm::MachineFunctionAnalysisManagerModuleProxy>();
  PA.preserve<llvm::FunctionAnalysisManagerModuleProxy>();
  PA.preserve<llvm::MachineFunctionAnalysis>();
  return PA;
}
} // namespace luthier