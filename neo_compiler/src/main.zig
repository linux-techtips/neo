const std = @import("std");

const Neo_Source = extern struct {
    ptr: [*]const u8,
    len: usize,
};

const Neo_Token = extern struct {
    tag: u8,
    len: u8,
};

const Neo_Tokens = extern struct {
    ptr: [*]const Neo_Token,
    len: u32,
};

extern fn Neo_Source_Alloc(text_ptr: [*]const u8, text_len: usize) callconv(.C) Neo_Source;
extern fn Neo_Source_Free(source: Neo_Source) callconv(.C) void;
extern fn Neo_Tokenize(source: Neo_Source) callconv(.C) Neo_Tokens;
extern fn Neo_Parse(tokens: Neo_Tokens) callconv(.C) Neo_Tokens;
extern fn Neo_Token_Name(tag: u8) callconv(.C) [*:0]const u8;

const Error = error{
    no_source_provided,
    invalid_compilation_mode,
};

const Mode = enum {
    tokenize,
    parse,
};

fn renderTokens(neo_tokens: Neo_Tokens) !void {
    const tokens = neo_tokens.ptr[0..neo_tokens.len];
    for (tokens) |token| {
        std.debug.print("{s}\n", .{Neo_Token_Name(token.tag)});
        if (token.tag == 128) break;
    }
}

fn renderTree(neo_parse_tree: Neo_Tokens) !void {
    var i = neo_parse_tree.len - 1;
    while (true) : (i -= 1) {
        const token = neo_parse_tree.ptr[i];
        std.debug.print("{s}\n", .{Neo_Token_Name(token.tag)});
        if (token.tag == 128) break;
    }
}

fn collect(allocator: std.mem.Allocator, args: std.process.ArgIterator) ![]u8 {
    var len: usize = 0;
    var lenIt = args;

    while (lenIt.next()) |arg| len += arg.len + 1;

    var buffer = try allocator.alloc(u8, len);
    var bufferIt = args;
    var i: usize = 0;

    while (bufferIt.next()) |arg| {
        @memcpy(buffer[i..][0..arg.len], arg[0..]);
        buffer[i + 1] = ' ';
        i += arg.len + 1;
    }

    return buffer[0..buffer.len];
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var text: ?[]u8 = null;
    var mode: Mode = .tokenize;

    const modeMap = std.StaticStringMap(Mode).initComptime(.{
        .{ @tagName(Mode.tokenize), Mode.tokenize },
        .{ @tagName(Mode.parse), Mode.parse },
    });

    defer if (text != null) allocator.free(text.?);

    var args = std.process.args();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--")) {
            text = try collect(allocator, args);
            break;
        }

        if (std.mem.eql(u8, arg, "--mode")) {
            const modeArg = args.next() orelse return error.invalid_compilation_mode;
            mode = modeMap.get(modeArg) orelse return error.invalid_compilation_mode;
        }
    }

    const stdin = std.io.getStdIn();
    if (!std.posix.isatty(stdin.handle)) {
        text = if (text == null) try stdin.reader().readAllAlloc(allocator, std.math.maxInt(u32)) else text;
    }

    const source = Neo_Source_Alloc(text.?.ptr, text.?.len);
    defer Neo_Source_Free(source);

    var tokens: Neo_Tokens = undefined;
    var parseTree: Neo_Tokens = undefined;

    switch (mode) {
        .tokenize => {
            tokens = Neo_Tokenize(source);
            try renderTokens(tokens);
        },
        .parse => {
            tokens = Neo_Tokenize(source);
            parseTree = Neo_Parse(tokens);
            try renderTree(parseTree);
        },
    }
}
