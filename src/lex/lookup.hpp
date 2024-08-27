#pragma once

#include <lex/token.hpp>

namespace neo::lex::lookup {

namespace {

[[nodiscard, gnu::always_inline]]
constexpr auto pack(str text) -> u64 {
  u8 data[8] = { 0 };

  if (__builtin_is_constant_evaluated()) {
    for (auto i = 0u; i < text.size() - 1; ++i) data[i] = static_cast<u8>(text[i]);

  } else __builtin_memcpy(data, text.ptr, text.len);

  return __builtin_bit_cast(u64, data);
}

[[nodiscard, gnu::always_inline]]
constexpr auto pext(u64 text, u64 mask) -> u64 {
  auto pext_impl = [] (u64 text, u64 mask) {
    constexpr static auto Size = sizeof(u64) * __CHAR_BIT__;

    auto bit_mask = mask;
    auto bit_idx = 0ul;
    auto result = 0ul;

    for (auto i = 0u; i < Size; ++i) {
      if (bit_mask & 1) {
        result |= ((text >> i) & 1) << bit_idx++;
      
      } bit_mask >>= 1;
    
    } return result;
  };

  if (__builtin_is_constant_evaluated()) {
    return pext_impl(text, mask);

  } else {
    #if defined (__BMI2__)
      return __builtin_ia32_pext_di(text, mask);
    #else
      return pext_impl(text, mask);
    #endif
  }
}

template <auto Texts>
[[nodiscard]]
consteval auto make_mask() -> u64 {
  constexpr static auto EntrySize = Texts.size();
  constexpr static auto HashSize = EntrySize << 1ul;
  
  auto max = u64 {};

  for (auto i = 0ul; i < EntrySize; ++i) {
    if (Texts[i] > max) max = Texts[i];
  }

  const auto lz = static_cast<usize>(__builtin_clzl(max));
  const auto nbits = static_cast<int>(sizeof(max) * __CHAR_BIT__ - lz - 1u); 

  auto hashed = Array<u64, HashSize> {};
  auto mask = u64 { (u64 { 1 } << nbits) - 1u };

  for (int i = nbits; i >= 0; --i) {
    mask &= ~(u64 { 1 } << i);
    hashed = {};

    for (auto j = 0u; j < EntrySize; ++j) {
      const auto masked = u64 { (Texts[j] & mask) + 1u };

      auto slot = masked % HashSize;
      auto found = false;
      auto n = 0;

      while (hashed[slot]) {
        if (hashed[slot] == masked and not n--) {
          found = true;
          break;
        
        } slot = (slot + 1u) % HashSize;

      } if (found) {
        mask |= (u64 { 1 } << i);
        break;
      
      } hashed[slot] = masked;
    }

  } return mask;
}

template <auto Texts, u64 Mask>
[[nodiscard]]
consteval auto make_size() -> u64 {
  auto max = 0ul;

  for (auto i = 0ul; i < Texts.size(); ++i) {
    const auto text = Texts[i];
    if (const auto slot = pext(text, Mask); slot > max) {
      max = slot;
    }
  
  } return max + 1;
}

template <auto Texts, auto Kinds, u64 Mask, u64 Size>
[[nodiscard]]
consteval auto make_table() -> decltype(auto) {
  struct {
    Array<u64, Size> texts;
    Array<Token::Kind, Size> kinds;

  } table;

  for (auto i = 0u; i < Texts.size(); ++i) {
    const auto text = Texts[i];
    const auto kind = Kinds[i];

    const auto slot = pext(text, Mask);

    table.texts[slot] = text;
    table.kinds[slot] = kind;
    
  } return table;
}

struct Keyword {
  constexpr static auto Texts = Array {
    #define TOKEN_KEYWORD(Name, Text) \
      pack(Text),

    #include "lex/token.def"
  };

  constexpr static auto Kinds = Array {
    #define TOKEN_KEYWORD(Name, Text) \
      Token::Name,

    #include "lex/token.def"
  };

  constexpr static auto Mask = make_mask<Texts>();
  constexpr static auto Size = make_size<Texts, Mask>();
  constexpr static auto Table = make_table<Texts, Kinds, Mask, Size>();
};

struct Symbol {
  constexpr static auto Texts = std::array {
    #define TOKEN_SYMBOL(Name, Text) \
      pack(Text),

    #include "lex/token.def"
  };

  constexpr static auto Kinds = std::array {
    #define TOKEN_SYMBOL(Name, Text) \
      Token::Name,

    #include "lex/token.def"
  };

  constexpr static auto Mask = make_mask<Texts>();
  constexpr static auto Size = make_size<Texts, Mask>();
  constexpr static auto Table = make_table<Texts, Kinds, Mask, Size>();
};

} // anon

[[nodiscard]]
constexpr auto keyword(str text) -> Token::Kind {
  if (text.size() > 8) return Token::Ident;

  const auto data = pack(text);
  const auto slot = pext(data, Keyword::Mask);

  const auto match = Keyword::Table.texts[slot] == data;

  return static_cast<Token::Kind>(match * Keyword::Table.kinds[slot]);
}

[[nodiscard]]
constexpr auto symbol(str text) -> Token::Kind {
  assert_lte(text.size(), 8, "Attempted to lex too large a symbol");

  const auto data = pack(text);
  const auto slot = pext(data, Symbol::Mask);

  return Symbol::Table.kinds[slot];
}

} // neo::lex::lookup
