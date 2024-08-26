#pragma once

#if defined(__x86_64__) or defined(_M_X64)
  #include <x86intrin.h>
#endif

#include <neo/collections>

namespace neo::lexer::scan {

namespace {

using ScalarLUT = Array<bool, 256>;

#if defined(__x86_64__) or defined(_M_X64)

struct alignas(16) SimdLUT {
  u8 nibble_0;
  u8 nibble_1;
  u8 nibble_2;
  u8 nibble_3;
  u8 nibble_4;
  u8 nibble_5;
  u8 nibble_6;
  u8 nibble_7;
  u8 nibble_8;
  u8 nibble_9;
  u8 nibble_a;
  u8 nibble_b;
  u8 nibble_c;
  u8 nibble_d;
  u8 nibble_e;
  u8 nibble_f;

  [[nodiscard, gnu::always_inline]]
  auto load() const -> __m128i {
    return _mm_load_si128(reinterpret_cast<const __m128i*>(this));
  }
};

#endif


struct KeywordOrIdent {
  // TODO: Unicode identifiers.
  constexpr static auto Table = [] {
    auto table = ScalarLUT {};

    for (usize ch = 'A'; ch <= 'Z'; ++ch) table[ch] = true;
    for (usize ch = 'a'; ch <= 'z'; ++ch) table[ch] = true;
    for (usize ch = '0'; ch <= '9'; ++ch) table[ch] = true;

    table['_'] = true;

    return table;
  }();

#if defined(__x86_64__) or defined(_M_X64)

  constexpr static auto High = SimdLUT {
    .nibble_0 = 0b0000'0000,
    .nibble_1 = 0b0000'0000,
    .nibble_2 = 0b0000'0000,
    .nibble_3 = 0b0000'0010,
    .nibble_4 = 0b0000'0100,
    .nibble_5 = 0b0000'1001,
    .nibble_6 = 0b0000'0100,
    .nibble_7 = 0b0000'1000,
    .nibble_8 = 0b1000'0000,
    .nibble_9 = 0b1000'0000,
    .nibble_a = 0b1000'0000,
    .nibble_b = 0b1000'0000,
    .nibble_c = 0b1000'0000,
    .nibble_d = 0b1000'0000,
    .nibble_e = 0b1000'0000,
    .nibble_f = 0b1000'0000,
  };
  
  constexpr static auto Low = SimdLUT {
    .nibble_0 = 0b1000'1010,
    .nibble_1 = 0b1000'1110,
    .nibble_2 = 0b1000'1110,
    .nibble_3 = 0b1000'1110,
    .nibble_4 = 0b1000'1110,
    .nibble_5 = 0b1000'1110,
    .nibble_6 = 0b1000'1110,
    .nibble_7 = 0b1000'1110,
    .nibble_8 = 0b1000'1110,
    .nibble_9 = 0b1000'1110,
    .nibble_a = 0b1000'1100,
    .nibble_b = 0b1000'0100,
    .nibble_c = 0b1000'0100,
    .nibble_d = 0b1000'0100,
    .nibble_e = 0b1000'0100,
    .nibble_f = 0b1000'0101,
  };
};

#endif

struct NumberLiteral {
  constexpr static auto Table = [] {
    auto table = ScalarLUT {};

    for (usize ch = '0'; ch <= '9'; ++ch) table[ch] = true;
    for (usize ch = 'a'; ch <= 'f'; ++ch) table[ch] = true;
    for (usize ch = 'A'; ch <= 'F'; ++ch) table[ch] = true;

    table['_'] = true;
    table['.'] = true;

    table['+'] = true;
    table['-'] = true;

    table['o'] = true;
    table['b'] = true;
    table['x'] = true;

    return table;
  }();

#if defined(__x86_64__) or defined(_M_X64)

  constexpr static auto High = SimdLUT {
    .nibble_0 = 0b0000'0000,
    .nibble_1 = 0b0000'0000,
    .nibble_2 = 0b0000'0100,
    .nibble_3 = 0b0001'0000,
    .nibble_4 = 0b0000'1000,
    .nibble_5 = 0b0000'0010,
    .nibble_6 = 0b0000'1000,
    .nibble_7 = 0b0000'0001,
    .nibble_8 = 0b0000'0000,
    .nibble_9 = 0b0000'0000,
    .nibble_a = 0b0000'0000,
    .nibble_b = 0b0000'0000,
    .nibble_c = 0b0000'0000,
    .nibble_d = 0b0000'0000,
    .nibble_e = 0b0000'0000,
    .nibble_f = 0b0000'0000,
  };

  constexpr static auto Low = SimdLUT {
    .nibble_0 = 0b0001'0000,
    .nibble_1 = 0b0001'1000,
    .nibble_2 = 0b0001'1000,
    .nibble_3 = 0b0001'1000,
    .nibble_4 = 0b0001'1000,
    .nibble_5 = 0b0001'1000,
    .nibble_6 = 0b0001'1000,
    .nibble_7 = 0b0001'0000,
    .nibble_8 = 0b0001'0001,
    .nibble_9 = 0b0001'0000,
    .nibble_a = 0b0000'0000,
    .nibble_b = 0b0000'0100,
    .nibble_c = 0b0000'0000,
    .nibble_d = 0b0000'0100,
    .nibble_e = 0b0000'0100,
    .nibble_f = 0b0000'0010, 
  };
};

#endif

struct Symbol {
  constexpr static auto Table = [] {
    auto table = ScalarLUT {};

    table[':'] = true;
    table['='] = true;

    table['&'] = true;
    table['|'] = true;
    table['^'] = true;
    table['~'] = true;

    table['+'] = true;
    table['-'] = true;
    table['*'] = true;
    table['/'] = true;
    table['%'] = true;

    table['.'] = true;
    table[','] = true;
    table['?'] = true;
    table['!'] = true;
    table['#'] = true;

    table['<'] = true;
    table['>'] = true;

    return table;
  }();

#if defined(__x86_64__) or defined(_M_X64)

  constexpr static auto High = SimdLUT {
    .nibble_0 = 0b0000'0000,
    .nibble_1 = 0b0000'0000,
    .nibble_2 = 0b0000'1000,
    .nibble_3 = 0b0000'0100,
    .nibble_4 = 0b0000'0000,
    .nibble_5 = 0b0000'0001,
    .nibble_6 = 0b0000'0000,
    .nibble_7 = 0b0000'0010,
    .nibble_8 = 0b0000'0000,
    .nibble_9 = 0b0000'0000,
    .nibble_a = 0b0000'0000,
    .nibble_b = 0b0000'0000,
    .nibble_c = 0b0000'0000,
    .nibble_d = 0b0000'0000,
    .nibble_e = 0b0000'0000,
    .nibble_f = 0b0000'0000,
  };

  constexpr static auto Low = SimdLUT {
    .nibble_0 = 0b0000'0000,
    .nibble_1 = 0b0000'1000,
    .nibble_2 = 0b0000'0000,
    .nibble_3 = 0b0000'1000,
    .nibble_4 = 0b0000'0000,
    .nibble_5 = 0b0000'1000,
    .nibble_6 = 0b0000'1000,
    .nibble_7 = 0b0000'0000,
    .nibble_8 = 0b0000'0000,
    .nibble_9 = 0b0000'0000,
    .nibble_a = 0b0000'1100,
    .nibble_b = 0b0000'1000,
    .nibble_c = 0b0000'1110,
    .nibble_d = 0b0000'1100,
    .nibble_e = 0b0000'1111,
    .nibble_f = 0b0000'1100,
  };
};

#endif

template <typename Impl>
[[nodiscard]]
constexpr auto scan_scalar(str text) -> str {
  auto size = 0ull;

  while (size < text.size() and Impl::Table[static_cast<usize>(text[size])]) ++size;

  return text.slice(0, size);
} 

#if defined(__x86_64__) or defined(_M_X64)

template <typename Impl>
[[nodiscard]]
constexpr auto scan_simd(str text) -> str {
  const auto high = Impl::High.load();
  const auto low = Impl::Low.load();

  auto size = 0ull;

  for (; size + sizeof(SimdLUT) <= text.size(); size += sizeof(SimdLUT)) {
    const auto input = _mm_loadu_si128(std::bit_cast<const __m128i*>(text.ptr + size));

    #if __SSE4_1__
      if (not _mm_test_all_zeros(_mm_set1_epi8(static_cast<char>(0x80)), input)) break;
    #else
      if (_mm_movemask_epi8(input)) break;
    #endif

    const auto high_input = _mm_and_si128(_mm_srli_epi32(input, 4), _mm_set1_epi8(0x0f));
    const auto high_mask = _mm_shuffle_epi8(high, high_input);
    const auto low_mask = _mm_shuffle_epi8(low, input);

    const auto mask = _mm_and_si128(low_mask, high_mask);

    const auto id_nibble_mask = _mm_cmpeq_epi8(mask, _mm_setzero_si128());
    const auto tail_ascii_mask = static_cast<u32>(_mm_movemask_epi8(id_nibble_mask));

    if (tail_ascii_mask) [[likely]] {
      return text.slice(0, size + static_cast<usize>(__builtin_ctz(tail_ascii_mask)));
    }

  } return text.slice(0, size + scan_scalar<Impl>(text.slice(0, size)).size());
}

#endif

template <typename Impl>
[[nodiscard, gnu::always_inline]]
constexpr auto scan(str text) -> str {
#if defined(__x86_64__) or defined(_M_X64) 
  return scan_simd<Impl>(text);
#else
  return scan_scalar<Impl>(text);
#endif
} 

} // hidden

[[nodiscard, gnu::always_inline]]
constexpr auto keyword_or_ident(str text) -> str {
  return scan<KeywordOrIdent>(text);
}

[[nodiscard, gnu::always_inline]]
constexpr auto number_literal(str text) -> str {
    return scan<NumberLiteral>(text);
}

[[nodiscard, gnu::always_inline]]
constexpr auto string_literal(str text) -> str {
  const auto* start = text.ptr + 1;
  const auto* end = __builtin_bit_cast(const char*, __builtin_memchr(start, '\"', text.size()));

  // TODO: Account for the case where we do not find a matching '\"'

  return text.slice(0, static_cast<usize>(end - start + 2));
}

[[nodiscard, gnu::always_inline]]
constexpr auto symbol(str text) -> str {
    return scan<Symbol>(text);
}

} // neo::lexer::scan

