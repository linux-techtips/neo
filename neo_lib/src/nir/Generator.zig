const tokenizer = @import("../tokenizer.zig");
const nir = @import("../nir.zig");
const std = @import("std");

const Generator = @This();

const Allocator = std.mem.Allocator;
const Source = @import("../Source.zig");
const Token = tokenizer.Token;

const Module = nir.Module;
const Error = nir.Error;
const Inst = nir.Inst;

const Stack = std.ArrayListUnmanaged(struct {
    tokens_idx: Token.Index,
    source_idx: u32,
    state: State,
});

module: Module = .new,

tokens: []const Token,
source: [:0]const u8,

stack: Stack,

pub const State = enum(u8) {
    start,
};

pub fn init(allocator: Allocator, source: Source, tokens: []const Token) Generator {
    const stack = Stack.append(allocator, .{
        .tokens_idx = @intCast(tokens.len - 1),
        .source_idx = 0,
        .state = .start,
    });

    return .{
        .tokens = tokens,
        .source = source.text(),
        .stack = stack,
    };
}

pub fn deinit(self: *Generator, allocator: Allocator) void {
    self.stack.deinit(allocator);
}

pub fn generate(self: *Generator, allocator: Allocator) Error!Module {
    try self.gen(allocator);

    return self.module;
}
