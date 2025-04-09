const tokenizer = @import("tokenizer.zig");
const operators = tokenizer.operators;
const parser = @import("parser.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Source = @import("Source.zig");
const Token = tokenizer.Token;

pub const Error = Allocator.Error || error{};

pub const Inst = struct {
    token: Token,
    data: Data,
    tag: Tag,

    pub const Index = u32;

    pub const Data = union {
        bin: struct {
            lhs: Index,
            rhs: Index,
        },
        int: u64,
    };

    const Tag = enum(u8) {
        add,
        int,
    };
};

pub const Module = struct {
    code: std.MultiArrayList(Inst),

    pub const new = Module{ .code = .empty };

    pub fn deinit(self: *Module, allocator: Allocator) void {
        self.code.deinit(allocator);
    }

    pub fn addInst(self: *Module, allocator: Allocator, inst: Inst) Error!Inst.Index {
        try self.code.append(allocator, inst);

        return @intCast(self.code.len - 1);
    }

    pub fn getDataRef(self: *Module, index: Inst.Index) *Inst.Data {
        return &self.code.items(.data)[index];
    }
};

pub const Generator = struct {
    allocator: Allocator,
    tokens: []const Token,
    source: [:0]const u8,

    module: Module = .new,

    const Stack = std.ArrayListUnmanaged(Context);

    const Context = struct {
        inst: Inst.Index = undefined,
        tokens_idx: u32,
        source_idx: u32,
    };

    pub fn generate(allocator: Allocator, source: Source, tokens: []const Token) Error!Module {
        var generator = Generator{ .allocator = allocator, .source = source.text(), .tokens = tokens };
        _ = try generator.genToplevel(.{ .tokens_idx = @intCast(tokens.len - 1), .source_idx = 0 });

        return generator.module;
    }

    fn genToplevel(self: *Generator, ctx: Context) Error!Context {
        const token = self.tokens[ctx.tokens_idx];

        if (!token.isOperator()) @panic("Expected an Operator at toplevel");

        return try self.genBinOp(ctx);
    }

    fn genBinOp(self: *Generator, ctx: Context) Error!Context {
        const token = self.tokens[ctx.tokens_idx];
        const tag: Inst.Tag = switch (token.tag) {
            .@"+" => .add,
            else => unreachable,
        };

        const inst = try self.module.addInst(self.allocator, .{
            .tag = tag,
            .token = token,
            .data = undefined,
        });

        const lhs = try self.genOperand(.{
            .tokens_idx = ctx.tokens_idx - 1,
            .source_idx = ctx.source_idx,
        });

        const rhs = try self.genOperandOrOperator(.{
            .tokens_idx = lhs.tokens_idx,
            .source_idx = self.skipWhitespace(lhs.source_idx + token.len),
        });

        self.module.getDataRef(inst).* = .{
            .bin = .{ .lhs = lhs.inst, .rhs = rhs.inst },
        };

        return .{
            .inst = inst,
            .tokens_idx = rhs.tokens_idx,
            .source_idx = self.skipWhitespace(rhs.source_idx),
        };
    }

    fn genOperand(self: *Generator, ctx: Context) Error!Context {
        const token = self.tokens[ctx.tokens_idx];
        const slice = self.source[ctx.source_idx..][0..token.len];

        const inst = try self.module.addInst(self.allocator, .{
            .tag = .int,
            .token = token,
            .data = .{ .int = std.fmt.parseInt(u64, slice, 10) catch unreachable },
        });

        return .{ .inst = inst, .tokens_idx = ctx.tokens_idx - 1, .source_idx = self.skipWhitespace(ctx.source_idx + token.len) };
    }

    fn genOperandOrOperator(self: *Generator, ctx: Context) Error!Context {
        const token = self.tokens[ctx.tokens_idx];

        if (token.isOperand()) return try self.genOperand(ctx);
        if (token.isOperator()) return try self.genBinOp(ctx);

        @panic("Expected to generate an operand or operator");
    }

    fn skipWhitespace(self: *Generator, offset: u32) u32 {
        var i = offset;
        while (i < self.source.len and self.source[i] == ' ') : (i += 1) {}
        return i;
    }
};

test "generate" {
    const allocator = std.testing.allocator;

    const source = try Source.fromText(allocator, "2 + 2 + 2");
    defer source.deinit(allocator);

    const tokens = try tokenizer.tokenize(allocator, source);
    defer allocator.free(tokens);

    const tree = try parser.parse(allocator, tokens);
    defer allocator.free(tree);

    var module = try generate(allocator, source, tree);
    defer module.deinit(allocator);

    const slice = module.code.slice();
    for (0..module.code.len) |i| {
        const inst = slice.get(i);
        std.debug.print("{}\n", .{inst});
    }
}

pub const generate = Generator.generate;
