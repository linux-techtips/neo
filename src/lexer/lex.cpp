#include <lexer/lexer.hpp>

namespace neo::lexer {

[[nodiscard]]
auto lex(mem::Allocator allocator, Source& source) -> Buffer {
  auto lexer = Lexer::init(allocator, source);
  defer { lexer.deinit(); };

  while (not lexer.cursor.eof()) {
    (DispatchTable[static_cast<usize>(lexer.cursor.curr())])(lexer);
  
  } return lexer.buffer;
}

} // neo::lexer;
