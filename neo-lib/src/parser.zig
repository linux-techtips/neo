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

test "prefix" {
    const text = (
        \\ add : fn(x: u32, y: u32) : {
        \\   x + y
        \\ }
    );

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const tree = try parse(std.testing.allocator, tokens);
    defer std.testing.allocator.free(tree);
}
