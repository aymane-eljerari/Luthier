//===-- OpcodeHistogram.hip - Opcode Histogram Example ----------*- C++ -*-===//
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
/// Opcode histogram tool migrated to the per-tool \c HSATool singleton
/// design. Inserts per-opcode counter increments and accumulates a global
/// histogram across all instrumented dispatches.
//===----------------------------------------------------------------------===//
#include <SIInstrInfo.h>
#include <chrono>
#include <hip/hip_runtime.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/CodeGen/TargetInstrInfo.h>
#include <llvm/Demangle/Demangle.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/FormatVariadic.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/PrettyStackTrace.h>
#include <llvm/Support/SmallVectorMemoryBuffer.h>
#include <llvm/Support/raw_ostream.h>
#include <luthier/Common/ErrorCheck.h>
#include <luthier/HSA/AqlPacket.h>
#include <luthier/HSA/HsaError.h>
#include <luthier/HSATooling/HSATool.h>
#include <luthier/HSATooling/HsaMemoryAllocationAccessor.h>
#include <luthier/Intrinsic/Intrinsics.h>
#include <luthier/LLVM/CodeGenHelpers.h>
#include <luthier/LLVM/streams.h>
#include <luthier/Rocprofiler/ApiTableSnapshot.h>
#include <luthier/ToolCodeGen/CodeDiscoveryPass.h>
#include <luthier/ToolCodeGen/EntryPoint.h>
#include <luthier/ToolCodeGen/FunctionAnnotations.h>
#include <luthier/ToolCodeGen/InitialEntryPointAnalysis.h>
#include <luthier/ToolCodeGen/InitialExecutionPointAnalysis.h>
#include <luthier/ToolCodeGen/InstrumentationPMDriver.h>
#include <luthier/ToolCodeGen/InstrumentationPass.h>
#include <luthier/ToolCodeGen/IPPredicatedCFG.h>
#include <luthier/ToolCodeGen/LuthierCallGraph.h>
#include <luthier/ToolCodeGen/MemoryAllocationAccessor.h>
#include <luthier/ToolCodeGen/MetadataParserAnalysis.h>
#include <luthier/ToolCodeGen/NewPMAsmPrinter.h>
#include <luthier/ToolCodeGen/PrePostAmbleEmitter.h>
#include <memory>
#include <mutex>

#undef DEBUG_TYPE
#define DEBUG_TYPE "luthier-opcode-hist-tool"

struct OpcodeHistogramTool
    : public luthier::HSATool<OpcodeHistogramTool, llvm::MachineFunction> {
  using HSATool::HSATool;

  /// Per-opcode kernel-execution counter (one slot per AMDGPU opcode).
  __attribute__((device)) static uint64_t
      KernelHistogram[llvm::AMDGPU::INSTRUCTION_LIST_END];

  LUTHIER_HOOK_MEMBER_ATTR static void
  countOpcodeHistogramVector(bool CountWaveFrontLevel, int OpcodeNumber);

  LUTHIER_HOOK_MEMBER_ATTR static void countOpcodeHistogramScalar(int OpcodeNumber);

  struct Options {
    llvm::cl::OptionCategory Cat{"Opcode Histogram Tool Options"};
    llvm::cl::opt<unsigned> InstrBeginInterval{
        "instr-begin-interval", llvm::cl::desc("Begin interval, inclusive"),
        llvm::cl::init(0), llvm::cl::NotHidden, llvm::cl::cat(Cat)};
    llvm::cl::opt<unsigned> InstrEndInterval{
        "instr-end-interval", llvm::cl::desc("End interval, exclusive"),
        llvm::cl::init(std::numeric_limits<unsigned>::max()),
        llvm::cl::NotHidden, llvm::cl::cat(Cat)};
    llvm::cl::opt<unsigned> KernelBeginInterval{
        "kernel-start-interval", llvm::cl::desc("Kernel begin, inclusive"),
        llvm::cl::init(0), llvm::cl::NotHidden, llvm::cl::cat(Cat)};
    llvm::cl::opt<unsigned> KernelEndInterval{
        "kernel-end-interval", llvm::cl::desc("Kernel end, exclusive"),
        llvm::cl::init(std::numeric_limits<unsigned>::max()),
        llvm::cl::NotHidden, llvm::cl::cat(Cat)};
    llvm::cl::opt<bool> CountWavefrontLevel{
        "count-wavefront-level",
        llvm::cl::desc("Count instructions at wavefront level"),
        llvm::cl::init(false), llvm::cl::NotHidden, llvm::cl::cat(Cat)};
    llvm::cl::opt<bool> DemangleKernelNames{
        "demangle-kernel-names",
        llvm::cl::desc("Demangle kernel names before printing"),
        llvm::cl::init(true), llvm::cl::NotHidden, llvm::cl::cat(Cat)};
    luthier::InstrumentationPMDriverOptions DriverOpts;
    luthier::CodeDiscoveryPassOptions DiscoveryOpts;
  } Opts;

  std::recursive_mutex Mutex;
  uint32_t NumKernelLaunched = 0;
  uint64_t TotalNumInstructions = 0;
  llvm::StringMap<uint64_t> GlobalHistogram;
  std::vector<uint64_t> KernelHistogramHostBuffer{
      std::vector<uint64_t>(llvm::AMDGPU::INSTRUCTION_LIST_END, 0)};
  unsigned NextInstrIdx = 0;

  void onPackets(const hsa_queue_t &Queue, uint64_t PacketIdx,
                 llvm::ArrayRef<luthier::hsa::AqlPacket> Packets,
                 hsa_amd_queue_intercept_packet_writer PacketWriter);

  luthier::InstrumentationPreservedAnalyses
  runInstrumentationPass(llvm::Module &IModule, llvm::ModuleAnalysisManager &,
                         llvm::MachineFunction &MF,
                         llvm::FunctionAnalysisManager &);
};

__attribute__((device)) uint64_t
    OpcodeHistogramTool::KernelHistogram[llvm::AMDGPU::INSTRUCTION_LIST_END];

LUTHIER_HOOK_MEMBER_ATTR void OpcodeHistogramTool::countOpcodeHistogramVector(
    bool CountWaveFrontLevel, int OpcodeNumber) {
  unsigned long long int ExecMask = __builtin_amdgcn_read_exec();
  const uint32_t LaneId = __lane_id() + 1;
  uint32_t FirstActiveThreadId = __ffsll(ExecMask);
  uint32_t NumActiveThreads = __popcll(ExecMask);
  if (FirstActiveThreadId == LaneId) {
    if (CountWaveFrontLevel) {
      if (NumActiveThreads > 0)
        atomicAdd(&OpcodeHistogramTool::KernelHistogram[OpcodeNumber], 1);
    } else {
      atomicAdd(&OpcodeHistogramTool::KernelHistogram[OpcodeNumber],
                NumActiveThreads);
    }
  }
}

LUTHIER_HOOK_MEMBER_ATTR void
OpcodeHistogramTool::countOpcodeHistogramScalar(int OpcodeNumber) {
  luthier::sAtomicAdd(&OpcodeHistogramTool::KernelHistogram[OpcodeNumber], 1UL);
}

static luthier::rocprofiler::HsaApiTableSnapshot<::CoreApiTable>
    *CoreApiSnapshot{nullptr};
static luthier::rocprofiler::HsaApiTableSnapshot<::AmdExtTable>
    *AmdExtSnapshot{nullptr};
static luthier::rocprofiler::HsaExtensionTableSnapshot<HSA_EXTENSION_AMD_LOADER>
    *LoaderSnapshot{nullptr};

static llvm::Expected<std::unique_ptr<llvm::MemoryBuffer>>
runInstrumentationPipelineForDispatch(
    OpcodeHistogramTool &T, const hsa_kernel_dispatch_packet_t &Packet) {
  T.NextInstrIdx = 0;

  llvm::LLVMContext Ctx;
  auto M = std::make_unique<llvm::Module>("luthier.target", Ctx);
  M->setTargetTriple(llvm::Triple("amdgcn-amd-amdhsa"));

  // C++ destroys these in reverse order, and MAM caches a
  // `FunctionAnalysisManagerModuleProxy::Result` whose destructor calls
  // `FAM->clear()`. So MAM must die before FAM — declare MAM LAST.
  llvm::LoopAnalysisManager LAM;
  llvm::FunctionAnalysisManager FAM;
  llvm::CGSCCAnalysisManager CGAM;
  llvm::ModuleAnalysisManager MAM;
  llvm::PassBuilder PB;
  PB.registerModuleAnalyses(MAM);
  PB.registerFunctionAnalyses(FAM);
  PB.registerLoopAnalyses(LAM);
  PB.registerCGSCCAnalyses(CGAM);
  PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);

  const auto &KD = *reinterpret_cast<const llvm::amdhsa::kernel_descriptor_t *>(
      Packet.kernel_object);

  MAM.registerPass([&] {
    return luthier::InitialEntryPointAnalysis(
        [&](llvm::Module &, llvm::ModuleAnalysisManager &) {
          return luthier::EntryPoint(KD);
        });
  });
  MAM.registerPass([&] {
    return luthier::InitialExecutionPointAnalysis(
        [&](llvm::Module &, llvm::ModuleAnalysisManager &)
            -> const llvm::amdhsa::kernel_descriptor_t & { return KD; });
  });
  MAM.registerPass([&] {
    return luthier::MemoryAllocationAnalysis(
        std::make_unique<luthier::HsaMemoryAllocationAccessor>(
            T, *::CoreApiSnapshot, *::AmdExtSnapshot,
            ::LoaderSnapshot->getTable()));
  });
  luthier::amdgpu::hsamd::MetadataParser MetadataParserInstance;
  MAM.registerPass([&] {
    return luthier::MetadataParserAnalysis(MetadataParserInstance);
  });
  MAM.registerPass([] { return luthier::LuthierCallGraphAnalysis(); });
  MAM.registerPass(
      [] { return luthier::FunctionPreambleDescriptorAnalysis(); });
  MAM.registerPass([] { return luthier::IPPredCFGAnalysis(); });

  llvm::SmallVector<char, 0> ObjBuf;
  llvm::raw_svector_ostream ObjOS(ObjBuf);

  llvm::ModulePassManager MPM;
  MPM.addPass(luthier::CodeDiscoveryPass(T.Opts.DiscoveryOpts));
  MPM.addPass(T.buildPipeline(T.Opts.DriverOpts));
  MPM.addPass(
      luthier::NewPMAsmPrinter(llvm::CodeGenFileType::ObjectFile, ObjOS));
  MPM.run(*M, MAM);

  return std::make_unique<llvm::SmallVectorMemoryBuffer>(
      std::move(ObjBuf), "luthier.instrumented",
      /*RequiresNullTerminator=*/false);
}

luthier::InstrumentationPreservedAnalyses
OpcodeHistogramTool::runInstrumentationPass(llvm::Module &IModule,
                                            llvm::ModuleAnalysisManager &,
                                            llvm::MachineFunction &MF,
                                            llvm::FunctionAnalysisManager &) {
  for (auto &MBB : MF) {
    for (auto &MI : MBB) {
      unsigned I = NextInstrIdx++;
      if (I < Opts.InstrBeginInterval || I >= Opts.InstrEndInterval)
        continue;
      auto *OpcodeNumber = llvm::ConstantInt::get(
          llvm::Type::getInt32Ty(IModule.getContext()), MI.getOpcode(), false);
      const void *HostHandle = nullptr;
      llvm::SmallVector<InjectedPayloadCreationPass::PayloadArg, 2> Args;
      if (luthier::isScalar(MI) || luthier::isLaneAccess(MI)) {
        HostHandle = reinterpret_cast<const void *>(
            &OpcodeHistogramTool::countOpcodeHistogramScalar);
        Args.push_back(OpcodeNumber);
      } else {
        HostHandle = reinterpret_cast<const void *>(
            &OpcodeHistogramTool::countOpcodeHistogramVector);
        Args.push_back(llvm::ConstantInt::getBool(IModule.getContext(),
                                                  Opts.CountWavefrontLevel));
        Args.push_back(OpcodeNumber);
      }
      LUTHIER_REPORT_FATAL_ON_ERROR(
          this->createInjectedPayload(HostHandle, IModule, MI, Args));
    }
  }
  return luthier::InstrumentationPreservedAnalyses{};
}

void OpcodeHistogramTool::onPackets(
    const hsa_queue_t &, uint64_t,
    llvm::ArrayRef<luthier::hsa::AqlPacket> Packets,
    hsa_amd_queue_intercept_packet_writer PacketWriter) {
  std::vector<luthier::hsa::AqlPacket> AppPackets(Packets.begin(),
                                                  Packets.end());
  for (auto &Packet : AppPackets) {
    auto *DispatchPacket = Packet.asKernelDispatch();
    if (!DispatchPacket) {
      PacketWriter(&Packet, 1);
      continue;
    }
    std::lock_guard<std::recursive_mutex> Lock(Mutex);
    const auto Core = ::CoreApiSnapshot->getTable();
    const auto AmdExt = ::AmdExtSnapshot->getTable();

    const bool ActiveRegion = NumKernelLaunched >= Opts.KernelBeginInterval &&
                              NumKernelLaunched < Opts.KernelEndInterval;
    bool MustDestroySignalAfterLaunch = false;
    if (DispatchPacket->completion_signal.handle == 0) {
      LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
          AmdExt.callFunction<&::AmdExtTable::hsa_amd_signal_create_fn>(
              0, 0, nullptr, 0, &DispatchPacket->completion_signal),
          "Failed to create a signal for the dispatch packet."));
      MustDestroySignalAfterLaunch = true;
    }
    const hsa_signal_value_t SignalValue =
        Core.callFunction<&::CoreApiTable::hsa_signal_load_scacquire_fn>(
            DispatchPacket->completion_signal);

    if (ActiveRegion) {
      luthier::errs() << "Kernel is being instrumented.\n";
      const auto *KD =
          reinterpret_cast<const llvm::amdhsa::kernel_descriptor_t *>(
              DispatchPacket->kernel_object);
      if (auto MissErr = this->overrideWithInstrumented(*DispatchPacket, 0)) {
        llvm::consumeError(std::move(MissErr));
        std::unique_ptr<llvm::MemoryBuffer> ObjBuf;
        LUTHIER_REPORT_FATAL_ON_ERROR(
            runInstrumentationPipelineForDispatch(*this, *DispatchPacket)
                .moveInto(ObjBuf));
        LUTHIER_REPORT_FATAL_ON_ERROR(
            this->loadInstrumented(std::move(ObjBuf), KD, 0).takeError());
        LUTHIER_REPORT_FATAL_ON_ERROR(
            this->overrideWithInstrumented(*DispatchPacket, 0));
      }
      std::fill(KernelHistogramHostBuffer.begin(),
                KernelHistogramHostBuffer.end(), 0);
    }

    constexpr auto Timeout =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::seconds{300})
            .count();
    PacketWriter(DispatchPacket, 1);
    const hsa_signal_value_t Current =
        Core.callFunction<&::CoreApiTable::hsa_signal_wait_relaxed_fn>(
            DispatchPacket->completion_signal, HSA_SIGNAL_CONDITION_LT,
            SignalValue, Timeout, HSA_WAIT_STATE_ACTIVE);
    if (Current >= SignalValue)
      llvm::report_fatal_error(llvm::formatv(
          "Wait timeout for signal {0:x}",
          DispatchPacket->completion_signal.handle));
    if (MustDestroySignalAfterLaunch) {
      LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_HSA_CALL_ERROR_CHECK(
          Core.callFunction<&::CoreApiTable::hsa_signal_destroy_fn>(
              DispatchPacket->completion_signal),
          "Failed to destroy the dispatch packet's completion signal."));
    }
    NumKernelLaunched++;
  }
}

namespace luthier {

static void atToolFini(void *) {
  static std::once_flag Once{};
  std::call_once(Once, []() {
    OpcodeHistogramTool::withInstance([](OpcodeHistogramTool &T) {
      luthier::errs() << "Instruction Opcode Results: \n";
      for (const auto &[OpcodeName, Count] : T.GlobalHistogram)
        luthier::errs() << llvm::formatv("  {0} = {1}\n", OpcodeName, Count);
      luthier::errs() << "Total number of instructions counted: "
                      << T.TotalNumInstructions << "\n";
    });
    OpcodeHistogramTool::destroyInstance();
    delete LoaderSnapshot;
    LoaderSnapshot = nullptr;
    delete AmdExtSnapshot;
    AmdExtSnapshot = nullptr;
    delete CoreApiSnapshot;
    CoreApiSnapshot = nullptr;
  });
}

static void atToolFini() { atToolFini(nullptr); }

static void atToolInit(void *) {
  static std::once_flag Once{};
  std::call_once(Once, [] {
    luthier::errs() << "Opcode Histogram tool is launching.\n";
    std::atexit(atToolFini);

    llvm::Error Err = llvm::Error::success();
    CoreApiSnapshot =
        new luthier::rocprofiler::HsaApiTableSnapshot<::CoreApiTable>(Err);
    if (Err)
      llvm::report_fatal_error(std::move(Err));
    AmdExtSnapshot =
        new luthier::rocprofiler::HsaApiTableSnapshot<::AmdExtTable>(Err);
    if (Err)
      llvm::report_fatal_error(std::move(Err));
    LoaderSnapshot = new luthier::rocprofiler::HsaExtensionTableSnapshot<
        HSA_EXTENSION_AMD_LOADER>(Err);
    if (Err)
      llvm::report_fatal_error(std::move(Err));

    OpcodeHistogramTool::createInstance(*CoreApiSnapshot, *AmdExtSnapshot,
                                        *LoaderSnapshot, Err);
    if (Err)
      llvm::report_fatal_error(std::move(Err));

    const auto Argv = "";
    LUTHIER_REPORT_FATAL_ON_ERROR(LUTHIER_GENERIC_ERROR_CHECK(
        llvm::cl::ParseCommandLineOptions(0, &Argv,
                                          "Luthier Opcode Histogram Tool",
                                          &luthier::errs(), nullptr,
                                          "LUTHIER_ARGS"),
        "Failed to parse the command line arguments."));
    llvm::EnablePrettyStackTrace();
    llvm::sys::PrintStackTraceOnErrorSignal(llvm::StringRef());
    llvm::setBugReportMsg("PLEASE submit a bug report to "
                          "https://github.com/matinraayai/Luthier/issues/ and "
                          "include the crash error message and backtrace.\n");
    llvm::sys::AddSignalHandler(atToolFini, nullptr);
  });
}

} // namespace luthier

extern "C" __attribute__((used)) rocprofiler_tool_configure_result_t *
rocprofiler_configure(uint32_t Version, const char *RuntimeVersion,
                      uint32_t Priority, rocprofiler_client_id_t *ClientID) {
  luthier::atToolInit(nullptr);

  LLVM_DEBUG(const uint32_t RocProfVerMajor = Version / 10000;
             const uint32_t RocProfVerMinor = (Version % 10000) / 100;
             const uint32_t RocProfVerPatch = Version % 100;
             llvm::dbgs() << "Registering Luthier tool with rocprofiler-sdk.\n";
             llvm::dbgs() << "Rocprofiler-sdk version: " << RocProfVerMajor
                          << "." << RocProfVerMinor << "." << RocProfVerPatch
                          << " (" << RuntimeVersion << ")\n";
             llvm::dbgs() << "Tool priority: " << Priority << ";\n";);
  ClientID->name = "Luthier Opcode Histogram tool";

  static auto Cfg = rocprofiler_tool_configure_result_t{
      sizeof(rocprofiler_tool_configure_result_t), nullptr,
      &luthier::atToolFini, nullptr};
  return &Cfg;
}
