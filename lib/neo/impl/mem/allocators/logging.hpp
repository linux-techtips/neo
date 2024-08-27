#pragma once

#include <neo/impl/mem/allocator.hpp>

namespace neo::mem {

struct LoggingAllocator {
  Allocator backing_allocator;
  FILE* file = stderr;

  [[nodiscard]]
  constexpr auto allocator(this auto&& self) -> Allocator {
    return {
      .impl = &self,
      .vtable = {
        .realloc = [] (void* impl, u8* data, usize old_size, usize new_size, u8 align) -> u8* {
          auto& self = *reinterpret_cast<LoggingAllocator*>(impl);

          fmt::println(self.file, "[realloc] - data: 0x{:x}, old_size: {}, new_size: {}, align: {}",
            reinterpret_cast<usize>(data), old_size, new_size, align);

          return self.backing_allocator.raw_realloc(data, old_size, new_size, align);
        },
        .dealloc = [] (void* impl, u8* data, usize size) -> void {
          auto& self = *reinterpret_cast<LoggingAllocator*>(impl);

          fmt::println(self.file, "[dealloc] - data: 0x{:x}, size: {}", reinterpret_cast<usize>(data), size);

          return self.backing_allocator.raw_dealloc(data, size);
        },
        .alloc = [] (void* impl, usize size, u8 align) -> u8* {
          auto& self = *reinterpret_cast<LoggingAllocator*>(impl);

          fmt::println(self.file, "[alloc] - size: {}, align: {}", size, align);

          return self.backing_allocator.raw_alloc(size, align);
        },
      },
    };
  }
};

} // neo::mem
