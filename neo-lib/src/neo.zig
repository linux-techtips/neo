const tokenizer = @import("tokenizer.zig");
const builtin = @import("builtin");
const std = @import("std");

const allocator = if (builtin.target.isWasm()) std.heap.wasm_allocator else std.heap.page_allocator;

const Slice = if (builtin.target.isWasm()) packed struct(u64) {
    ptr: u32,
    len: u32,
} else extern struct {
    ptr: [*c]const u8,
    len: usize,
};

fn Neo_Wasm_Alloc(len: usize) callconv(.C) [*]u8 {
    return if (allocator.alloc(u8, len)) |slice| slice.ptr else |_| unreachable;
}

fn Neo_Wasm_Free(ptr: [*c]const u8, len: usize) callconv(.C) void {
    allocator.free(ptr[0..len]);
}

fn Neo_Wasm_Source_Alloc(text_ptr: [*]const u8, text_len: usize) callconv(.C) u64 {
    const source = tokenizer.Source.fromText(allocator, text_ptr[0..text_len :0]) catch unreachable;
    return @bitCast(Slice{
        .ptr = @intFromPtr(source.buffer.ptr),
        .len = source.buffer.len,
    });
}

fn Neo_Wasm_Source_Free(source_ptr: [*]const u8, source_len: usize) callconv(.C) void {
    const source = tokenizer.Source{ .buffer = @alignCast(source_ptr[0..source_len :0]), .path = "(wasm)" };
    source.deinit(allocator);
}

fn Neo_Wasm_Tokenize(source_ptr: [*]const u8, source_len: usize) callconv(.C) u64 {
    const source = tokenizer.Source{ .buffer = @alignCast(source_ptr[0..source_len :0]), .path = "(wasm)" };
    const tokens = tokenizer.tokenize(allocator, source) catch unreachable;

    return @bitCast(Slice{
        .ptr = @intFromPtr(tokens.ptr),
        .len = tokens.len,
    });
}

export fn Neo_Token_Name(tag: tokenizer.Token.Tag) callconv(.C) [*:0]const u8 {
    return @tagName(tag);
}

comptime {
    if (builtin.target.isWasm()) {
        @export(&Neo_Wasm_Alloc, .{ .name = "Neo_Alloc", .linkage = .strong });
        @export(&Neo_Wasm_Free, .{ .name = "Neo_Free", .linkage = .strong });
        @export(&Neo_Wasm_Source_Alloc, .{ .name = "Neo_Source_Alloc", .linkage = .strong });
        @export(&Neo_Wasm_Source_Free, .{ .name = "Neo_Source_Free", .linkage = .strong });
        @export(&Neo_Wasm_Tokenize, .{ .name = "Neo_Tokenize", .linkage = .strong });
    }
}
