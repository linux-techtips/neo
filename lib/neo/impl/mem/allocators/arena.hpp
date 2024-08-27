#pragma once

#include <neo/impl/mem/allocator.hpp>
#include <neo/impl/mem/align.hpp>

namespace neo::mem {

struct Arena {
  Allocator backing_allocator;

  struct Chunk {
    // NOTE: This structure is left intetionally large. 
    // In the future it will be benchmarked to figure out what to remove,
    // but for the sake of rapid development and figuring out what can be removed, we will give it *ALL* the data.
    Chunk* prev;
    Chunk* next;

    usize size;
    usize used;

    [[nodiscard]]
    auto data(this auto&& self) -> u8* {
      return &self.as_raw_bytes()[sizeof(Chunk)];
    }

    [[nodiscard]]
    constexpr auto grow(this auto&& self, usize size) -> u8* {
      auto* data = &self.data()[self.used];
      
      self.used = size;

      return data; 
    }

    [[nodiscard]]
    constexpr auto actual_size(this auto&& self) -> usize {
      return self.size + sizeof(Chunk);
    }

    [[nodiscard]]
    auto as_raw_bytes(this auto&& self) -> u8* {
      return __builtin_bit_cast(u8*, &self);
    }
  };

  Chunk* chunk;

  [[nodiscard]]
  constexpr static auto init(Allocator backing_allocator) -> Arena {
    return { backing_allocator };
  }

  constexpr auto deinit(this auto&& self) -> void {
    if (__builtin_is_constant_evaluated()) return;

    while (auto* chunk = self.chunk) {
      auto* prev_chunk = chunk->prev;

      self.backing_allocator.raw_dealloc(chunk->as_raw_bytes(), chunk->actual_size()); 
      self.chunk = prev_chunk;
    }
  }

  [[nodiscard]]
  constexpr auto allocator() -> Allocator {
    return Allocator {
      .impl = this,
      .vtable = {
        .realloc = realloc,
        .dealloc = dealloc,
        .alloc = alloc,
      },
    };
  }

  [[nodiscard]]
  constexpr auto capacity(this auto&& self) -> usize {
    auto* chunk = self.chunk;
    auto size = 0ull;

    while (chunk) {
      size += chunk->size;
      chunk = chunk->prev;
    
    } return size;
  }

  [[nodiscard]]
  constexpr auto first_chunk(this auto&& self) -> Chunk* {
    auto* chunk = self.chunk;

    while (chunk and chunk->prev) {
      chunk = chunk->prev;
    
    } return chunk;
  }

  [[nodiscard]]
  auto push_chunk(this auto&& self, usize previous_size, usize requested_size) -> Chunk* {
    const auto actual_requested_size = requested_size + sizeof(Chunk);
    const auto lowest_effort_size = previous_size + actual_requested_size;

    const auto size = lowest_effort_size + lowest_effort_size / 2;
    const auto log2_align = static_cast<u8>(align_log2(alignof(Chunk)));

    if (auto* data = self.backing_allocator.raw_alloc(size, log2_align)) [[likely]] {
      auto* chunk = __builtin_bit_cast(Chunk*, data);

      chunk->size = size - sizeof(Chunk); 
      chunk->used = 0;

      chunk->prev = self.chunk;
      chunk->next = nullptr;

      if (self.chunk) [[likely]] {
        self.chunk->next = chunk;
      }
      self.chunk = chunk; 

      return chunk;

    } else return nullptr;
  }

  [[nodiscard]]
  static auto realloc(void* impl, u8* data, usize old_size, usize new_size, u8) -> u8* {
    auto& self = *__builtin_bit_cast(Arena*, impl);

    if (auto* chunk = self.chunk; chunk->data() + chunk->used == data + old_size) {
      return (new_size <= old_size) ? data : nullptr; 
    
    } else if (old_size >= new_size) {
      chunk->used -= old_size - new_size;
      
      return data;

    } else if (chunk->size - chunk->used >= new_size - old_size) {
      chunk->used += new_size - old_size;

      return data;

    } else return nullptr;
  }

  static auto dealloc(void* impl, u8* data, usize size) -> void {
    auto& self = *__builtin_bit_cast(Arena*, impl);

    if (auto* chunk = self.chunk; chunk->data() + chunk->used == data + size) {
      chunk->used -= size;
    }
  }

  [[nodiscard]]
  static auto alloc(void* impl, usize size, u8 align) -> u8* {
    auto& self = *__builtin_bit_cast(Arena*, impl); 
    
    const auto adjusted_align = 1u << align;

    if (Chunk* chunk; (chunk = self.chunk) or (chunk = self.push_chunk(0, size + adjusted_align))) [[likely]] {
      const auto adjusted_index = self.chunk->used + size; 

      if (adjusted_index <= chunk->size) {
        return chunk->grow(adjusted_index);
      
      } else if (auto* new_chunk = self.push_chunk(chunk->size, size + adjusted_align)) {
        return new_chunk->data();
      }
    }

    return nullptr;
  }
};

} // neo::mem
