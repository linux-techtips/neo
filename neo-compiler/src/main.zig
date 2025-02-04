const std = @import("std");

const Text = extern struct {
    ptr: ?[*:0]const u8,
    len: usize,
};

const Source = extern struct {
    ptr: ?[*:0]const u8,
    len: usize,
};

const Token = extern struct {
    tag: u8,
    len: u8,
};

const Tokens = extern struct {
    ptr: ?[*]Token,
    len: usize,
};

extern fn Neo_Source_Alloc(text: Text) callconv(.C) Source;
extern fn Neo_Source_Dealloc(source: Source) callconv(.C) void;
extern fn Neo_Tokenize(source: Source) callconv(.C) Tokens;

pub fn main() void {
    const text = "Hello World";
    const source = Neo_Source_Alloc(.{ .ptr = text.ptr, .len = text.len });
    defer Neo_Source_Dealloc(source);

    const buffer = Neo_Tokenize(source);
    const tokens = (buffer.ptr orelse unreachable)[0..buffer.len];

    for (tokens) |token| {
        std.debug.print("{d} {d}\n", .{ token.tag, token.len });
    }
}
