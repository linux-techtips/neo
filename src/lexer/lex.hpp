#pragma once

#include <lexer/source.hpp>
#include <lexer/buffer.hpp>

namespace neo::lexer {

[[nodiscard]]
auto lex(mem::Allocator allocator, Source& source) -> Buffer;

} // neo::lexer
