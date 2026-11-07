#!/usr/bin/env python3
"""Writes Cores/mame/sources.txt and Cores/mame/generated/ from drivers.flt. Run it after changing
drivers.flt or the upstream pin; scripts/build-core.sh never runs it, or anything upstream.

It does what MAME's own makefile does before compiling, in a temporary folder: builds GENie from
upstream/3rdparty/genie, asks it for the libretro (OSD "retro") projects of the machines in
drivers.flt with the iOS options of upstream's Makefile.libretro, then runs upstream's generator rules
(layouts, CPU tables, the driver list, the UI font). Needs Xcode and python3, nothing else.

    Cores/mame/generate.py
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

here = os.path.dirname(os.path.abspath(__file__))
up = os.path.join(here, "upstream")

# Upstream sources replaced by files in Cores/mame: the web server, socket and network output files open
# sockets and netlist's library loader loads code (MameSupport.cpp), and the OSD library maps executable memory, changes page protection and loads
# libraries for the recompilers and optional modules (MameOsdLib.cpp).
replaced = {
    "src/emu/http.cpp",
    "src/osd/modules/file/posixsocket.cpp",
    "src/osd/modules/lib/osdlib_retro.cpp",
    "src/osd/modules/output/network.cpp",
    "src/lib/netlist/plib/pdynlib.cpp",
}
# Upstream links static libraries, so a file no machine reaches is dropped. build-core.sh links every
# object, so these, which only name devices this build has not got, are left out instead.
unreached = {
    "src/devices/cpu/m6502/gew7.cpp",
    "src/devices/cpu/m6502/rp2a03.cpp",
    "src/devices/cpu/m68000/mcf5206e.cpp",
    "src/devices/cpu/m6805/m68hc05pge.cpp",
    "src/devices/cpu/z80/tmpz84c015.cpp",
    "src/devices/cpu/z80/z84c015.cpp",
    "src/devices/imagedev/mfmhd.cpp",
    "src/devices/machine/terminal.cpp",
}


def run(args, **kwargs):
    subprocess.run(args, check=True, **kwargs)


def main():
    # Real path: GENie writes paths relative to it, and /var is a symlink on macOS.
    work = os.path.realpath(tempfile.mkdtemp(prefix="gaga-mame-"))
    try:
        genie = os.path.join(work, "genie")
        g = os.path.join(up, "3rdparty", "genie")
        make = open(os.path.join(g, "build", "gmake.darwin", "genie.make")).read()
        genie_sources = sorted({os.path.join(g, o + ".c") for o in re.findall(r"\$\(OBJDIR\)/(src/host/\S+)\.o", make)})
        run(["xcrun", "clang", "-Os", "-w", "-DNDEBUG", "-DLUA_COMPAT_MODULE", "-DLUA_USE_MACOSX",
             "-I" + os.path.join(g, "src", "host", "lua-5.3.0", "src"), "-o", genie] + genie_sources
            + ["-framework", "CoreServices"])

        # GENie reads --build-dir and SOURCEFILTER relative to the MAME folder.
        build = os.path.relpath(os.path.join(work, "build"), up)
        flt = os.path.relpath(os.path.join(here, "drivers.flt"), up)
        run([genie, "--file=scripts/genie.lua", "--build-dir=" + build, "--osd=retro", "--target=mame",
             "--subtarget=gaga", "--targetos=macosx", "--PLATFORM=arm64", "--NOASM=1", "--DONT_USE_NETWORK=1",
             "--NO_USE_MIDI=1", "--NO_OPENGL=1", "--USE_QTDEBUG=0", "--NO_USE_PORTAUDIO=1", "--LIBRETRO_IOS=1",
             "--LIBRETRO_OS=macosx", "--LIBRETRO_CPU=arm64", "--PYTHON_EXECUTABLE=" + sys.executable,
             "--SOURCEFILTER=" + flt, "--with-emulator", "--gcc=osx-clang", "--gcc_version=170000", "gmake"],
            cwd=up, stdout=subprocess.DEVNULL)

        projects = os.path.join(work, "build", "projects", "retro", "mamegaga", "gmake-osx-clang")
        upstream_prefix = None
        sources = []
        for path in sorted(glob.glob(os.path.join(projects, "*.make"))):
            name = os.path.basename(path)[:-5]
            text = open(path).read()
            release = re.search(r"ifeq \(\$\(config\),release64\)(.*?)\nendif\n", text, re.S).group(1)
            rules = {}
            for m in re.finditer(r"\n\$\(OBJDIR\)/(\S+?)\.o: (\S+)[^\n]*\n((?:\t[^\n]*\n)+)", text):
                rules[m.group(1)] = (m.group(2), "$(CXX)" in m.group(3))
            # Run every generator rule: a target under generated/ built by a python script. A few of
            # dasm.make's name inputs upstream does not have; nothing compiled includes those outputs.
            for m in re.finditer(r"\n(\S+): (\S+)[^\n]*\n((?:\t[^\n]*\n)+)", text):
                if m.group(1).startswith("../../../../generated/") and "python" in m.group(3).lower():
                    made = subprocess.run(["make", "-s", "-f", os.path.basename(path), "config=release64", m.group(1)],
                                          cwd=projects, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                    if made.returncode:
                        print("not generated: %s: %s" % (m.group(1).split("generated/", 1)[1], made.stderr.strip()[-200:]))
            if name == "precompile":
                continue  # The precompiled emu.h only.
            for obj in re.findall(r"\$\(OBJDIR\)/(\S+?)\.o", release):
                source, cxx = rules[obj]
                if source.startswith("../../../../generated/"):  # The build's, not src/lib/netlist/generated.
                    sources.append("generated/" + source.split("/generated/", 1)[1])
                    continue
                rel = source.split("/Cores/mame/upstream/", 1)[1]
                if rel in replaced or rel in unreached or "upstream/" + rel in sources:  # retromain.cpp is in two projects.
                    continue
                if cxx and rel.endswith(".c"):
                    # Upstream compiles this C file as C++ (Lua, so sol2 can use it), and build-core.sh picks
                    # the compiler by extension.
                    wrapper = os.path.join("generated", "cxx", rel + ".cpp")
                    os.makedirs(os.path.dirname(os.path.join(work, wrapper)), exist_ok=True)
                    with open(os.path.join(work, wrapper), "w") as f:
                        f.write('#include "%s"\n' % rel)
                    sources.append(wrapper)
                else:
                    sources.append("upstream/" + rel)

        generated = os.path.join(work, "build", "generated")
        # Machine layouts are not in the projects: upstream's makefile compresses every src/mame/layout/*.lay.
        # This does the same for the ones the compiled sources include.
        for source in sources:
            if not source.startswith("upstream/src/mame/"):
                continue
            for name in re.findall(r'#include "(\w+)\.lh"', open(os.path.join(here, source), errors="ignore").read()):
                lay = os.path.join(up, "src", "mame", "layout", name + ".lay")
                lh = os.path.join(generated, "mame", "layout", name + ".lh")
                if os.path.exists(lay) and not os.path.exists(lh):
                    os.makedirs(os.path.dirname(lh), exist_ok=True)
                    run([sys.executable, os.path.join(up, "scripts", "build", "complay.py"), lay, lh, "layout_" + name])
        # makedep.py lists every machine in mame.lst for a filter that names no source file, so the list
        # is written here the way its DriverLister writes one: the filter's machines and the empty one.
        drivers = sorted(set(re.findall(r"^\+(\w+)", open(os.path.join(here, "drivers.flt")).read(), re.M)) | {"___empty"})
        with open(os.path.join(generated, "mame", "gaga", "drivlist.cpp"), "w") as f:
            f.write('#include "emu.h"\n\n#include "drivenum.h"\n\n')
            f.writelines("GAME_EXTERN(%s);\n" % d for d in drivers)
            f.write("\ngame_driver const *const driver_list::s_drivers_sorted[%d] =\n{\n" % len(drivers))
            f.writelines("\t&GAME_NAME(%s),\n" % d for d in drivers)
            f.write("};\n\nstd::size_t const driver_list::s_driver_count = %d;\n" % len(drivers))
        # The same list for import, which places a .zip named after one of these as Arcade.
        with open(os.path.join(here, "..", "..", "Sources", "App", "MameMachines.swift"), "w") as f:
            f.write("// Written by Cores/mame/generate.py from drivers.flt. Do not edit.\n\n")
            f.write("extension CoreCatalog {\n    /// The machines this build's MAME lists, by short name.\n")
            f.write("    static let mameMachines: Set<String> = [\n")
            f.writelines('        "%s",\n' % d for d in drivers if d != "___empty")
            f.write("    ]\n}\n")
        with open(os.path.join(generated, "version.cpp"), "w") as f:
            version = re.search(r'BARE_BUILD_VERSION "([0-9.]+)"', open(os.path.join(up, "makefile")).read()).group(1)
            commit = subprocess.run(["git", "-C", up, "rev-parse", "--short=8", "HEAD"], check=True,
                                    capture_output=True, text=True).stdout.strip()
            f.write('#define BARE_BUILD_VERSION "%s"\n#define BARE_VCS_REVISION "%s"\n' % (version, commit))
            f.write("extern const char bare_build_version[];\nextern const char bare_vcs_revision[];\n")
            f.write("extern const char build_version[];\n")
            f.write("const char bare_build_version[] = BARE_BUILD_VERSION;\n")
            f.write("const char bare_vcs_revision[] = BARE_VCS_REVISION;\n")
            f.write('const char build_version[] = BARE_BUILD_VERSION " (" BARE_VCS_REVISION ")";\n')
        if os.path.isdir(os.path.join(work, "generated", "cxx")):
            shutil.copytree(os.path.join(work, "generated", "cxx"), os.path.join(generated, "cxx"))
        for leftover in glob.glob(os.path.join(generated, "**", "*.flt"), recursive=True):
            os.remove(leftover)

        out = os.path.join(here, "generated")
        shutil.rmtree(out, ignore_errors=True)
        shutil.copytree(generated, out)
        with open(os.path.join(here, "sources.txt"), "w") as f:
            for source in sources + ["../shared/LibretroAdapter.c", "MameCore.c", "MameSupport.cpp", "MameOsdLib.cpp"]:
                f.write(source + "\n")
        print("%d sources, generated/ from %s" % (len(sources), os.path.relpath(generated, work)))
    finally:
        shutil.rmtree(work, ignore_errors=True)


main()
