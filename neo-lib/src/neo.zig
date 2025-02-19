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

export fn Neo_Alloc(len: usize) callconv(.C) [*]u8 {
    return if (allocator.alloc(u8, len)) |slice| slice.ptr else |_| unreachable;
}

export fn Neo_Free(ptr: [*]const u8, len: usize) callconv(.C) void {
    allocator.free(ptr[0..len]);
}

export fn Neo_Source_Free(source_ptr: [*]const u8, source_len: usize) callconv(.C) void {
    const source = tokenizer.Source.fromRawBuffer(source_ptr, source_len);
    source.deinit(allocator);
}

// TODO: The signatures of these functions only slightly differ for now, but in the future, there will be a difference between the wasm and native libraries.
usingnamespace if (builtin.target.isWasm()) struct {
    export fn Neo_Source_Alloc(text_ptr: [*]const u8, text_len: usize) callconv(.C) u64 {
        const source = tokenizer.Source.fromText(allocator, text_ptr[0..text_len :0]) catch unreachable;
        return @bitCast(Slice{
            .ptr = @intFromPtr(source.buffer.ptr),
            .len = source.buffer.len,
        });
    }

    export fn Neo_Tokenize(source_ptr: [*]const u8, source_len: usize) callconv(.C) u64 {
        const source = tokenizer.Source.fromRawBuffer(source_ptr, source_len);
        const tokens = tokenizer.tokenize(allocator, source) catch unreachable;

        return @bitCast(Slice{
            .ptr = @intFromPtr(tokens.ptr),
            .len = tokens.len,
        });
    }

    export fn Neo_Token_Name(tag: tokenizer.Token.Tag) callconv(.C) u64 {
        const slice: [:0]const u8 = @tagName(tag);
        return @bitCast(Slice{
            .ptr = @intFromPtr(slice.ptr),
            .len = slice.len,
        });
    }
} else struct {
    // TODO: Handle C Pointers.
    export fn Neo_Source_Alloc(text_ptr: [*]const u8, text_len: usize) callconv(.C) Slice {
        const source = tokenizer.Source.fromText(allocator, text_ptr[0..text_len :0]) catch unreachable;
        return .{
            .ptr = source.buffer.ptr,
            .len = source.buffer.len,
        };
    }

    // TODO: Handle C Pointers.
    export fn Neo_Tokenize(source_ptr: [*]const u8, source_len: usize) callconv(.C) Slice {
        const source = tokenizer.Source.fromRawBuffer(source_ptr, source_len);
        const tokens = tokenizer.tokenize(allocator, source) catch unreachable;

        return .{
            .ptr = tokens.ptr,
            .len = tokens.len,
        };
    }

    export fn Neo_Token_Name(tag: tokenizer.Token.Tag) callconv(.C) [*:0]const u8 {
        return @tagName(tag);
    }
};
