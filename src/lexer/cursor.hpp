#pragma once

#include <neo/collections>

namespace neo::lexer {

struct Cursor {
  str source;
  u32 offset;

  [[nodiscard]]
  static auto init(str text) -> Cursor {
    return {.source = text};
  }

  auto deinit(this auto &&self) -> void {
    self.offset = -1u;
  }

  [[nodiscard]]
  auto data(this auto &&self) -> str {
    return self.source;
  }

  [[nodiscard]]
  auto size(this auto &&self) -> u32 {
    return static_cast<u32>(self.source.size());
  }

  [[nodiscard]]
  auto eof(this auto &&self) -> bool {
    return self.offset > self.size();
  }

  [[nodiscard]]
  auto pos(this auto &&self) -> u32 {
    return self.offset;
  }

  [[nodiscard]]
  auto curr(this auto &&self) -> char {
    assert_gte(self.size(), self.pos(), "Cursor offset is out of bounds.");

    return self.source[self.pos()];
  }

  [[nodiscard]]
  auto rest(this auto &&self) -> str {
    assert_gte(self.size(), self.pos(), "Cursor offset is out of bounds.");

    return self.source.slice(self.pos(), self.size());
  }

  [[nodiscard]]
  auto peek(this auto&& self, u32 index) -> Perchance<char> {
    if (self.offset + index > self.size()) [[unlikely]] return Null;

    return self.source[self.offset + index];
  }

  auto inc(this auto &&self, u32 amount) -> void {
    self.offset += amount;

    assert_lt(self.pos(), self.size(), "Cursor offset is out of bounds.");
  }

  auto dec(this auto &&self, usize amount) -> void {
    // TODO: Check for wraparound
    self.offset -= amount;
  }

  auto skip_horizontal_whitespace(this auto &&self) -> void {
    for (auto ch = self.curr(); not self.eof() and (ch == ' ' or ch == '\t');
         ch = self.curr())
      self.inc(1);
  }
};

} // namespace neo::lexer
