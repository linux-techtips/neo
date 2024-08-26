#include <lexer/cursor.hpp>
#include <lexer/lookup.hpp>
#include <lexer/scan.hpp>

#include <lexer/lex.hpp>
#include <neo/core>

namespace neo::lexer {

namespace {

struct Lexer {
  ArrayList<u32> open_groupings;
  bool mismatched_groupings;

  u32 line_idx;

  Source& source;

  Cursor cursor;
  Buffer buffer;

  [[nodiscard]]
  static auto init(mem::Allocator allocator, Source& source) -> Lexer {
    auto lines = source.lines(allocator);

    return {
      .open_groupings = ArrayList<u32>::with_capacity(allocator, 100),
      .source = source,
      .cursor = Cursor::init(source.as_str()),
      .buffer = Buffer::init(allocator, lines),
    };
  }

  auto deinit(this auto&& self) -> void {
    self.open_groupings.deinit();
  }

  auto next_line(this auto& self) -> Line& {
    assert_lt(self.line_idx + 1, self.buffer.lines.size(), "Attempted to index past line buffer size.");

    return self.buffer.lines.at_unchecked(++self.line_idx);
  }

  auto lex_symbol(this auto& self) -> void {
    const auto text = scan::symbol(self.cursor.rest());
    defer { self.cursor.inc(static_cast<u32>(text.size())); };

    self.buffer.add_token({
      .kind = lookup::symbol(text),
      .source_idx = self.cursor.pos(),
      .line_idx = self.line_idx,
    });
  }

  auto lex_keyword_or_ident(this auto& self) -> void {
    const auto text = scan::keyword_or_ident(self.cursor.rest());
    defer { self.cursor.inc(static_cast<u32>(text.size())); };

    const auto key_or_ident = lookup::keyword(text);
    if (key_or_ident == Token::Ident) {
      ++self.buffer.ident_count;
    }

    self.buffer.add_token({
      .kind = key_or_ident, 
      .source_idx = self.cursor.pos(),
      .line_idx = self.line_idx,
      .ident_len = static_cast<u32>(text.size()),
    });
  }

  auto lex_number_literal(this auto& self) -> void {
    const auto text = scan::number_literal(self.cursor.rest());
    defer { self.cursor.inc(static_cast<u32>(text.size())); };

    ++self.buffer.number_literal_count;

    self.buffer.add_token({
      .kind = Token::NumberLiteral,
      .source_idx = self.cursor.pos(),
      .line_idx = self.line_idx,
      .number_literal_len = static_cast<u32>(text.size()),
    });
  }

  auto lex_string_literal(this auto& self) -> void {
    const auto text = scan::string_literal(self.cursor.rest());
    defer { self.cursor.inc(static_cast<u32>(text.size())); };

    ++self.buffer.string_literal_count;

    self.buffer.add_token({
      .kind = Token::StringLiteral,
      .source_idx = self.cursor.pos(),
      .line_idx = self.line_idx,
      .string_literal_len = static_cast<u32>(text.size()),
    });
  }

  template <Token::Kind Kind>
  requires requires { Token::is_grouping_open(Kind); }
  auto lex_grouping_open(this auto& self) -> void {
    defer { self.cursor.inc(1); };

    self.open_groupings.push(static_cast<u32>(self.buffer.tokens.size()));

    self.buffer.add_token({
      .kind = Kind,
      .source_idx = self.cursor.pos(),
      .line_idx = self.line_idx,
    });
  }

  template <Token::Kind Kind>
  requires requires { Token::is_grouping_close(Kind); }
  auto lex_grouping_close(this auto& self) -> void {
    defer { self.cursor.inc(1); };

    if (auto [idx, ok] = self.open_groupings.pop(); ok) {
      auto opening = self.buffer.tokens.at_unchecked(idx);

      if (Kind != Token::matching_grouping_kind(opening.kind)) {
        self.mismatched_groupings = true;
        return;
      }

      opening.close_idx = static_cast<u32>(self.buffer.tokens.size());

      self.buffer.add_token({
        .kind = Kind,
        .source_idx = self.cursor.pos(),
        .open_idx = idx,
      });

    } else self.mismatched_groupings = true;
  }

  auto lex_coment_or_symbol(this auto& self) -> void {
    // TODO: Skip comments in bulk with SIMD

    if (auto [ch, ok] = self.cursor.peek(1); ok and ch == '/') [[likely]] {
      self.lex_vertical_whitespace();
    
    } else self.lex_symbol();
  }

  auto lex_horizontal_whitespace(this auto& self) -> void {
    self.cursor.skip_horizontal_whitespace();
  }

  auto lex_vertical_whitespace(this auto& self) -> void {
    auto& line = self.next_line();

    self.cursor.offset = static_cast<u32>(line.offset);
    self.cursor.skip_horizontal_whitespace();

    line.indent = self.cursor.offset - line.offset;
  }

  auto lex_carriage_return(this auto& self) -> void {
    // TODO: Needs testing
    if (auto [ch, ok] = self.cursor.peek(1); ok and ch == '\n') [[likely]] {
      self.lex_vertical_whitespace();
    
    } else {
        // TODO: Error handling
        assert_eq(true, false, "panik");
    }
  } 

  auto lex_invalid(this auto& self) -> void {
    // TODO: This could actually pass in a rare case. But why would we ever handle that.
    assert_eq(self.cursor.pos(), -1ull, "Attempted to lex an invalid token");
  
    self.cursor.inc(1);
  }

  auto lex_eof(this auto& self) -> void {
    // TODO: Handle unexpected eof

    self.cursor.deinit();
  }
};

constexpr static auto DispatchTable = [] {
  auto table = Array<auto (*)(Lexer&) -> void, 256>::filled_with(&Lexer::lex_invalid);

  // TODO: Unicode identifiers

  for (usize ch = 'A'; ch <= 'Z'; ++ch) table[ch] = &Lexer::lex_keyword_or_ident;
  for (usize ch = 'a'; ch <= 'z'; ++ch) table[ch] = &Lexer::lex_keyword_or_ident;

  table['_'] = &Lexer::lex_keyword_or_ident;

  for (usize ch = '0'; ch <= '9'; ++ch) table[ch] = &Lexer::lex_number_literal;

  table['\"'] = &Lexer::lex_string_literal;

  #define TOKEN_SYMBOL(Name, Text) \
    table[(Text)[0]] = &Lexer::lex_symbol;

  #define TOKEN_GROUPING_OPEN(Name, Close, Text) \
    table[(Text)[0]] = &Lexer::lex_grouping_open<Token::Name>;

  #define TOKEN_GROUPING_CLOSE(Name, Open, Text) \
    table[(Text)[0]] = &Lexer::lex_grouping_close<Token::Name>;

  #include "lexer/token.def"

  table['/'] = &Lexer::lex_coment_or_symbol;

  table['\t'] = &Lexer::lex_horizontal_whitespace;
  table[' '] = &Lexer::lex_horizontal_whitespace;

  table['\n'] = &Lexer::lex_vertical_whitespace;
  table['\r'] = &Lexer::lex_carriage_return;

  table['\0'] = &Lexer::lex_eof;

  return table;
}();

} // anon 

} // neo::lexer
