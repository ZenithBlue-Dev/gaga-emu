# 04 — No-JIT Interpreter Architecture & Execution Engine

This document is canonical for interpreter design and performance tiers. `docs/03` owns the core list, licences and renderers. `docs/05` owns graphics. `docs/06` owns the bridge API. `docs/07` owns phases and status.

**Status**

| Item | State |
|---|---|
| App shell and mock core (`Sources/Bridge/GagaCoreRegistry.c:200-220`) | Built. It is the only core that runs today. |
| 12 non-mock registry cores (`Sources/Bridge/GagaCoreRegistry.c:256`) | Stub. No guest code from any real system has run in GagaEmu. |
| Per-core no-JIT gate (section 8) | Planned. No gate script is in this repository yet. |
| Interpreter design (section 6) | Design only. No GagaEmu interpreter exists. |
| All performance tiers (section 7) | Target (unmeasured). GagaEmu has no benchmark yet. |

The design goal is that every shipped core runs guest code through a precompiled interpreter, with no JIT, no RWX mapping and no dynarec.

**Reference repositories.** These are external sister projects. They are not part of the GagaEmu binary.

| Alias | Path | System | Interpreter |
|---|---|---|---|
| S2 | `balero-s2` | PS2 | New threaded R5900 interpreter. No device benchmark found in the repository. |
| S3 | `samba-s3/samba-s3-ui` | PS3 | RPCS3 static interpreters, patched. Core submodule below is written `S3core` = `S3/app/src/main/cpp/rpcsx`. Measured on an iPhone 17. |
| S4 | `Bachata-S4-Dev` | PS4 | New threaded x86-64 interpreter. Measured on a OnePlus 13 and an iPhone 17. |

---

## 1. Main findings

1. **Dispatch is not the largest cost.** S3 measured dispatch at about a third of the cost of a simple instruction, so free dispatch would give at most about 1.5x (`S3/docs/ios/benchmarks/S3 log A:275`). A threaded interpreter is worth building only together with block linking, decode-time simplification and a guest memory fast path.
2. **Block linking is the largest measured interpreter gain.** S4 measured 1.07x to 1.87x per workload on device, and about 3x on a tight loop (section 4, rank 6).
3. **LTO and PGO did not help where they were measured.** S3 found both neutral on a full core (section 4, rank 17).
4. **More fused handlers can stop helping.** S3 and S4 both removed batches that saved dispatches but gained nothing on device (section 5).
5. **Third-party cores keep their upstream interpreters.** No CPU-core rewrite is assumed. Their realistic levers are build flags, a clean dynarec-free build, configuration and targeted patches (section 4.1).
6. **Heavy guests hit a limit that interpreter tuning does not remove.** S3 reached about 10 fps in PS3 game A, about 4x below its dev-only JIT build on the same phone (`S3 log A:411-412`). PS2 and Dolphin stay research (section 7).

---

## 2. iOS execution constraints

JIT denial comes from OS enforcement: W^X, code signing of executable pages, and no public iOS entitlement for general JIT. It is not attributed here to App Review Guideline 2.5.2. Guideline 4.7 covers "retro game console and PC emulator apps"; Apple defines no generations and does not define "retro". See <https://developer.apple.com/app-store/review/guidelines/>.

- `com.apple.security.cs.allow-jit` is a macOS hardened-runtime entitlement. It is not an iOS path. See <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit>.
- The Dolphin iOS team reports that Apple denied its DMA interoperability request for JIT support (<https://oatmealdome.me/blog/why-dolphin-isnt-coming-to-the-app-store>).
- Debugger-based JIT on sideloaded apps is a separate, changing path. On iOS 26 TXM-era devices it needs per-app changes and a script for StikDebug (<https://forums.libretro.com/t/what-is-the-current-situation-with-ra-on-ios-26-and-jit-support/49244>, a forum source). It is out of scope regardless.

S3 tested these behaviours on iOS 27.0.1, iPhone18,3, TXM, in a dev-signed build (`S3 log A:368-373`):

| Attempt | Result |
|---|---|
| `MAP_JIT` | `EPERM` |
| RWX `mmap` | Silently becomes `rw-` |
| `mprotect` RW to RX | `EACCES` |
| `pthread_jit_write_protect_np` | Absent (`dlsym` returns NULL) |

The silent `rw-` result matters for the gate: a dynarec may fail only when it first jumps to its buffer, not when it maps it.

GPU shaders are a separate rule. Runtime shader translation through MoltenVK and SPIRV-Cross is accepted; see `docs/05`.

---

## 3. What the sister projects do

Evidence comes from source and benchmark records, not from their overview documents. Where the two differ, the source is used: `S2/docs/02-no-jit-interpreter-strategy.md` describes `Block* succ[2]` and a QoS table that the S2 code does not contain.

| Technique | S2 | S3 | S4 |
|---|---|---|---|
| Dispatch | `[[clang::musttail]]` (`core/include/balero/ee_core.h:19,49`) | SPU on iOS: `musttail` (`S3core/rpcs3/Emu/Cell/SPUInterpreter.cpp:3299,3386`). PPU: plain `return fn(...)`, no attribute, relies on the optimiser (`PPUInterpreter.cpp:152-156`) | `musttail`, with a loop fallback (`src/core/guest_cpu/interp/access.h:167`, `engine.cpp:77-88`) |
| `preserve_none` | Yes (`ee_core.h:18,27`) | Not used in the source tree | Yes, behind `__has_attribute` (`interp_config.h:14-19`) |
| Handler arguments | ctx, op | spu, opcode, pc, record | op, state, two reserved values kept at zero (`op.h:16-19`) |
| Op layout | 16 bytes, checked by `static_assert` (`ee_core.h:35-47`) | 16-byte record per local-store word (`S3 log A:114`) | 32 bytes, checked by `static_assert` (`op.h:32-45`), because x86 needs a 64-bit displacement and immediate |
| Decode unit | Block, at most 64 instructions (`ee_core.cpp:1835`) | Per word, lazily | Block, at most 64 instructions (`interp_config.h:61`), plus superblocks |
| Block lookup | Page chunks of per-instruction pointers (`ee_core.h:114-116`) | Direct index by LS address | Direct-mapped L1 with 65,536 entries (`interp_config.h:65`, `block_cache.h:87-90`), then a locked map |
| Block linking | None. Every block returns to `EeCore::run` (`ee_core.cpp:1894-1908`) | Not applicable. Records are contiguous and branches pick a record | Link slots filled lazily (`op.h:49-55`), inline cache for indirect transfers, 16-entry return stack |
| Guest registers | In memory | In memory, pc passed in a register (`SPUInterpreter.cpp:3281-3282`) | In memory and always written. Fused pairs forward one value in a host register (`access.h:27-36`) |
| Guest memory | Base plus mask, with a bounds path (`mmu.h:12`) | Base plus offset; `spu.ls` for SPU | Identity mapped: guest address equals host pointer (`access.h:104`) |
| Self-modifying code | Dirty byte per 4 KB page, checked at block lookup (`mmu.h:66-67`, `ee_core.cpp:1876`) | Records reset per 128-byte line, plus an epoch check at taken branches (`S3 log A:115`) | Sealed code pages, per roadmap (`docs/plans/ios-nojit/roadmap.md:189-191`); overlap kill and link clearing (`block_cache.cpp:162`, `block_cache.h:34-36`) |
| Yield | Per block (below) | State check after taken branches and channel ops | Per linked transfer (below) |
| SIMD | NEON intrinsics (`core/src/vu/vu_core.cpp:95`) | Direct NEON for hot SPU ops, `sse2neon` elsewhere (commit `707be0b57`) | Lane-wise NEON; fused VEX chains |
| Compile flags | `-O3 -ffast-math`, no `-mcpu` (`CMakeLists.txt:26-31`) | `-O3 -march=armv8.4-a` (`S3 log A:174`), `-fno-split-cold-code`, LTO off (`S3core/ios/CMakeLists.txt:33,47-48`) | `-O3 -fomit-frame-pointer -ffp-contract=off`, `-mcpu=apple-a12` on iOS (`interp.cmake:36-47`) |
| QoS | None found in code | `USER_INTERACTIVE` for guest threads (`S3core/rpcs3/util/Thread.cpp:2253`) | `USER_INTERACTIVE` for frame-critical threads (`src/common/thread.cpp:130-136`) |
| Measured on iOS | No | Yes | Yes |

**Where each project yields.** No project charges a budget per op. The old per-op design in this document matched none of them.

- **S2** counts per block. `op_block_exit` subtracts the block's op count from `cycles_left` and returns (`ee_core.cpp:1751-1759`). `EeCore::run` tests the budget between blocks (`ee_core.cpp:1894`). `op_idle_skip` burns extra budget on a self-branch (`ee_core.cpp:529-537`).
- **S3** has no per-op check. It tests `spu.state` after taken branches and channel, stop, halt and interrupt ops (`SPUInterpreter.cpp:3380,3414`). Checking only there was neutral against checking after every instruction (`S3/docs/ios/benchmarks/S3 log B:145-146`).
- **S4** has no guest cycle accounting. `chain_budget` decrements only on a linked transfer, default 4096 (`interp_config.h:64`, `handlers/control.cpp:47,70,156`, `handlers/int_alu.cpp:200`). The dispatcher resets it on entry (`engine.cpp:246`).
- **PPSSPP** tests `downcount` at block exit before it chains (`IR_EXIT` in <https://raw.githubusercontent.com/hrydgard/ppsspp/master/Core/MIPS/IR/IRInterpreter.cpp>).

**Dispatch and branch prediction.** The claim that a shared `switch` jump "constantly mispredicts" is contested and is not used here.

- Rohou, Swamy and Seznec (2015) argued that indirect branch accuracy is no longer critical for interpreters (<https://researchr.org/publication/RohouSS15>; this page could not be fetched, so the paper is cited through the summary below).
- Ertl disputes that conclusion. His Haswell runs show a 1.08x to 1.37x speedup from non-shared dispatch, without a consistent reduction in mispredictions (<https://compilers.iecc.com/comparch/article/22-10-056>).
- That data is from x86 and is reached here through secondary summaries. No sister project has recorded misprediction counts on Apple cores.
- The PPSSPP source says that losing per-op jumps costs 10-15%. The comment names no device.

**Limits of portability.**

| Technique | Limit |
|---|---|
| `INTERP_TSO`, `LDAPR` through `-mcpu=apple-a12` (`S4 interp.cmake:43-47`) | Needed for x86 guest memory order. Not needed for a single-CPU retro guest. |
| Lazy flags, dead-flag removal, VEX fusion, upper-half store skipping | x86 and AVX guest only. |
| `-fno-plt` | Not applied on Darwin (`S4 interp.cmake:39`). |
| S4 OnePlus numbers | Android, Snapdragon 8 Elite. Use the ratios as a guide only. |
| Thread affinity | iOS has no affinity API (`S3 log A:123,180`). QoS is the only lever. |
| Debugger-blessed JIT runs in `S3 log A:361` onwards | Dev-only. Never shippable. |

**Compiler facts for `musttail` and `preserve_none` on Apple clang.**

- S4 records availability in NDK 30 clang 21 for AArch64 and absence in clang 18 (`interp_config.h:11-13`). It gates on `__has_attribute`. Its Xcode 16.3 requirement is for `std::atomic_ref`, not this attribute (`S4/.github/workflows/ios-core.yml:92`).
- S2's document says Xcode 16 and later, without evidence (`S2/docs/02-no-jit-interpreter-strategy.md`). S3's research says to verify it.
- Checked for this document: Apple clang 21.0.0 (clang-2100.4.1.1), Xcode 27.2, target `arm64-apple-ios17.0`. Both attributes compile. The first two arguments arrive in `x20` and `x21`, so the S2 comment "params stay in x0-x7" (`ee_core.h:16`) does not hold for this compiler. The minimum Apple clang version is unverified.
- `preserve_none` is part of the function type. The alias must carry it, or `musttail` rejects the indirect call (`ee_core.h:25-27`).

---

## 4. Ranked optimisations

The order reflects expected gain against cost for GagaEmu, using recorded data where it exists. "Unmeasured" means no project isolated the effect. Gains are for the workload named and do not transfer directly to another guest.

The class column reads: **All** = realistic for third-party cores; **Patch** = a targeted patch to an upstream hot path; **In-house** = needs the design in section 6.

| # | Optimisation | Used in | Recorded gain | Cost | Class |
|---|---|---|---|---|---|
| 1 | Clean dynarec-free build, and the fastest legal interpreter mode per core | S3 `S3core/ios/CMakeLists.txt:28-29`; S4 `address_space.cpp:1031-1034` | Precondition. Upstream PPSSPP and melonDS run without JIT (section 7) | Low | All |
| 2 | Stop host waste: spin backoff, FIFO wait sleep, guest idle-loop skip | S3 `e0f2c29da`, `d5325d6cf`; S4 `spin_backoff` (`engine.h:27`); S2 `op_idle_skip` | RSX thread CPU 62% to 30% (`e0f2c29da`). 53.3-56.3 fps against 50.6-54.2 (`S3 log B:180`) | Low | All |
| 3 | Keep Apple clang from splitting hot code: `-Xclang -fno-split-cold-code` | S3 `S3core/ios/CMakeLists.txt:31-33` | 35.1 to 40.7 fps, bundled with ranks 2 and 4, not isolated (`S3 log B:137-138`) | Very low | All |
| 4 | `USER_INTERACTIVE` QoS on frame-critical guest threads | S3 `Thread.cpp:2253`; S4 `thread.cpp:130-136` | Bundled with rank 3. S4 reports default QoS put its main thread on E-cores about 40% of the time | Very low; present in GagaEmu | All |
| 5 | Inline guest memory fast path | S2 `mmu.h:12`; S3; S4 `access.h:104` | Unmeasured | Medium | Patch, In-house |
| 6 | Block linking, with an exit record per block exit | S4 `op.h:49-55`, `handlers/control.cpp:47`. Not in S2 | 1.07x-1.87x per workload (`S4/docs/plans/ios-nojit/status.md:169-182`). About 3x on a tight loop (`tasks.md:78`). S4 calls linking "the dominant optimisation" | Medium; invalidation must clear links | In-house, sometimes Patch |
| 7 | Pre-decoded ops, one decode per guest instruction | S2, S4; S3 `8535da1dd` | +4% to +12%, mean +8%, where decode was already cheap (`S3 log A:116`) | Medium | In-house, Patch |
| 8 | Profile-chosen pair fusion | S3 `c35eda38a`, `f1596e387`; S4 `db66ecd76`, `384bef8aa` | S3: 128 pairs +7.7%, then 512 against 128 +11% pooled, 1.091 without one outlier (`S3 log A:250,566`). S4: fusion and dead flags 0-20% per workload (`status.md:181`) | Medium to high; needs a profile per guest | In-house |
| 9 | Decode-time specialisation: drop no-ops, fold absent operands, drop zero-register tests | S4 `5dc78b868`, `080c54395`, `17428bd5b` | +12.9% offline, combined. One workload +7.5%. NOP removal +0.5% | Low once decoding exists | In-house, Patch |
| 10 | Indirect-branch inline cache, reading the block table in place on a miss | S4 `ac497277a` | 104 to 132 M iterations/s on one thread; about 7 to 110 per thread on four threads sharing an engine | Low once linking exists | In-house |
| 11 | Tail-call threaded dispatch | S2, S4, S3 SPU | Not isolated. S3: 40.7 to 43.3 fps, bundled with NEON shuffles, single run (`S3 log B:139`). PPSSPP comment: 10-15% against a single jump. S3 caps it at about 1.5x in total | High if it means a rewrite | In-house |
| 12 | Carry the pc in a register or rebuild it from the op pointer | S3 `c3fdebb29`, `SPUInterpreter.cpp:3354-3357` | +3.0% (`S3 log A:170`) | Low in a new design | In-house |
| 13 | `preserve_none` | S2, S4 | Unmeasured in all three. A local compile shows a handler with a slow-path call at 13 instructions against 18, with no spill of ctx or op. CPython's corrected tail-call gain is about 3-5% on Clang, and `musttail` alone regressed there (`S3/docs/ios/research/03-no-jit-execution-strategies.md:61`) | Very low with rank 11 | In-house |
| 14 | Direct NEON and multi-op vector chains | S3 `707be0b57`; S4 `349beed23` | Offline: +19% for pairs, +19% more for chains, matrix/dot loop 31% less time. Device chains within noise | Medium | In-house, Patch |
| 15 | Native fast paths for hot library or BIOS calls | S4 `8cf48cfe5`, `hle_fast.h` | +3% guest instructions/s, +1-2% fps | Medium | Patch, In-house |
| 16 | Superblocks and inlined direct calls | S4 `3b755678b`, `597a5fe26` | Offline +0.6% and +0.8%, within noise. Device run for superblocks noisy, for inlined calls pending | Medium | Low priority |
| 17 | ThinLTO and PGO | Tested in S3 only. Shipped builds of S3 have LTO off | Neutral. ThinLTO 50.2, 45.9, 50.1 against 50.7, 49.7, 50.0. PGO 46.3, 49.4, 50.0 against 47.2, 48.4, 48.9 (`S3 log B:179,181`) | ThinLTO low, PGO high | All, only if measured per core |
| 18 | `-mcpu` or `-mtune` for hot handlers, `-fomit-frame-pointer` | S3 test; S4 uses both | Same hot-handler instruction count; frame-pointer flag removed 1 instruction from 3 handlers (`S3 log A:174`) | Very low | All; do not expect gain |

### 4.1 What is realistic for third-party cores

mGBA, Gambatte, Nestopia, bsnes, JGenesis, PCSX-ReARMed, melonDS DS, MAME, DOSBox Pure, Mupen64Plus-Next and PPSSPP use their upstream interpreters. No CPU-core rewrite is assumed.

Realistic work, in order:

1. Build each core without its dynarec and pass the gate in section 8.
2. Apply one shared release profile: `-O3` (or the core's own tested level) and `-Xclang -fno-split-cold-code`. Keep each core's own floating-point settings. Do not add `-ffast-math`.
3. Select the fastest legal mode in configuration. Run one A/B per core for ThinLTO. Keep it only when it beats the noise floor in section 7.2.
4. Add idle-loop skipping and wait backoff where upstream exposes them. Check accuracy on the title being tested.
5. Write a targeted patch only after a profile names the hot path. Upstream it where the licence and the maintainers allow. PGO is the last resort, since an instrumented S3 core ran at 2.5 fps and the result was neutral (`S3 log B:186`).

Threaded dispatch, block linking and fusion in a third-party core are not small patches. Treat them as in-house work.

PPSSPP needs less than this document used to imply. Upstream `master` now has computed-goto dispatch on GCC and Clang, a `switch` fallback for other compilers and unlisted ops, and block chaining while `downcount` lasts. Pin a build at or after that code and check it, because the older dispatch was a plain `switch`.

### 4.2 In-house or heavily patched interpreters

These are candidates where upstream speed may be the blocker. **Each would be separately scheduled work with its own milestone in `docs/07`, and none is scheduled today. Nothing in this document implies a rewrite.** Start one only after the section 7.2 benchmark shows that the stock interpreter misses its target and a profile shows CPU interpretation is the cause.

| Candidate | Why | Note |
|---|---|---|
| Flycast SH-4 (Dreamcast) | Tier 3 today. The core list already needs a maintained JIT-less fork | First candidate |
| Beetle Saturn SH-2 | Tier 3. Two guest CPUs | Accuracy risk. Patch hot paths before any redesign |
| Mupen64Plus-Next VR4300 and RSP | Tier 2, heavy per guest instruction | Audit the RSP path first (section 7.1) |
| Azahar ARM11 interpreter | Tier 3 and multi-core | Large scope. Later than the others |
| EKA2L1 interpreter | Depends on its spike | No work before the spike |
| PPSSPP IR hot loop | Upstream is already threaded and chained | Targeted patches only |

Check the licence impact of a modified core against `docs/03`. This is engineering guidance, not legal advice.

---

## 5. Tried and rejected

| Attempt | Where | Result |
|---|---|---|
| Second batch of 254 fused sequences | S4 `4da0f48ac` | Cut dispatches about 5%. Off against on 1.006 and 1.016. Reverted |
| 128 or 256 fused triples on top of 512 pairs | S3 (`S3 log A:568-573`) | 0.983 and 0.955. Dropped. Simulated dispatch savings did not predict gain |
| 256 pairs against 128 | S3 `f1596e387` | 0.98. Dropped, though 512 won 6 of 6 |
| Quads and same-op runs | S3 (`S3 log A:580-581`) | Rated under +1%. Not built |
| Reading the opcode from the record | S3 (`S3 log A:172`) | One instruction fewer, 0.966 |
| Value forwarding in fused pairs by patched register field | S3 (`S3 log A:296-302`) | LLVM still reloaded the register. Real forwarding needs per-handler code |
| Avoiding `stp` before a dependent `ldr q` | S3 tested and dropped. S4 `d0253ea88` kept a split | S3 found no stall on Apple M6. S4 measured +1.3% offline. Unresolved, and small either way |
| Lower QoS for selected guest threads | S3 | One PS3 game B preset kept it. The PS3 game A rows were invalid: the setting had been skipped (`S3 log A:311-314`) |
| Game-specific native ports | S4 `1f2a5c40a`; S3 EDGE experiment | S3 measured +5.3% and did not ship it. S4 removed its ports, since they are game code compiled ahead of time. GagaEmu follows the same rule. Open-source library code may stay |
| `-ffast-math` | S2 uses it (`CMakeLists.txt:30`) | No measurement. S4 uses `-ffp-contract=off` for exact guest results. Do not copy it from S2 |

---

## 6. In-house interpreter design

**Status: design.** Use this only for the work in section 4.2.

### 6.1 Op layout and dispatch

The op follows the S2 layout: 16 bytes, four to a 64-byte line. S4's 32-byte layout is for x86 operands. Fixed-width RISC guests fit 16 bytes. Guests with long immediates use a side table.

`ExitRec` adds linking, which S2 lacks. S4 holds the same data behind a pointer in its 64-bit immediate (`op.h:42-55`). Here a 32-bit index keeps the op at 16 bytes and costs a load only at control transfers.

The budget is charged at block exit, not per op. An op that has finished is never saved as the resume point, so it cannot run twice at a slice end. A chain can overrun a slice by at most one block. The overrun carries into the next slice as a negative `cycles_left`.

```cpp
#include <arm_neon.h>
#include <cstdint>
#include <cstring>

#if !__has_cpp_attribute(clang::musttail) || !__has_attribute(preserve_none)
#error "The in-house interpreter needs musttail and preserve_none"
#endif
#define GAGA_HANDLER __attribute__((preserve_none))
#define GAGA_MUSTTAIL [[clang::musttail]]

struct CpuContext;
struct IrOp;

// preserve_none is part of the function type: the alias must carry it or musttail rejects the call.
using OpHandler = void (GAGA_HANDLER *)(CpuContext* __restrict ctx, const IrOp* __restrict op);

struct IrAux {
    uint16_t sub_op;
    uint16_t mask;
};

struct alignas(16) IrOp {
    OpHandler fn;
    uint8_t rd, rs, rt, sa;
    union {
        uint32_t imm32;  // immediate, or index into CpuContext::exits for control transfers
        IrAux aux;
    };
};
static_assert(sizeof(IrOp) == 16, "four ops per 64-byte line");

// One record per block exit. Kept outside IrOp so the op stays at 16 bytes.
struct ExitRec {
    const IrOp* link;   // next block's first op, nullptr until the dispatcher links it
    uint32_t guest_pc;  // where execution continues after this exit
    int32_t cycles;     // guest cycles of the block, charged once at this exit
};
static_assert(sizeof(ExitRec) == 16);

inline constexpr uint32_t kPageShift = 12;
inline constexpr uint32_t kPageMask = (1u << kPageShift) - 1;

struct alignas(16) CpuContext {
    uint32_t gpr[32];
    float32x4_t vr[32];
    float32x4_t acc;
    uint8_t* const* read_pages;  // nullptr entry: MMIO or unmapped, take the slow path
    ExitRec* exits;
    ExitRec* unlinked;           // exit the dispatcher should link, or nullptr
    const IrOp* cur_op;          // set before a slow path, maps a fault back to a guest pc
    int32_t cycles_left;
    uint32_t pc;                 // valid whenever the chain has returned
    bool stop;
};

uint32_t mem_read32_slow(CpuContext* ctx, uint32_t addr);
const IrOp* find_or_decode_block(CpuContext* ctx, uint32_t pc);

#define DISPATCH() GAGA_MUSTTAIL return op[1].fn(ctx, op + 1)

// The decoder turns a write to a hardwired zero register into a nop, so handlers need no test.
GAGA_HANDLER void op_add(CpuContext* ctx, const IrOp* op) {
    ctx->gpr[op->rd] = ctx->gpr[op->rs] + ctx->gpr[op->rt];
    DISPATCH();
}

GAGA_HANDLER void op_addi(CpuContext* ctx, const IrOp* op) {
    ctx->gpr[op->rt] = ctx->gpr[op->rs] + op->imm32;
    DISPATCH();
}

// Every block ends here. The block has already run, so saving guest_pc cannot re-execute an op.
GAGA_HANDLER void op_exit(CpuContext* ctx, const IrOp* op) {
    ExitRec* const exit = &ctx->exits[op->imm32];
    ctx->pc = exit->guest_pc;
    ctx->cycles_left -= exit->cycles;
    const IrOp* const next = exit->link;
    if (next != nullptr && ctx->cycles_left > 0) [[likely]] {
        GAGA_MUSTTAIL return next->fn(ctx, next);
    }
    ctx->unlinked = next == nullptr ? exit : nullptr;
}

// Taken: leave through this op's exit record. Not taken: op[1] is the fall-through exit.
GAGA_HANDLER void op_beq(CpuContext* ctx, const IrOp* op) {
    if (ctx->gpr[op->rs] == ctx->gpr[op->rt]) {
        GAGA_MUSTTAIL return op_exit(ctx, op);
    }
    DISPATCH();
}

__attribute__((cold, noinline))
GAGA_HANDLER void op_lw_slow(CpuContext* ctx, const IrOp* op) {
    ctx->cur_op = op;
    ctx->gpr[op->rt] = mem_read32_slow(ctx, ctx->gpr[op->rs] + op->imm32);
    DISPATCH();
}

// One table load and one test on the fast path. Assumes a little-endian guest.
GAGA_HANDLER void op_lw(CpuContext* ctx, const IrOp* op) {
    const uint32_t addr = ctx->gpr[op->rs] + op->imm32;
    const uint8_t* const page = ctx->read_pages[addr >> kPageShift];
    if (page != nullptr && (addr & 3) == 0) [[likely]] {
        uint32_t value;
        std::memcpy(&value, page + (addr & kPageMask), sizeof(value));
        ctx->gpr[op->rt] = value;
        DISPATCH();
    }
    GAGA_MUSTTAIL return op_lw_slow(ctx, op);
}

// vfmaq_f32 is fused. Use it only where the guest operation is fused or relaxed accuracy allows it.
GAGA_HANDLER void op_vmadd(CpuContext* ctx, const IrOp* op) {
    ctx->vr[op->rd] = vfmaq_f32(ctx->acc, ctx->vr[op->rs], ctx->vr[op->rt]);
    DISPATCH();
}

// Plain AAPCS entry. It saves the callee-saved registers that preserve_none handlers overwrite.
__attribute__((noinline)) void enter_chain(CpuContext* ctx, const IrOp* first) {
    first->fn(ctx, first);
}

// Called by the core's step_frame. Each return is a slice boundary or an unlinked exit.
void run_slice(CpuContext* ctx, int32_t cycles) {
    ctx->cycles_left += cycles;
    while (ctx->cycles_left > 0 && !ctx->stop) {
        const IrOp* const first = find_or_decode_block(ctx, ctx->pc);
        if (ctx->unlinked != nullptr) {
            ctx->unlinked->link = first;
            ctx->unlinked = nullptr;
        }
        enter_chain(ctx, first);
    }
}
```

**Snippet status.** The fence above compiled without warnings under `-Wall -Wextra -pedantic` with Apple clang 21.0.0 for `arm64-apple-ios17.0`, at `-O3` with `-Xclang -fno-split-cold-code`. A separate host test on an arm64 Mac ran the same code at `-O0`, `-O1` and `-O3`, with and without ASan and UBSan. It drove a loop through slice ends and linking, a mapped load and a slow-path load. It asserted that each increment ran exactly once, that all cycles were charged once, and that `cur_op` pointed at the slow op. Nothing has been run on an iOS device, and no speed was measured.

**Entry function.** Enter the chain from a small function with no over-aligned locals, as `enter_chain` does. An earlier test without `enter_chain` crashed under ASan at `-O1`, when a large `main` called a handler directly. The frame used `x19` as its base pointer, and that register held a data address after the call. Adding `enter_chain` removed the crash. Treat this diagnosis as local: it comes from disassembly and was not confirmed upstream.

**Bridge.** The host reaches a core only through `GagaCoreInterface` function pointers (`Sources/Bridge/GagaBridge.h:72-104`). `step_frame` (`GagaBridge.h:89`) returns once per guest frame. `run_slice` stays behind it.

### 6.2 Cycle accounting and yield

- Charge guest cycles at block exit. Guests with timing-sensitive events set the slice length to the next scheduled event, and a slow path that needs exact time adds the cycles consumed so far. Memory ops use `imm32` for the offset, so that count goes in the `sa` byte.
- Check for events only at block exits, taken branches and slow paths. S3 measured this placement as neutral against a check after every instruction.
- Block size stays bounded. S2 and S4 both use 64 instructions.
- Detect a self-branch at decode and skip to the next event. S2 does this with `op_idle_skip`.

### 6.3 Block cache and linking

- Use a direct table where the code space is small: S2's per-page chunks, or S4's direct-mapped L1 in front of a map.
- Allocate ops from a bump arena. S4 keeps invalidated blocks readable because other threads may still run them (`block_cache.h:39-41`). A single-CPU guest thread can free at a safe point, which is the dispatcher.
- Each block records the link slots that point at it. Killing a block clears them (`S4 block_cache.h:34-36`) and clears `unlinked` if it refers to that block.
- Add an indirect-branch inline cache and a small return stack only after a profile shows many returns to the dispatcher. S4's `lookups per frame` counter exists to answer that question (`S4/docs/plans/ios-nojit/benchmark.md:47-50`).

### 6.4 Fusion

- Do not guess. Take the list from a run-weighted profile of the target guest, as S3 and S4 both did.
- Use one A/B per addition. Expect the first batch to pay and later batches to stop. Handler count has a cost: S3 suspects its 225-409 extra triple handlers cost about what they saved.
- A fused handler must keep exact state at any point where a fault or event can be observed. S4 writes `CpuState` on every op and uses forwarding only to shorten reads (`access.h:27-30`).
- Build a differential test against the unfused engine, with planted bugs. S4 ran this for each fusion commit.

### 6.5 Guest memory

| Method | Used by | Fits |
|---|---|---|
| Base plus mask | S2 RDRAM (`mmu.h:12`) | A flat region with simple mirroring |
| Software page table, as in `op_lw` | Design | Guests with MMIO and mirrors mixed in the address space |
| Host-fault mapping or identity mapping | S4 (`access.h:104,162-163`) | Rare events only, since a fault costs far more than a test |

S4 relies on host faults for guest code sealing and its GPU write tracker, and it marks `cur_op` before accesses so that a fault maps back to a guest address. Its guest memory sits at or above 4 GiB, because `__PAGEZERO` occupies the range below (`S4/docs/plans/ios-nojit/ios-core.md:64`). Identity mapping therefore does not fit retro guests with low addresses.

Masks are per guest and per region. `0x01FFFFFF` in S2 is for 32 MB of PS2 RDRAM. PS1 main RAM is 2 MB, mirrored across the first 8 MB (<https://psx-spx.consoledev.net/memorymap/>).

Big-endian guests swap at the memory boundary with `__builtin_bswap*`, not across guest memory (`S3/docs/ios/research/03-no-jit-execution-strategies.md:80`).

### 6.6 Self-modifying code

| Option | Used by | Cost |
|---|---|---|
| Dirty byte per page, checked at lookup | S2 | One byte store per guest store. A running or linked block does not see it, so with linking it needs a kill path |
| Records reset per line, epoch for other writers | S3 | A check in every store handler: STQD is 25 instructions including it (`S3 log A:579`) |
| Sealed code pages, fault on write | S4, per roadmap | No store cost. A fault per first write to a code page |

Design for linked in-house cores: keep a `write_pages` table like `read_pages`, with a null entry for any page holding decoded code, so a store takes the slow path, which kills overlapping blocks and clears links. This is unmeasured. DMA writers must use the same path.

### 6.7 Vector units

Lower guest vector ops to NEON intrinsics directly and avoid generic SSE translation in hot paths. S3 replaced `sse2neon` for its hot SPU shuffles.

`FMLA` has a latency of 4 cycles and a throughput of 0.25 cycles on Firestorm (<https://dougallj.github.io/applecpu/firestorm-simd.html>). It is not a single-cycle operation. `vfmaq_f32` rounds once. A guest that rounds the product first needs `vmulq_f32` then `vaddq_f32` for bit-exact results. Compile with `-ffp-contract=off` so the compiler does not merge them (`S4 interp.cmake:40`).

### 6.8 Cold paths

- Move rare work into `cold, noinline` functions. S4 outlined its NaN fix-ups for this reason (`5dc78b868`).
- With `preserve_none`, `ctx` and `op` sit in registers that an AAPCS callee preserves, so a slow call spills neither.
- Apple clang can treat a dispatch loop as cold. S3 found its interpreter loops moved into minsize `.cold.N` functions (`S3core/ios/CMakeLists.txt:31-32`). Use `-Xclang -fno-split-cold-code` and check the disassembly of hot handlers.

---

## 7. Performance tiers

A tier is expected CPU load, not delivery order. `docs/07` may schedule differently. `docs/03` owns the core list; this table adds only the performance view.

**No number in this table is a measurement of GagaEmu.** Replace a target with a measured result only through section 7.2.

| Tier | Target (unmeasured) |
|---|---|
| 1 | Full guest speed, sustained, with fast-forward headroom |
| 2 | Full guest speed for most titles on a current device. Title-dependent |
| 3 | Experimental. No full-speed promise. Results recorded per title |

This document sets no CPU device floor, because no benchmark supports one. GPU support is a separate graphics decision (`docs/05`): A14 required for layer-path 3D cores; 2D cores have no such floor.

### 7.1 Core table

"Not audited" means this document has not checked upstream's dispatch or build flags. The gate must confirm each row. Manic EMU release notes list sideload JIT support for Flycast, melonDS, Mupen64Plus-Next, DOSBox Pure, Beetle PSX and Azahar (<https://github.com/Manic-EMU/ManicEMU/releases>, public repo). Those cores therefore have a recompiler path that must be left out.

| Platform | Core | Guest CPU | Dispatch evidence | No-JIT configuration | Tier | Target and evidence |
|---|---|---|---|---|---|---|
| Game Boy / GBC | Gambatte | SM83 | Audited at `77f2567d`: compiled sources have no code-generation calls, enforced by `scripts/build-core.sh` | No dynarec in this core. `HAVE_NETWORK` off, so no sockets (`Cores/gambatte/core.env`) | 1 | Target (unmeasured). Built, legal gate open, device benchmark pending |
| GBA | mGBA | ARM7TDMI | Audited at 0.10.5: compiled sources have no code-generation calls, enforced by `scripts/build-core.sh` | No dynarec in this core. `Cores/mgba/flags.h` | 1 | Target (unmeasured). Device benchmark pending |
| NES | Nestopia UE | 6502 family (2A03) | Audited at `f1e02d12`: compiled sources have no code-generation calls, enforced by `scripts/build-core.sh`. The CPU is a table-driven interpreter (`source/core/NstCpu.cpp`) | No dynarec in this core. Single threaded, no sockets, no dlopen (`FORBIDDEN_IMPORTS` in `Cores/nestopia/core.env`) | 1 | Target (unmeasured). Simulator only: core 0.82 ms per frame mean, 1.03 ms p95, 60.10 fps over 10 s on the generated ROM (not a performance measure). Built, legal gate open, device benchmark pending |
| SNES | bsnes | 65C816, SPC700 | Not audited | No dynarec expected | 2 | Target (unmeasured). Accuracy-first core |
| Genesis / Mega-CD | JGenesis | M68000, Z80 | Not audited. Self-maintained iOS port | No dynarec expected | 2 | Target (unmeasured) |
| PS1 | PCSX-ReARMed | R3000A | `psxBSC` function table, not direct threading (<https://raw.githubusercontent.com/libretro/pcsx_rearmed/master/libpcsxcore/psxinterpreter.c>) | `DYNAREC = 0` for `ios-arm64` (<https://raw.githubusercontent.com/libretro/pcsx_rearmed/master/Makefile.libretro>, lines 228-231) | 1 | Target (unmeasured) on the interpreter. Beetle PSX as an alternate has its own target to set |
| DS | melonDS DS | ARM946E-S, ARM7TDMI | Not audited | JIT disabled by default in iOS builds (`docs/03`) | 2 | Target (unmeasured). Evidence: 100% speed without JIT on "most newer iOS devices", Delta (<https://rileytestut.com/blog/2021/04/21/delta-1-3-ds-for-everyone>, 2021, standalone melonDS, developer statement) |
| Saturn | Beetle Saturn | Dual SH-2, 68EC000 | Not audited | Audit | 3 | Target (unmeasured) |
| N64 | Mupen64Plus-Next | VR4300, RSP | Not audited | `WITH_DYNAREC` is empty on `ios-arm64`, but `HAVE_PARALLEL_RSP = 1` compiles a JIT RSP, so it fails the gate as configured upstream. A non-JIT RSP is required (`docs/03` section 4) | 2 | Target (unmeasured). Depends on ParaLLEl-RDP on MoltenVK as well |
| PSP | PPSSPP | Allegrex | Upstream `master`: computed-goto threaded with `switch` fallback on other compilers (<https://raw.githubusercontent.com/hrydgard/ppsspp/master/Core/MIPS/IR/IRInterpreter.cpp>) | `CPUCore` `IR_INTERPRETER` | 2 | Target (unmeasured). Evidence: "nearly all PSP games at full speed" without JIT, developer statement (<https://www.ppsspp.org/news/live-on-app-store/>) |
| Dreamcast | Flycast JIT-less fork | SH-4 | Fork to be named | Fork's interpreter | 3 | Target (unmeasured). Anecdote: runs poorly on iPhone 16 Pro, reported stable on M4 iPad (<https://mjtsai.com/blog/?p=48998>). Not a benchmark |
| 3DS | Azahar | ARM11 MPCore | Not audited | `use_cpu_jit` and `use_shader_jit` default to true and must be off and compiled out (`docs/03`). Experimental | 3 | Target (unmeasured) |
| Arcade | MAME | Per driver | Not audited | Recompiler paths off; audit per driver | 2 | Target (unmeasured). Load varies widely by driver, so one tier cannot describe every set |
| DOS / Win9x | DOSBox Pure | x86 | Not audited | Normal core only; dynamic core out of the build | 2 | Target (unmeasured). Depends on the guest PC configured |
| Java ME | J2meJS | JVM bytecode | Spike | No-JIT and JS runtime path unverified | 2 | Target (unmeasured). Spike first |
| Symbian | EKA2L1 | ARM | Spike | Interpreter unverified | 3 | Target (unmeasured). Spike first |

**Research, not shipping and not promised.**

- **Dolphin (GameCube, Wii).** Gekko is based on the PowerPC 750CXe. Upstream reports about 30 fps (50% speed) for Mario Kart Wii on an iPhone 16 Pro Max without JIT, on default settings (<https://oatmealdome.me/?p=1695>). This is a data point about Dolphin, not a GagaEmu target.
- **PS2.** S2 is reference code. Its repository holds no device benchmark.

**External sister projects, never catalog rows or frame producers.** S3 and S4 are measured evidence for technique only. On an iPhone 17, S3 reached 59.8 fps at nominal to fair in PS3 game B at a 60 fps cap, with 1% low 44-45 (`S3 log B:192`), and about 8-10 fps in PS3 game A (`S3 log A:623-625`).

### 7.2 Required benchmark method

Adapted from `S3/docs/ios/benchmarks/` and `S4/docs/plans/ios-nojit/benchmark.md`.

**Record for every run:** device model, iOS version, build and core commit, core settings, title and scene, thermal state at start, end and highest, and the input script.

**Metrics:**

- Guest frames per second, and the 1% low.
- CPU time on the core thread per guest frame, in ms. This is the primary metric for retro cores. A game capped at 60 fps hides any speed-up in the fps number, while its ms per frame still falls (`S4 benchmark.md:43-46`).
- CPU time per thread, as a percentage of one core.
- Peak memory footprint, and `os_proc_available_memory()`.
- For interpreters that have them: block lookups per frame, blocks decoded and blocks invalidated.

**Procedure:**

1. Use the same scene and a scripted input loop for at least 60 s. A savestate start is best where the core allows it.
2. Run three times per build. Start with the phone cool. A run that throttles is reported separately, not discarded silently, and is never compared with a cool run.
3. Discard the first run after an install. S3 and S4 both saw unexplained results there (`S3 log A:571`, S4 `ceed20d68`).
4. Compare optimisations in the same run when possible: alternate the two arms every 6-10 s and pool the phases, as in S3 `Config AB` (`10c69c2db`) and S4 `interp_ab_*`. Separate runs drift with heat and scene: S3 saw 10.6 fps at nominal and 7.35 at serious in one scene (`S3 log A:186-187`).
5. Run a null A/B first to find the noise floor. S3's was 0.924-1.061 per run, about ±3% pooled (`S3 log A:314,343`). Do not keep a change inside that band.
6. Test on the oldest supported device and a current one, and record where the busy threads ran. An A19 has 2 P-cores and 4 E-cores.

**Labels:**

| Label | Meaning |
|---|---|
| `measured` | Has a run record as above. Cite it |
| `target (unmeasured)` | A goal, with no run record |
| `reported` | A third-party or developer statement, with its source |
| `estimate` | Engineering guess. Mark it as S3 marks `[est]` |

**Running it (built, milestone 2.8a).** `BenchmarkRun` in `Sources/Debug/BenchmarkHarness.swift` is in debug builds only.

1. Install a Debug build on the iPhone from Xcode: `scripts/build-core.sh`, `scripts/generate-project.sh`, open `GagaEmu.xcodeproj`, choose the phone, Run. Turn off Low Power Mode and let the phone cool.
2. Start a run with Settings > About > Run Benchmark, which plays the generated test ROM for 60 s. Or set launch arguments in the Xcode scheme: `-GagaBenchmark`, optionally `-GagaBenchmarkCore <core_id>` (default `mgba`; the GB, GBC and GBA cores get a generated test ROM, others need a ROM), `-GagaBenchmarkSeconds 60` and `-GagaBenchmarkROM <file name in the ROMs folder>`. The first 5 s are warm-up and are not measured.
3. Wait for "Benchmark finished". Do not touch the screen. A run that backgrounds or pauses is marked `interrupted`.
4. Fetch the record from the Files app, On My iPhone > GagaEmu > Benchmarks, or from Finder's Files tab for the phone. It is named `<core>-<device>-<UTC time>.json`.
5. Repeat for three runs, discarding the first after an install (procedure above). Keep the JSON, and cite it where the core's result is recorded.

The record holds device, OS, build and core commit, core settings, ROM file and SHA-256, input script, frames, fps and 1% low, frame interval, core CPU and wall ms per frame with percentiles, CPU per thread, memory, thermal state at start, end and highest, audio underruns, video drops and any `CodeGenCheck` violations. A Simulator record is labelled "simulator, not a performance measure"; a device record is labelled `measured`. The host app is always a Debug build, as recorded in `hostConfiguration`, while the core keeps its own optimised flags. So core ms per frame carries over to Release, and host thread percentages do not. The generated test ROM is trivial and sets a floor, not a game's load, so `-GagaBenchmarkROM` with a game the owner has the right to use gives the meaningful figure.

---

## 8. Per-core no-JIT gate

**Status: built (milestone 2.7).** Every core build runs this gate before it enters the app, and again on the final binary. Passing a final-binary check once is not enough, because a later core can add a path. Adapted from `S3/scripts/ios/build-core.sh:45-54`. S4 uses a similar symbol check (`S4/scripts/ios/build-core.sh:55`).

**JIT denial is OS enforcement.** iOS applies W^X and offers no public JIT entitlement to App Store apps, so a mapping that asks for write and execute comes back without execute on a device. The gate does not enforce that and could not. It catches a core that would depend on code generation, at build time, before it fails on a phone.

**Static check.** `scripts/nojit-gate.sh` has three modes:

```bash
scripts/nojit-gate.sh <binary or object> [forbidden-strings-regex]   # one core binary
scripts/nojit-gate.sh --entitlements <plist>                         # refuses JIT entitlement keys
scripts/nojit-gate.sh --app <App.app> <entitlements plist>           # everything in a built app
```

`scripts/build-core.sh` runs the first on each slice, with `FORBIDDEN_STRINGS` from `Cores/<id>/core.env`. The app's post-build step runs `--app`, which fails the build if a core in `Cores/` is not embedded, the entitlements ask for `allow-jit`, `allow-unsigned-executable-memory`, `disable-executable-page-protection` or `dynamic-codesigning`, or any binary in the app fails the check. A binary it cannot read fails too. The symbol list is S3's: `_pthread_jit_write_protect_np`, `_sys_icache_invalidate`, `___clear_cache`, `_mach_vm_protect`, `_vm_protect`.

Limits of the static check:

- `mmap` and `mprotect` cannot be banned by symbol. S4 calls `mprotect(PROT_READ)` for a data sentinel (`engine.cpp:103-106`), and `MAP_JIT` is a flag, invisible to `nm`.
- Each core needs its own string list from its audit. Do not grep for bare `jit`. In S3, 12 of the remaining matches were machine-code bytes (`0bb4dc8e9`).

**Build-configuration check.** Each core's build must set its no-JIT option and fail if the option is missing. The table in section 7.1 lists what is known.

**Source audit for startup code generation.** `scripts/build-core.sh` greps the core's compiled source files for the calls below and stops on a hit, which needs a read and a per-core decision. It does not read headers or embedded assemblers, so those stay a manual step. S3 found code generation even in interpreter mode: thread trampolines, SPU and PPU gateways, a 2 GiB W+X arena, RSX copy routines, and reservations with `MAP_JIT` (`S3/docs/ios/research/00-README.md`, "Hidden blocker"). It needed about 15 static replacements and an `IOS_NO_JIT` build (`S3core` commit `30e9f7c42`). Selecting "interpreter" in a core's settings does not prove that no code is generated. Audit each core for:

- `PROT_EXEC`, `MAP_JIT`, `mprotect`, `vm_protect`, `mach_vm_remap`
- `__clear_cache`, `sys_icache_invalidate`
- Embedded assemblers: asmjit, Lightning, xbyak, vixl, and core-specific emitters

**Runtime check.** `CodeGenCheck` in `Sources/Debug/CodeGenCheck.swift`, debug and test builds only, walks the process's memory map with `vm_region_recurse_64` and takes a baseline at startup. Against that baseline it reports a new region that is both writable and executable, and a new executable region that no loaded image owns, as `dladdr` sees it. Asking dyld is what stops a lazily loaded framework from counting as code generation. `GameSession` reports violations when a session stops, the benchmark record lists them, and `Tests/MgbaCoreTests.swift` runs mGBA between two checks, including a positive control that maps executable memory on the Simulator. S4 walks regions with `vm_region_64` on device (`S4/docs/plans/ios-nojit/ios-core.md:57`). This check has run on the Simulator only. The positive control cannot create such a mapping on a device, because the OS refuses it, so a device run shows a clean walk and not a proved detection.

Because RWX `mmap` becomes `rw-` silently, also run each core under test with crash reports collected. An `EXC_BAD_ACCESS` at a jump into a heap address is a gate failure.

---

## 9. Threading, memory and thermal

### 9.1 Threads and QoS

| Work | Current code | Status | Design |
|---|---|---|---|
| Core execution | `DispatchQueue` at `.userInteractive` with a frame timer (`Sources/Bridge/EmulatorCoreProtocol.swift:98-99`) | Built, runs the mock core | Keep the class. Decide queue against dedicated thread once a real core is measured. S3 and S4 use `pthread_set_qos_class_self_np` on their own threads |
| Audio output | `AVAudioEngine` (`Sources/Audio/AudioEngineManager.swift:7`), scheduler queue at `.userInteractive` (`:42`) | Built | The engine's render thread belongs to the system. The app sets QoS only on its scheduler queue |
| Frame presentation | `MTKViewDelegate` `draw(in:)` (`Sources/Metal/MetalRenderer.swift:211,344`) | Built. The renderer creates no thread or queue of its own | No separate render thread exists |
| Wi-Fi transfer | `DispatchQueue` at `.userInitiated` (`Sources/Hub/WiFiTransferServer.swift:24`) | Built | Consider `.utility` so a transfer does not compete with a running core. Not decided |
| Disk I/O and decompression | No dedicated queue | Planned | `.utility` |

`QOS_CLASS_USER_INTERACTIVE` is a preference, not a pin. S3 still saw guest threads spend most samples on E-cores when it ran more busy threads than P-cores: 8-42% of samples per thread on P-cores (`S3 log A:178-180`). Most Tier 1 cores have one busy thread. Multi-thread cores need their thread count tested against 2 P-cores.

### 9.2 Memory

The two entitlements control different limits:

- `com.apple.developer.kernel.extended-virtual-addressing` is address space. It allows larger reservations.
- `com.apple.developer.kernel.increased-memory-limit` is the RAM limit.

`S4/ios/BachataS4/App/BachataS4.entitlements` states this: the emulator reserves about 256 GB of address space, and games need more RAM than the default limit. S2 and S3 carry both keys. **GagaEmu has neither today**: `Sources/App/GagaEmu.entitlements` holds only Game Center. Both must be added to the entitlements file and the App ID before Tier 3 cores.

This document states no fixed ceiling, because the limit varies by device and OS. One data point: S4 read about 6 GB available from `os_proc_available_memory` on an iPhone18,3 with 7672 MiB of RAM and both entitlements (`S4/docs/plans/ios-nojit/device-runs/2026-10-22-iphone-first-launches.md:8`). Cores should read that function and evict caches under pressure, as S4 does (`src/video_core/system_memory.h:52`).

Size the block-op arena per core, and clear it at a safe point when it hits its bound.

### 9.3 Thermal

Thermal state is a first-order input. S3 measured PS3 game B at 59.8 fps at nominal and fair, and at 53-56 fps at serious (`S3 log B:192-193`). Read `ProcessInfo.thermalState` in the benchmark and log it. Any runtime policy that reacts to thermal state is undecided and belongs in `docs/07` if adopted.

---

## 10. Recommendation

1. Ship Tier 1 and Tier 2 cores on their upstream interpreters, built dynarec-free, gated by section 8, with ranks 2 to 4 applied.
2. Build the benchmark in section 7.2 before any optimisation work (milestone 2.8a in `docs/07`). Use it to fill in the core table.
3. Spend effort in this order only when a core misses its target: configuration, then a targeted patch from a profile, then ThinLTO as a measured A/B.
4. If an in-house interpreter is scheduled, Dreamcast is the first candidate. Build in this order: pre-decoded blocks, memory fast path, linking, tail-call dispatch with `preserve_none` as part of the same structure, then profile-driven pairs. Stop adding fused handlers when an A/B no longer beats the noise floor.
5. Do not plan on PS2 or Dolphin from this work. S3's result shows a limit that interpreter tuning does not remove for heavy guests.
