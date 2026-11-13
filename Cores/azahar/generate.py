#!/usr/bin/env python3
"""Writes Cores/azahar/sources.txt, cmake.env and generated/ from upstream's own CMake build.

Azahar builds its libretro core (src/citra_libretro) with CMake only. This runs that configure step once, for
iOS arm64 with ENABLE_LIBRETRO=ON, builds only the host_shaders target (GLSL text turned into headers),
reads compile_commands.json, and keeps every file it compiles except the ones listed in EXCLUDE. Nothing
else is built here; scripts/build-core.sh compiles the list.

    Cores/azahar/generate.py            needs cmake and ninja (Homebrew), and the submodules in core.env
    Cores/azahar/generate.py --jit      the sideload JIT build's lists (jit.env): jit-sources.txt and jit-cmake.env,
                                        from the same configure with ENABLE_GENERIC off, so Dynarmic and oaknut are
                                        in. Needs externals/dynarmic, externals/oaknut and dynarmic's externals/mcl.
                                        Leaves sources.txt, cmake.env and generated/ alone.

CMake runs on a copy-on-write copy of upstream without its .git file, because upstream's configure step
copies a pre-commit hook into .git/hooks, which must not touch the pinned submodule.

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

# The configure options (milestone 6.3, docs/07):
# - ENABLE_GENERIC: no architecture, so CMake adds no Dynarmic, oaknut or xbyak. flags.h also sets
#   CITRA_ARCH(arm64) to 0, so no source selects the ARM JIT or the shader JIT.
# - No OpenGL (not an accepted renderer, docs/05). Vulkan on MoltenVK, and the software renderer.
# - ENABLE_BUILTIN_KEYBLOB=OFF: no console keys of any kind ship. Only decrypted content runs.
# - The options libretro forbids (Qt, SDL2, web service, scripting, GDB stub, rooms, OpenAL, cubeb, libusb)
#   are off, as are Qt translations, Discord, microprofile, tests, LTO and precompiled headers.
CMAKE_OPTIONS = [
    "-DCMAKE_SYSTEM_NAME=iOS",
    "-DCMAKE_OSX_ARCHITECTURES=arm64",
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
    "-DENABLE_LIBRETRO=ON",
    "-DENABLE_GENERIC=ON",
    "-DENABLE_VULKAN=ON",
    "-DENABLE_OPENGL=OFF",
    "-DENABLE_SOFTWARE_RENDERER=ON",
    "-DENABLE_BUILTIN_KEYBLOB=OFF",
    "-DENABLE_DISCORD_RPC=OFF",
    "-DENABLE_MICROPROFILE=OFF",
    "-DENABLE_DEVELOPER_OPTIONS=OFF",
    "-DENABLE_TESTS=OFF",
    "-DENABLE_LTO=OFF",
    "-DCITRA_USE_PRECOMPILED_HEADERS=OFF",
    "-DCITRA_WARNINGS_AS_ERRORS=OFF",
    "-DENABLE_QT_TRANSLATION=OFF",
    # glslang: no precompiled header, and no SPIRV-Tools optimizer, which Azahar never calls.
    "-DENABLE_PCH=OFF",
    "-DENABLE_OPT=OFF",
    "-Dtsl-robin-map_DIR=" + os.path.join(here, "cmake"),
]

# Never compiled (docs/03 section 5, Azahar licence obligations, has the reasons):
EXCLUDE = [
    # The PICA200 shader JIT. The interpreter (shader_interpreter.cpp) runs every vertex shader.
    r"^src/video_core/shader/shader_jit",
    # The ARM11 JIT front end. The CPU runs the dyncom interpreter (src/core/arm/dyncom).
    r"^src/core/arm/dynarmic/",
    r"^externals/(dynarmic|oaknut|xbyak)/",
    # OpenGL: not an accepted renderer.
    r"^src/video_core/renderer_opengl/",
    r"^externals/glad/",
    # Objective-C (build-core.sh compiles C and C++ only) and assembly.
    r"\.(mm|m|S|s|asm)$",
]

# The JIT build (--jit) compiles Dynarmic's A32 front end and arm64 back end with oaknut, and nothing else that
# the interpreter build leaves out. Dynarmic's macOS exception handler (a mach exception port, only for fastmem,
# which Azahar never configures) gives way to its generic one, which jit.env adds.
JIT_EXCLUDE = [p for p in EXCLUDE if not p.startswith(r"^src/core/arm/dynarmic/") and "dynarmic|oaknut" not in p] + [
    r"^externals/xbyak/",
    r"^externals/dynarmic/src/dynarmic/backend/exception_handler_",
    r"^externals/dynarmic/src/dynarmic/backend/(x64|riscv64)/",
    r"^externals/dynarmic/src/dynarmic/backend/x64/mig/",
]

# The upstream submodules these files come from, each at the commit upstream 2126.2 records (core.env).
SUBMODULES = ("externals/boost externals/cryptopp externals/fmt externals/inih/inih externals/faad2/faad2 "
              "externals/library-headers externals/soundtouch externals/teakra externals/zstd externals/enet "
              "externals/libressl externals/lodepng/lodepng externals/spirv-headers externals/spirv-tools "
              "externals/glslang externals/sirit/sirit externals/vma externals/vulkan-headers externals/xxHash "
              "externals/libretro-common/libretro-common externals/nihstro externals/dds-ktx")


def flags_of(command, src, build):
    """The -I, -D, -U and -include flags of one compile command, as paths relative to Cores/azahar."""
    words = shlex.split(command)
    out = []
    i = 0

    def path_of(p):
        p = os.path.realpath(p)
        if p.startswith(build + os.sep) or p == build:
            return os.path.join("generated", os.path.relpath(p, build))
        if p.startswith(src + os.sep) or p == src:
            return os.path.join("upstream", os.path.relpath(p, src))
        if p.startswith(os.path.realpath(here) + os.sep):
            return os.path.relpath(p, os.path.realpath(here))  # deps/robin-map
        raise SystemExit(f"include outside upstream and the build folder: {p}")

    while i < len(words):
        w = words[i]
        if w in ("-I", "-isystem", "-iquote"):
            w, i = "-I" + words[i + 1], i + 1
        elif w.startswith("-isystem"):
            w = "-I" + w[len("-isystem"):]
        if w.startswith("-I"):
            out.append("-I" + path_of(w[2:]))
        elif w.startswith(("-D", "-U")):
            out.append(w)
        elif w == "-include":
            out += ["-include", path_of(words[i + 1])]
            i += 1
        i += 1
    seen = set()
    return [f for f in out if not (f in seen or seen.add(f))]


def extra_flags(flags, base):
    """A file's flags that the shared ones lack. A file whose include paths differ from the shared ones gets
    all of its own first, so its library's headers win."""
    extra = [f for f in flags if f not in base]
    own = [f for f in flags if f.startswith("-I")]
    if own != [f for f in base if f.startswith("-I")]:
        extra = own + [f for f in extra if not f.startswith("-I")]
    return extra


def write_jit(files, by_name, base):
    """jit-cmake.env: the Core library's flags that the interpreter build's cmake.env lacks (Dynarmic's, mcl's,
    oaknut's include paths). jit-sources.txt: each file the JIT configure compiles that sources.txt does not, or
    compiles with other flags, as a sources.txt line against those flags. jit.env merges both into its list."""
    with open(os.path.join(here, "cmake.env")) as f:
        default_base = shlex.split(shlex.split(f.read().split("cmake_flags=", 1)[1])[0])
    lost = [f for f in default_base if f not in base]
    if lost:
        raise SystemExit(f"the JIT configure drops interpreter-build flags: {lost}")
    jit_base = [f for f in base if f not in default_base]
    default = {}
    with open(os.path.join(here, "sources.txt")) as f:
        for line in f:
            words = shlex.split(line)
            default[words[0]] = words[1:]
    gone = [n for n in default if n.startswith(("upstream/", "generated/")) and n not in by_name]
    if gone:
        raise SystemExit(f"the JIT configure leaves out interpreter-build files: {gone[:5]}")
    generic = "upstream/externals/dynarmic/src/dynarmic/backend/exception_handler_generic.cpp"
    by_name[generic] = by_name["upstream/externals/dynarmic/src/dynarmic/backend/block_range_information.cpp"]
    lines = []
    for name in sorted(files + [generic]):
        flags = extra_flags(by_name[name], base)
        if name in default and flags == default[name]:
            continue
        if name.startswith("generated/") and name not in default:
            raise SystemExit(f"the JIT configure generates a source the interpreter build lacks: {name}")
        lines.append(" ".join([name] + [shlex.quote(f) for f in flags]) + "\n")
    with open(os.path.join(here, "jit-sources.txt"), "w") as out:
        out.writelines(lines)
    with open(os.path.join(here, "jit-cmake.env"), "w") as out:
        out.write("# Written by generate.py --jit: the Core library's flags that cmake.env lacks in the JIT configure.\n")
        out.write("jit_cmake_flags='" + " ".join(jit_base) + "'\n")
    print(f"{len(lines)} JIT lines, {len(jit_base)} extra Core flags", file=sys.stderr)


def main():
    jit =sys.argv[1:] == ["--jit"]
    if sys.argv[1:] and not jit:
        raise SystemExit("usage: generate.py [--jit]")
    options = [o.replace("ENABLE_GENERIC=ON", "ENABLE_GENERIC=OFF") for o in CMAKE_OPTIONS] if jit else CMAKE_OPTIONS
    exclude = JIT_EXCLUDE if jit else EXCLUDE
    tmp = os.path.realpath(tempfile.mkdtemp(prefix="azahar-cmake-"))
    src, build = os.path.join(tmp, "src"), os.path.join(tmp, "build")
    try:
        subprocess.run(["/bin/cp", "-cR", upstream, src], check=True)  # macOS cp: -c clones (APFS)
        os.remove(os.path.join(src, ".git"))
        # Configure copies the Qt game list's resource file, a submodule the libretro core never uses.
        open(os.path.join(src, "dist/compatibility_list/compatibility_list.qrc"), "a").close()
        # Upstream's own release-archive inputs for scm_rev.cpp (GenerateBuildInfo.cmake), and the commit
        # time as the build date, so the generated files depend only on the pin.
        def git(*args):
            return subprocess.run(["git", "-C", upstream] + list(args), check=True, capture_output=True,
                                  text=True).stdout.strip()
        with open(os.path.join(src, "GIT-COMMIT"), "w") as f:
            f.write(git("rev-parse", "HEAD"))
        with open(os.path.join(src, "GIT-TAG"), "w") as f:
            f.write(git("describe", "--tags", "--exact-match"))
        env = dict(os.environ, SOURCE_DATE_EPOCH=git("log", "-1", "--format=%ct"))
        subprocess.run(["cmake", "-S", src, "-B", build, "-G", "Ninja"] + options,
                       check=True, stdout=subprocess.DEVNULL, env=env)
        subprocess.run(["ninja", "-C", build, "host_shaders"], check=True, stdout=subprocess.DEVNULL)
        with open(os.path.join(build, "compile_commands.json")) as f:
            commands = json.load(f)

        # Only the targets the libretro core links. compile_commands.json lists every configured target.
        wanted = set()
        ninja = subprocess.run(["ninja", "-C", build, "-t", "inputs", "citra_libretro"], check=True,
                               capture_output=True, text=True).stdout.split()
        for name in ninja:
            wanted.add(os.path.realpath(os.path.join(build, name)))

        files, by_name, base = [], {}, None
        for entry in commands:
            path = os.path.realpath(os.path.join(entry["directory"], entry["file"]))
            obj = os.path.realpath(os.path.join(entry["directory"], entry.get("output", "")))
            if obj not in wanted:
                continue
            # Dynarmic's multi-architecture wrapper (CMAKE_OSX_ARCHITECTURES set): an #if for the target
            # architecture around the source itself, which is arm64 here. The source is compiled directly.
            if "/arch_gen/" in path:
                path = path.split("/arch_gen", 1)[1]
            if path.startswith(build + os.sep):
                name = os.path.join("generated", os.path.relpath(path, build))
            else:
                name = os.path.join("upstream", os.path.relpath(path, src))
            flags = flags_of(entry["command"], src, build)
            rel = name.split("/", 1)[1]
            if any(re.search(p, rel) for p in exclude) or name in by_name:
                continue
            by_name[name] = flags
            files.append(name)
            if rel == "src/core/core.cpp":
                base = flags
        assert base, "src/core/core.cpp not in compile_commands.json"
        if jit:
            write_jit(files, by_name, base)
            return

        # Generated files: every source in the build folder, and every header under a build include path.
        shutil.rmtree(os.path.join(here, "generated"), ignore_errors=True)
        copied = set()
        for name in files:
            if name.startswith("generated/"):
                copied.add(os.path.relpath(name, "generated"))
        for flags in by_name.values():
            for f in flags:
                if f.startswith("-Igenerated/"):
                    root = os.path.join(build, f[len("-Igenerated/"):])
                    for d, dirs, names in os.walk(root):
                        dirs[:] = [x for x in dirs if x != "CMakeFiles"]
                        for n in names:
                            if n.endswith((".h", ".hpp", ".inc")):
                                copied.add(os.path.relpath(os.path.join(d, n), build))
        for rel in sorted(copied):
            dst = os.path.join(here, "generated", rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy(os.path.join(build, rel), dst)

        with open(os.path.join(here, "sources.txt"), "w") as out:
            # AzaharSupport.cpp reaches the Vulkan renderer's scheduler, so it takes that file's include paths.
            renderer = "upstream/src/video_core/renderer_vulkan/renderer_vulkan.cpp"
            for name in ("AzaharCore.c", "AzaharSupport.cpp", "../shared/LibretroAdapter.c",
                         "../shared/LibretroVulkan.c"):
                flags = extra_flags(by_name[renderer], base) if name == "AzaharSupport.cpp" else []
                out.write(" ".join([name] + [shlex.quote(f) for f in flags]) + "\n")
            for name in sorted(files):
                # xargs splits these lines, so a quoted define such as -DOPENSSLDIR="/etc/ssl" is quoted again.
                out.write(" ".join([name] + [shlex.quote(f) for f in extra_flags(by_name[name], base)]) + "\n")
        with open(os.path.join(here, "cmake.env"), "w") as out:
            out.write("# Written by generate.py: the include paths and defines of upstream's citra_core library.\n")
            out.write("cmake_flags='" + " ".join(base) + "'\n")
        print(f"{len(files)} upstream files, {len(copied)} generated files", file=sys.stderr)
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
