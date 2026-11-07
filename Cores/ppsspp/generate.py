#!/usr/bin/env python3
"""Writes Cores/ppsspp/sources.txt, cmake.env and generated/ from upstream's own CMake build.

upstream builds its libretro core with CMake only (libretro/Makefile is stale for iOS). This runs that CMake
configure step once, for iOS arm64 with LIBRETRO=ON, reads compile_commands.json, and keeps every file it
compiles except the ones listed in EXCLUDE. Nothing is built here; scripts/build-core.sh compiles the list.

    Cores/ppsspp/generate.py            needs cmake and ninja (Homebrew), and the submodules in core.env

Each upstream library has its own include paths and defines. The Core library's are the shared flags
(cmake.env); a file whose library adds others gets them after its path on its sources.txt line.
"""
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

here = os.path.dirname(os.path.abspath(__file__))
upstream = os.path.join(here, "upstream")

# The configure options. USE_FFMPEG=OFF: upstream's FFmpeg is prebuilt binaries (ppsspp-ffmpeg), not
# source; without it PSMF/MPEG video is not decoded, and audio uses upstream's own decoders (at3_standalone,
# minimp3). No Discord, no UPnP. HEADLESS and UNITTEST are other programs.
CMAKE_OPTIONS = [
    "-DCMAKE_TOOLCHAIN_FILE=" + os.path.join(upstream, "cmake/Toolchains/ios.cmake"),
    "-DLIBRETRO=ON",
    "-DUSE_FFMPEG=OFF",
    "-DUSE_DISCORD=OFF",
    "-DUSE_MINIUPNPC=OFF",
    "-DHEADLESS=OFF",
    "-DUNITTEST=OFF",
    "-DUSE_CCACHE=OFF",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
]

# Never compiled (docs/03 section 5, PPSSPP licence obligations, has the reasons):
EXCLUDE = [
    # Every CPU JIT back end and code emitter. The CPU runs the IR interpreter (CPUCore::IR_INTERPRETER).
    r"^Core/MIPS/(ARM|ARM64|x86|RiscV|LoongArch64)/",
    r"^Common/(Arm|Arm64|x64|RiscV|LoongArch64)Emitter\.cpp$",
    r"^Common/(Thunk|ABI|x64Analyzer)\.cpp$",
    # The vertex decoder JIT and the software renderer's x86 JIT.
    r"^GPU/Common/VertexDecoder(Arm|Arm64|X86|RiscV|LoongArch64)\.cpp$",
    r"^GPU/Software/(DrawPixelX86|SamplerX86|RasterizerRegCache)\.cpp$",
    # Executable memory. Replaced by Cores/ppsspp/MemoryUtil.cpp, which never maps code.
    r"^Common/MemoryUtil(Horizon)?\.cpp$",
    # Compiled through Cores/ppsspp/JitCommonNoJit.cpp, which selects upstream's FakeJit.
    r"^Core/MIPS/JitCommon/JitCommon\.cpp$",
    # OpenGL and OpenGL ES: not an accepted renderer (docs/05). Video is Vulkan on MoltenVK.
    r"^Common/GPU/OpenGL/",
    r"^GPU/GLES/",
    r"^libretro/LibretroGL(Core)?Context\.cpp$",
    # Compiled through Cores/ppsspp/LibretroVulkanContextGaga.cpp, which gives it a surface.
    r"^libretro/LibretroVulkanContext\.cpp$",
    # Compiled through Cores/ppsspp/LibretroGraphicsContextNoGL.cpp, which has no OpenGL context.
    r"^libretro/LibretroGraphicsContext\.cpp$",
    # OpenXR (VR headsets).
    r"^Common/VR/",
    # Objective-C (build-core.sh compiles C and C++ only). draw_text_cocoa.mm draws UI text, unused here.
    r"\.mm$",
]

# Files CMake generates in its build folder, committed under generated/.
GENERATED = {"include/glslang/build_info.h": "generated/include/glslang/build_info.h"}


def rel(path):
    return os.path.relpath(os.path.realpath(path), here)


def flags_of(command, build):
    """The -I, -D and -U flags of one compile command, as paths relative to Cores/ppsspp."""
    words = shlex.split(command)
    out = []
    i = 0
    while i < len(words):
        w = words[i]
        if w in ("-I", "-isystem"):
            w, i = "-I" + words[i + 1], i + 1
        if w.startswith("-I"):
            path = os.path.realpath(w[2:])
            if path.startswith(os.path.realpath(build)):
                path = os.path.join(here, "generated", os.path.relpath(path, os.path.realpath(build)))
            out.append("-I" + rel(path))
        elif w.startswith(("-D", "-U")) and not w.startswith("-DASSETS_DIR"):
            out.append(w)
        i += 1
    seen = set()
    return [f for f in out if not (f in seen or seen.add(f))]


def extra_flags(flags, base):
    """A file's flags that the shared ones lack. A file whose include paths differ from the shared ones gets
    all of its own first, so its library's headers win (libchdr's own over libretro-common's copies)."""
    extra = [f for f in flags if f not in base]
    own = [f for f in flags if f.startswith("-I")]
    if own != [f for f in base if f.startswith("-I")]:
        extra = own + [f for f in extra if not f.startswith("-I")]
    return extra


def main():
    build = tempfile.mkdtemp(prefix="ppsspp-cmake-")
    try:
        subprocess.run(["cmake", "-S", upstream, "-B", build, "-G", "Ninja"] + CMAKE_OPTIONS,
                       check=True, stdout=subprocess.DEVNULL)
        with open(os.path.join(build, "compile_commands.json")) as f:
            commands = json.load(f)
        for src, dst in GENERATED.items():
            os.makedirs(os.path.dirname(os.path.join(here, dst)), exist_ok=True)
            shutil.copy(os.path.join(build, src), os.path.join(here, dst))

        files = []
        upstream_flags = {}
        base = None
        for entry in commands:
            path = os.path.realpath(entry["file"])
            if not path.startswith(os.path.realpath(upstream) + os.sep):
                continue  # CMake's precompiled-header stub and git-version.cpp (PpssppSupport.cpp has it).
            name = os.path.relpath(path, os.path.realpath(upstream))
            flags = flags_of(entry["command"], build)
            upstream_flags[name] = flags
            if any(re.search(p, name) for p in EXCLUDE) or name in (f for f, _ in files):
                continue
            files.append((name, flags))
            if name == "Core/Core.cpp":
                base = flags
        assert base, "Core/Core.cpp not in compile_commands.json"

        with open(os.path.join(here, "sources.txt"), "w") as out:
            # A file that wraps an upstream one gets that one's flags.
            for name, wraps in (("PpssppCore.c", None), ("PpssppSupport.cpp", None),
                                ("JitCommonNoJit.cpp", "Core/MIPS/JitCommon/JitCommon.cpp"),
                                ("MemoryUtil.cpp", "Common/MemoryUtil.cpp"),
                                ("LibretroVulkanContextGaga.cpp", "libretro/LibretroVulkanContext.cpp"),
                                ("LibretroGraphicsContextNoGL.cpp", "libretro/LibretroGraphicsContext.cpp"),
                                ("../shared/LibretroAdapter.c", None), ("../shared/LibretroVulkan.c", None)):
                extra = extra_flags(upstream_flags.get(wraps, base), base)
                out.write(" ".join([name] + extra) + "\n")
            for name, flags in sorted(files):
                extra = extra_flags(flags, base)
                if name.startswith("ext/libchdr/"):
                    extra += ["-include", "chdr_lzma.h"]
                out.write(" ".join(["upstream/" + name] + extra) + "\n")
        with open(os.path.join(here, "cmake.env"), "w") as out:
            out.write("# Written by generate.py: the include paths and defines of upstream's Core library.\n")
            out.write("cmake_flags='" + " ".join(base) + "'\n")
        print(f"{len(files)} upstream files", file=sys.stderr)
    finally:
        shutil.rmtree(build)


if __name__ == "__main__":
    main()
