#!/usr/bin/env python3
"""Sideload JIT build only (Cores/azahar/jit.env): writes build-time copies of four upstream files into <out>.
Upstream is never changed. Each replacement must match exactly as often as expected, so a new pin fails here
instead of building something unreviewed.

    jit/patch.py <Cores/azahar/upstream> <out>
"""
import os
import sys

upstream, out = sys.argv[1], sys.argv[2]

FALLBACK = """        try {
            for (u32 i = 0; i < num_cores; ++i) {
                cpu_cores.push_back(std::make_shared<ARM_Dynarmic>(
                    *this, *memory, i, timing->GetTimer(i), *exclusive_monitor));
            }
        } catch (const std::bad_alloc&) {
            // Jit26: no debugger-prepared code region (oaknut::CodeBlock, jit/oaknut/code_block.hpp). The CPU
            // runs the interpreter, as with the JIT off.
            std::printf("[gaga-core] jit26: Dynarmic got no code region: interpreter\\n");
            cpu_cores.clear();
            Settings::values.use_cpu_jit = false;
            exclusive_monitor = MakeExclusiveMonitor(*memory, num_cores);
            for (u32 i = 0; i < num_cores; ++i) {
                cpu_cores.push_back(
                    std::make_shared<ARM_DynCom>(*this, *memory, USER32MODE, i, timing->GetTimer(i)));
            }
        }
"""

LATER = """    std::unique_ptr<Dynarmic::A32::Jit> new_jit;
    try {
        new_jit = MakeJit();
    } catch (const std::bad_alloc&) {
        // Jit26: no code region for a later page table. The first is core.cpp's to turn into the interpreter.
        // Later, this CPU stops and the session ends with a message, rather than run another process's code.
        if (!jit) {
            throw;
        }
        std::printf("[gaga-core] jit26: no code region for a new process: emulation stops\\n");
        break_flag = true;
        system.SetStatus(Core::System::ResultStatus::ErrorUnknown,
                         "The JIT ran out of code memory. Turn off JIT for this game.");
        return;
    }
"""

PATCHES = {
    # oaknut writes through the RW alias (CodeBlock::wptr); every address it computes stays the RX one (ptr).
    "externals/dynarmic/src/dynarmic/backend/arm64/address_space.cpp": [
        ("mem.ptr(), mem.ptr()", "mem.wptr(), mem.ptr()", 3),
    ],
    "src/core/arm/dynarmic/arm_dynarmic.cpp": [
        ("#include <csignal>\n", "#include <csignal>\n#include <cstdio>\n#include <new>\n", 1),
        # Upstream's default is 128 MiB per JIT, one JIT per CPU core and page table. Each is a debugger region.
        ("    config.define_unpredictable_behaviour = true;\n",
         "    config.define_unpredictable_behaviour = true;\n    config.code_cache_size = 32 * 1024 * 1024;\n", 1),
        ("    auto new_jit = MakeJit();\n", LATER, 1),
    ],
    "src/core/core.cpp": [
        ("#include <stdexcept>\n", "#include <cstdio>\n#include <new>\n#include <stdexcept>\n", 1),
        ("""        for (u32 i = 0; i < num_cores; ++i) {
            cpu_cores.push_back(std::make_shared<ARM_Dynarmic>(
                *this, *memory, i, timing->GetTimer(i), *exclusive_monitor));
        }
""", FALLBACK, 1),
    ],
    # No PICA200 shader JIT: it maps one code block per shader, which a debugger region per shader cannot serve.
    "src/video_core/shader/shader.cpp": [
        ("CITRA_ARCH(x86_64) || CITRA_ARCH(arm64)", "0 /* Jit26: shader interpreter only */", 2),
    ],
}

for rel, edits in PATCHES.items():
    with open(os.path.join(upstream, rel)) as f:
        text = f.read()
    for old, new, count in edits:
        if text.count(old) != count:
            raise SystemExit(f"jit/patch.py: upstream {rel} changed ({old.strip()[:40]!r}); review the copy")
        text = text.replace(old, new)
    dst = os.path.join(out, os.path.basename(rel))
    os.makedirs(out, exist_ok=True)
    with open(dst, "w") as f:
        f.write(text)
