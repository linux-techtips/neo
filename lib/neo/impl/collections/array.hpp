#pragma once

#include <neo/mem>

namespace neo {

template <typename T, usize N>
struct Array {
  T ptr[N];

  [[nodiscard]]
  constexpr static auto filled_with(const T& x) -> Array {
    auto arr = Array {};

    for (auto& elem : arr) elem = x;

    return arr;
  }

  [[nodiscard]]
  constexpr auto data(this auto&& self) -> mem::Slice<T> {
    return { self.data, N };
  }

  [[nodiscard]]
  constexpr auto size(this auto&& self) -> usize {
    return N;
  }

  [[nodiscard]]
  constexpr auto slice(this auto&& self, usize start, usize end) -> mem::Slice<T> {
    assert_lte(start, self.size(), "Attempted to index past array bounds.");
    assert_lte(end, self.size(), "Attempted to index past array bounds.");

    return { &self.ptr[start], end }; 
  }

  // Go ahead, refactor this, you want to remove the decltype, I know you want to.
  [[nodiscard]]
  constexpr auto begin(this auto&& self) -> decltype(&self.ptr[0]) {
    return &self.ptr[0];
  } 

  [[nodiscard]]
  constexpr auto end(this auto&& self) -> decltype(&self.ptr[N]) {
    return &self.ptr[N];
  }

  [[nodiscard]]
  constexpr auto operator [] (this auto&& self, usize index) -> decltype(auto) {
    assert_lte(index, self.size(), "Attempted to index past array bounds.");

    return self.ptr[index];
  }
};

template <typename T, typename... Args>
Array(T&& x, Args&&... xs) -> Array<T, 1 + sizeof...(Args)>;

} // neo
