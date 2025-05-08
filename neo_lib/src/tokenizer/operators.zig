const std = @import("std");

const Token = @import("../tokenizer.zig").Token;

const Tag = Token.Tag;

const Precedences = blk: {
    var table = std.mem.zeroes([256]u8);

    const precs = [_][]const Tag{
        &[_]Tag{.eof},
        &[_]Tag{.newline},
        &[_]Tag{.@")"},
        &[_]Tag{.@"("},
        &[_]Tag{.@","},
        &[_]Tag{ .@"=", .@":" },
        &[_]Tag{ .@"<", .@"<=", .@"==", .@"!=", .@">=", .@">" },
        &[_]Tag{ .@"+", .@"++", .@"-" },
        &[_]Tag{ .@"*", .@"**", .@"/" },
        &[_]Tag{.@"."},
    };

    for (precs, 1..) |ops, i| {
        for (ops) |op| table[@intFromEnum(op)] = i;
    }

    break :blk table;
};

pub fn precedence(token: Token) u8 {
    return Precedences[@intFromEnum(token.tag)];
}

const Classification = enum(u8) {
    symbol,
    operand,
    binary,
    unary_prefix,
    unary_postfix,
    reset,
};

const Classifications = blk: {
    // TODO: Operator ambiguity. Some operators could be binary or unary depending on the context.
    // We should add tokens for operators that are explicitly unary like .@"unary -" or .@"unary .".
    // This however will be hard to implement as tokens are already assigned a hash value for their
    // enumeration values and we would need to modify these hash values for unary operators without collisions.

    // NOTE: @validark seems to have an implementation for this but it is undocumented and not trivial to understand.
    // I should probably ask him about this and a few other things.

    // Every token that is not given a specific classification is considered to be a symbol.
    // NOTE: Currently operands and symbols are treated equally, this might need to change in the future for
    // correct parsing behavior even for structural tokens like whitespace.
    var table = [1]Classification{.symbol} ** std.math.maxInt(u8);

    // Every token kind from identifiers to characters are considered operands.
    for (table[@intFromEnum(Token.Kinds.ident)..@intFromEnum(Token.Kinds.char)]) |*slot| {
        slot.* = .operand;
    }

    // The classic unambiguous binary operators.
    for ([_]Tag{
        .@"+",   .@"+=", .@"++", .@"-",
        .@"-=",  .@"*=", .@"**", .@"/",
        .@"/=",  .@"%",  .@"%=", .@"^",
        .@"^=",  .@"&",  .@"&=", .@"|",
        .@"|=",  .@"||", .@"=",  .@"==",
        .@"=>",  .@"<",  .@"<=", .@"<<",
        .@"<<=", .@">",  .@">=", .@">>",
        .@">>=", .@"!=", .@"or", .@"and",
        .@":",   .@"*",
    }) |op| {
        table[@intFromEnum(op)] = .binary;
    }

    // Unary operators that occur before an operand.
    for ([_]Tag{
        .@"!", .@"~",
    }) |op| {
        table[@intFromEnum(op)] = .unary_prefix;
    }

    // Unary operators that occur after an operand.
    for ([_]Tag{
        .@")",
    }) |op| {
        table[@intFromEnum(op)] = .unary_postfix;
    }

    // Unary postfix operators that signal the end of a statement and a context reset of the parser.
    for ([_]Tag{
        .@"(", .@",", .newline,
    }) |op| {
        table[@intFromEnum(op)] = .reset;
    }

    break :blk table;
};

pub fn classify(token: Token) Classification {
    return Classifications[@intFromEnum(token.tag)];
}

pub fn isOperator(token: Token) bool {
    return token.classify() != .operand;
}

pub fn isOperand(token: Token) bool {
    return token.classify() == .operand;
}
