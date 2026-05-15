//===-- SVAFrameLanesTest.cpp -----------------------------------*- C++ -*-===//
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
/// \file
/// Tests the per-physreg → SVA-lane mapping helpers in SVAFrameLanes.h.
/// Covers the lookup direction we replaced the defunct stateValueArray::*
/// namespace with: SGPR0/1 + FLAT_SCR_LO/HI for the kernel-prolog spill
/// slots, and SGPR32 + FLAT_SCR_LO for the payload's app-frame slots.
//===----------------------------------------------------------------------===//
#include "luthier/ToolCodeGen/SVAFrameLanes.h"
#include "luthier/ToolCodeGen/StateValueArraySpecs.h"

#include <AMDGPU.h>
#include <AMDGPUTargetMachine.h>
#include <gtest/gtest.h>
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Type.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>

#include <memory>

using namespace luthier;

namespace {

/// Build a small AMDGPU target machine for a given GPU. Skips the test
/// gracefully when the AMDGPU backend isn't available in the test binary
/// (e.g., when LLVM was configured without AMDGPU).
class SVAFrameLanesTestFixture : public ::testing::Test {
protected:
  static void SetUpTestSuite() {
    llvm::InitializeAllTargetInfos();
    llvm::InitializeAllTargets();
    llvm::InitializeAllTargetMCs();
  }

  std::unique_ptr<llvm::TargetMachine>
  makeTM(llvm::StringRef CPU, llvm::StringRef Features = "") {
    std::string Triple = "amdgcn-amd-amdhsa";
    std::string Err;
    const llvm::Target *T = llvm::TargetRegistry::lookupTarget(Triple, Err);
    if (!T)
      return nullptr;
    llvm::TargetOptions Opts;
    return std::unique_ptr<llvm::TargetMachine>(
        T->createTargetMachine(llvm::Triple(Triple), CPU, Features, Opts,
                               std::nullopt, std::nullopt));
  }

  /// Build a non-empty Module with a single stub function tagged for \p CPU.
  /// getSVASpecs's subtarget lookup requires at least one Function.
  std::unique_ptr<llvm::Module> makeStubModule(llvm::StringRef CPU) {
    auto M = std::make_unique<llvm::Module>("test", Ctx);
    M->setTargetTriple(llvm::Triple("amdgcn-amd-amdhsa"));
    auto *FTy = llvm::FunctionType::get(llvm::Type::getVoidTy(Ctx), false);
    auto *F = llvm::Function::Create(FTy, llvm::Function::ExternalLinkage,
                                     "stub", M.get());
    F->addFnAttr("target-cpu", CPU);
    return M;
  }

  llvm::LLVMContext Ctx;
};

/// Round-trips the canonical SVA lane layout: install the IModule named MD
/// for one SA via setModuleSVASpec, read it back via getSVASpecs, then
/// verify the per-physreg lookups match the constants in
/// StateValueArraySpecs.
TEST_F(SVAFrameLanesTestFixture, KernelPrologSpillLanesMatchSpecsConstants) {
  auto TM = makeTM("gfx908");
  if (!TM)
    GTEST_SKIP() << "AMDGPU backend not registered in test binary";

  auto M = makeStubModule("gfx908");
  llvm::SmallDenseSet<ScalarValueArgument> Requested;
  Requested.insert(PRIVATE_SEGMENT_WAVE_BYTE_OFFSET);
  auto Specs = StateValueArraySpecs::setModuleSVASpec(*M, *TM, Requested);
  ASSERT_NE(Specs, nullptr);

  // SGPR0 spills to lane 0 (StackPointerRegSpillLane).
  auto Lane = getKernelPrologFrameSpillLane(llvm::AMDGPU::SGPR0, *Specs);
  ASSERT_TRUE(Lane.has_value());
  EXPECT_EQ(*Lane, Specs->getStackPointerRegSpillLane());
  EXPECT_EQ(*Lane, 0u);

  // SGPR1 spills to lane 1 (FramePointerRegSpillLane).
  Lane = getKernelPrologFrameSpillLane(llvm::AMDGPU::SGPR1, *Specs);
  ASSERT_TRUE(Lane.has_value());
  EXPECT_EQ(*Lane, Specs->getFramePointerRegSpillLane());
  EXPECT_EQ(*Lane, 1u);

  // FLAT_SCR_LO is overloaded onto StackPointerStoreLane (lane 2) — see
  // SVAFrameLanes.h layout comment for why these names collide.
  Lane = getKernelPrologFrameSpillLane(llvm::AMDGPU::FLAT_SCR_LO, *Specs);
  ASSERT_TRUE(Lane.has_value());
  EXPECT_EQ(*Lane, Specs->getStackPointerStoreLane());
  EXPECT_EQ(*Lane, 2u);

  // FLAT_SCR_HI lives at getFrameRsrcOrScratchStoreLaneIfExists() — IFF
  // the subtarget actually uses absolute FS or buffer rsrc spills. On
  // gfx908 (absolute FS + scratch-flat), this returns lane 3.
  Lane = getKernelPrologFrameSpillLane(llvm::AMDGPU::FLAT_SCR_HI, *Specs);
  if (Specs->getFrameRsrcOrScratchStoreLaneIfExists()) {
    ASSERT_TRUE(Lane.has_value());
    EXPECT_EQ(*Lane, *Specs->getFrameRsrcOrScratchStoreLaneIfExists());
  } else {
    EXPECT_FALSE(Lane.has_value());
  }

  // A non-prolog-managed physreg returns nullopt.
  EXPECT_FALSE(
      getKernelPrologFrameSpillLane(llvm::AMDGPU::SGPR32, *Specs).has_value());
}

/// Verifies that the ordered table iterates the four well-known physregs
/// in spill order.
TEST_F(SVAFrameLanesTestFixture, KernelPrologSpillSlotsOrderedByLane) {
  auto TM = makeTM("gfx908");
  if (!TM)
    GTEST_SKIP() << "AMDGPU backend not registered in test binary";

  auto M = makeStubModule("gfx908");
  llvm::SmallDenseSet<ScalarValueArgument> Requested;
  Requested.insert(PRIVATE_SEGMENT_WAVE_BYTE_OFFSET);
  auto Specs = StateValueArraySpecs::setModuleSVASpec(*M, *TM, Requested);
  ASSERT_NE(Specs, nullptr);

  auto Slots = getKernelPrologFrameSpillSlots(*Specs);
  // gfx908 has absolute FS, so all four registers participate.
  ASSERT_EQ(Slots.size(), 4u);

  // First two are always SGPR0, SGPR1 at lanes 0, 1.
  EXPECT_EQ(Slots[0].first, llvm::AMDGPU::SGPR0);
  EXPECT_EQ(Slots[0].second, 0u);
  EXPECT_EQ(Slots[1].first, llvm::AMDGPU::SGPR1);
  EXPECT_EQ(Slots[1].second, 1u);
  EXPECT_EQ(Slots[2].first, llvm::AMDGPU::FLAT_SCR_LO);
  EXPECT_EQ(Slots[3].first, llvm::AMDGPU::FLAT_SCR_HI);
}

/// The payload PEI's app-frame spill table is a 2-entry list mapping
/// SGPR32 → app-SP-spill lane, FLAT_SCR_LO → app-FP-spill lane. These are
/// at the same lanes the kernel prolog uses, which is the lane-sharing
/// invariant the layout depends on (the prolog overwrites the spilled
/// values with the per-wave-computed values that the payload reads back).
TEST_F(SVAFrameLanesTestFixture, PayloadAppFrameSpillSlotsMatchSpecsConstants) {
  auto TM = makeTM("gfx908");
  if (!TM)
    GTEST_SKIP() << "AMDGPU backend not registered in test binary";

  auto M = makeStubModule("gfx908");
  llvm::SmallDenseSet<ScalarValueArgument> Requested;
  Requested.insert(PRIVATE_SEGMENT_WAVE_BYTE_OFFSET);
  auto Specs = StateValueArraySpecs::setModuleSVASpec(*M, *TM, Requested);
  ASSERT_NE(Specs, nullptr);

  auto AppSlots = getPayloadAppFrameSpillSlots(*Specs);
  ASSERT_EQ(AppSlots.size(), 2u);
  EXPECT_EQ(AppSlots[0].first, llvm::AMDGPU::SGPR32);
  EXPECT_EQ(AppSlots[0].second, Specs->getStackPointerRegSpillLane());
  EXPECT_EQ(AppSlots[1].first, llvm::AMDGPU::FLAT_SCR_LO);
  EXPECT_EQ(AppSlots[1].second, Specs->getFramePointerRegSpillLane());
}

/// Verifies that the load-side helper returns SGPR32's lane from the
/// "store" position (StackPointerStoreLane) and FLAT_SCR_LO from the
/// scratch-store position when it exists.
TEST_F(SVAFrameLanesTestFixture, PayloadAppFrameLoadSlotsRouteToStoreLanes) {
  auto TM = makeTM("gfx908");
  if (!TM)
    GTEST_SKIP() << "AMDGPU backend not registered in test binary";

  auto M = makeStubModule("gfx908");
  llvm::SmallDenseSet<ScalarValueArgument> Requested;
  Requested.insert(PRIVATE_SEGMENT_WAVE_BYTE_OFFSET);
  auto Specs = StateValueArraySpecs::setModuleSVASpec(*M, *TM, Requested);
  ASSERT_NE(Specs, nullptr);

  auto Slots = getPayloadAppFrameLoadSlots(*Specs);
  // SGPR32 is always present; FLAT_SCR_LO depends on absolute-FS.
  ASSERT_FALSE(Slots.empty());
  EXPECT_EQ(Slots[0].first, llvm::AMDGPU::SGPR32);
  EXPECT_EQ(Slots[0].second, Specs->getStackPointerStoreLane());
  if (auto Frame = Specs->getFrameRsrcOrScratchStoreLaneIfExists()) {
    ASSERT_EQ(Slots.size(), 2u);
    EXPECT_EQ(Slots[1].first, llvm::AMDGPU::FLAT_SCR_LO);
    EXPECT_EQ(Slots[1].second, *Frame);
  }
}

/// SAs allocated by IntrinsicMIRLoweringPass land at lanes past the
/// kernel-prolog reserved region. We verify the lane returned by
/// findArgumentLane is strictly higher than 3 (the highest prolog-reserved
/// lane on a buffer-rsrc-free, FS-using subtarget like gfx908).
TEST_F(SVAFrameLanesTestFixture, SAsLandPastKernelPrologReservedRegion) {
  auto TM = makeTM("gfx908");
  if (!TM)
    GTEST_SKIP() << "AMDGPU backend not registered in test binary";

  auto M = makeStubModule("gfx908");
  llvm::SmallDenseSet<ScalarValueArgument> Requested;
  Requested.insert(PRIVATE_SEGMENT_WAVE_BYTE_OFFSET);
  auto Specs = StateValueArraySpecs::setModuleSVASpec(*M, *TM, Requested);
  ASSERT_NE(Specs, nullptr);

  auto It = Specs->findArgumentLane(PRIVATE_SEGMENT_WAVE_BYTE_OFFSET);
  ASSERT_NE(It, Specs->argument_lane_end());
  // Reserved region is lanes 0-3 on this configuration; SAs must not
  // collide.
  EXPECT_GE(It->second, 4u);
}

} // namespace
