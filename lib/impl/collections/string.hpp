#pragma once

#include <neo/mem>

namespace neo {

struct str : public mem::Slice<const char> {
  template <usize N>
  [[nodiscard]]
  constexpr explicit(false) str(const char (&literal)[N]) {
    this->ptr = literal;
    this->len = N - 1;
  }

  [[nodiscard]]
  constexpr explicit(false) str(const char* c_string) {
    this->ptr = c_string;
    this->len = __builtin_strlen(c_string);
  }

  [[nodiscard]]
  constexpr explicit(false) str(const char* ptr, usize len) {
    this->ptr = ptr;
    this->len = len;
  } 

  [[nodiscard]]
  constexpr auto slice(this auto&& self, usize start, usize end) -> str {
    assert_lte(start, self.size(), "Attempted to index past slice bounds.");
    assert_lte(end, self.size(), "Attempted to index past slice bounds.");

    return { &self.ptr[start], end };
  }
};

} // neo

template <>
struct neo::fmt::formatter<neo::str> {
  constexpr auto format(const neo::str& str, auto& ctx) const {
    return neo::fmt::format_to_n(ctx.out(), str.size(), "{}", str.ptr).out; 
  }

  constexpr auto parse(auto& ctx) {
    return ctx.begin();
  }
};
