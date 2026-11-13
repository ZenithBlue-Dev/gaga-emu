// Forced into every Azahar file by core.env (-include flags.h), before anything else it includes.
#pragma once

// No network (docs/04 section 8). Azahar's HTTP, SSL, SOC (homebrew sockets), NUS download and room code
// stays compiled, but every route out starts at one of these calls. Renaming them in every file, the
// system headers included, sends each call to a stand-in in AzaharSupport.cpp that refuses it, so the
// framework never imports the socket or name lookup API. Uniform renaming keeps std::bind and the
// members of the same names working. bind is the exception: boost/mpl builds a header name from the word
// bind, so core.env sends it to the stand-in at link time instead (-alias).
#define socket gaga_azahar_no_socket
#define connect gaga_azahar_no_connect
#define listen gaga_azahar_no_listen
#define accept gaga_azahar_no_accept
#define getaddrinfo gaga_azahar_no_getaddrinfo
#define gethostbyname gaga_azahar_no_gethostbyname

// No JIT (docs/04). Upstream picks its ARM11 JIT (Dynarmic), its exclusive monitor and its PICA200 shader
// JIT with CITRA_ARCH(arm64), which boost/predef sets from the compiler. Setting it to 0 sends every one of
// those choices to the interpreters: the dyncom CPU and shader_interpreter.cpp. No JIT file is compiled
// either (generate.py, FORBIDDEN_SOURCES), so a missed selection fails at link time instead of running.
// The sideload JIT build (jit.env, GAGA_CORE_JIT) keeps CITRA_ARCH(arm64) for Dynarmic; its shader.cpp copy
// still picks the shader interpreter.
#if defined(__cplusplus) && !defined(GAGA_CORE_JIT)
#include "common/arch.h"
#undef CITRA_ARCH_arm64
#define CITRA_ARCH_arm64 0
#endif
