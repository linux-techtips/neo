const tokenizer = @import("tokenizer.zig");
const std = @import("std");
const builtin = @import("builtin");

const Text = extern struct {
    ptr: ?[*:0]const u8,
    len: usize,
};

const Source = extern struct {
    ptr: ?[*:0]align(tokenizer.Source.ChunkSize) const u8,
    len: usize,
};

const Tokens = extern struct {
    ptr: ?[*]const tokenizer.Token,
    len: usize,
};

fn Neo_Tokenize(source: Source) callconv(.C) Tokens {
    const allocator = std.heap.page_allocator;

    const neo_source = if (source.ptr) |ptr| tokenizer.Source{
        .buffer = ptr[0..source.len :0],
        .path = undefined,
    } else return .{ .ptr = null, .len = 0 };

    return if (tokenizer.tokenize(allocator, neo_source)) |tokens| .{
        .ptr = tokens.ptr,
        .len = tokens.len,
    } else |_| .{ .ptr = null, .len = 0 };
}

fn Neo_Source_Alloc(text: Text) callconv(.C) Source {
    const allocator = if (builtin.target.isWasm()) std.heap.wasm_allocator else std.heap.page_allocator;

    return if (tokenizer.Source.fromText(allocator, (text.ptr orelse unreachable)[0..text.len :0])) |source| .{
        .ptr = source.buffer.ptr,
        .len = source.buffer.len,
    } else |_| .{
        .ptr = null,
        .len = 0,
    };
}

fn Neo_Source_Dealloc(source: Source) callconv(.C) void {
    const allocator = std.heap.page_allocator;
    const buffer = if (source.ptr) |ptr| ptr[0..source.len :0] else return;

    @as(tokenizer.Source, .{ .buffer = buffer, .path = undefined }).deinit(allocator);
}

const Test = extern struct {
    ptr: ?[*]const u8,
    len: usize,
};

export fn Neo_Test(text_ptr: ?[*]const u8, text_len: usize) ?[*]const u8 {
    const allocator = std.heap.wasm_allocator;
    const text = (text_ptr orelse unreachable)[0..text_len];

    const buffer = allocator.alloc(u8, text.len) catch unreachable;

    for (text, 0..) |ch, i| if (ch >= 'a' and ch <= 'z') {
        buffer[i] = ch - ('a' - 'A');
    } else {
        buffer[i] = ch;
    };

    return buffer.ptr;
}
