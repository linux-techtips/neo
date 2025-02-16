const std = @import("std");

const Tokenizer = struct {
    const State = enum {
        whitespace,
        newline,
        number,
        start,
        ident,
        symbol,
    };

    text: [:0]const u8,

    tokens: []Token = undefined,
    tokenCount: usize = 0,

    begin: usize = 0,
    index: usize = 0,

    pub fn tokenize(allocator: std.mem.Allocator, source: Source) ![]Token {
        var self = Tokenizer{ .text = source.text() };

        self.tokens = try allocator.alloc(Token, source.estimatedTokenSize());
        errdefer allocator.free(self.tokens);

        state: switch (State.start) {
            .start => switch (self.text[self.begin]) {
                '(', ')', '{', '}', '[', ']', '.', ':', ',', '?', '+', '-', '*', '/', '%', '^', '&', '|', '!', '=', '<', '>', '~' => {
                    self.index = self.begin;
                    continue :state .symbol;
                },
                'A'...'Z', 'a'...'z', '_' => {
                    self.index = self.begin;
                    continue :state .ident;
                },
                '\t', '\r', ' ' => {
                    self.index = self.begin;
                    continue :state .whitespace;
                },
                '0'...'9' => {
                    self.index = self.begin;
                    continue :state .number;
                },
                '\n' => {
                    self.index = self.begin;
                    continue :state .newline;
                },
                0 => {
                    // TODO: Handle invalid eof.
                    self.push(.eof);
                    break :state;
                },
                else => {
                    // TODO: Handle
                    self.push(.invalid);
                },
            },
            .symbol => switch (self.text[self.index]) {
                '(', ')', '{', '}', '[', ']', '.', ':', ',', '?', '+', '-', '*', '/', '%', '^', '&', '|', '!', '=', '<', '>', '~' => {
                    self.index += 1;
                    continue :state .symbol;
                },
                else => {
                    self.pushAndReset(Symbols.lookup(self.text[self.begin..self.index]) orelse .invalid);
                    continue :state .start;
                },
            },
            .ident => switch (self.text[self.index]) {
                'A'...'Z', 'a'...'z', '0'...'9', '_' => {
                    self.index += 1;
                    continue :state .ident;
                },
                else => {
                    self.pushAndReset(Keywords.lookup(self.text[self.begin..self.index]) orelse .ident);
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
        }

        return self.shrink(allocator);
    }

    fn push(self: *Tokenizer, tag: Token.Tag) void {
        // TODO: Overflow check
        self.tokens[self.tokenCount] = .{ .tag = tag, .len = @intCast(self.index - self.begin) };
        self.tokenCount += 1;
    }

    fn pushAndReset(self: *Tokenizer, tag: Token.Tag) void {
        self.push(tag);
        self.begin = self.index;
    }

    fn shrink(self: *Tokenizer, allocator: std.mem.Allocator) []Token {
        return self.tokens[0..if (allocator.resize(self.tokens, self.tokenCount)) self.tokenCount else 0];
    }
};

pub const Token = extern struct {
    tag: Tag,
    len: u8,

    pub const Tag = blk: {
        const kinds_fields = std.meta.fields(Kinds);
        const field_size = kinds_fields.len + Symbols.Texts.len + Keywords.Texts.len;
        var fields: [field_size]std.builtin.Type.EnumField = undefined;

        var iter: usize = 0;

        for (Symbols.Texts) |op| {
            const hash = Symbols.hashSlice(op);
            const index = Symbols.hashToIndex(hash);
            // TODO: Explain why `~` is not used here. Synced with the `Symbols.hashToTag` impl.
            fields[iter + index] = .{ .name = op ++ "\x00", .value = index };
        }

        iter += Symbols.Texts.len;

        for (Keywords.Texts) |kw| {
            const hash = Keywords.hashSlice(kw);
            const index = Keywords.hashToIndex(hash);
            // TODO: Explain why the `~` is used here. Synced with the `Keywords.hashToTag` impl.
            fields[iter + index] = .{ .name = kw ++ "\x00", .value = ~index };
        }

        iter += Keywords.Texts.len;

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
        invalid = 0xaa, // TODO: I would rather this be 0.
        eof = 128 | @as(u8, 0),
        sentinel_operator = 128 | @as(u8, 20),

        ident = 128 | @as(u8, 1),
        builtin = 128 | @as(u8, 9),
        number = 128 | @as(u8, 17),

        whitespace = 128 | @as(u8, 34),
        newline = 128 | @as(u8, 35),

        symbol = 128 | @as(u8, 3),

        string = 128 | @as(u8, 4),
        string_ident = 128 | @as(u8, 12),
        char_literal = 128 | @as(u8, 19),
    };
};

// test "tokenize" {
//     const source = try Source.fromText(std.heap.page_allocator, "Hello World");
//     const tokens = try tokenize(std.heap.page_allocator, source);

//     const expected = [_]Token{
//         .{ .tag = .ident, .len = 5 },
//         .{ .tag = .whitespace, .len = 1 },
//         .{ .tag = .ident, .len = 5 },
//         .{ .tag = .newline, .len = 1 },
//         .{ .tag = .eof, .len = 0 },
//     };

//     try std.testing.expectEqual(tokens, expected[0..]);
// }

pub const tokenize = Tokenizer.tokenize;

pub const Symbols = @import("tokenizer/Symbols.zig");
pub const Keywords = @import("tokenizer/Keywords.zig");
pub const Source = @import("tokenizer/Source.zig");
