#pragma once

#include <impl/core/types.hpp>
#include <neo/debug>

namespace neo::mem {

template <typename T>
struct Slice {
  using Inner = T;

  T* data;
  usize size;

  [[nodiscard]]
  static auto from_bytes(u8* data, usize size) -> Slice {
    return { __builtin_bit_cast(T*, data), size };
  }

  template <usize N>
  [[nodiscard]]
  static auto from_str(const s8 (&str)[N]) -> Slice {
    auto* data = str;

    return { __builtin_bit_cast(T*, data), N };
  }

  [[nodiscard]]
  auto bytes(this auto&& self) -> u8* {
    return __builtin_bit_cast(u8*, self.data);
  }

  [[nodiscard]]
  constexpr auto byte_size(this auto&& self) -> usize {
    return self.size * sizeof(T);
  } 

  [[nodiscard]]
  constexpr auto slice(this auto&& self, usize start, usize end) -> Slice {
    assert_lte(start, self.size, "Attempted to index past slice bounds.");
    assert_lte(end, self.size, "Attempted to index past slice bounds.");

    return { &self.data[start], end }; 
  }

  [[nodiscard]]
  constexpr auto begin(this auto&& self) -> T* {
    return self.data;
  }

  [[nodiscard]]
  constexpr auto end(this auto&& self) -> T* {
    return &self.data[self.size+1];
  }

  [[nodiscard]]
  constexpr auto operator [] (this auto&& self, usize index) -> T& {
    assert_lte(index, self.size, "Attempted to index past slice bounds.");

    return self.data[index];
  }

  [[nodiscard]]
  constexpr auto operator = (this auto&& self, decltype(self) other) -> decltype(auto) {
    self.data = other.data;
    self.size = other.size;

    return self;
  }

  [[nodiscard]]
  constexpr operator bool (this auto&& self) {
    return self.data != nullptr;
  }

  [[nodiscard]]
  constexpr operator T* (this auto&& self) {
    return self.data;
  }
};

} // neo::mem
