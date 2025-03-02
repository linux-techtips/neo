const tokenizer = @import("tokenizer.zig");
const Source = @import("Source.zig");

const std = @import("std");

const operators = tokenizer.operators;

pub fn parse(allocator: std.mem.Allocator, tokens: []const tokenizer.Token) ![]tokenizer.Token {
    var tree = try std.ArrayList(tokenizer.Token).initCapacity(allocator, tokens.len);
    errdefer tree.deinit();

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const stack_allocator = fba.allocator();
    var stack = std.ArrayList(tokenizer.Token).init(stack_allocator);

    var idx = tokens.len - 1;
    while (true) : (idx -= 1) {
        const cur = tokens[idx];

        const lookahead = if (idx > 0) tokens[idx - 1] else cur;
        if (lookahead.len == 0) {
            try tree.append(cur);
            if (idx == 0) break;
            continue;
        }

        switch (operators.classify(cur)) {
            .unary_prefix => try stack.append(cur),
            .unary_postfix => {
                try tree.append(cur);
                while (stack.popOrNull()) |top| {
                    try tree.append(top);
                    if (top.tag == .@")") break;
                }
            },
            .reset => {
                while (stack.popOrNull()) |top| {
                    try tree.append(top);
                    if (top.tag == .@")") break;
                }
                try tree.append(cur);
            },
            .binary => {
                while (true) if (stack.getLastOrNull()) |top| {
                    if (operators.precedence(top) < operators.precedence(cur)) break;
                    try tree.append(stack.pop());
                } else break;
                try stack.append(cur);
            },
            .symbol, .operand => try tree.append(cur),
        }

        if (idx == 0) break;
    }

    while (stack.popOrNull()) |cur| try tree.append(cur);

    std.debug.assert(tree.items.len == tokens.len);
    return tree.allocatedSlice();
}

test "parse prefix expression" {
    const text = (
        \\(a+y)*(b-c)/d+e
    );

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const tree = try parse(std.testing.allocator, tokens);
    defer std.testing.allocator.free(tree);

    const expected_tree = [_]tokenizer.Token{
        .{ .tag = .eof, .len = 1 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@")", .len = 1 },
        .{ .tag = .@"/", .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"-", .len = 1 },
        .{ .tag = .@"(", .len = 1 },
        .{ .tag = .@"*", .len = 1 },
        .{ .tag = .@")", .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .@"(", .len = 1 },
    };

    try std.testing.expectEqualSlices(tokenizer.Token, &expected_tree, tree);
}

test "parse biiig token" {
    const text = "a" ** 500 ++ "\n" ++ (
        \\ x + y + z
    );

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const tree = try parse(std.testing.allocator, tokens);
    defer std.testing.allocator.free(tree);

    const expected_tree = [_]tokenizer.Token{
        .{ .tag = .eof, .len = 1 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .newline, .len = 1 },
        @bitCast(@as(u16, 500)),
        .{ .tag = .ident, .len = 0 },
    };

    try std.testing.expectEqualSlices(tokenizer.Token, &expected_tree, tree);
}
