// Sideload JIT build only (Cores/azahar/jit.env): compiled in place of Dynarmic's common/spin_lock_arm64.cpp.
// Upstream builds the host side of SpinLock as generated code in a static oaknut::CodeBlock, so the region is asked
// for while dyld runs initializers: with no debugger the Jit26 code block throws there and the app aborts at launch,
// and with one it would write through the RX address. The host side here is plain C++ atomics on the same word, with
// the same acquire and release order as the emitted LDAXR/STXR and STLR, so JIT code and host code share the lock.
// The emitters are upstream's, unchanged.
#include <oaknut/oaknut.hpp>

#include "dynarmic/backend/arm64/abi.h"
#include "dynarmic/common/spin_lock.h"

namespace Dynarmic {

using Backend::Arm64::Wscratch0;
using Backend::Arm64::Wscratch1;
using namespace oaknut::util;

void EmitSpinLockLock(oaknut::CodeGenerator& code, oaknut::XReg ptr) {
    oaknut::Label start, loop;

    code.MOV(Wscratch1, 1);
    code.SEVL();
    code.l(start);
    code.WFE();
    code.l(loop);
    code.LDAXR(Wscratch0, ptr);
    code.CBNZ(Wscratch0, start);
    code.STXR(Wscratch0, Wscratch1, ptr);
    code.CBNZ(Wscratch0, loop);
}

void EmitSpinLockUnlock(oaknut::CodeGenerator& code, oaknut::XReg ptr) {
    code.STLR(WZR, ptr);
}

void SpinLock::Lock() {
    while (__atomic_exchange_n(&storage, 1, __ATOMIC_ACQUIRE) != 0) {
        while (__atomic_load_n(&storage, __ATOMIC_RELAXED) != 0) {
        }
    }
}

void SpinLock::Unlock() {
    __atomic_store_n(&storage, 0, __ATOMIC_RELEASE);
}

}  // namespace Dynarmic
