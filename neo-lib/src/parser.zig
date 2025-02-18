const tokenizer = @import("tokenizer.zig");
const std = @import("std");

const Cursor = struct {
    tokens: []tokenizer.Token,
    source: tokenizer.Source,

    tokens_idx: u32 = 0,
    source_idx: u32 = 0,

    pub fn init(tokens: []tokenizer.Token, source: tokenizer.Source) Cursor {
        return .{ .tokens = tokens, .source = source };
    }

    pub fn done(self: *const Cursor) bool {
        return (self.tokens_idx >= self.tokens.len);
    }

    pub fn next(self: *Cursor) void {
        _, const slice = self.curr();

        // SAFETY: The length of a slice should never exceed the bounds of `u8`.
        self.source_idx += @intCast(slice.len);
        self.tokens_idx += 1;
    }

    pub fn curr(self: *const Cursor) struct { tokenizer.Token, []const u8 } {
        const token = self.tokens[self.tokens_idx];
        const slice = self.source.text()[self.source_idx..][0..token.len];

        return .{ token, slice };
    }

    pub fn rest(self: *const Cursor) ?struct { []tokenizer.Token, []const u8 } {
        @branchHint(.unlikely);
        if (self.done()) return null;

        return .{ self.tokens[self.tokens_idx..], self.source.text()[self.source_idx..] };
    }

    pub fn iter(self: *Cursor) ?struct { tokenizer.Token, []const u8 } {
        @branchHint(.unlikely);
        if (self.done()) return null;

        const token, const slice = self.curr();
        self.next();

        return .{ token, slice };
    }
};

// https://en.wikipedia.org/wiki/Shunting_yard_algorithm
pub fn parse_postfix(heap_allocator: std.mem.Allocator, source: tokenizer.Source, tokens: []tokenizer.Token) ![]tokenizer.Token {
    var tree = try std.ArrayList(tokenizer.Token).initCapacity(heap_allocator, tokens.len);
    errdefer tree.deinit();

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const stack_allocator = fba.allocator();
    var stack = std.ArrayList(tokenizer.Token).init(stack_allocator);

    var cursor = Cursor.init(tokens, source);
    while (cursor.iter()) |it| {
        const cur, _ = it;

        switch (cur.classify()) {
            .reset => {
                while (stack.popOrNull()) |top| {
                    if (top.tag == .@"(") break;
                    try tree.append(top);
                }

                try tree.append(cur);
            },
            .unary => try stack.append(cur),
            .binary => {
                while (true) if (stack.getLastOrNull()) |top| {
                    if (top.precedence() < cur.precedence()) break;
                    try tree.append(stack.pop());
                } else break;

                try stack.append(cur);
            },
            else => {
                try tree.append(cur);
            },
        }
    }

    while (stack.popOrNull()) |token| try tree.append(token);

    return tree.items;
}

test "parse" {
    const source = try tokenizer.Source.fromText(std.testing.allocator, "a*b+c+d");
    defer source.deinit(std.testing.allocator);

    const tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const expected_tokens = [_]tokenizer.Token{
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"*", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .eof, .len = 0 },
    };

    try std.testing.expectEqualSlices(tokenizer.Token, tokens, &expected_tokens);

    const tree = try parse_postfix(std.testing.allocator, source, tokens);
    defer std.testing.allocator.free(tree);

    const expected_tree = [_]tokenizer.Token{
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"*", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .eof, .len = 0 },
    };

    try std.testing.expectEqualSlices(tokenizer.Token, tree, &expected_tree);
}
