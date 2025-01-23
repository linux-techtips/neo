const std = @import("std");

extern fn Neo_Lex(x: usize, y: usize) usize;

pub fn main() void {
    std.debug.print("Hello from explorer!\n", .{});
    std.debug.print("{d}\n", .{Neo_Lex(34, 35)});
}
