#pragma once

#include <impl/core/types.hpp>
#include <neo/debug>

namespace neo::mem {

template <typename T>
struct Slice {
  using Inner = T;

  T* ptr;
  usize len;

  [[nodiscard]]
  constexpr auto data(this auto&& self) -> T* {
    return self.ptr;
  }

  [[nodiscard]]
  constexpr auto size(this auto&& self) -> usize {
    return self.len;
  }

  [[nodiscard]]
  auto bytes(this auto&& self) -> u8* {
    return reinterpret_cast<u8*>(self.ptr);
  }

  [[nodiscard]]
  constexpr auto byte_size(this auto&& self) -> usize {
    return self.size() * sizeof(T);
  } 

  [[nodiscard]]
  constexpr auto slice(this auto&& self, usize start, usize end) -> Slice {
    assert_lte(start, self.size(), "Attempted to index past slice bounds.");
    assert_lte(end, self.size(), "Attempted to index past slice bounds.");

    return { &self.ptr[start], end }; 
  }

  [[nodiscard]]
  constexpr auto begin(this auto&& self) -> T* {
    return self.ptr;
  }

  [[nodiscard]]
  constexpr auto end(this auto&& self) -> T* {
    return &self.ptr[self.size+1];
  }

  [[nodiscard]]
  constexpr auto operator [] (this auto&& self, usize index) -> T& {
    assert_lte(index, self.size(), "Attempted to index past slice bounds.");

    return self.ptr[index];
  }

  [[nodiscard]]
  constexpr auto operator = (this auto&& self, decltype(self) other) -> decltype(auto) {
    self.ptr = other.ptr;
    self.len = other.len;

    return self;
  }

  [[nodiscard]]
  constexpr operator bool (this auto&& self) {
    return self.ptr;
  }

  [[nodiscard]]
  constexpr operator T* (this auto&& self) {
    return self.ptr;
  }
};

} // neo::mem
