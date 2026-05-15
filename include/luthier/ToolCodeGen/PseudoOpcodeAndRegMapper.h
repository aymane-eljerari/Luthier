//===-- PseudoOpcodeAndRegMapper.h -------------------------------*- C++-*-===//
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
/// \file PseudoOpcodeAndRegMapper.h
/// Declares the free functions that map real (encoding-bound) AMDGPU opcodes
/// and register enums to their pseudo (selector-stage) counterparts. The
/// bodies are generated at build time by the \c LuthierRealToPseudoOpcodeMap
/// and \c LuthierRealToPseudoRegEnumMap tablegen targets and included from
/// \c PseudoOpcodeAndRegMapper.cpp.
//===----------------------------------------------------------------------===//
#ifndef LUTHIER_TOOL_CODE_GEN_PSEUDO_OPCODE_AND_REG_MAPPER_H
#define LUTHIER_TOOL_CODE_GEN_PSEUDO_OPCODE_AND_REG_MAPPER_H
#include <llvm/Support/Compiler.h>

namespace luthier {

LLVM_READONLY
unsigned short getPseudoOpcodeFromReal(unsigned short Opcode);

LLVM_READONLY
unsigned short RealToPseudoRegisterMapTable(unsigned short Reg);

} // namespace luthier

#endif