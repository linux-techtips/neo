const std = @import("std");

const NeoIR = @This();
const Error = std.mem.Allocator.Error;

allocator: std.mem.Allocator,
instructions: std.MultiArrayList(Inst) = .empty,
variables: std.StringHashMapUnmanaged(Index) = .empty,

pub fn init(allocator: std.mem.Allocator) NeoIR {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *NeoIR) void {
    self.instructions.deinit(self.allocator);
}

pub fn addInt(self: *NeoIR, source: []const u8) Error!Index {
    const num = std.fmt.parseInt(u64, source, 10) catch |err| switch (err) {
        error.InvalidCharacter => unreachable,
        error.Overflow => unreachable,
    };

    try self.instructions.append(self.allocator, .{
        .tag = .int,
        .data = .{ .int = num },
    });

    return @enumFromInt(self.instructions.len - 1);
}

const BinOp = enum(u8) {
    add = @intFromEnum(Inst.Tag.add),
    sub = @intFromEnum(Inst.Tag.sub),
    mul = @intFromEnum(Inst.Tag.mul),
    div = @intFromEnum(Inst.Tag.div),

    fn toInstTag(self: BinOp) Inst.Tag {
        return @enumFromInt(@intFromEnum(self));
    }
};

pub fn addBin(self: *NeoIR, op: BinOp) Error!Index {
    try self.instructions.append(self.allocator, .{
        .tag = op.toInstTag(),
        .data = .{ .bin = undefined },
    });

    return @enumFromInt(self.instructions.len - 1);
}

pub fn addVarDecl(self: *NeoIR, name: []const u8) Error!Index {
    try self.instructions.append(self.allocator, .{
        .tag = .var_decl,
        .data = .{
            .name = name,
            .expr = undefined,
        },
    });
}

pub fn eval(self: *NeoIR, index: Index) struct { next: Index, value: u64 } {
    const inst = self.instructions.slice().get(@intFromEnum(index));
    return switch (inst.tag) {
        .var_decl => eval(self, inst.data.decl.expr),
        .int => .{ .next = @enumFromInt(@intFromEnum(index) + 1), .value = inst.data.int },
        .add => {
            const op = inst.data.bin;

            const lhs = eval(self, op.lhs);
            const rhs = eval(self, op.rhs);

            return .{ .next = rhs.next, .value = lhs.value +% rhs.value };
        },
        .sub => {
            const op = inst.data.bin;

            const lhs = eval(self, op.lhs);
            const rhs = eval(self, op.rhs);

            return .{ .next = rhs.next, .value = lhs.value -% rhs.value };
        },
        .mul => {
            const op = inst.data.bin;

            const lhs = eval(self, op.lhs);
            const rhs = eval(self, op.rhs);

            return .{ .next = rhs.next, .value = lhs.value *% rhs.value };
        },
        .div => {
            const op = inst.data.bin;

            const lhs = eval(self, op.lhs);
            const rhs = eval(self, op.rhs);

            return .{ .next = rhs.next, .value = lhs.value / rhs.value };
        },
    };
}

const Inst = struct {
    tag: Tag,
    data: Data,

    const Tag = enum(u8) {
        var_decl,
        int,
        add,
        sub,
        mul,
        div,
    };

    const Data = union {
        decl: struct {
            name: []const u8,
            expr: Index,
        },
        bin: struct {
            lhs: Index,
            rhs: Index,
        },
        int: u64,
    };
};

const Index = enum(u32) {
    _,
};

test "nir" {
    var nir = NeoIR.init(std.testing.allocator);
    defer nir.deinit();

    const op = try nir.addBin(.add);
    const op_lhs = try nir.addInt("34");
    const op_rhs = try nir.addBin(.sub);

    const op_rhs_lhs = try nir.addInt("36");
    const op_rhs_rhs = try nir.addInt("1");

    nir.instructions.items(.data)[@intFromEnum(op_rhs)].bin = .{
        .lhs = op_rhs_lhs,
        .rhs = op_rhs_rhs,
    };

    nir.instructions.items(.data)[@intFromEnum(op)].bin = .{
        .lhs = op_lhs,
        .rhs = op_rhs,
    };

    const result = nir.eval(op);

    try std.testing.expectEqual(69, result.value);
}

fn skipWhitespace(source: [:0]const u8, source_idx: u32) u32 {
    var idx = source_idx;
    while (idx < source.len) : (idx += 1) {
        if (source[idx] != ' ') break;
    }

    return idx;
}

fn dfs(nir: *NeoIR, source: [:0]const u8, source_idx: u32, tokens: []const Token, tokens_idx: u32) !struct { source_idx: u32, tokens_idx: u32, nir_idx: Index } {
    const token = tokens[tokens_idx];
    const slice = source[source_idx..][0..token.len];

    switch (operators.classify(token)) {
        .operand => {
            return .{
                .source_idx = skipWhitespace(source, @intCast(source_idx + token.len)),
                .tokens_idx = tokens_idx - 1,
                .nir_idx = try nir.addInt(slice),
            };
        },
        .binary => {
            const op = try nir.addBin(switch (token.tag) {
                .@"+" => .add,
                .@"-" => .sub,
                .@"*" => .mul,
                .@"/" => .div,
                else => |tag| {
                    std.debug.print("Invalid token for binary operator: {s}\n", .{@tagName(tag)});
                    unreachable;
                },
            });

            const lhs = try dfs(nir, source, source_idx, tokens, tokens_idx - 1);
            const rhs = try dfs(nir, source, skipWhitespace(source, @intCast(lhs.source_idx + token.len)), tokens, lhs.tokens_idx);

            nir.instructions.items(.data)[@intFromEnum(op)].bin = .{
                .lhs = lhs.nir_idx,
                .rhs = rhs.nir_idx,
            };

            return .{
                .source_idx = rhs.source_idx,
                .tokens_idx = rhs.tokens_idx,
                .nir_idx = op,
            };
        },
        else => |class| {
            std.debug.print("Invalid operator classification for codegen: {s} - {s}\n", .{ @tagName(class), @tagName(token.tag) });
            unreachable;
        },
    }
}

test "gen" {
    const allocator = std.testing.allocator;

    const source = try Source.fromText(allocator, "2 * 2 / 2");
    defer source.deinit(allocator);

    const tokens = try tokenizer.tokenize(allocator, source);
    defer std.testing.allocator.free(tokens);

    const tree = try parser.parse(allocator, tokens);
    defer std.testing.allocator.free(tree);

    var nir = NeoIR.init(allocator);
    defer nir.deinit();

    const root = try dfs(&nir, source.text(), 0, tree, @intCast(tree.len - 1));
    const result = nir.eval(root.nir_idx);

    std.debug.print("{}\n", .{result.value});
}

const tokenizer = @import("tokenizer.zig");
const operators = tokenizer.operators;
const parser = @import("parser.zig");

const Source = @import("Source.zig");
const Token = tokenizer.Token;
