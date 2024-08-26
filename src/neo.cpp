#ifdef UNITY
  #include <lexer/lex.cpp>
#else
  #include <lexer/lex.hpp>
#endif

#include <neo/core>

using namespace neo;

auto main(int argc, char** argv) -> int {
  const auto args = mem::Slice { argv, static_cast<usize>(argc) };

  if (args.size() < 2) {
    fmt::println(stderr, "[ERROR] Must provide a file to lex.");
    return 1;
  }

  const auto path = str { args[1] };

  if (auto source = lexer::Source::init(path)) {
    defer { source.deinit(); };

    auto arena = mem::Arena::init(mem::page_allocator);
    defer { arena.deinit(); };

    auto buffer = lexer::lex(arena.allocator(), source);
    defer { buffer.deinit(); };

    fmt::println("Number Literal Count: {}", buffer.number_literal_count);
    fmt::println("String Literal Count: {}", buffer.string_literal_count);
    fmt::println("Identifier Count: {}", buffer.ident_count);

  } else {
    fmt::println(stderr, "[ERROR] Could not open file: \"{}\"", path);
    return 1;
  }
}
