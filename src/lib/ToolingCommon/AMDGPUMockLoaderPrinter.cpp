//===-- AMDGPUMockLoaderPrinter.cpp ---------------------------------------===//
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
/// \file MockLoadAMDGPUCodeObjects.cpp
/// Implements the \c MockLoadAMDGPUCodeObjects class.
//===----------------------------------------------------------------------===//
#include "luthier/Tooling/AMDGPUMockLoaderPrinter.h"
#include "luthier/Object/ObjectFileUtils.h"
#include "luthier/Tooling/MockAMDGPULoader.h"
#include <llvm/BinaryFormat/ELF.h>
#include <llvm/IR/Module.h>
#include <llvm/MC/MCAsmInfo.h>
#include <llvm/MC/MCContext.h>
#include <llvm/MC/MCDisassembler/MCDisassembler.h>
#include <llvm/MC/MCInstPrinter.h>
#include <llvm/MC/MCInstrAnalysis.h>
#include <llvm/MC/MCInstrInfo.h>
#include <llvm/MC/MCRegisterInfo.h>
#include <llvm/MC/MCTargetOptions.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Support/TargetSelect.h>

namespace luthier {

static void printELFType(const llvm::object::ELF64LE::Phdr &Phdr,
                         llvm::raw_ostream &OS) {
  switch (Phdr.p_type) {
  case llvm::ELF::PT_DYNAMIC:
    OS << "DYNAMIC";
    break;
  case llvm::ELF::PT_GNU_EH_FRAME:
    OS << "EH_FRAME";
    break;
  case llvm::ELF::PT_GNU_RELRO:
    OS << "RELRO";
    break;
  case llvm::ELF::PT_GNU_PROPERTY:
    OS << "PROPERTY";
    break;
  case llvm::ELF::PT_GNU_STACK:
    OS << "STACK";
    break;
  case llvm::ELF::PT_GNU_SFRAME:
    OS << "SFRAME";
    break;
  case llvm::ELF::PT_INTERP:
    OS << "INTERP";
    break;
  case llvm::ELF::PT_LOAD:
    OS << "LOAD";
    break;
  case llvm::ELF::PT_NOTE:
    OS << "NOTE";
    break;
  case llvm::ELF::PT_OPENBSD_BOOTDATA:
    OS << "OPENBSD_BOOTDATA";
    break;
  case llvm::ELF::PT_OPENBSD_MUTABLE:
    OS << "OPENBSD_MUTABLE";
    break;
  case llvm::ELF::PT_OPENBSD_NOBTCFI:
    OS << "OPENBSD_NOBTCFI";
    break;
  case llvm::ELF::PT_OPENBSD_RANDOMIZE:
    OS << "OPENBSD_RANDOMIZE";
    break;
  case llvm::ELF::PT_OPENBSD_SYSCALLS:
    OS << "OPENBSD_SYSCALLS";
    break;
  case llvm::ELF::PT_OPENBSD_WXNEEDED:
    OS << "OPENBSD_WXNEEDED";
    break;
  case llvm::ELF::PT_PHDR:
    OS << "PHDR";
    break;
  case llvm::ELF::PT_TLS:
    OS << "TLS";
    break;
  default:
    OS << "UNKNOWN";
  }
}

AMDGPUMockLoaderPrinter::AMDGPUMockLoaderPrinter(llvm::raw_ostream &OS)
    : OS(OS) {
  /// Need to initialize the
  LLVMInitializeAMDGPUDisassembler();
}

llvm::PreservedAnalyses
AMDGPUMockLoaderPrinter::run(llvm::Module &M,
                             llvm::ModuleAnalysisManager &MAM) {
  llvm::LLVMContext &Ctx = M.getContext();
  /// Get the mock loader analysis
  MockAMDGPULoader &Loader =
      MAM.getResult<MockAMDGPULoaderAnalysis>(M).getLoader();

  unsigned CodeObjectIdx = 0;

  OS << "Num Code Objects: " << Loader.loaded_code_objects_size() << "\n";
  OS << "Loaded Code Object Contents:\n";

  for (const auto &LCO : Loader.loaded_code_objects()) {
    auto TargetTripleOrErr =
        object::getObjectFileTargetTuple(LCO.getCodeObject());

    LUTHIER_CTX_EMIT_ON_ERROR(Ctx, TargetTripleOrErr.takeError());

    auto [TT, CPU, FS] = *TargetTripleOrErr;

    std::string Error;
    const llvm::Target *Target = llvm::TargetRegistry::lookupTarget(TT, Error);
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx,
        LUTHIER_GENERIC_ERROR_CHECK(
            Target, llvm::formatv("Failed to lookup target {0} in LLVM. Reason "
                                  "according to LLVM: {1}.",
                                  TT.normalize(), Error)));

    auto MRI =
        std::unique_ptr<llvm::MCRegisterInfo>(Target->createMCRegInfo(TT));
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx,
        LUTHIER_GENERIC_ERROR_CHECK(
            MRI.get(),
            llvm::formatv("Failed to create machine register info for {0}.",
                          TT.getTriple())));

    llvm::MCTargetOptions Options{};

    auto MAI = std::unique_ptr<llvm::MCAsmInfo>(
        Target->createMCAsmInfo(*MRI, TT, Options));
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx, LUTHIER_GENERIC_ERROR_CHECK(
                 MAI, llvm::formatv("Failed to create MCAsmInfo from target "
                                    "{0} for Target Triple {1}.",
                                    Target, TT.getTriple())));

    auto MII = std::unique_ptr<llvm::MCInstrInfo>(Target->createMCInstrInfo());

    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx,
        LUTHIER_GENERIC_ERROR_CHECK(
            MII, llvm::formatv("Failed to create MCInstrInfo from target {0}",
                               Target)));

    auto MIA = std::unique_ptr<llvm::MCInstrAnalysis>(
        Target->createMCInstrAnalysis(MII.get()));
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx, LUTHIER_GENERIC_ERROR_CHECK(
                 MIA, llvm::formatv(
                          "Failed to create MCInstrAnalysis for target {0}.",
                          Target)));

    auto STI = std::unique_ptr<llvm::MCSubtargetInfo>(
        Target->createMCSubtargetInfo(TT, CPU, FS.getString()));
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx, LUTHIER_GENERIC_ERROR_CHECK(
                 STI, llvm::formatv(
                          "Failed to create MCSubTargetInfo from target {0} "
                          "for triple {1}, CPU {2}, with feature string {3}",
                          Target, TT.getTriple(), CPU, FS.getString())));

    auto IP = std::unique_ptr<llvm::MCInstPrinter>(Target->createMCInstPrinter(
        TT, MAI->getAssemblerDialect(), *MAI, *MII, *MRI));
    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx, LUTHIER_GENERIC_ERROR_CHECK(
                 IP, llvm::formatv("Failed to create MCInstPrinter from Target "
                                   "{0} for Triple {1}.",
                                   Target, TT.normalize())));

    auto MCCtx =
        std::make_unique<llvm::MCContext>(TT, MAI.get(), MRI.get(), STI.get());

    auto DisAsm = std::unique_ptr<llvm::MCDisassembler>(
        Target->createMCDisassembler(*STI, *MCCtx));

    LUTHIER_CTX_EMIT_ON_ERROR(
        Ctx, LUTHIER_GENERIC_ERROR_CHECK(DisAsm.get(),
                                         "Failed to create a disassembler"));

    OS << "Code Object Index: " << CodeObjectIdx << "\n";
    OS << llvm::formatv(
        "\tLoad Base Address: {0:x}\n",
        reinterpret_cast<uint64_t>(LCO.getLoadedRegion().data()));
    OS << llvm::formatv("\tLoad size: {0:x}\n", LCO.getLoadedRegion().size());

    OS << "Loaded Segment Headers: \n";

    // auto PHeaders = LCO.getCodeObject().getELFFile().program_headers();
    // LUTHIER_CTX_EMIT_ON_ERROR(Ctx, PHeaders.takeError());
    for (const auto &[PHIdx, PH] : llvm::enumerate(LCO.getLoadSegments())) {
      if (PH->p_type == llvm::ELF::PT_LOAD) {
        OS << "PH Idx: " << PHIdx << "\n";
        constexpr auto Fmt = "0x%016" PRIx64 " ";
        OS << "\tType:";
        printELFType(*PH, OS);
        OS << "\n";
        OS << "\tOffset: "
           << llvm::format(Fmt, static_cast<uint64_t>(PH->p_offset)) << "\n";
        OS << "\tVAddr: "
           << llvm::format(Fmt, static_cast<uint64_t>(PH->p_vaddr)) << "\n";
        OS << "\tPAddr: "
           << llvm::format(Fmt, static_cast<uint64_t>(PH->p_paddr)) << "\n";
        OS << llvm::format("\talign 2**%u",
                           llvm::countr_zero<uint64_t>(PH->p_align))
           << "\n";
        OS << "\tFilesz: "
           << llvm::format(Fmt, static_cast<uint64_t>(PH->p_filesz)) << "\n";
        OS << "\tMemsz: "
           << llvm::format(Fmt, static_cast<uint64_t>(PH->p_memsz)) << "\n";
        OS << "\tFlags: " << ((PH->p_flags & llvm::ELF::PF_R) ? "r" : "-")
           << ((PH->p_flags & llvm::ELF::PF_W) ? "w" : "-")
           << ((PH->p_flags & llvm::ELF::PF_X) ? "x" : "-") << "\n";

        if ((PH->p_flags & llvm::ELF::PF_X)) {
          OS << "\tSegment disassembly:\n";
          /// Disassemble both the loaded segmet
          uint64_t SegmentCurrAddr =
              reinterpret_cast<uint64_t>(LCO.getLoadedRegion().data()) +
              PH->p_vaddr;
          uint64_t SegmentEndAddr = SegmentCurrAddr + PH->p_filesz;
          uint64_t MaxReadSize = MAI->getMaxInstLength();
          while (SegmentCurrAddr < SegmentEndAddr) {
            OS << llvm::formatv("Addr: {0:x}, Inst: ", SegmentCurrAddr);
            size_t ReadSize = (SegmentCurrAddr + MaxReadSize) < SegmentEndAddr
                                  ? MaxReadSize
                                  : SegmentEndAddr - SegmentCurrAddr;
            llvm::MCInst Inst;
            size_t InstSize{};
            llvm::ArrayRef ReadBytes = {
                reinterpret_cast<uint8_t *>(SegmentCurrAddr), ReadSize};

            LUTHIER_CTX_EMIT_ON_ERROR(
                Ctx,
                LUTHIER_GENERIC_ERROR_CHECK(
                    DisAsm->getInstruction(Inst, InstSize, ReadBytes,
                                           SegmentCurrAddr, llvm::nulls()) ==
                        llvm::MCDisassembler::Success,
                    llvm::formatv(
                        "Failed to disassemble instruction at address {0:x}",
                        SegmentCurrAddr)));
            IP->printInst(&Inst, SegmentCurrAddr, "", *STI, OS);
            OS << "\n";
            SegmentCurrAddr += InstSize;
          }

        } else {
        }
      }
    }
    CodeObjectIdx++;
  }
  return llvm::PreservedAnalyses::all();
};

} // namespace luthier