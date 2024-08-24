#pragma once

#define CONCAT_IMPL(X, Y) X##Y
#define CONCAT(X, Y) CONCAT_IMPL(X, Y)

#define defer auto CONCAT(__defer_, __LINE__) = ::defer_helper + [&] [[gnu::always_inline]] mutable noexcept
