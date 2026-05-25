//===-- SubtargetMarkerPass.cpp -------------------------------------------===//
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
/// \file SubtargetMarkerPass.cpp
/// Implementation of \c luthier::SubtargetMarkerPass.
//===----------------------------------------------------------------------===//
#include "luthier/ToolIRCompilation/SubtargetMarkerPass.h"
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/StringExtras.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/DataLayout.h>
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/GlobalValue.h>
#include <llvm/IR/GlobalVariable.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/ErrorHandling.h>
#include <llvm/TargetParser/Triple.h>
#include <llvm/Transforms/Utils/ModuleUtils.h>

namespace luthier {

namespace {

constexpr unsigned Wave64Bit = 1u << 0;
constexpr unsigned CuModeBit = 1u << 1;

/// Returns a function to read codegen-flag attributes (target-cpu,
/// target-features) from. Clang sets both attributes on every \c Function
/// in the TU — definitions and declarations alike — with the same values.
/// We prefer a definition (more likely to have all attributes populated
/// even on stripped/minified bitcode), but fall back to any declaration
/// if the module is declarations-only. Returns nullptr only for a
/// completely empty module (no functions at all), in which case there is
/// nothing to instrument anyway and the marker can be safely omitted.
const llvm::Function *firstAttrDonor(const llvm::Module &M) {
  const llvm::Function *FirstDecl = nullptr;
  for (const llvm::Function &F : M.functions()) {
    if (!F.isDeclaration())
      return &F;
    if (!FirstDecl)
      FirstDecl = &F;
  }
  return FirstDecl;
}

/// Returns true if \p Features (a comma-separated `target-features` string)
/// contains the exact token \p Token.
bool hasFeature(llvm::StringRef Features, llvm::StringRef Token) {
  llvm::SmallVector<llvm::StringRef, 32> Parts;
  Features.split(Parts, ',', /*MaxSplits=*/-1, /*KeepEmpty=*/false);
  for (llvm::StringRef Part : Parts)
    if (Part.trim() == Token)
      return true;
  return false;
}

/// Default CU mode for a given gfx family. WGP mode exists only on
/// gfx10+; gfx9 and earlier are CU mode unconditionally.
///
/// `target-cpu` values come in three shapes:
///   * Concrete:               `gfx906`, `gfx942`, `gfx1030`, `gfx1200` —
///                             leading digits = family, trailing 2 chars =
///                             minor/stepping.
///   * Concrete with letter:   `gfx90a`, `gfx90c` — same, but the last
///                             stepping char is a letter.
///   * Generic:                `gfx9-generic`, `gfx10-1-generic`,
///                             `gfx12-generic` — the leading number IS the
///                             family directly.
bool defaultCuModeFor(llvm::StringRef TargetCpu) {
  llvm::StringRef Stem = TargetCpu;
  if (Stem.consume_back("-generic")) {
    // Strip an optional `-N` minor for forms like `gfx10-1-generic`.
    auto LastDash = Stem.rfind('-');
    if (LastDash != llvm::StringRef::npos &&
        Stem.substr(LastDash + 1).find_first_not_of("0123456789") ==
            llvm::StringRef::npos)
      Stem = Stem.substr(0, LastDash);
  }
  if (!Stem.consume_front("gfx"))
    return true; // Unknown form — default to CU; safer than guessing WGP.

  bool HasLetterSuffix = false;
  if (!Stem.empty() && llvm::isAlpha(Stem.back())) {
    Stem = Stem.drop_back();
    HasLetterSuffix = true;
  }

  unsigned N;
  if (Stem.consumeInteger(10, N) || !Stem.empty())
    return true;

  unsigned Major;
  if (HasLetterSuffix)
    Major = N / 10; // gfx90a → digits "90", family = 9
  else if (N >= 100)
    Major = N / 100; // gfx906 → 9; gfx1030 → 10; gfx1200 → 12
  else
    Major = N; // gfx9-generic / gfx10-1-generic → family already in N

  return Major < 10; // CU-only on gfx6..gfx9; WGP option from gfx10
}

} // namespace

llvm::PreservedAnalyses
SubtargetMarkerPass::run(llvm::Module &M, llvm::ModuleAnalysisManager &) {
  // Same plugin runs on the host TU under --cuda-host-only, where the
  // module is x86_64. The marker is meaningless there.
  llvm::Triple T(M.getTargetTriple());
  if (T.getArch() != llvm::Triple::amdgcn)
    return llvm::PreservedAnalyses::all();

  const llvm::Function *Donor = firstAttrDonor(M);
  if (!Donor)
    return llvm::PreservedAnalyses::all();

  llvm::StringRef Features =
      Donor->getFnAttribute("target-features").getValueAsString();
  llvm::StringRef TargetCpu =
      Donor->getFnAttribute("target-cpu").getValueAsString();

  unsigned Encoded = 0;

  // Wave size: clang always sets exactly one of these on AMDGPU codegen.
  // If neither is present, the IR is malformed for AMDGCN — bail rather
  // than guess.
  bool Wave32 = hasFeature(Features, "+wavefrontsize32");
  bool Wave64 = hasFeature(Features, "+wavefrontsize64");
  if (Wave32 == Wave64)
    return llvm::PreservedAnalyses::all();
  if (Wave64)
    Encoded |= Wave64Bit;

  // CU mode: explicit `+cumode` / `-cumode` overrides; absent means the
  // arch's default applies (CU on gfx9-, WGP on gfx10+).
  bool CuMode;
  if (hasFeature(Features, "+cumode"))
    CuMode = true;
  else if (hasFeature(Features, "-cumode"))
    CuMode = false;
  else
    CuMode = defaultCuModeFor(TargetCpu);
  if (CuMode)
    Encoded |= CuModeBit;

  auto *I32 = llvm::Type::getInt32Ty(M.getContext());
  // Place the global in the module's default globals address space.
  // On amdgcn data layouts that's AS 1; using AS 0 would survive
  // verifier but trip AMDGPU codegen, which expects globals to live in
  // a non-generic space.
  unsigned AS = M.getDataLayout().getDefaultGlobalsAddressSpace();
  auto *GV = new llvm::GlobalVariable(
      M, I32, /*isConstant=*/true, llvm::GlobalValue::ExternalLinkage,
      llvm::ConstantInt::get(I32, Encoded), "__luthier_subtarget",
      /*InsertBefore=*/nullptr, llvm::GlobalValue::NotThreadLocal, AS);
  GV->setSection(".luthier.subtarget");
  GV->setVisibility(llvm::GlobalValue::ProtectedVisibility);

  // appendToUsed pins the global through DCE / strip-bodies passes so it
  // reliably ends up in the final ELF's symbol table.
  llvm::appendToUsed(M, {GV});

  return llvm::PreservedAnalyses::none();
}

} // namespace luthier
