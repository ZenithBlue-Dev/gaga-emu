// Sideload JIT build only (jit.env), in place of upstream/src/common/jit_code_buffer.cpp. The code buffer is a
// debugger-prepared RX region from Cores/shared/Jit26.c that is never re-protected: every pointer this class hands
// out is the RX address, and the bytes it writes itself go through the RW alias. The recompiler writes through that
// alias too (jit.env's copy of cpu_recompiler_code_generator_aarch64.cpp). Otherwise as upstream's file.
#include "common/jit_code_buffer.h"
#include "common/align.h"

#include "Jit26.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <libkern/OSCacheControl.h>

static void* writable(void* rx) { return gaga_jit26_writable(rx); }

JitCodeBuffer::JitCodeBuffer() = default;

JitCodeBuffer::~JitCodeBuffer()
{
  Destroy();
}

bool JitCodeBuffer::Allocate(uint32_t size /* = 64 * 1024 * 1024 */, uint32_t far_code_size /* = 0 */)
{
  Destroy();

  m_total_size = size + far_code_size;
  m_code_ptr = static_cast<uint8_t*>(gaga_jit26_alloc(m_total_size));
  // Upstream compiles its dispatcher into the buffer right after this without checking. Reached only once
  // gaga_jit26_wanted ran its probe region (the execution mode option is Recompiler only then).
  if (!m_code_ptr)
  {
    std::printf("[gaga-core] jit26: no region for the recompiler's %u bytes\n", m_total_size);
    std::fflush(stdout);
    std::abort();
  }

  m_free_code_ptr = m_code_ptr;
  m_code_size = size;
  m_code_used = 0;

  m_far_code_ptr = static_cast<uint8_t*>(m_code_ptr) + size;
  m_free_far_code_ptr = m_far_code_ptr;
  m_far_code_size = far_code_size;
  m_far_code_used = 0;

  m_old_protection = 0;
  m_owns_buffer = true;
  return true;
}

// A caller's buffer would need mprotect to PROT_EXEC, which TXM refuses. cpu_code_cache.cpp uses Allocate on Apple.
bool JitCodeBuffer::Initialize(void* buffer, uint32_t size, uint32_t far_code_size /* = 0 */, uint32_t guard_size /* = 0 */)
{
  (void)buffer;
  (void)size;
  (void)far_code_size;
  (void)guard_size;
  Destroy();
  return false;
}

void JitCodeBuffer::Destroy()
{
  if (m_owns_buffer)
    gaga_jit26_free(m_code_ptr, m_total_size);

  m_code_ptr = nullptr;
  m_free_code_ptr = nullptr;
  m_code_size = 0;
  m_code_reserve_size = 0;
  m_code_used = 0;
  m_far_code_ptr = nullptr;
  m_free_far_code_ptr = nullptr;
  m_far_code_size = 0;
  m_far_code_used = 0;
  m_total_size = 0;
  m_guard_size = 0;
  m_old_protection = 0;
  m_owns_buffer = false;
}

void JitCodeBuffer::ReserveCode(uint32_t size)
{
  m_code_reserve_size += size;
  m_free_code_ptr += size;
  m_code_size -= size;
}

void JitCodeBuffer::CommitCode(uint32_t length)
{
  if (length == 0)
    return;

  // ARM instruction and data caches are not coherent, we need to flush after every block.
  FlushInstructionCache(m_free_code_ptr, length);

  m_free_code_ptr += length;
  m_code_used += length;
}

void JitCodeBuffer::CommitFarCode(uint32_t length)
{
  if (length == 0)
    return;

  FlushInstructionCache(m_free_far_code_ptr, length);

  m_free_far_code_ptr += length;
  m_far_code_used += length;
}

void JitCodeBuffer::Reset()
{
  /* Nothing allocated when running the interpreter. */
  if (!m_code_ptr)
    return;

  m_free_code_ptr = m_code_ptr + m_guard_size + m_code_reserve_size;
  m_code_used = 0;
  std::memset(writable(m_free_code_ptr), 0, m_code_size);
  FlushInstructionCache(m_free_code_ptr, m_code_size);

  if (m_far_code_size > 0)
  {
    m_free_far_code_ptr = m_far_code_ptr;
    m_far_code_used = 0;
    std::memset(writable(m_free_far_code_ptr), 0, m_far_code_size);
    FlushInstructionCache(m_free_far_code_ptr, m_far_code_size);
  }
}

void JitCodeBuffer::Align(uint32_t alignment, uint8_t padding_value)
{
  const uint32_t num_padding_bytes =
    std::min(static_cast<uint32_t>(Common::AlignUpPow2(reinterpret_cast<uintptr_t>(m_free_code_ptr), alignment) -
                              reinterpret_cast<uintptr_t>(m_free_code_ptr)),
             GetFreeCodeSpace());
  std::memset(writable(m_free_code_ptr), padding_value, num_padding_bytes);
  m_free_code_ptr += num_padding_bytes;
  m_code_used += num_padding_bytes;
}

// Takes the RX address, which is the one that runs. sys_icache_invalidate also cleans the data cache by address.
void JitCodeBuffer::FlushInstructionCache(void* address, uint32_t size)
{
  sys_icache_invalidate(address, size);
}
