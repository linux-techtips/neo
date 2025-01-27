const std = @import("std");

// TODO: Handle vector length error.
pub const Chunk = @Vector(std.simd.suggestVectorLength(u8).?, u8);
pub const ChunkAlign = @alignOf(Chunk);
pub const ChunkSize = @sizeOf(Chunk);

// TODO: Explain this.
pub const FrontPad = "\n";
pub const BackPad = FrontPad ++ "\x00" ** 63;

const States = enum(u8) {
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

pub const Token = extern struct {
    tag: Tag,
    len: u8,

    pub const Tag = blk: {
        const state_fields = std.meta.fields(States);
        const field_size = state_fields.len + Keywords.Texts.len;
        var fields: [field_size]std.builtin.Type.EnumField = undefined;

        var iter: usize = 0;

        for (Keywords.Texts) |kw| {
            const index = Keywords.hashToIndex(Keywords.hashSlice(kw));
            fields[iter + index] = .{ .name = kw ++ "\x00", .value = ~index };
        }

        iter += Keywords.Texts.len;

        for (state_fields, 0..) |state, i| {
            fields[iter + i] = state;
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
};

pub const Keywords = @import("tokenize/Keywords.zig");
pub const Source = @import("tokenize/Source.zig");
