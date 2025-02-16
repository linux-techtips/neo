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

test "walk" {
    const source = try tokenizer.Source.fromText(std.testing.allocator, "a + b * c / d");
    defer source.deinit(std.testing.allocator);

    const tokens = try tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    var cursor = Cursor.init(tokens, source);
    while (cursor.iter()) |it| {
        const token, const slice = it;
        std.debug.print("Token: {s}, Slice: {s}\n", .{ @tagName(token.tag), slice });
    }
}
