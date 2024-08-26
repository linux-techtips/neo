#pragma once

#include <impl/collections/perchance.hpp>
#include <neo/mem>

namespace neo {

namespace {

struct Config {
  bool unmanaged = false;
  bool chunked = false;
};

[[nodiscard]]
constexpr auto grow_capacity(usize cap, usize min) -> usize {
  while (true) if ((cap += cap / 2 + 8) >= min) return cap;
}

} // anon

template <typename T, Config = {}>
struct ArrayList {
  mem::Allocator allocator; 
  mem::Slice<T> mem;

  usize len;

  [[nodiscard]]
  constexpr static auto init(mem::Allocator allocator) -> ArrayList {
    return { allocator };
  }

  [[nodiscard]]
  constexpr static auto with_capacity(mem::Allocator allocator, usize capacity) -> ArrayList {
    return {
      .allocator = allocator,
      .mem = allocator.alloc<T>(capacity),
    };
  }

  constexpr auto deinit(this auto&& self) -> void {
    if (self.mem) [[likely]] {
      self.allocator.dealloc(self.mem);
    }
  }

  [[nodiscard]]
  constexpr auto data(this auto&& self) -> T* {
    return self.mem.data();
  }

  [[nodiscard]]
  constexpr auto size(this auto&& self) -> usize {
    return self.len;
  }

  [[nodiscard]]
  constexpr auto capacity(this auto&& self) -> usize {
    return self.mem.size();
  }

  [[nodiscard]]
  constexpr auto is_empty(this auto&& self) -> bool {
    return self.size() == 0;
  }

  [[nodiscard]]
  constexpr auto begin(this auto&& self) -> T* {
    return self.mem.begin();
  }
 
  [[nodiscard]]
  constexpr auto end(this auto&& self) -> T* {
    return &self.mem[self.len];
  }

  [[nodiscard]]
  constexpr auto front(this auto&& self) -> decltype(auto) {
    return *self.begin();
  }

  [[nodiscard]]
  constexpr auto back(this auto&& self) -> decltype(auto) {
    return *self.end();
  }

  constexpr auto resize(this auto&& self, usize capacity) -> mem::Slice<T> {
    if (self.capacity() >= capacity) [[likely]] return self.mem;

    const auto new_capacity = grow_capacity(self.capacity(), capacity);
    auto& old_mem = self.mem;

    if (auto new_mem = self.allocator.realloc(old_mem, new_capacity)) {
      return new_mem;
    
    } else if (auto new_mem = self.allocator.template alloc<T>(new_capacity)) {
      if (old_mem) [[likely]] {
        __builtin_memcpy(new_mem.bytes(), old_mem.bytes(), old_mem.byte_size()); 
        self.allocator.dealloc(old_mem);
      }

      return (self.mem = new_mem);
    } else return {};
  } 

  [[nodiscard]]
  constexpr auto add_slot(this auto&& self) -> T* {
    if (auto mem = self.resize(self.len + 1)) [[likely]] {
      return &mem[self.len++];

    } else return nullptr;
  }

  constexpr auto push(this auto&& self, T&& elem) -> T* {
    if (auto* slot = self.add_slot()) [[likely]] {
      return &(*slot = static_cast<T&&>(elem));

    } else return nullptr;
  }
  
  constexpr auto push(this auto&& self, const T& elem) -> T* {
    if (auto* slot = self.add_slot()) [[likely]] {
      return &(*slot = elem);
    
    } else return nullptr;
  }

  [[nodiscard]]
  constexpr auto pop(this auto&& self) -> Perchance<T> {
    if (self.len) [[likely]] {
      return self.mem[--self.len];

    } else return Null;
  }

  constexpr auto at_unchecked(this auto&& self, usize index) -> decltype(auto) {
    return self.mem[index];
  }
};

template <typename T>
struct ArrayList<T, Config { .unmanaged = true }> {
  mem::Slice<T> mem;

  usize len;

  [[nodiscard]]
  constexpr static auto init() -> ArrayList {
    return {};
  }

  [[nodiscard]]
  constexpr static auto with_capacity(mem::Allocator allocator, usize capacity) -> ArrayList {
    return { allocator.alloc<T>(capacity) };
  }

  constexpr auto deinit(this auto&& self, mem::Allocator allocator) -> void {
    allocator.dealloc(self.mem); 
  }

  [[nodiscard]]
  constexpr auto data(this auto&& self) -> T* {
    return self.mem.data();
  }

  [[nodiscard]]
  constexpr auto size(this auto&& self) -> usize {
    return self.len;
  }

  [[nodiscard]]
  constexpr auto capacity(this auto&& self) -> usize {
    return self.mem.size();
  }

  [[nodiscard]]
  constexpr auto is_empty(this auto&& self) -> bool {
    return self.size() == 0;
  }

  [[nodiscard]]
  constexpr auto begin(this auto&& self) -> T* {
    return self.mem.begin();
  }

  [[nodiscard]]
  constexpr auto end(this auto&& self) -> T* {
    return &self.mem.data[self.len];
  }

  [[nodiscard]]
  constexpr auto front(this auto&& self) -> decltype(auto) {
    return *self.begin();
  }

  [[nodiscard]]
  constexpr auto back(this auto&& self) -> decltype(auto) {
    return *self.end();
  }

  constexpr auto resize(this auto&& self, mem::Allocator allocator, usize capacity) -> mem::Slice<T> {
    if (self.capacity() >= capacity) return self.mem;

    const auto new_capacity = grow_capacity(self.capacity(), capacity);
    auto& old_mem = self.mem;

    if (auto new_mem = allocator.realloc(old_mem, new_capacity)) {
      return new_mem;
    
    } else if (auto new_mem = allocator.template alloc<T>(new_capacity)) {
      if (old_mem) [[likely]] {
        __builtin_memcpy(new_mem.bytes(), old_mem.bytes(), self.size * sizeof(T));
        allocator.dealloc(old_mem);
      }

      return (self.mem = new_mem);

    } else return {};
  } 

  [[nodiscard]]
  constexpr auto add_slot(this auto&& self, mem::Allocator allocator) -> T* {
    if (auto mem = self.resize(allocator, self.len + 1)) [[likely]] {
      return &mem[self.len++];

    } else return nullptr;
  }

  constexpr auto push(this auto&& self, mem::Allocator allocator, T&& elem) -> T* {
    if (auto* slot = self.add_slot(allocator)) [[likely]] {
      return &(*slot = static_cast<T&&>(elem));

    } else return nullptr;
  }
  
  constexpr auto push(this auto&& self, mem::Allocator allocator, const T& elem) -> T* {
    if (auto* slot = self.add_slot(allocator)) [[likely]] {
      return &(*slot = elem);
    
    } else return nullptr;
  }

  [[nodiscard]]
  constexpr auto pop(this auto&& self) -> Perchance<T> {
    if (self.len) [[likely]] {
      return self.mem[--self.len];

    } else return Null;
  }

  constexpr auto at_unchecked(this auto&& self, usize index) -> decltype(auto) {
    return *self.mem[index];
  }
};

template <typename T>
struct ArrayList<T, { .chunked = true }> {
  mem::Arena arena;
  
  struct Iter {
    mem::Arena::Chunk* chunk;
    mem::Arena& arena;

    usize index;

    auto operator ++ (this auto&& self) -> decltype(auto) {
      const auto adjusted_index = self.index + sizeof(T);

      if (adjusted_index >= self.chunk->used) [[unlikely]] {
        self.chunk = self.chunk->next;
        self.index = 0;

      } else self.index = adjusted_index;

      return self;
    }

    auto operator == (this auto&& self, decltype(self) other) -> bool {
      return (self.chunk == other.chunk) and (self.index == other.index);
    }

    auto operator * (this auto&& self) -> decltype(auto) {
      return *__builtin_bit_cast(T*, &self.chunk->data()[self.index]);
    }
  };

  [[nodiscard]]
  constexpr static auto init(mem::Allocator allocator) -> ArrayList {
    return { mem::Arena::init(allocator) };
  }

  [[nodiscard]]
  constexpr static auto with_capacity(mem::Allocator allocator, usize size) -> ArrayList {
    auto arena = mem::Arena::init(allocator);
    (void*)arena.push_chunk(0, size * sizeof(T));

    return { arena };
  }

  constexpr auto deinit(this auto&& self) -> void {
    self.arena.deinit();
  }

  [[nodiscard]]
  constexpr auto capacity(this auto&& self) -> usize {
    return self.arena.capacity() / sizeof(T);
  }

  [[nodiscard]]
  auto begin(this auto&& self) -> Iter {
    return { self.arena.first_chunk(), self.arena };
  }

  [[nodiscard]]
  auto end(this auto&& self) -> Iter {
    return { nullptr, self.arena };
  }

  auto add_slot(this auto&& self) -> T* {
    auto* data = mem::Arena::alloc(&self.arena, sizeof(T), alignof(T));

    return __builtin_bit_cast(T*, data);
  }

  auto push(this auto&& self, const T& elem) -> T* {
    if (auto* slot = self.add_slot()) [[likely]] {
      return &(*slot = elem);
    
    } else return nullptr;
  }

  auto push(this auto&& self, T&& elem) -> T* {
    if (auto* slot = self.add_slot()) [[likely]] {
      return &(*slot = static_cast<T&&>(elem));
    
    } else return nullptr;
  }
};

} // neo::collections
