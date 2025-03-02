const tokenizer = @import("tokenizer.zig");
const Source = @import("Source.zig");

const Token = tokenizer.Token;

pub const CursorConfig = enum {
    inorder,
    preorder,
};

pub fn Cursor(config: CursorConfig) type {
    return if (config == .inorder) struct {
        source: [:0]const u8,
        tokens: []Token,

        source_idx: u32 = 0,
        tokens_idx: u32 = 0,

        const Self = @This();

        pub fn init(source: Source, tokens: []Token) Self {
            return .{ .source = source.text(), .tokens = tokens };
        }

        pub fn next(self: *Self) ?struct { Token.Tag, []const u8 } {
            if (self.tokens_idx >= self.tokens.len) return null;

            const token = self.tokens[self.tokens_idx];
            self.tokens_idx += 1;

            const len: u16 = if (token.len != 0) token.len else @bitCast(self.tokens[self.tokens_idx]);
            self.tokens_idx += @intFromBool(token.len == 0);

            const index = self.source_idx - @as(u32, if (token.tag == .eof) 1 else 0);
            const slice = self.source[index..][0..len];
            self.source_idx += len;

            return .{ token.tag, slice };
        }
    } else unreachable;
}
