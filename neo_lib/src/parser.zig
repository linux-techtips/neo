const tokenizer = @import("tokenizer.zig");
const Source = @import("Source.zig");

const std = @import("std");

const operators = tokenizer.operators;

// TODO(carter): This needs to be more robust accounting for associativity and operator fixity.
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
                while (stack.pop()) |top| {
                    try tree.append(top);
                    if (top.tag == .@")") break;
                }
            },
            .reset => {
                while (stack.pop()) |top| {
                    try tree.append(top);
                    if (top.tag == .@")") break;
                }
                try tree.append(cur);
            },
            .binary => {
                while (true) if (stack.getLastOrNull()) |top| {
                    if (operators.precedence(top) < operators.precedence(cur)) break;
                    try tree.append(stack.pop().?);
                } else break;
                try stack.append(cur);
            },
            .symbol, .operand => try tree.append(cur),
        }

        if (idx == 0) break;
    }

    while (stack.pop()) |cur| try tree.append(cur);

    std.debug.assert(tree.items.len == tokens.len);
    return tree.allocatedSlice();
}
