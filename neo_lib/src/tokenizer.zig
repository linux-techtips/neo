const std = @import("std");

const Source = @import("Source.zig");

const Tokenizer = struct {
    const State = enum {
        whitespace,
        comment,
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

    begin: Token.Index = 0,
    index: Token.Index = 0,

    pub fn tokenize(allocator: std.mem.Allocator, source: Source) ![]Token {
        var self = Tokenizer{ .text = source.text() };

        self.tokens = try allocator.alloc(Token, source.estimatedTokenSize());
        errdefer allocator.free(self.tokens);

        state: switch (State.start) {
            .start => switch (self.text[self.begin]) {
                '.', ',', '?', '+', '-', '*', '%', '^', '&', '|', '!', '<', '>', '~' => {
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
                ':', '=' => {
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
                '/' => {
                    if (self.text[self.begin + 1] == '/') {
                        self.index = self.begin + 2;
                        continue :state .comment;
                    } else {
                        self.index = self.begin + 1;
                        continue :state .symbol;
                    }
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
                    // self.pushAndReset(.whitespace);
                    self.begin = self.index;
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
            .comment => switch (self.text[self.index]) {
                '\n' => {
                    self.pushAndReset(.comment);

                    self.index = self.begin + 1;
                    continue :state .newline;
                },
                else => {
                    self.index += 1;
                    continue :state .comment;
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
                self.tokens[self.tokenCount] = .{ .tag = .eof, .len = 1 };
                self.tokenCount += 1;
                break :state;
            },
        }

        return self.shrink(allocator);
    }

    fn push(self: *Tokenizer, tag: Token.Tag) void {
        // TODO: Gracefully handle the case where the token len exceeds the bounds of u16. "Who would ever need an identifier that large???"
        const len: u16 = @intCast(self.index - self.begin);
        std.debug.assert(len != 0);

        const token = Token{
            .tag = tag,
            .len = if (len > std.math.maxInt(u8)) 0 else @intCast(len),
        };

        self.tokens[self.tokenCount] = token;
        self.tokenCount += 1;

        self.tokens[self.tokenCount] = @bitCast(len);
        self.tokenCount += @intFromBool(token.len == 0);
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

pub const Token = extern struct {
    tag: Tag,
    len: u8,

    pub const Index = u32;

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
        symbol = 128 | @as(u8, 2),
        builtin = 128 | @as(u8, 3),
        number = 128 | @as(u8, 4),

        string = 128 | @as(u8, 5),
        char = 128 | @as(u8, 6),

        whitespace = 128 | @as(u8, 7),
        newline = 128 | @as(u8, 8),
        comment = 128 | @as(u8, 9),
    };
};

pub const operators = @import("tokenizer/operators.zig");
pub const keywords = @import("tokenizer/keywords.zig");
pub const symbols = @import("tokenizer/symbols.zig");
pub const tokenize = Tokenizer.tokenize;
