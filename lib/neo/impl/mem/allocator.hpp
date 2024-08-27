#pragma once

#include <neo/impl/mem/slice.hpp>

namespace neo::mem {

struct Allocator {
  using Realloc = auto (*)(void* impl, u8* data, usize old_size, usize new_size, u8 align) -> u8*;
  using Dealloc = auto (*)(void* impl, u8* data, usize size) -> void;
  using Alloc = auto (*)(void* impl, usize size, u8 align) -> u8*;

  void* impl;

  struct {
    Realloc realloc = [] (void*, u8*, usize, usize, u8) -> u8* { return nullptr; };
    Dealloc dealloc;
    Alloc alloc;
  
  } vtable;

  [[nodiscard]]
  constexpr auto is_initialized(this auto&& self) -> bool {
    return self.vtable.realloc and self.vtable.dealloc and self.vtable.alloc;
  }

  template <typename T>
  [[nodiscard]]
  constexpr auto realloc(this auto&& self, Slice<T> slice, usize size) -> Slice<T> {
    if (__builtin_is_constant_evaluated()) return {};

    auto* data = self.raw_realloc(
      slice.bytes(),
      sizeof(T) * slice.size(),
      sizeof(T) * size,
      alignof(T));

    return { reinterpret_cast<T*>(data), size };
  }
  
  template <typename T>
  constexpr auto dealloc(this auto&& self, Slice<T> slice) -> void {
    if (__builtin_is_constant_evaluated()) {
      delete [] slice.ptr;

    } else self.raw_dealloc(slice.bytes(), slice.size());
  }

  template <typename T>
  [[nodiscard]]
  constexpr auto alloc(this auto&& self, usize size) -> Slice<T> {
    if (__builtin_is_constant_evaluated()) {
      return Slice { new T [size], size };

    } else return { reinterpret_cast<T*>(self.raw_alloc(size * sizeof(T), alignof(T))), size }; 
  }

  [[nodiscard]]
  constexpr auto raw_realloc(this auto&& self, u8* data, usize old_size, usize new_size, u8 align) -> u8* {
    assert_neq(reinterpret_cast<usize>(self.vtable.realloc), 0, "Realloc is not initialized when called");

    return self.vtable.realloc(self.impl, data, old_size, new_size, align);  
  }

  constexpr auto raw_dealloc(this auto&& self, u8* data, usize size) -> void {
    assert_neq(reinterpret_cast<usize>(self.vtable.dealloc), 0, "Dealloc is not initialized when called");
    self.vtable.dealloc(self.impl, data, size);
  }

  [[nodiscard]]
  constexpr auto raw_alloc(this auto&& self, usize size, u8 align) -> u8* {
    assert_neq(reinterpret_cast<usize>(self.vtable.alloc), 0, "Alloc is not initialized when called");
    return self.vtable.alloc(self.impl, size, align);
  }
};

} // neo::mem
