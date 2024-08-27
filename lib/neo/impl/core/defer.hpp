#pragma once

namespace {

template <typename Fn>
struct Defer {
  [[no_unique_address]] Fn fn;

  [[gnu::always_inline]]
  constexpr ~Defer() noexcept {
    fn();
  }
};

struct DeferHelper {
  template <typename Fn>
  [[gnu::always_inline]]
  constexpr auto operator + (Fn&& fn) const noexcept -> Defer<Fn> {
    return { static_cast<Fn&&>(fn) };
  }
};

[[maybe_unused]]
constexpr static auto defer_helper = DeferHelper {};

} // anon 
