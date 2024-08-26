#pragma once

#include <lexer/source.hpp>
#include <lexer/token.hpp>

namespace neo::lexer {

struct Buffer {
  using Tokens = ArrayList<Token>;

  Tokens tokens;
  Lines lines;

  u32 number_literal_count;
  u32 string_literal_count;
  u32 ident_count;

  [[nodiscard]]
  static auto init(mem::Allocator allocator, Lines& lines) -> Buffer {
    // TODO: Guesstimate how many tokens based off of file size
    return {
        .tokens = Tokens::with_capacity(allocator, lines.size() * 50),
        .lines = lines,
    };
  }

  auto deinit(this auto&& self) -> void {
    self.tokens.deinit();
    self.lines.deinit();
  } 

  auto add_token(this auto&& self, Token&& token) -> Token* {
    return self.tokens.push(static_cast<Token&&>(token)); 
  }
};

} // namespace neo::lexer
