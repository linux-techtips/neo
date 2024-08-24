#pragma once

#include <impl/mem/allocator.hpp>
#include <impl/mem/align.hpp>

namespace {

extern "C" auto malloc(usize size) -> void*;
extern "C" auto free(void*) -> void;

} // anon

namespace neo::mem {

[[maybe_unused]]
constexpr static auto c_allocator = Allocator {
  .impl = nullptr,
  .vtable = {
    .realloc = [] (void*, u8* data, usize old_size, usize new_size, u8) -> u8* {
      return (new_size <= old_size) ? data : nullptr;
    },
    .dealloc = [] (void*, u8* data, usize) -> void {
      free(__builtin_bit_cast(u8**, data)[-1]);
    },
    .alloc = [] (void*, usize size, u8 log2_align) -> u8* {
      const auto align = 1ull << log2_align;

      auto* data = __builtin_bit_cast(usize*, malloc(size + align - 1 + sizeof(u8*)));

      auto unaligned_addr = __builtin_bit_cast(usize, data);
      auto aligned_addr = align_forward(unaligned_addr + sizeof(u8*), align);

      auto aligned_ptr = __builtin_bit_cast(usize**, unaligned_addr + (aligned_addr - unaligned_addr));

      aligned_ptr[-1] = data;

      return __builtin_bit_cast(u8*, aligned_ptr);
    }
  },
};

} // neo::mem
