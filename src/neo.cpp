#include <neo/collections>

using namespace neo;

auto main() -> int {
  auto allocator = mem::c_allocator;
  auto list = ArrayList<int>::with_capacity(allocator, 100);
  defer { list.deinit(); };

  for (auto i = 0; i < 500; ++i) {
    list.push(i);
  }

  for (auto elem : list) {
    fmt::println("{}", elem);
  }
}
