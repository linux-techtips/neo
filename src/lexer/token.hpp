#pragma once

#include <neo/collections>

namespace neo::lexer {

struct Token {
  enum Kind : u8 {
    #define TOKEN(Name) \
      Name,

    #include "lexer/token.def"
  };

  Kind kind;

  u32 source_idx;
  u32 line_idx;

  union {
    u32 string_literal_len;
    u32 number_literal_len;
    u32 ident_len;
    u32 close_idx;
    u32 open_idx;
    u32 err_len;
  };

  [[nodiscard]]
  constexpr static auto name(Kind kind) -> str {
    constexpr static str Table[] = {
      #define TOKEN(Name) \
        #Name,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

  [[nodiscard]]
constexpr static auto text(Kind kind) -> str {
    constexpr static str Table[] = {
      #define TOKEN(Name) \
        #Name,

      #define TOKEN_SYMBOL(Name, Text) \
        Text,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

  [[nodiscard]]
  constexpr static auto is_symbol(Kind kind) -> bool {
    constexpr static bool Table[] = {
      #define TOKEN(Name) \
        false,

      #define TOKEN_SYMBOL(Name, Text) \
        true,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

 [[nodiscard]]
  constexpr static auto is_keyword(Kind kind) -> bool {
    constexpr static bool Table[] = {
      #define TOKEN(Name) \
        false,

      #define TOKEN_KEYWORD(Name, Text) \
        true,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

  [[nodiscard]]
  constexpr static auto is_grouping(Kind kind) -> bool {
    constexpr static bool Table[] = {
      #define TOKEN(Name) \
        false,

      #define TOKEN_GROUPING(Name, Match, Text) \
        true,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

  [[nodiscard]]
  constexpr static auto is_grouping_open(Kind kind) -> bool {
    constexpr static bool Table[] = {
      #define TOKEN(Name) \
        false,

      #define TOKEN_GROUPING_OPEN(Name, Close, Text) \
        true,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

  [[nodiscard]]
  constexpr static auto is_grouping_close(Kind kind) -> bool {
    constexpr static bool Table[] = {
      #define TOKEN(Name) \
        false,

      #define TOKEN_GROUPING_CLOSE(Name, Open, Text) \
        true,

      #include "lexer/token.def"
    };

    return Table[kind];
  }

  [[nodiscard]]
  constexpr static auto matching_grouping_kind(Kind kind) -> Kind {
    constexpr static Kind Table[] = {
      #define TOKEN(Name) \
        Ident,

      #define TOKEN_GROUPING(Name, Match, Text) \
        Match,

      #include "lexer/token.def"
    };

    return Table[kind];
  }
};

static_assert(sizeof(Token) <= sizeof(u128));

} // neo::lexer

template <>
struct neo::fmt::formatter<neo::lexer::Token::Kind> {
  using Token = neo::lexer::Token;

  constexpr auto format(const Token::Kind& kind, auto& ctx) const {
    return neo::fmt::format_to(ctx.out(), "{}", Token::name(kind));
  }

  constexpr auto parse(auto& ctx) {
    return ctx.begin();
  }
};

template <>
struct neo::fmt::formatter<neo::lexer::Token> {
  using Token = neo::lexer::Token;

  constexpr auto format(const Token& token, auto& ctx) const {
    return neo::fmt::format_to(ctx.out(),
      "Token {{\n"
      "  .kind = {}\n"
      "  .source_idx = {}\n"
      "  .line_idx = {}\n"
      "}}",
      token.kind, token.source_idx, token.line_idx);
  }

  constexpr auto parse(auto& ctx) {
    return ctx.begin();
  }
};
