// Upstream's JitCommon.cpp with no native JIT: CreateNativeJit then builds upstream's FakeJit, which the
// IR interpreter never asks for. DISASM_ALL keeps the ARM64 disassembler (text only, used by debug views).
#include "ppsspp_config.h"
#undef PPSSPP_ARCH_ARM64
#define DISASM_ALL 1

// FakeJit lags upstream's JitInterface by one method, so it cannot be built as it is.
#include "Core/MIPS/fake/FakeJit.h"
namespace MIPSComp {
class GagaNoJit : public FakeJit {
public:
	using FakeJit::FakeJit;
	const u8 *GetCodeBase() const override { return nullptr; }
};
}  // namespace MIPSComp
#define FakeJit GagaNoJit

#include "upstream/Core/MIPS/JitCommon/JitCommon.cpp"
