const std = @import("std");

const Source = @import("Source.zig");

const Tokenizer = struct {
    const State = enum {
        whitespace,
        newline,
        string,
        char,
        number,
        start,
        ident,
        symbol,
        invalid,
        eof,
    };

    text: [:0]const u8,

    tokens: []Token = undefined,
    tokenCount: usize = 0,

    begin: u32 = 0,
    index: u32 = 0,

    pub fn tokenize(allocator: std.mem.Allocator, source: Source) ![]Token {
        var self = Tokenizer{ .text = source.text() };

        self.tokens = try allocator.alloc(Token, source.estimatedTokenSize());
        errdefer allocator.free(self.tokens);

        state: switch (State.start) {
            .start => switch (self.text[self.begin]) {
                '.', ':', ',', '?', '+', '-', '*', '/', '%', '^', '&', '|', '!', '=', '<', '>', '~' => {
                    self.index = self.begin;
                    continue :state .symbol;
                },
                '(', ')', '{', '}', '[', ']' => {
                    const slice = self.text[self.begin..][0..1];
                    const symbol = symbols.lookup(slice).?;

                    self.index += 1;
                    self.push(symbol);
                    self.begin += 1;

                    continue :state .start;
                },
                'A'...'Z', 'a'...'z', '_' => {
                    self.index = self.begin + 1;
                    continue :state .ident;
                },
                '\t', '\r', ' ' => {
                    self.index = self.begin + 1;
                    continue :state .whitespace;
                },
                '0'...'9' => {
                    self.index = self.begin + 1;
                    continue :state .number;
                },
                '\n' => {
                    self.index = self.begin + 1;
                    continue :state .newline;
                },
                '\"' => {
                    self.index = self.begin + 1;
                    continue :state .string;
                },
                '\'' => {
                    self.index = self.begin + 1;
                    continue :state .char;
                },
                0 => {
                    continue :state .eof;
                },
                else => {
                    self.index = self.begin + 1;
                    continue :state .invalid;
                },
            },
            .symbol => switch (self.text[self.index]) {
                '.', ':', ',', '?', '+', '-', '*', '/', '%', '^', '&', '|', '!', '=', '<', '>', '~' => {
                    self.index += 1;
                    continue :state .symbol;
                },
                else => {
                    self.pushAndReset(symbols.lookup(self.text[self.begin..self.index]) orelse .invalid);
                    continue :state .start;
                },
            },
            .ident => switch (self.text[self.index]) {
                'A'...'Z', 'a'...'z', '0'...'9', '_' => {
                    self.index += 1;
                    continue :state .ident;
                },
                else => {
                    self.pushAndReset(keywords.lookup(self.text[self.begin..self.index]) orelse .ident);
                    continue :state .start;
                },
            },
            .whitespace => switch (self.text[self.index]) {
                '\t', '\r', ' ' => {
                    self.index += 1;
                    continue :state .whitespace;
                },
                else => {
                    self.pushAndReset(.whitespace);
                    continue :state .start;
                },
            },
            .number => switch (self.text[self.index]) {
                // TODO: Handle more than just integral numbers.
                '0'...'9' => {
                    self.index += 1;
                    continue :state .number;
                },
                else => {
                    self.pushAndReset(.number);
                    continue :state .start;
                },
            },
            .newline => switch (self.text[self.index]) {
                '\n' => {
                    self.index += 1;
                    continue :state .newline;
                },
                else => {
                    self.pushAndReset(.newline);
                    continue :state .start;
                },
            },
            .string => switch (self.text[self.index]) {
                // TODO: Handle escaping. Ugh.
                '\"' => {
                    const tag: Token.Tag = if (self.index - self.begin < 2) .invalid else .string;

                    self.index += 1;
                    self.pushAndReset(tag);

                    continue :state .start;
                },
                '\n' => {
                    // SAFETY: Since the source text is terminated with a newline followed by an eof, we do not need to handle the eof case.
                    // TODO: Handle overflowing invalid chars.
                    self.pushAndReset(.invalid);
                    continue :state .newline;
                },
                else => {
                    self.index += 1;
                    continue :state .string;
                },
            },
            .char => switch (self.text[self.index]) {
                // TODO: Handle escaping. Ugh.
                '\'' => {
                    const tag: Token.Tag = if (self.index - self.begin < 2) .invalid else .char;

                    self.index += 1;
                    self.pushAndReset(tag);

                    continue :state .start;
                },
                '\n' => {
                    // SAFETY: Since the source text is terminated with a newline followed by an eof, we do not need to handle the eof case.
                    // TODO: Handle overflowing invalid chars.
                    self.pushAndReset(.invalid);
                    continue :state .newline;
                },
                else => {
                    self.index += 1;
                    continue :state .char;
                },
            },
            .invalid => switch (self.text[self.index]) {
                ' ', '\t', '\r' => {
                    self.pushAndReset(.invalid);
                    continue :state .start;
                },
                '\n' => {
                    self.pushAndReset(.invalid);
                    continue :state .newline;
                },
                else => {
                    self.index += 1;
                    continue :state .invalid;
                },
            },
            .eof => {
                // TODO: Handle invalid eof.
                // std.debug.panic("Slice: {s}\n", .{self.text[self.begin..self.index]});
                self.tokens[self.tokenCount] = .{ .tag = .eof, .len = 0 };
                self.tokenCount += 1;
                break :state;
            },
        }

        return self.shrink(allocator);
    }

    fn push(self: *Tokenizer, tag: Token.Tag) void {
        const len = self.index - self.begin;

        // TODO: Fold len info into adjacent tokens with known lengths.
        // TODO: Figure out how to handle invalid tokenzier state. Maybe ft. Chandler Carruth?
        const token: Token = if (len > std.math.maxInt(u8)) .{
            .tag = .invalid,
            .len = 0,
        } else .{
            .tag = tag,
            .len = @intCast(len),
        };

        self.tokens[self.tokenCount] = token;
        self.tokenCount += 1;
    }

    fn pushAndReset(self: *Tokenizer, tag: Token.Tag) void {
        self.push(tag);
        self.begin = self.index;
    }

    fn shrink(self: *Tokenizer, allocator: std.mem.Allocator) []Token {
        // TODO: Handle non-resizable allocator like wasm better.
        // The issue being, we don't want to return a slice that points past the valid tokens.
        // We also don't want to return a slice that won't allow us to free the allocated memory if resize fails.
        // The current behavior is to have the consumer of the tokenizer buffer remember to check for the ending eof. I do not like this.
        return self.tokens[0..if (allocator.resize(self.tokens, self.tokenCount)) self.tokenCount else self.tokens.len];
    }
};

test "tokenize expression" {
    const text = (
        \\
        \\ a * b + c + d
        \\
    );

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try Tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const expected_tokens = [_]Token{
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .@"*", .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .@"+", .len = 1 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .ident, .len = 1 },
        .{ .tag = .newline, .len = 2 },
        .{ .tag = .eof, .len = 0 },
    };

    try std.testing.expectEqualSlices(Token, &expected_tokens, tokens);
}

test "tokenize groupings" {
    const text = "()";

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try Tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const expected_tokens = [_]Token{
        .{ .tag = .@"(", .len = 1 },
        .{ .tag = .@")", .len = 1 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .eof, .len = 0 },
    };

    try std.testing.expectEqualSlices(Token, &expected_tokens, tokens);
}

test "tokenize strings" {
    const text = (
        \\ "hello" "world"
    );

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try Tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const expected_tokens = [_]Token{
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .string, .len = 7 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .string, .len = 7 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .eof, .len = 0 },
    };

    try std.testing.expectEqualSlices(Token, &expected_tokens, tokens);
}

test "tokenize chars" {
    const text = (
        \\ 'a' '1' '*'
    );

    const source = try Source.fromText(std.testing.allocator, text);
    defer source.deinit(std.testing.allocator);

    const tokens = try Tokenizer.tokenize(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);

    const expected_tokens = [_]Token{
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .char, .len = 3 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .char, .len = 3 },
        .{ .tag = .whitespace, .len = 1 },
        .{ .tag = .char, .len = 3 },
        .{ .tag = .newline, .len = 1 },
        .{ .tag = .eof, .len = 0 },
    };

    try std.testing.expectEqualSlices(Token, &expected_tokens, tokens);
}
pub const tokenize = Tokenizer.tokenize;

pub const Token = extern struct {
    tag: Tag,
    len: u8,

    pub const Tag = blk: {
        const kinds_fields = std.meta.fields(Kinds);
        const field_size = kinds_fields.len + symbols.Texts.len + keywords.Texts.len;
        var fields: [field_size]std.builtin.Type.EnumField = undefined;

        var iter: usize = 0;

        for (symbols.Texts) |op| {
            const hash = symbols.hashSlice(op);
            const index = symbols.hashToIndex(hash);

            // TODO: Explain why `~` is not used here. Synced with the `Symbols.hashToTag` impl.
            fields[iter + index] = .{ .name = op ++ "\x00", .value = index };
        }

        iter += symbols.Texts.len;

        for (keywords.Texts) |kw| {
            const hash = keywords.hashSlice(kw);
            const index = keywords.hashToIndex(hash);

            // TODO: Explain why the `~` is used here. Synced with the `Keywords.hashToTag` impl.
            fields[iter + index] = .{ .name = kw ++ "\x00", .value = ~index };
        }

        iter += keywords.Texts.len;

        for (kinds_fields, 0..) |kind, i| {
            fields[iter + i] = kind;
        }

        break :blk @Type(.{
            .@"enum" = .{
                .tag_type = u8,
                .fields = &fields,
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    };

    pub const Kinds = enum(u8) {
        // TODO: Explan the whole 128 | thing.
        // TODO: I would rather have invalid be 0x00.
        invalid = 0xaa,
        eof = 128 | @as(u8, 0),

        ident = 128 | @as(u8, 1),
        builtin = 128 | @as(u8, 9),
        number = 128 | @as(u8, 17),

        whitespace = 128 | @as(u8, 34),
        newline = 128 | @as(u8, 35),

        symbol = 128 | @as(u8, 3),

        string = 128 | @as(u8, 4),
        char = 128 | @as(u8, 19),
    };
};

pub const operators = @import("tokenizer/operators.zig");
pub const keywords = @import("tokenizer/keywords.zig");
pub const symbols = @import("tokenizer/symbols.zig");
