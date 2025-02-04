const tokenizer = @import("tokenizer.zig");
const std = @import("std");

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

export fn Neo_Tokenize(source: Source) callconv(.C) Tokens {
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

export fn Neo_Source_Alloc(text: Text) callconv(.C) Source {
    const allocator = std.heap.page_allocator;

    return if (tokenizer.Source.fromText(allocator, (text.ptr orelse unreachable)[0..text.len :0])) |source| .{
        .ptr = source.buffer.ptr,
        .len = source.buffer.len,
    } else |_| .{
        .ptr = null,
        .len = 0,
    };
}

export fn Neo_Source_Dealloc(source: Source) callconv(.C) void {
    const allocator = std.heap.page_allocator;
    const buffer = if (source.ptr) |ptr| ptr[0..source.len :0] else return;

    @as(tokenizer.Source, .{ .buffer = buffer, .path = undefined }).deinit(allocator);
}
