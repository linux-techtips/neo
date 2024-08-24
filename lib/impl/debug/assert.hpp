#pragma once

#include <neo/fmt>

namespace std {

struct source_location {
  struct __impl {
    const char* _M_file_name;
    const char* _M_function_name;
    unsigned _M_line;
    unsigned _M_column;
  };
};

} // std

template <>
struct neo::fmt::formatter<std::source_location::__impl> {
  constexpr auto format(const std::source_location::__impl& source, auto& ctx) const {
    return neo::fmt::format_to(ctx.out(), "{}:{}:{}", source._M_file_name, source._M_function_name, source._M_line);  
  } 

  constexpr auto parse(auto& ctx) {
    return ctx.begin();
  }
};

namespace neo::debug {

inline auto assert(
  const bool cond,
  const char* cond_text,
  const char* why,
  const char* lhs,
  const char* rhs,
  const auto& lvalue,
  const auto& rvalue,
  const std::source_location::__impl* source = __builtin_source_location()
) -> void {
  if (cond) [[likely]] return;


  fmt::println(stderr,
    "[ASSERT] {} - Expected {} to be {} {}\n"
    "  Where:\n"
    "    {} => {}\n"
    "    {} => {}\n"
    "  Why:\n"
    "    {}",
    *source, lhs, cond_text, rhs, 
    lhs, lvalue,
    rhs, rvalue,
    why);

  __builtin_trap();
}

} // neo::debug
