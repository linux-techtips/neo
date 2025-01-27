const tokenize = @import("tokenize.zig");
const std = @import("std");

const Keywords = tokenize.Keywords;
const Source = tokenize.Source;
const Token = tokenize.Token;

const State = enum {
    whitespace,
    start,
    ident,
};

const Tokenizer = struct {
    source: Source,
    tokens: []Token = undefined,

    count: usize = 0,
    curr: usize = 0,
    last: usize = 0,

    pub fn push(self: *Tokenizer, tag: Token.Tag) void {
        // TODO: Overflow check
        self.tokens[self.count] = .{ .tag = tag, .len = @intCast(self.last - self.curr) };
        self.count += 1;
    }

    pub fn shrink(self: *Tokenizer, allocator: std.mem.Allocator) []Token {
        return self.tokens[0..if (allocator.resize(self.tokens, self.count)) self.count else 0];
    }

    pub fn tokenize(self: *Tokenizer, allocator: std.mem.Allocator) ![]Token {
        self.tokens = try allocator.alloc(Token, self.source.estimatedTokenSize());

        const text = self.source.text();

        state: switch (State.start) {
            .start => switch (text[self.curr]) {
                'A'...'Z', 'a'...'z', '_' => {
                    self.last = self.curr;
                    continue :state .ident;
                },
                ' ', '\t' => {
                    self.last = self.curr;
                    continue :state .whitespace;
                },
                '\n' => {
                    self.last += self.curr + 1;
                    self.push(.newline);

                    self.curr += 1;

                    continue :state .start;
                },
                0 => break :state,
                else => unreachable,
            },
            .ident => switch (text[self.last]) {
                'A'...'Z', 'a'...'z', '_', '0'...'9' => {
                    self.last += 1;
                    continue :state .ident;
                },
                else => {
                    const ident = text[self.curr..self.last];

                    self.push(Keywords.lookup(ident) orelse .ident);
                    self.curr = self.last;
                    continue :state .start;
                },
            },
            .whitespace => switch (text[self.last]) {
                ' ', '\t' => {
                    self.last += 1;
                    continue :state .whitespace;
                },
                else => {
                    self.push(.whitespace);
                    self.curr = self.last;
                    continue :state .start;
                },
            },
        }

        return self.shrink(allocator);
    }
};

fn lex_extern(x: usize, y: usize) callconv(.C) usize {
    return x + y;
}

comptime {
    @export(&lex_extern, .{ .name = "Neo_Lex", .linkage = .strong });
}

test "lexer" {
    const allocator = std.testing.allocator;

    const source = try Source.fromText(allocator, "any type for loop");
    defer source.deinit(allocator);

    var tokenizer: Tokenizer = .{ .source = source };

    const tokens = try tokenizer.tokenize(allocator);
    defer allocator.free(tokens);

    for (tokens) |token| {
        std.debug.print("{any}\n", .{token});
    }
}
