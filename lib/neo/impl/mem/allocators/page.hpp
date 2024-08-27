#pragma once

#include <neo/impl/mem/allocator.hpp>
#include <neo/impl/mem/align.hpp>

#include <neo/sys>
#include <sys/mman.h>

namespace neo::mem {

// TODO: Atomic when multi_threading
thread_local static u8* next_heap_addr = nullptr;

[[maybe_unused]]
constexpr static auto page_allocator = Allocator {
  .impl = nullptr,
  .vtable = {
    .realloc = [] (void*, u8* data, usize old_size, usize new_size, u8) -> u8* {
      static_assert(sys::os == sys::Os::Linux);

      const auto aligned_new_size = align_forward(new_size, sys::page_size);
      const auto aligned_old_size = align_forward(old_size, sys::page_size);

      auto* new_data = reinterpret_cast<u8*>(mremap(
        data,
        aligned_old_size,
        aligned_new_size,
        MREMAP_MAYMOVE | MREMAP_DONTUNMAP));

      if (new_data != MAP_FAILED) [[likely]] {
        next_heap_addr = new_data + aligned_new_size; 
        return new_data;
      
      } else return nullptr;
    },
    .dealloc = [] (void*, u8* data, usize size) -> void {
      static_assert(sys::os == sys::Os::Linux);

      munmap(data, align_forward(size, sys::page_size));
    },
    .alloc = [] (void*, usize size, u8) -> u8* {
      static_assert(sys::os == sys::Os::Linux);

      const auto aligned_size = align_forward(size, sys::page_size);

      const auto map_flag = MAP_PRIVATE | MAP_ANON;
      const auto prot = PROT_READ | PROT_WRITE; 

      if (auto* data = reinterpret_cast<u8*>(mmap(next_heap_addr, aligned_size, prot, map_flag, -1, 0))) {
        next_heap_addr = data + aligned_size;
        return data;
      
      } else return nullptr;
    },
  },
};

} // neo::mem;
