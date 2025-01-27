const std = @import("std");

const Token = extern struct {
    tag: Tag,
    len: u8,

    const Tag = enum(u8) {
        invalid = 0,
        whitespace,
        ident,
    };
};

const Source = extern struct {
    ptr: [*:0]const u8,
    len: usize,
};

const Tokens = extern struct {
    ptr: [*c]Token,
    len: usize,
};

const State = enum {
    whitespace,
    start,
    ident,
};

const Tokenizer = struct {
    source: [:0]const u8,
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
        self.tokens = try allocator.alloc(Token, self.source.len);

        state: switch (State.start) {
            .start => switch (self.source[self.curr]) {
                'A'...'Z', 'a'...'z', '_' => {
                    self.last = self.curr;
                    continue :state .ident;
                },
                ' ', '\t' => {
                    self.last = self.curr;
                    continue :state .whitespace;
                },
                0 => break :state,
                else => unreachable,
            },
            .ident => switch (self.source[self.last]) {
                'A'...'Z', 'a'...'z', '_', '0'...'9' => {
                    self.last += 1;
                    continue :state .ident;
                },
                else => {
                    self.push(.ident);
                    self.curr = self.last;
                    continue :state .start;
                },
            },
            .whitespace => switch (self.source[self.last]) {
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

    const source = "hello        world";
    var tokenizer: Tokenizer = .{ .source = source };
    const tokens = try tokenizer.tokenize(allocator);

    defer allocator.free(tokens);

    for (tokens) |token| {
        std.debug.print("{any}\n", .{token});
    }
}
