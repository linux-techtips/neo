const tokenizer = @import("tokenizer.zig");
const builtin = @import("builtin");
const std = @import("std");

const allocator = if (builtin.target.isWasm()) std.heap.wasm_allocator else std.heap.page_allocator;

fn Neo_Wasm_Alloc(len: usize) callconv(.C) [*c]u8 {
    return if (allocator.alloc(u8, len)) |slice| slice.ptr else |_| @ptrFromInt(0);
}

fn Neo_Wasm_Free(ptr: [*c]const u8, len: usize) callconv(.C) void {
    allocator.free(ptr[0..len]);
}

const Wasm_Slice = packed struct(u64) {
    ptr: u32,
    len: u32,
};

export fn Neo_Source_Alloc(text_ptr: [*c]const u8, text_len: usize) callconv(.C) u64 {
    if (@intFromPtr(text_ptr) == 0) return 0;

    const source = tokenizer.Source.fromText(allocator, text_ptr[0..text_len :0]) catch return 0;
    return @bitCast(Wasm_Slice{
        .ptr = @intFromPtr(source.buffer.ptr),
        .len = source.buffer.len,
    });
}

export fn Neo_Source_Free(source_ptr: [*c]align(tokenizer.Source.ChunkSize) u8, source_len: usize) callconv(.C) void {
    if (@intFromPtr(source_ptr) == 0) return;

    const source = tokenizer.Source{ .buffer = @alignCast(source_ptr[0..source_len :0]), .path = undefined };
    source.deinit(allocator);
}

export fn Neo_Tokenize(source_ptr: [*c]align(tokenizer.Source.ChunkSize) u8, source_len: usize) callconv(.C) u64 {
    if (source_ptr == 0) return 0;

    const source = tokenizer.Source{ .buffer = @alignCast(source_ptr[0..source_len :0]), .path = undefined };
    const tokens = tokenizer.tokenize(allocator, source) catch return 0;

    return @bitCast(Wasm_Slice{
        .ptr = @intFromPtr(tokens.ptr),
        .len = tokens.len,
    });
}

export fn Neo_Token_Name(tag: tokenizer.Token.Tag) callconv(.C) [*:0]const u8 {
    return @tagName(tag);
}

comptime {
    if (builtin.target.isWasm()) @export(&Neo_Wasm_Alloc, .{ .name = "Neo_Alloc", .linkage = .strong });
    if (builtin.target.isWasm()) @export(&Neo_Wasm_Free, .{ .name = "Neo_Free", .linkage = .strong });
}
