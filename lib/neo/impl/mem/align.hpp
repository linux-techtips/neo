#pragma once

#include <neo/impl/core/types.hpp>
#include <neo/debug>

namespace neo::mem {

[[nodiscard]]
constexpr auto align_backward(usize from, usize to) -> usize {
  return from & ~(to - 1);
}

[[nodiscard]]
constexpr auto align_forward(usize from, usize to) -> usize {
  return align_backward(from + (to - 1), to);
}

[[nodiscard]]
constexpr auto align_log2(usize num) -> usize {
  assert_neq(num, 0, "Cannot log2 align on 0");

  return (8 * sizeof(num) - 1) - static_cast<usize>(__builtin_clzll(num));
}

} // neo::mem
