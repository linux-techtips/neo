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
pub fn parse(source: tokenizer.Source, tokens: *[]tokenizer.Token) !void {
    std.debug.print("POSTFIX PARSER\n", .{});

    var cursor = Cursor.init(tokens.*, source);

    // TODO: We could reuse the back padding of the Source buffer as a stack? Seems fringe.
    var buffer: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const allocator = fba.allocator();

    var stack = std.ArrayListUnmanaged(tokenizer.Token){};
    var index: u32 = 0;

    while (cursor.iter()) |it| {
        const cur, _ = it;

        switch (cur.classify()) {
            .reset => {
                while (stack.popOrNull()) |top| {
                    if (top.tag == .@"(") break;

                    std.debug.print("{s}\n", .{@tagName(top.tag)});
                    tokens.*[index] = top;
                    index += 1;
                }

                std.debug.print("{s}\n", .{@tagName(cur.tag)});
                tokens.*[index] = cur;
                index += 1;
            },
            .unary => try stack.append(allocator, cur),
            .binary => {
                while (true) if (stack.getLastOrNull()) |top| {
                    if (top.precedence() < cur.precedence()) break;

                    std.debug.print("{s}\n", .{@tagName(top.tag)});
                    tokens.*[index] = stack.pop();
                    index += 1;
                } else break;

                try stack.append(allocator, cur);
            },
            else => {
                std.debug.print("{s}\n", .{@tagName(cur.tag)});
                tokens.*[index] = cur;
                index += 1;
            },
        }
    }

    while (stack.popOrNull()) |token| {
        std.debug.print("{s}\n", .{@tagName(token.tag)});
        tokens.*[index] = token;
        index += 1;
    }
}

const WalkError = error{
    UnbalancedExpression,
};

fn prefix(allocator: std.mem.Allocator, tokens: []tokenizer.Token) !void {
    std.debug.print("PREFIX PARSER\n", .{});

    var stack = try std.ArrayListUnmanaged(tokenizer.Token).initCapacity(allocator, tokens.len);
    defer stack.deinit(allocator);

    for (tokens) |token| if (token.isOperator()) {
        const rhs = stack.pop();
        const lhs = stack.pop();

        const expr = [_]tokenizer.Token{ token, rhs, lhs };
        try stack.appendSlice(allocator, &expr);
    } else try stack.append(allocator, token);

    for (stack.items) |token| {
        std.debug.print("{s}\n", .{@tagName(token.tag)});
    }
}

test "parse" {
    const source = try tokenizer.Source.fromText(std.testing.allocator, "a*b+c+d");
    defer source.deinit(std.testing.allocator);

    var tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    try parse(source, &tokens);
    try prefix(std.testing.allocator, tokens);
}

// test "precedence" {
//     const t0 = tokenizer.Token{ .tag = .number, .len = 0 };
//     try std.testing.expectEqual(t0.precedence(), 0);

//     const t1 = tokenizer.Token{ .tag = .@"+", .len = 0 };
//     const t2 = tokenizer.Token{ .tag = .@"*", .len = 0 };
//     try std.testing.expect(t2.precedence() > t1.precedence());
// }
