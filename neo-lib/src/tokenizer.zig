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

        ident = 128 | @as(u8, 1),
        builtin = 128 | @as(u8, 9),
        number = 128 | @as(u8, 17),

        whitespace = 128 | @as(u8, 34),
        newline = 128 | @as(u8, 35),

        symbol = 128 | @as(u8, 3),

        string = 128 | @as(u8, 4),
        string_ident = 128 | @as(u8, 12),
        char = 128 | @as(u8, 19),
    };

    const Precedences = blk: {
        var table = std.mem.zeroes([256]u8);

        const precs = [_][]const Tag{
            &[_]Tag{.@"("},
            &[_]Tag{.@")"},
            &[_]Tag{ .@"+", .@"-" },
            &[_]Tag{ .@"*", .@"/" },
        };

        for (precs, 1..) |ops, i| {
            for (ops) |op| table[@intFromEnum(op)] = i;
        }

        break :blk table;
    };

    pub fn precedence(self: Token) u8 {
        return Precedences[@intFromEnum(self.tag)];
    }

    const Classification = enum(u8) {
        symbol = 0,
        unary,
        binary,
        operand,
        reset,
    };

    const Classifications = blk: {
        var table = [1]Classification{.symbol} ** 256;

        for (table[@intFromEnum(Kinds.ident)..@intFromEnum(Kinds.char)]) |*slot| {
            slot.* = .operand;
        }

        for ([_]Tag{ .@"+", .@"-", .@"*", .@"/" }) |op| {
            table[@intFromEnum(op)] = .binary;
        }

        for ([_]Tag{.@"("}) |op| {
            table[@intFromEnum(op)] = .unary;
        }

        for ([_]Tag{ .@")", .newline }) |op| {
            table[@intFromEnum(op)] = .reset;
        }

        break :blk table;
    };

    pub fn classify(self: Token) Classification {
        return Classifications[@intFromEnum(self.tag)];
    }

    pub fn isOperator(self: Token) bool {
        return self.classify() != .operand;
    }

    pub fn isOperand(self: Token) bool {
        return self.classify() == .operand;
    }
};

test "tokenize" {
    const text =
        \\
        \\ a * b + c + d
        \\
    ;

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

    try std.testing.expectEqualSlices(Token, tokens, &expected_tokens);
}

pub const tokenize = Tokenizer.tokenize;

pub const Symbols = @import("tokenizer/Symbols.zig");
pub const Keywords = @import("tokenizer/Keywords.zig");
pub const Source = @import("tokenizer/Source.zig");
