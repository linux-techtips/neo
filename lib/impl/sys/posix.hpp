#pragma once

#include <neo/core>

namespace neo::sys::posix {

struct Prot {
  constexpr static auto Read = 0x1;
  constexpr static auto Write = 0x2;
  constexpr static auto Exec = 0x4;
  constexpr static auto None = 0x0;
};

struct Map {
  constexpr static auto Shared = 0x01;
  constexpr static auto Private = 0x02;
  constexpr static auto Exec = 0x4;
  constexpr static auto Anon = 0x20;
};

struct Remap {
  constexpr static auto MayMove = 1;
};

extern "C" auto mmap(void* addr, usize size, int prot, int flags, int fd, u32 offset) -> void*;
extern "C" auto mremap(void* addr, usize old_size, usize new_size, int flags) -> void*;
extern "C" auto munmap(void* addr, usize size) -> int;

} // neo::sys::posix
