#pragma once

#ifndef __SIZEOF_INT128__
#error "Here's a nickel kid, go buy yourself a real computer."
#endif

using u128 = __uint128_t;
using u64 = __UINT64_TYPE__;
using u32 = __UINT32_TYPE__;
using u16 = __UINT16_TYPE__;
using u8 = __UINT8_TYPE__;

static_assert(sizeof(u128) == 16);
static_assert(sizeof(u64) == 8);
static_assert(sizeof(u32) == 4);
static_assert(sizeof(u16) == 2);
static_assert(sizeof(u8) == 1);

using s128 = __int128_t;
using s64 = __INT64_TYPE__;
using s32 = __INT32_TYPE__;
using s16 = __INT16_TYPE__;
using s8 = __INT8_TYPE__;

static_assert(sizeof(s128) == 16);
static_assert(sizeof(s64) == 8);
static_assert(sizeof(s32) == 4);
static_assert(sizeof(s16) == 2);
static_assert(sizeof(s8) == 1);

using d128 = long double;
using d64 = double;
using d32 = float;

static_assert(sizeof(d128) == 16);
static_assert(sizeof(d64) == 8);
static_assert(sizeof(d32) == 4);


using usize = u64;
using ssize = s64;
using dsize = d64;

static_assert(sizeof(usize) == 8);
static_assert(sizeof(ssize) == 8);
static_assert(sizeof(dsize) == 8);
