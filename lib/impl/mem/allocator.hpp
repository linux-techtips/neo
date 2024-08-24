#pragma once

#include <impl/mem/slice.hpp>

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

  template <typename T>
  [[nodiscard]]
  constexpr auto realloc(this auto&& self, Slice<T> slice, usize size) -> Slice<T> {
    auto* data = self.raw_realloc(
      slice.bytes(),
      sizeof(T) * slice.size,
      sizeof(T) * size,
      alignof(T));

    return Slice<T>::from_bytes(data, size);
  }
  
  template <typename T>
  constexpr auto dealloc(this auto&& self, Slice<T> slice) -> void {
    if (__builtin_is_constant_evaluated()) {
      delete [] slice.data;

    } else {
      self.raw_dealloc(slice.bytes(), slice.size * sizeof(T));
    }
  }

  template <typename T>
  [[nodiscard]]
  constexpr auto alloc(this auto&& self, usize size) -> Slice<T> {
    if (__builtin_is_constant_evaluated()) {
      return Slice { new T [size], size };

    } else {
      return Slice<T>::from_bytes(self.raw_alloc(size * sizeof(T), alignof(T)), size); 
    }
  }

  [[nodiscard]]
  constexpr auto raw_realloc(this auto&& self, u8* data, usize old_size, usize new_size, u8 align) -> u8* {
    return self.vtable.realloc(self.impl, data, old_size, new_size, align);  
  }

  constexpr auto raw_dealloc(this auto&& self, u8* data, usize size) -> void {
    self.vtable.dealloc(self.impl, data, size);
  }

  [[nodiscard]]
  constexpr auto raw_alloc(this auto&& self, usize size, u8 align) -> u8* {
    return self.vtable.alloc(self.impl, size, align);
  }
};

} // neo::mem
