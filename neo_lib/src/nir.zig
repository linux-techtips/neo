// TODO: (carter) This whole thing is going to be refactored don't pay attention to how unoptimal this is.

const std = @import("std");

pub const Error = Allocator.Error;

const Allocator = std.mem.Allocator;

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Index = u32;

    pub const Key = enum(u32) {
        const index_start = @intFromEnum(Key.type_u64);

        type_s32,
        type_s64,
        type_u32,
        type_u64,

        none = std.math.maxInt(u32),

        _,

        pub fn lookup(slice: []const u8) ?Key {
            const map = std.StaticStringMap(Key).initComptime(.{
                .{ "s32", .type_s32 },
                .{ "s64", .type_s64 },
                .{ "u32", .type_u32 },
                .{ "u64", .type_u64 },
            });

            return map.get(slice);
        }

        pub fn fromIndex(index: Index) Key {
            return @enumFromInt(index + index_start);
        }

        pub fn toIndexUnchecked(key: Key) Index {
            return @intFromEnum(key) - index_start;
        }

        pub fn toIndexChecked(key: Key) ?Index {
            const val = Key.toIndexUnchecked(key);
            return if (val > index_start or key == .none) null else val;
        }
    };

    pub const Tag = enum {
        block,
        param,
        local,
        func,
        decl,
        call,
        int,
        add,
        sub,
        mul,
        div,
    };

    pub const Data = union {
        block: Block,
        local: Local,
        param: Param,
        decl: Decl,
        func: Func,
        call: Call,
        int: u64,
        bin: Bin,

        pub const Func = struct {
            params: Index,
            ret_ty: Key,
        };

        pub const Call = struct {
            name: []const u8,
            vals: Index,
        };

        pub const Block = struct {
            end: u32,
        };

        pub const Local = struct {
            name: []const u8,
        };

        pub const Param = struct {
            name: []const u8,
            type: Key,
        };

        pub const Decl = struct {
            name: []const u8,
            type: Key,
            expr: Index,
        };

        pub const Bin = struct {
            lhs: Index,
            rhs: Index,
        };
    };
};

pub const Code = struct {
    data: std.ArrayListUnmanaged(Inst),

    pub const new = Code{ .data = .empty };

    pub fn addInst(code: *Code, gpa: Allocator, inst: Inst) Error!Inst.Index {
        try code.data.append(gpa, inst);

        return @intCast(code.data.items.len - 1);
    }

    pub fn getInstRef(code: *Code, index: Inst.Index) *Inst {
        return &code.data.items[index];
    }
};

const Evaluator = struct {
    locals: std.StringHashMap(Inst.Index),
    code: *Code,

    const Context = struct {
        index: Inst.Index,
        value: u64,
    };

    pub fn evaluate(gpa: Allocator, code: *Code) Error!u64 {
        var eval = Evaluator{
            .locals = std.StringHashMap(Inst.Index).init(gpa),
            .code = code,
        };

        defer eval.locals.deinit();

        const inst = code.getInstRef(0);
        std.debug.assert(inst.tag == .block);

        return (try eval.evalBlock(inst, 0)).value;
    }

    fn evalExpr(eval: *Evaluator, index: Inst.Index) Error!Context {
        const inst = eval.code.getInstRef(index);
        return switch (inst.tag) {
            .add, .sub, .mul, .div => try eval.evalOperator(inst),
            .decl => try eval.evalVarDecl(inst, index),
            .block => try eval.evalBlock(inst, index),
            .local => {
                const local = eval.locals.get(inst.data.local.name) orelse
                    std.debug.panic("Attempted to access the value of undefined local: {s}", .{inst.data.local.name});

                return try eval.evalExpr(local);
            },
            .int => .{ .index = index + 1, .value = inst.data.int },
            .call => {
                const call = inst.data.call;
                const decl = eval.code.getInstRef(eval.locals.get(inst.data.call.name) orelse
                    std.debug.panic("Attempted to access the value of undefined function: {s}", .{call.name})).data.decl;

                const func_type = Inst.Key.toIndexUnchecked(decl.type);
                const func = eval.code.getInstRef(func_type).data.func;

                const params = eval.code.getInstRef(func.params).data.block;

                var i: Inst.Index = 1;
                while (true) : (i += 1) {
                    const params_idx = func.params + 1;
                    const values_idx = call.vals + 1;

                    const name = eval.code.getInstRef(params_idx).data.param.name;
                    try eval.locals.put(name, values_idx);

                    if (params_idx >= params.end) break;
                }

                return try eval.evalExpr(decl.expr);
            },
            else => |tag| std.debug.panic("Attempted to evaluate an un-evaluatable instruction: {s}", .{@tagName(tag)}),
        };
    }

    fn evalBlock(eval: *Evaluator, inst: *const Inst, index: Inst.Index) Error!Context {
        var ctx = Context{ .index = index + 1, .value = undefined };
        while (ctx.index < inst.data.block.end) {
            ctx = try eval.evalExpr(ctx.index);
        }

        return ctx;
    }

    fn evalOperator(eval: *Evaluator, inst: *const Inst) Error!Context {
        const lhs = try eval.evalExpr(inst.data.bin.lhs);
        const rhs = try eval.evalExpr(inst.data.bin.rhs);

        const value = switch (inst.tag) {
            .add => lhs.value +% rhs.value,
            .sub => lhs.value -% rhs.value,
            .mul => lhs.value *% rhs.value,
            .div => lhs.value / rhs.value,
            else => unreachable,
        };

        return .{ .index = rhs.index, .value = value };
    }

    fn evalVarDecl(eval: *Evaluator, inst: *const Inst, index: Inst.Index) Error!Context {
        const decl = inst.data.decl;
        try eval.locals.put(decl.name, index);

        switch (decl.type) {
            .type_s32, .type_s64, .type_u32, .type_u64 => {
                return try eval.evalExpr(inst.data.decl.expr);
            },
            else => { // Function decl.
                // Just skip past the function body.
                const expr = eval.code.getInstRef(decl.expr);
                std.debug.assert(expr.tag == .block);

                // We need to skip past the type instruction. Ugh.
                return .{ .value = undefined, .index = expr.data.block.end + 1 };
            },
        }
    }
};

pub const evaluate = Evaluator.evaluate;

test "code" {
    const allocator = std.testing.allocator;

    var code = Code.new;
    defer code.data.deinit(allocator);

    const block = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = undefined },
    });

    const decl = try code.addInst(allocator, .{
        .tag = .decl,
        .data = .{ .decl = .{ .name = "square", .type = undefined, .expr = undefined } },
    });

    const func = try code.addInst(allocator, .{
        .tag = .func,
        .data = .{ .func = .{ .params = undefined, .ret_ty = .type_u32 } },
    });

    code.getInstRef(decl).data.decl.type = Inst.Key.fromIndex(func);

    const params = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = undefined },
    });

    code.getInstRef(func).data.func.params = params;

    const param = try code.addInst(allocator, .{
        .tag = .param,
        .data = .{ .param = .{ .name = "x", .type = .type_s32 } },
    });

    code.getInstRef(params).data.block.end = param;

    const body = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = undefined },
    });

    code.getInstRef(decl).data.decl.expr = body;

    const op = try code.addInst(allocator, .{
        .tag = .mul,
        .data = .{ .bin = undefined },
    });

    const lhs = try code.addInst(allocator, .{
        .tag = .local,
        .data = .{ .local = .{ .name = "x" } },
    });

    const rhs = try code.addInst(allocator, .{
        .tag = .local,
        .data = .{ .local = .{ .name = "x" } },
    });

    code.getInstRef(op).data.bin = .{ .lhs = lhs, .rhs = rhs };
    code.getInstRef(body).data.block.end = rhs;

    const call = try code.addInst(allocator, .{
        .tag = .call,
        .data = .{ .call = .{ .name = "square", .vals = undefined } },
    });

    const vals = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = undefined },
    });

    code.getInstRef(call).data.call.vals = vals;

    const x = try code.addInst(allocator, .{
        .tag = .int,
        .data = .{ .int = 8 },
    });

    code.getInstRef(vals).data.block.end = x;
    code.getInstRef(block).data.block.end = x;

    std.debug.print("{!}\n", .{evaluate(allocator, &code)});
}
