// Common/MemArenaDarwin.cpp for GagaEmu, in place of upstream's (docs/07, device run 13). Upstream probes on iOS
// for a base between 4 and 6 GiB where every PSP memory view fits at a fixed address. That range also holds the
// app's frameworks, about 700 MB, and its heap, so after many cores had run in one process no base was free:
// vm_remap failed with KERN_NO_SPACE (3) at each try and Memory::Init failed ("[BOOT] Memory init failed").
// Here the views and the arena behind them each get one block of address space, reserved when the framework
// loads and reused by every game after. Memory is only ever readable and writable: vm_remap maps the arena's
// read-write pages a second time and nothing changes a page's protection (docs/04).
#include "ppsspp_config.h"

#if defined(__APPLE__)

#include <mach/mach.h>
#include <mach/vm_map.h>

#include "Common/Log.h"
#include "Common/MemArena.h"

namespace {

// The end of the highest view Memory_TryBase maps on iOS, where MASKED_PSP_MEMORY folds every address into
// 1 GiB and the kernel mirrors are skipped: the third RAM view starts at 0x0BE00000 and is at most 31 MiB.
constexpr vm_size_t kViewSpan = 0x0E000000;
// What MemoryMap_Setup asks GrabMemSpace for, at most: 64 KiB null page, 16 KiB scratchpad, four 2 MiB VRAM
// views and three 31 MiB RAM views, about 101 MiB.
constexpr vm_size_t kArenaSize = 0x07000000;

vm_address_t s_views = 0;
vm_address_t s_arena = 0;

// Address space only: no page is touched, so a reservation costs no memory.
vm_address_t Reserve(vm_size_t size) {
	vm_address_t address = 0;
	return vm_allocate(mach_task_self(), &address, size, VM_FLAGS_ANYWHERE) == KERN_SUCCESS ? address : 0;
}

// Fresh zero-filled pages over a range of a block reserved here: the block stays held, and the pages the last
// game wrote go back to the system.
bool Refill(vm_address_t address, vm_size_t size) {
	return vm_allocate(mach_task_self(), &address, size, VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE) == KERN_SUCCESS;
}

bool InViews(vm_address_t address, vm_size_t size) {
	return s_views && address >= s_views && address + size <= s_views + kViewSpan;
}

// At framework load, before any core has filled the address space.
__attribute__((constructor)) void ReserveAtLoad() {
	s_views = Reserve(kViewSpan);
	s_arena = Reserve(kArenaSize);
}

}  // namespace

size_t MemArena::roundup(size_t x) {
	return x;
}

bool MemArena::GrabMemSpace(size_t size) {
	vm_size = size;
	if (s_arena && size <= kArenaSize && Refill(s_arena, kArenaSize)) {
		vm_mem = s_arena;
		return true;
	}
	kern_return_t retval = vm_allocate(mach_task_self(), &vm_mem, size, VM_FLAGS_ANYWHERE);
	if (retval != KERN_SUCCESS) {
		ERROR_LOG(Log::MemMap, "Failed to grab a block of virtual memory");
		return false;
	}
	return true;
}

void MemArena::ReleaseSpace() {
	if (vm_mem && vm_mem == s_arena) {
		if (!Refill(s_arena, kArenaSize)) {
			vm_deallocate(mach_task_self(), s_arena, kArenaSize);
			s_arena = 0;
		}
	} else if (vm_mem) {
		vm_deallocate(mach_task_self(), vm_mem, vm_size);
	}
	vm_size = 0;
	vm_mem = 0;
}

void *MemArena::CreateView(s64 offset, size_t size, void *base) {
	mach_port_t self = mach_task_self();
	vm_address_t target = (vm_address_t)base;
	// Inside the reserved block the view replaces the reservation. Elsewhere the range must be free, as upstream.
	int flags = InViews(target, size) ? VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE : VM_FLAGS_FIXED;
	vm_address_t source = vm_mem + offset;
	vm_prot_t cur_protection = 0;
	vm_prot_t max_protection = 0;
	kern_return_t retval = vm_remap(self, &target, size, 0, flags, self, source, false,
									&cur_protection, &max_protection, VM_INHERIT_DEFAULT);
	if (retval != KERN_SUCCESS) {
		ERROR_LOG(Log::MemMap, "vm_remap failed (%d) - could not remap from %llx (offset %llx) of size %llx to %p",
				  (int)retval, (uint64_t)source, (uint64_t)offset, (uint64_t)size, base);
		return nullptr;
	}
	return (void *)target;
}

void MemArena::ReleaseView(s64 offset, void *view, size_t size) {
	(void)offset;
	vm_address_t address = (vm_address_t)view;
	if (InViews(address, size) && Refill(address, size))
		return;
	vm_deallocate(mach_task_self(), address, size);
}

bool MemArena::NeedsProbing() {
	return false;
}

// MemoryMap_Setup maps every view at this base. Nil, as when the reservation failed twice, fails Memory::Init.
u8 *MemArena::Find4GBBase() {
	if (!s_views)
		s_views = Reserve(kViewSpan);
	return (u8 *)s_views;
}

#endif  // __APPLE__
