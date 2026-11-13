// What upstream's build generates or links that this build replaces (generate.py, flags.h). Nothing here
// generates or runs code: every definition is a pointer accessor, a constant answer, or an empty body.
#include <stddef.h>
#include <string.h>

#include <dlfcn.h>

#include <chrono>
#include <filesystem>
#include <thread>

#include "Common/Arm64Emitter.h"
#include "Common/GPU/OpenGL/GLFeatures.h"
#include "Common/VR/PPSSPPVR.h"
#include "Core/System.h"
#include "GPU/Common/VertexDecoderCommon.h"
#include "GPU/Software/RasterizerRegCache.h"

// git-version.cpp, which CMake writes from `git describe`.
const char *PPSSPP_GIT_VERSION = "v1.20.4";

// flags.h renames dlopen to this: no library is ever loaded by name.
extern "C" void *gaga_ppsspp_no_dlopen(const char *path, int mode) {
	(void)path;
	(void)mode;
	return NULL;
}

// The ARM64 code emitter (Common/Arm64Emitter.cpp) is not compiled. The vertex decoder and the software
// renderer still hold an ARM64CodeBlock, and the ARM64 disassembler decodes float immediates, so these are
// upstream's own bodies for the parts that never emit an instruction. The code space they point into is
// never allocated: AllocateExecutableMemory returns null (MemoryUtil.cpp). The sideload JIT build (jit.env) compiles both.
#ifndef GAGA_CORE_JIT
namespace Arm64Gen {
void ARM64XEmitter::SetCodePointer(const u8 *ptr, u8 *writePtr) {
	m_code = ptr;
	m_writable = writePtr;
	m_lastCacheFlushEnd = ptr;
}
const u8 *ARM64XEmitter::GetCodePointer() const { return m_code; }
u8 *ARM64XEmitter::GetWritableCodePtr() { return m_writable; }
void ARM64CodeBlock::PoisonMemory(int offset) { (void)offset; }

float FPImm8ToFloat(uint8_t bits) {
	int sign = bits >> 7;
	uint32_t f = 0;
	f |= (sign << 31);
	int bit6 = (bits >> 6) & 1;
	uint32_t exp = ((!bit6) << 7) | (0x7C * bit6) | ((bits >> 4) & 3);
	uint32_t mantissa = (bits & 0xF) << 19;
	f |= exp << 23;
	f |= mantissa;
	float fl;
	memcpy(&fl, &f, sizeof(float));
	return fl;
}
}  // namespace Arm64Gen

// The vertex decoder JIT (VertexDecoderArm64.cpp) is not compiled. DrawEngineCommon only makes a
// VertexDecoderJitCache for the JIT CPU cores; the IR interpreter decodes vertices in C++.
JittedVertexDecoder VertexDecoderJitCache::Compile(const VertexDecoder &dec, int32_t *jittedSize) {
	(void)dec;
	*jittedSize = 0;
	return nullptr;
}
#endif

// The software renderer's code block (RasterizerRegCache.cpp) is not compiled. Upstream compiles pixel and
// sampler functions on x86-64 only; on ARM64 its Compile calls only Clear, so no space is needed.
namespace Rasterizer {
CodeBlock::CodeBlock(int size) : fp(this) { (void)size; }
std::string CodeBlock::DescribeCodePtr(const u8 *ptr) {
	(void)ptr;
	return std::string();
}
void CodeBlock::Clear() { descriptions_.clear(); }
}  // namespace Rasterizer

// retro_load_game starts PPSSPP's ExecLoader thread and returns. Unloading before it finishes shuts the kernel
// down under it (a null idle thread in __KernelStartIdleThreads), and frames run before it finishes show
// nothing. The first retro_run joins the finished thread and brings the GPU up on the context.
// A loader that is still running after 30 s is stuck. PSP_Shutdown under it crashes and nothing here can stop
// it, so the message makes the adapter fail the load and leak the instance instead of unloading it.
extern "C" const char *gaga_ppsspp_finish_load(void) {
	const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(30);
	while (PollBootState() == BootState::Booting) {
		if (std::chrono::steady_clock::now() >= deadline) return "The game took too long to start.";
		std::this_thread::sleep_for(std::chrono::milliseconds(2));
	}
	return nullptr;
}

// The frontend reads compat.ini, ppge_atlas.zim, the flash0 fonts and the VFPU tables from <system>/PPSSPP
// (libretro.cpp, retro_init); without them dialogs and font text draw nothing. build-core.sh puts upstream's
// copies in this framework's System folder, and this copies any missing or older file there before each
// load. It never refuses: a failed copy leaves the game as it ran without them.
extern "C" const char *gaga_ppsspp_install_assets(const char *system_dir, const char *rom_path) {
	(void)rom_path;
	Dl_info info;
	if (!system_dir || !dladdr((const void *)&gaga_ppsspp_install_assets, &info) || !info.dli_fname) return nullptr;
	namespace fs = std::filesystem;
	std::error_code error;
	const fs::path target = fs::path(system_dir) / "PPSSPP";
	fs::create_directories(target, error);
	fs::copy(fs::path(info.dli_fname).parent_path() / "System", target,
	         fs::copy_options::recursive | fs::copy_options::update_existing, error);
	return nullptr;
}

// OpenGL is not compiled (flags.h). The shader generators read these only for GLSL output, which Vulkan
// never asks for.
GLExtensions gl_extensions;
int GLExtensions::GLSLVersion() { return 0; }

// Common/VR (OpenXR) is not compiled. No headset is ever present.
bool IsVREnabled() { return false; }
bool IsBigScreenVRMode() { return false; }
bool IsFlatVRGame() { return false; }
bool IsGameVRScene() { return false; }
bool IsImmersiveVRMode() { return false; }
