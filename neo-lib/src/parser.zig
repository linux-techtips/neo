const tokenizer = @import("tokenizer.zig");
const std = @import("std");

const Parser = struct {
    tokens: std.ArrayList(tokenizer.Token),
    cursor: Cursor,
    state: std.ArrayList(State),

    invalid: bool = false,

    pub fn init(heap_allocator: std.mem.Allocator, stack_allocator: std.mem.Allocator, tokens: []tokenizer.Token, source: tokenizer.Source) !Parser {
        return .{
            .tokens = try std.ArrayList(tokenizer.Token).initCapacity(heap_allocator, tokens.len),
            .cursor = Cursor.init(tokens, source),
            .state = std.ArrayList(State).init(stack_allocator),
        };
    }

    pub fn deinit(self: *const Parser) void {
        self.tokens.deinit();
    }

    pub fn parse(self: *Parser) ![]tokenizer.Token {
        // defer std.debug.assert(self.tokens.items.len == self.cursor.tokens.len);

        state: switch (State.start) {
            .start => {
                const token, _ = self.cursor.iter() orelse break :state;
                switch (token.tag) {
                    .ident => {
                        try self.tokens.append(token);
                        continue :state .decl;
                    },
                    else => std.debug.print("Invalid token: {any} for state: {s}\n", .{ @tagName(token.tag), @tagName(State.start) }),
                }
            },
            .decl => {
                const token, _ = self.cursor.iter() orelse break :state;
                switch (token.tag) {}
            },

            else => break :state,
        }

        return self.tokens.allocatedSlice();
    }

    const State = enum {
        start,
        invalid,
        decl,
    };

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
            const slice = self.text()[self.source_idx..][0..token.len];

            return .{ token, slice };
        }

        pub fn rest(self: *const Cursor) ?struct { []tokenizer.Token, []const u8 } {
            @branchHint(.unlikely);
            if (self.done()) return null;

            return .{ self.tokens[self.tokens_idx..], self.text()[self.source_idx..] };
        }

        pub fn text(self: *const Cursor) [:0]const u8 {
            return self.source.text();
        }

        pub fn iter(self: *Cursor) ?struct { tokenizer.Token, []const u8 } {
            @branchHint(.unlikely);
            if (self.done()) return null;

            const token, const slice = self.curr();
            self.next();

            return .{ token, slice };
        }
    };
};

pub fn parse(heap_allocator: std.mem.Allocator, tokens: []tokenizer.Token, source: tokenizer.Source) ![]tokenizer.Token {
    var stack: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&stack);

    const stack_allocator = fba.allocator();

    var parser = try Parser.init(heap_allocator, stack_allocator, tokens, source);
    errdefer parser.deinit();

    return try parser.parse();
}

test "parser" {
    const text = (
        \\
        \\ main : fn : {}
        \\
    );

    const source = try tokenizer.Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const tree = try parse(std.testing.allocator, tokens, source);
    defer std.testing.allocator.free(tree);

    // for (tree) |token| {
    //     std.debug.print("{s}\n", .{@tagName(token.tag)});
    // }
}

// test "parse" {
//     const source = try tokenizer.Source.fromText(std.testing.allocator, "a*b+c+d");
//     defer source.deinit(std.testing.allocator);

//     const tokens = try tokenizer.tokenize(std.testing.allocator, source);
//     defer std.testing.allocator.free(tokens);

//     const expected_tokens = [_]tokenizer.Token{
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .@"*", .len = 1 },
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .@"+", .len = 1 },
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .@"+", .len = 1 },
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .newline, .len = 1 },
//         .{ .tag = .eof, .len = 0 },
//     };

//     try std.testing.expectEqualSlices(tokenizer.Token, &expected_tokens, tokens);

//     const tree = try parse_postfix(std.testing.allocator, source, tokens);
//     defer std.testing.allocator.free(tree);

//     const expected_tree = [_]tokenizer.Token{
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .@"*", .len = 1 },
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .@"+", .len = 1 },
//         .{ .tag = .ident, .len = 1 },
//         .{ .tag = .@"+", .len = 1 },
//         .{ .tag = .newline, .len = 1 },
//         .{ .tag = .eof, .len = 0 },
//     };

//     try std.testing.expectEqualSlices(tokenizer.Token, &expected_tree, tree);
// }

// https://en.wikipedia.org/wiki/Shunting_yard_algorithm
pub fn parse_postfix(heap_allocator: std.mem.Allocator, source: tokenizer.Source, tokens: []tokenizer.Token) ![]tokenizer.Token {
    var tree = try std.ArrayList(tokenizer.Token).initCapacity(heap_allocator, tokens.len);
    errdefer tree.deinit();

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const stack_allocator = fba.allocator();
    var stack = std.ArrayList(tokenizer.Token).init(stack_allocator);

    var cursor = Parser.Cursor.init(tokens, source);
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
            else => try tree.append(cur),
        }
    }

    while (stack.popOrNull()) |token| try tree.append(token);

    return tree.items;
}
