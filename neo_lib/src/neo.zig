const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const Source = @import("Source.zig");

const builtin = @import("builtin");
const std = @import("std");

const Token = tokenizer.Token;

const Wasm = struct {
    const allocator = std.heap.wasm_allocator;

    fn Neo_Alloc(len: usize) callconv(.C) u64 {
        const slice = allocator.alloc(u8, len) catch unreachable;
        return @bitCast(slice);
    }

    fn Neo_Free(ptr: [*]const u8, len: usize) callconv(.C) void {
        allocator.free(ptr[0..len]);
    }

    fn Neo_Source_Alloc(text_ptr: [*]const u8, text_len: u32) callconv(.C) u64 {
        const source = Source.fromText(allocator, text_ptr[0..text_len :0]) catch unreachable;
        return @bitCast(source.buffer);
    }

    fn Neo_Source_Free(source_ptr: [*]const u8, source_len: u32) callconv(.C) void {
        Source.fromRawBuffer(source_ptr, source_len).deinit(allocator);
    }

    fn Neo_Tokenize(source_ptr: [*]const u8, source_len: u32) callconv(.C) u64 {
        const source = Source.fromRawBuffer(source_ptr, source_len);
        const tokens = tokenizer.tokenize(allocator, source) catch unreachable;

        return @bitCast(tokens);
    }

    fn Neo_Parse(tokens_ptr: [*]const Token, tokens_len: u32) callconv(.C) u64 {
        const tokens = tokens_ptr[0..tokens_len];
        const parseTree = parser.parse(allocator, tokens) catch unreachable;

        return @bitCast(parseTree);
    }

    fn Neo_Token_Name(tag: Token.Tag) callconv(.C) u64 {
        return @bitCast(@tagName(tag));
    }
};

const C = struct {
    const allocator = std.heap.page_allocator;

    const Neo_Slice = extern struct {
        ptr: [*]u8,
        len: usize,
    };

    const Neo_Source = extern struct {
        ptr: [*]const u8,
        len: u32,
    };

    const Neo_Tokens = extern struct {
        ptr: [*]const Token,
        len: u32,
    };

    fn Neo_Alloc(len: usize) callconv(.C) Neo_Slice {
        const slice = allocator.alloc(u8, len) catch unreachable;
        return .{ .ptr = slice.ptr, .len = slice.len };
    }

    fn Neo_Free(mem: Neo_Slice) callconv(.C) void {
        allocator.free(mem.ptr[0..mem.len]);
    }

    fn Neo_Source_Alloc(text_ptr: [*]const u8, text_len: usize) callconv(.C) Neo_Source {
        const source = Source.fromText(allocator, text_ptr[0..text_len :0]) catch unreachable;
        return .{ .ptr = source.buffer.ptr, .len = @intCast(source.buffer.len) };
    }

    fn Neo_Source_Free(neo_source: Neo_Source) callconv(.C) void {
        Source.fromRawBuffer(neo_source.ptr, neo_source.len).deinit(allocator);
    }

    fn Neo_Tokenize(neo_source: Neo_Source) callconv(.C) Neo_Tokens {
        const source = Source.fromRawBuffer(neo_source.ptr, neo_source.len);
        const tokens = tokenizer.tokenize(allocator, source) catch unreachable;

        return .{ .ptr = tokens.ptr, .len = @intCast(tokens.len) };
    }

    fn Neo_Parse(neo_tokens: Neo_Tokens) callconv(.C) Neo_Tokens {
        const tokens = neo_tokens.ptr[0..neo_tokens.len];
        const parseTree = parser.parse(allocator, tokens) catch unreachable;

        return .{ .ptr = parseTree.ptr, .len = @intCast(parseTree.len) };
    }

    fn Neo_Token_Name(tag: Token.Tag) callconv(.C) [*:0]const u8 {
        return @tagName(tag);
    }
};

comptime {
    const Scope = if (builtin.cpu.arch.isWasm()) Wasm else C;

    @export(&Scope.Neo_Alloc, .{ .name = "Neo_Alloc" });
    @export(&Scope.Neo_Free, .{ .name = "Neo_Free" });
    @export(&Scope.Neo_Source_Alloc, .{ .name = "Neo_Source_Alloc" });
    @export(&Scope.Neo_Source_Free, .{ .name = "Neo_Source_Free" });
    @export(&Scope.Neo_Tokenize, .{ .name = "Neo_Tokenize" });
    @export(&Scope.Neo_Parse, .{ .name = "Neo_Parse" });
    @export(&Scope.Neo_Token_Name, .{ .name = "Neo_Token_Name" });
}
