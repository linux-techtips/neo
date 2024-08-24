#pragma once

#include <neo/mem>
#include <neo/fmt> 

namespace neo {

using str = mem::Slice<char>; 

} // neo


template <>
struct neo::fmt::formatter<neo::str> {
  constexpr auto format(const neo::str& str, auto& ctx) const {
    return neo::fmt::format_to_n(ctx.out(), str.size, "{}", str.data).out; 
  }

  constexpr auto parse(auto& ctx) {
    return ctx.begin();
  }
};
