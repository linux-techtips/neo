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

    const Tag = enum(u8) {
        decl,
        add,
        sub,
        mul,
        div,
        int,
    };
};

pub const Module = struct {
    code: std.MultiArrayList(Inst),

    pub const Code = std.MultiArrayList(Inst).Slice;
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

        if (token.tag == .@":") return try self.genVarDecl(ctx);
        if (token.isOperator()) return try self.genBinOp(ctx);

        std.debug.panic("Expected a toplevel expression but found: `{s}` instead.", .{@tagName(token.tag)});
    }

    fn genBinOp(self: *Generator, ctx: Context) Error!Context {
        const token = self.tokens[ctx.tokens_idx];
        const tag: Inst.Tag = switch (token.tag) {
            .@"+" => .add,
            .@"-" => .sub,
            .@"*" => .mul,
            .@"/" => .div,
            else => |tag| std.debug.panic("Invalid Binary Operator: {s}", .{@tagName(tag)}),
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

    fn genVarDecl(self: *Generator, ctx: Context) Error!Context {
        // Tokens :, name, :, type, expr
        // Source name, :, type, :, expr

        const inst = try self.module.addInst(self.allocator, .{
            .tag = .decl,
            .token = self.tokens[ctx.tokens_idx],
            .data = undefined,
        });

        const name = try self.parseIdent(.{
            .source_idx = ctx.source_idx,
            .tokens_idx = ctx.tokens_idx - 1, // Skip the ':' token.
        });

        const ty = try self.parseIdent(.{
            .source_idx = self.skipWhitespace(name.source_idx + 1), // Skip the ':' source.
            .tokens_idx = name.tokens_idx - 1, // Skip the ':' token.
        });

        const expr = try self.genBinOp(.{
            .source_idx = self.skipWhitespace(ty.source_idx + 1), // Skip the ':' source.
            .tokens_idx = ty.tokens_idx,
        });

        self.module.getDataRef(inst).decl = .{
            .name = self.source[ctx.source_idx..self.tokens[name.tokens_idx + 1].len],
            .expr = expr.inst,
        };

        return .{
            .inst = inst,
            .source_idx = expr.source_idx,
            .tokens_idx = expr.tokens_idx,
        };
    }

    fn parseIdent(self: *Generator, ctx: Context) Error!Context {
        const token = self.tokens[ctx.tokens_idx];
        const slice = self.source[ctx.source_idx..][0..token.len];

        if (token.tag != .ident) std.debug.print("Expected an ident but found: `{s} - {s}` instead.", .{ @tagName(token.tag), slice });

        return .{
            .source_idx = self.skipWhitespace(ctx.source_idx + token.len),
            .tokens_idx = ctx.tokens_idx - 1,
        };
    }

    fn skipWhitespace(self: *Generator, offset: u32) u32 {
        var i = offset;
        while (i < self.source.len and self.source[i] == ' ') : (i += 1) {}
        return i;
    }
};

const Evaluator = struct {
    code: Module.Code,

    pub fn evaluate(module: Module) u64 {
        var evaluator = Evaluator{ .code = module.code.slice() };
        return evaluator.evalExpr(0);
    }

    fn evalExpr(self: *Evaluator, index: Inst.Index) u64 {
        const inst = self.code.get(index);
        return switch (inst.tag) {
            .add, .sub, .mul, .div => |tag| {
                const lhs = self.evalExpr(inst.data.bin.lhs);
                const rhs = self.evalExpr(inst.data.bin.rhs);

                return Evaluator.evalBinOp(tag, lhs, rhs);
            },
            .decl => self.evalExpr(inst.data.decl.expr),
            .int => inst.data.int,
        };
    }

    fn evalBinOp(tag: Inst.Tag, lhs: u64, rhs: u64) u64 {
        return switch (tag) {
            .add => lhs +% rhs,
            .sub => lhs -% rhs,
            .mul => lhs *% rhs,
            .div => lhs / rhs,
            else => std.debug.panic("Not a binary operator: {s}", .{@tagName(tag)}),
        };
    }
};

test "generate" {
    const allocator = std.testing.allocator;

    const source = try Source.fromText(allocator, "x : u32 : 5 - 2 * 2");
    defer source.deinit(allocator);

    const tokens = try tokenizer.tokenize(allocator, source);
    defer allocator.free(tokens);

    const tree = try parser.parse(allocator, tokens);
    defer allocator.free(tree);

    var module = try generate(allocator, source, tree);
    defer module.deinit(allocator);

    const result = evaluate(module);
    std.debug.print("{}\n", .{result});
}

pub const generate = Generator.generate;
pub const evaluate = Evaluator.evaluate;
