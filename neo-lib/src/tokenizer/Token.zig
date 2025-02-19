const std = @import("std");

const Symbols = @import("./Symbols.zig");
const Keywords = @import("./Keywords.zig");
const Token = @This();

comptime {
    // INFO: These assertions enforce the ABI of the Token struct to match extern struct.
    std.debug.assert(@sizeOf(Token) == 2);
    std.debug.assert(@offsetOf(Token, "tag") == 0);
    std.debug.assert(@offsetOf(Token, "len") == 1);
}

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
