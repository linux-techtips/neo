const std = @import("std");

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
                '\"' => {
                    self.index = self.begin;
                    continue :state .string;
                },
                '\'' => {
                    self.index = self.begin;
                    continue :state .char;
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
                    self.pushAndReset(.string);
                    continue :state .start;
                },
                else => {
                    self.index += 1;
                    continue :state .string;
                },
            },
            .char => switch (self.text[self.index]) {
                // TODO: Handle escaping. Ugh.
                '\'' => {
                    const tag: Token.Tag = if (self.index - self.begin > 2) .invalid else .char;

                    self.pushAndReset(tag);
                    continue :state .start;
                },
                else => {
                    self.index += 1;
                    continue :state .string;
                },
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

test "tokenize" {
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

    try std.testing.expectEqualSlices(Token, tokens, &expected_tokens);
}

test "tokenize strings" {
    try std.testing.expect(false);
}

test "tokenize chars" {

}

pub const tokenize = Tokenizer.tokenize;

pub const Token = @import("tokenizer/Token.zig");
pub const Symbols = @import("tokenizer/Symbols.zig");
pub const Keywords = @import("tokenizer/Keywords.zig");
pub const Source = @import("tokenizer/Source.zig");
