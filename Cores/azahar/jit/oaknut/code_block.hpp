// Sideload JIT build only (Cores/azahar/jit.env), found before oaknut's own code_block.hpp on the include path.
// Upstream maps one region RX on iOS and flips it with mprotect, which TXM refuses. This block is a debugger-prepared
// RX region from Cores/shared/Jit26.c: ptr() is the RX address that every branch, link and relocation is computed
// against, and wptr() is its RW alias, which jit/patch.py's copy of Dynarmic's address_space.cpp gives oaknut's
// CodeGenerator as the write pointer.
#pragma once

#include <cstddef>
#include <cstdint>
#include <new>

#include <libkern/OSCacheControl.h>

#include "Jit26.h"

namespace oaknut {

class CodeBlock {
public:
    explicit CodeBlock(std::size_t size)
        : m_size(size)
    {
        m_memory = static_cast<std::uint32_t*>(gaga_jit26_alloc(size));
        // No region (no debugger, or it gave none): upstream's own failure. jit/patch.py's core.cpp copy turns the
        // first one into the interpreter.
        if (m_memory == nullptr)
            throw std::bad_alloc{};
        m_wmemory = static_cast<std::uint32_t*>(gaga_jit26_writable(m_memory));
    }

    ~CodeBlock()
    {
        gaga_jit26_free(m_memory, m_size);
    }

    CodeBlock(const CodeBlock&) = delete;
    CodeBlock& operator=(const CodeBlock&) = delete;
    CodeBlock(CodeBlock&&) = delete;
    CodeBlock& operator=(CodeBlock&&) = delete;

    std::uint32_t* ptr() const
    {
        return m_memory;
    }

    std::uint32_t* wptr() const
    {
        return m_wmemory;
    }

    // One side stays RX, the other RW: nothing to flip.
    void protect() {}
    void unprotect() {}

    // Always the RX address: the writes went through the alias, the same physical lines.
    void invalidate(std::uint32_t* mem, std::size_t size)
    {
        sys_icache_invalidate(mem, size);
    }

    void invalidate_all()
    {
        invalidate(m_memory, m_size);
    }

protected:
    std::uint32_t* m_memory;
    std::uint32_t* m_wmemory;
    std::size_t m_size = 0;
};

}  // namespace oaknut
