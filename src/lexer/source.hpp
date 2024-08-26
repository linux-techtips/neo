#pragma once

#include <neo/collections>

namespace neo::lexer {

struct Line {
  u64 offset;
  u64 length;
  u64 indent;
};

using Lines = ArrayList<Line>;

struct Map {
  u8 *ptr;
  usize len;

  [[nodiscard]]
  static auto init(str path) -> Map {
    static_assert(sys::os == sys::Os::Linux);

    auto fd = open(path.ptr, O_RDONLY);
    if (fd == -1) [[unlikely]] return {};

    struct stat stats;
    fstat(fd, &stats);

    const auto len = static_cast<usize>(stats.st_size);

    assert_lt(len, UINT32_MAX,
              "Cannot support files larger than 4gigs at this point. Consider "
              "not doing what you're doing");

    auto *ptr = mmap(nullptr, len, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);

    return { (ptr != MAP_FAILED) ? reinterpret_cast<u8*>(ptr) : nullptr, len };
  }

  auto deinit(this auto &&self) -> void {
    if (self.ptr)
      munmap(self.ptr, self.len);
  }
};

struct Source {
  str path;
  Map map;

  [[nodiscard]]
  static auto init(str path) -> Source {
    return {
        .path = path,
        .map = Map::init(path),
    };
  }

  auto deinit(this auto &&self) -> void { self.map.deinit(); }

  [[nodiscard]]
  auto size(this auto &&self) -> usize {
    return self.map.len;
  }

  [[nodiscard]]
  auto data(this auto &&self) -> mem::Slice<u8> {
    return {self.map.ptr, self.map.len};
  }

  [[nodiscard]]
  auto as_str(this auto &&self) -> str {
    return {reinterpret_cast<const char *>(self.map.ptr), self.map.len};
  }

  auto lines(this auto &&self, mem::Allocator allocator) -> Lines {
    // TODO: Guestimate initial capacity based on files size.
    auto lines = Lines::with_capacity(allocator, sys::page_size);

    const auto slice = self.as_str();
    const auto size = slice.size();

    auto start = 0ul;

    auto next = [&] {
      return __builtin_bit_cast(
          const char *, __builtin_memchr(&slice[start], '\n', size - start));
    };

    while (const auto &newline = next()) {
      const auto index = newline - slice.ptr;

      lines.push({
          .offset = start,
          .length = static_cast<u32>(index - start),
      });

      start = index + 1ul;
    }
    lines.push({
        .offset = start,
        .length = static_cast<u32>(size - start),
    });

    if (start != size)
      lines.push({.offset = size});

    return lines;
  }

  [[nodiscard]]
  operator bool(this auto &&self) {
    return self.map.ptr;
  }
};

} // namespace neo::lexer
