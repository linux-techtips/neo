const tokenize = @import("tokenize.zig");
const std = @import("std");

const Keywords = tokenize.Keywords;
const Symbols = tokenize.Symbols;
const Source = tokenize.Source;
const Token = tokenize.Token;

const State = enum {
    whitespace,
    newline,
    number,
    start,
    ident,
    symbol,
};

const Tokenizer = struct {
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

test "lexer" {
    const allocator = std.testing.allocator;

    const text =
        \\(any += type)
        \\
        \\ 1234   for loop
    ;
    const source = try Source.fromText(allocator, text);
    defer source.deinit(allocator);

    const tokens = try Tokenizer.tokenize(allocator, source);
    defer allocator.free(tokens);

    for (tokens) |token| {
        std.debug.print("({s}, {d})\n", .{ @tagName(token.tag), token.len });
    }
}
