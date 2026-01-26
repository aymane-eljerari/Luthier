
#include "luthier/Tooling/MachineInstrAnnotations.h"
#include "luthier/Common/ErrorCheck.h"
#include "luthier/Common/GenericLuthierError.h"
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/MDBuilder.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/Error.h>

namespace {

class MutableMDTuple : public llvm::MDTuple {
public:
  static bool classof(llvm::MDNode *Node) { return MDTuple::classof(Node); }

  LLVM_ABI void setOperand(unsigned I, Metadata *New) {
    MDTuple::setOperand(I, New);
  };
};

} // namespace

namespace luthier {

enum MachineInstrAnnotation : uint8_t {
  Tag = 0,
  TraceAddr = 1,
  InjectedPayload = 2,
  CanRelaxDirectBranch = 3,
  IndirectBranchTargets = 4,
  LastMachineInstrAnnotation = IndirectBranchTargets
};

template <MachineInstrAnnotation Annotation> struct MachineInstrAnnotationInfo;

template <> struct MachineInstrAnnotationInfo<Tag> {
  static constexpr auto MDName = "luthier.machine_instr.tag";
};

template <> struct MachineInstrAnnotationInfo<TraceAddr> {
  static constexpr auto MDName = "luthier.machine_instr.trace_addr";
};

template <> struct MachineInstrAnnotationInfo<InjectedPayload> {
  static constexpr auto MDName = "luthier.machine_instr.injected_payload";
};

template <> struct MachineInstrAnnotationInfo<CanRelaxDirectBranch> {
  static constexpr auto MDName =
      "luthier.machine_instr.can_relax_direct_branch";
};

template <> struct MachineInstrAnnotationInfo<IndirectBranchTargets> {
  static constexpr auto MDName =
      "luthier.machine_instr.indirect_branch_targets";
};

static llvm::MDTuple *
createPCSections(llvm::LLVMContext &Ctx,
                 llvm::ArrayRef<llvm::MDBuilder::PCSection> Sections) {
  llvm::SmallVector<llvm::Metadata *, 2> Ops;
  llvm::MDBuilder MDB{Ctx};
  for (const auto &Entry : Sections) {
    const llvm::StringRef &Sec = Entry.first;
    Ops.push_back(MDB.createString(Sec));

    // If auxiliary data for this section exists, append it.
    const llvm::SmallVector<llvm::Constant *> &AuxConsts = Entry.second;
    if (!AuxConsts.empty()) {
      llvm::SmallVector<llvm::Metadata *, 1> AuxMDs;
      AuxMDs.reserve(AuxConsts.size());
      for (llvm::Constant *C : AuxConsts)
        AuxMDs.push_back(MDB.createConstant(C));
      Ops.push_back(llvm::MDNode::getDistinct(Ctx, AuxMDs));
    }
  }

  return llvm::MDNode::getDistinct(Ctx, Ops);
}

llvm::Expected<TargetMachineInstrMDNode &>
TargetMachineInstrMDNode::initializeMDNode(llvm::MachineInstr &MI) {
  llvm::MachineBasicBlock *ParentMBB = MI.getParent();
  if (!ParentMBB) {
    return LUTHIER_MAKE_GENERIC_ERROR(
        llvm::formatv("MI {0} doesn't have a parent.", MI));
  }
  llvm::MachineFunction *MF = ParentMBB->getParent();
  if (!MF) {
    return LUTHIER_MAKE_GENERIC_ERROR(
        llvm::formatv("MI {0}'s MBB doesn't have a parent", MI));
  }
  llvm::LLVMContext &Ctx = MF->getFunction().getContext();
  TargetMachineInstrMDNode &MD = create(Ctx);
  MI.setPCSections(*MF, &MD);
  return MD;
}

TargetMachineInstrMDNode &
TargetMachineInstrMDNode::create(llvm::LLVMContext &Ctx) {
  return *llvm::cast<TargetMachineInstrMDNode>(createPCSections(
      Ctx, {{MachineInstrAnnotationInfo<Tag>::MDName,
             {llvm::ConstantInt::get(llvm::Type::getInt64Ty(Ctx), 0)}}}));
}

TargetMachineInstrMDNode *
TargetMachineInstrMDNode::getInstrMDNodeIfExists(llvm::MachineInstr &MI) {
  return llvm::dyn_cast<TargetMachineInstrMDNode>(MI.getPCSections());
}

template <MachineInstrAnnotation Annotation,
          typename = std::enable_if<Annotation != Tag>>
static std::optional<std::pair<llvm::MDString &, llvm::MDTuple &>>
getMDEntryIfExists(const TargetMachineInstrMDNode &MDNode) {
  auto &IndexList = llvm::cast<llvm::MDTuple>(*MDNode.getOperand(Tag + 1));
  if (IndexList.getNumOperands() < Annotation + 1) {
    return std::nullopt;
  } else {
    auto &Header =
        llvm::cast<llvm::MDString>(*IndexList.getOperand(Annotation));
    auto &ConstantList =
        llvm::cast<llvm::MDTuple>(*IndexList.getOperand(Annotation + 1));
    return std::make_pair(std::ref(Header), std::ref(ConstantList));
  }
}

template <MachineInstrAnnotation Annotation,
          typename = std::enable_if<Annotation != Tag>>
static std::pair<llvm::MDString &, llvm::MDTuple &>
getOrCreateMDEntry(llvm::LLVMContext &Ctx, TargetMachineInstrMDNode &MDNode) {
  auto &IndexList = llvm::cast<llvm::MDTuple>(*MDNode.getOperand(Tag + 1));
  if (IndexList.getNumOperands() < Annotation + 1) {
    llvm::MDBuilder MDB{Ctx};
    unsigned CurrentIdx = IndexList.getNumOperands();
    while (CurrentIdx != Annotation) {
      IndexList.push_back(MDB.createConstant(
          llvm::UndefValue::get(llvm::Type::getInt64Ty(Ctx))));
      CurrentIdx++;
    }
    IndexList.push_back(MDB.createConstant(llvm::ConstantInt::get(
        llvm::IntegerType::getInt64Ty(Ctx), MDNode.getNumOperands())));
    MDNode.push_back(
        MDB.createString(MachineInstrAnnotationInfo<Annotation>::MDName));
    MDNode.push_back(llvm::MDNode::getDistinct(Ctx, {}));
  }
  auto &Header = llvm::cast<llvm::MDString>(*IndexList.getOperand(Annotation));
  auto &ConstantList =
      llvm::cast<llvm::MDTuple>(*IndexList.getOperand(Annotation + 1));
  return {std::ref(Header), std::ref(ConstantList)};
}

void TargetMachineInstrMDNode::setTraceInstrAddress(llvm::LLVMContext &Ctx,
                                                    uint64_t Addr) {
  auto [StringHeader, AuxConstList] = getOrCreateMDEntry<TraceAddr>(Ctx, *this);
  llvm::MDBuilder MDB{Ctx};
  llvm::ConstantAsMetadata *NewAddressMD = MDB.createConstant(
      llvm::ConstantInt::get(llvm::IntegerType::getInt64Ty(Ctx), Addr));
  if (AuxConstList.getNumOperands() >= 1) {
    llvm::cast<MutableMDTuple>(AuxConstList).setOperand(0, NewAddressMD);
  } else {
    AuxConstList.push_back(NewAddressMD);
  }
}

std::optional<uint64_t> TargetMachineInstrMDNode::getTraceInstrAddress() const {
  auto TraceAddrHeaderAndEntry = getMDEntryIfExists<TraceAddr>(*this);
  if (!TraceAddrHeaderAndEntry.has_value())
    return std::nullopt;
  if (auto &ListMD = TraceAddrHeaderAndEntry->second;
      ListMD.getNumOperands() >= 1) {
    if (const auto *CI = llvm::mdconst::extract_or_null<llvm::ConstantInt>(
            ListMD.getOperand(0))) {
      return CI->getZExtValue();
    }
  }
  return std::nullopt;
}

bool TargetMachineInstrMDNode::classof(const Metadata *MD) {
  auto *MDAsTuple = llvm::dyn_cast<MDTuple>(MD);
  if (MDAsTuple && MDAsTuple->getNumOperands() >= Tag + 1) {
    if (auto *TagStringMD =
            llvm::dyn_cast<llvm::MDString>(MDAsTuple->getOperand(Tag))) {
      return TagStringMD->getString() ==
                 MachineInstrAnnotationInfo<Tag>::MDName &&
             llvm::isa<MDTuple>(MDAsTuple->getOperand(1));
    }
  }
  return false;
}

inline llvm::Expected<std::pair<llvm::MDString *, llvm::MDNode *>>
findPCSectionEntry(const llvm::MDNode &PCSectionMD,
                   llvm::StringRef HeaderName) {
  const unsigned NumOperands = PCSectionMD.getNumOperands();
  for (auto [Idx, MDOperand] : llvm::enumerate(PCSectionMD.operands())) {
    if (auto *MDS = llvm::dyn_cast<llvm::MDString>(MDOperand);
        MDS && Idx != NumOperands - 1 && MDS->getString() == HeaderName) {
      auto *ConstList =
          llvm::dyn_cast<llvm::MDNode>(PCSectionMD.getOperand(Idx + 1));
      if (!ConstList) {
        return LUTHIER_MAKE_GENERIC_ERROR(llvm::formatv(
            "The MDNode after the header {0} is not an LLVM MDNode",
            HeaderName));
      }
      return std::make_pair(MDS, ConstList);
    }
  }
  return std::make_pair(nullptr, nullptr);
}

llvm::Expected<llvm::MDNode &> createMachineInstrMetadata(
    llvm::LLVMContext &Ctx, bool Mutable, std::optional<uint64_t> TraceInstAddr,
    llvm::ArrayRef<llvm::Function *> InjectedPayloadFunctions,
    llvm::ArrayRef<llvm::Function *> IndirectBranchTargets) {
  llvm::MDBuilder Builder{Ctx};
  Builder.createPCSections(
      {MachineInstrAnnotationInfo<
           MachineInstrAnnotation::Mutable>::createPCSection(Ctx, Mutable),
       MachineInstrAnnotationInfo<
           MachineInstrAnnotation::Trace>::createPCSection(Ctx, TraceInstAddr),
       MachineInstrAnnotationInfo<
           MachineInstrAnnotation::InjectedPayloadFunctions>::
           createPCSection(Ctx, InjectedPayloadFunctions),
       MachineInstrAnnotationInfo<
           MachineInstrAnnotation::IndirectBranchTargets>::
           createPCSection(Ctx, IndirectBranchTargets)});
}

} // namespace luthier
