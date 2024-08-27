#pragma once

#include <neo/fmt>

namespace neo {

[[maybe_unused]]
constexpr static struct {} Null = {}; 

template <typename T>
struct Perchance {
  T value;
  bool ok;

  [[nodiscard]]
  constexpr explicit(false) Perchance(decltype(Null)) : ok { false } {};

  [[nodiscard]]
  constexpr explicit(false) Perchance(T&& value) :
    value { static_cast<T&&>(value) },
    ok { true }
  {}

  [[nodiscard]]
  constexpr explicit(false) Perchance(const T& value) :
    value { value },
    ok { true }
  {}

  [[nodiscard]]
  constexpr operator bool (this auto&& self) {
    return self.ok;
  }
};

} // neo

template <typename T>
struct neo::fmt::formatter<neo::Perchance<T>> {
  constexpr auto format(const neo::Perchance<T>& perchance, auto& ctx) const {
    if (auto [value, ok] = perchance; ok) {
      return neo::fmt::format_to(ctx.out(), "Perchance({})", value);

    } else return neo::fmt::format_to(ctx.out(), "Nah");
  }

  constexpr auto parse(auto& ctx) {
    return ctx.begin();
  } 
};
