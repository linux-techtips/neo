const nir = @import("nir.zig");
const std = @import("std");
const wasm = std.wasm;

const Allocator = std.mem.Allocator;
const Error = nir.Error;
const Inst = nir.Inst;
const Code = nir.Code;

pub const Scope = struct {};

pub const Wasm = struct {
    const Buffer = std.ArrayListUnmanaged(u8);

    code: *Code,
    gpa: Allocator,

    exports: Buffer = .empty,
    types: Buffer = .empty,
    funcs: Buffer = .empty,
    exprs: Buffer = .empty,

    locals: std.StringHashMapUnmanaged(u8) = .empty,

    curr_opcode: u8 = 0,
    curr_local: u8 = 0,
    curr_func: u8 = 0,

    pub fn deinit(gen: *Wasm) void {
        gen.locals.deinit(gen.gpa);
        gen.exports.deinit(gen.gpa);
        gen.types.deinit(gen.gpa);
        gen.funcs.deinit(gen.gpa);
        gen.exprs.deinit(gen.gpa);
    }

    pub fn toWasmType(key: Inst.Key) wasm.Valtype {
        return switch (key) {
            .type_s32 => wasm.Valtype.i32,
            .type_s64 => wasm.Valtype.i64,
            else => unreachable,
        };
    }

    pub fn toWasmOpcode(tag: Inst.Tag) wasm.Opcode {
        return switch (tag) {
            .add => wasm.Opcode.i32_add,
            .sub => wasm.Opcode.i32_sub,
            .mul => wasm.Opcode.i32_mul,
            .div => wasm.Opcode.i32_div_s,
            else => unreachable,
        };
    }

    pub fn genExpr(gen: *Wasm, index: Inst.Index) Error!Inst.Index {
        const inst = gen.code.getInstRef(index);
        return switch (inst.tag) {
            .decl => try gen.genDecl(index, &inst.data.decl),
            .block => try gen.genBlock(index, &inst.data.block),
            .add, .sub, .mul, .div => |tag| try gen.genBin(tag, &inst.data.bin),
            .call => try gen.genCall(index, &inst.data.call),
            .int => {
                const int = inst.data.int;
                try gen.exprs.append(gen.gpa, @intFromEnum(wasm.Opcode.i32_const));
                try gen.exprs.append(gen.gpa, @intCast(int));

                return index + 1;
            },
            .local => {
                const local = inst.data.local;
                const local_index = gen.locals.get(local.name) orelse @panic("invalid local");

                try gen.exprs.append(gen.gpa, @intFromEnum(wasm.Opcode.local_get));
                try gen.exprs.append(gen.gpa, local_index);

                return index + 1;
            },
            else => |tag| std.debug.panic("Attempted to generate an expression for an invalid instruction tag: {s}", .{@tagName(tag)}),
        };
    }

    pub fn genCall(gen: *Wasm, _: Inst.Index, call: *const Inst.Data.Call) Error!Inst.Index {
        const args = gen.code.getInstRef(call.args).data.block;
        const end = call.args + args.len + 1;

        var i = call.args + 1;
        while (i < end) {
            i = try gen.genExpr(i);
        }

        const func_index = gen.locals.get(call.name) orelse @panic("invalid function");
        try gen.exprs.append(gen.gpa, @intFromEnum(wasm.Opcode.call));
        try gen.exprs.append(gen.gpa, func_index);

        return i;
    }

    pub fn genBin(gen: *Wasm, tag: Inst.Tag, bin: *const Inst.Data.Bin) Error!Inst.Index {
        _ = try gen.genExpr(bin.lhs);
        const next = try gen.genExpr(bin.rhs);

        try gen.exprs.append(gen.gpa, @intFromEnum(Wasm.toWasmOpcode(tag)));

        return next;
    }

    pub fn genDecl(gen: *Wasm, index: Inst.Index, decl: *const Inst.Data.Decl) Error!Inst.Index {
        switch (decl.type) {
            .type_s32, .type_s64 => {
                try gen.locals.put(gen.gpa, decl.name, gen.curr_local);
                gen.curr_local += 1;

                return index + 1;
            },
            else => |key| {
                // This prevents us from creating function declarations within function declarations.
                // TODO(carter): Remove this restriction.
                std.debug.assert(gen.curr_local == 0);

                const func_index = Inst.Key.toIndexUnchecked(key);
                const func = gen.code.getInstRef(func_index).data.func;

                // Write the function to the locals table.
                // TODO(carter): This is a hack.
                try gen.locals.put(gen.gpa, decl.name, gen.curr_func);

                const next = try gen.genFunc(decl, &func);
                gen.curr_local = 0;

                return next;
            },
        }
    }

    pub fn genBlock(gen: *Wasm, index: Inst.Index, block: *const Inst.Data.Block) Error!Inst.Index {
        const end = index + block.len;

        var i = index + 1;
        while (i < end) {
            i = try gen.genExpr(i);
        }

        return i;
    }

    pub fn genFunc(gen: *Wasm, decl: *const Inst.Data.Decl, func: *const Inst.Data.Func) Error!Inst.Index {
        const name = decl.name;
        const params = gen.code.getInstRef(func.params).data.block;

        // Write function type header.
        try gen.types.append(gen.gpa, wasm.function_type);
        // Write number of function params.
        try gen.types.append(gen.gpa, @intCast(params.len));

        for (1..params.len + 1) |i| {
            const offset = func.params + i;
            const param = gen.code.getInstRef(@intCast(offset)).data.param;
            // Write the type of param.
            try gen.types.append(gen.gpa, @intFromEnum(toWasmType(param.type)));

            try gen.locals.put(gen.gpa, param.name, gen.curr_local);
            gen.curr_local += 1;
        }

        // Write the number of return params.
        try gen.types.append(gen.gpa, 1);
        // Write the type of the return param.
        try gen.types.append(gen.gpa, @intFromEnum(toWasmType(func.ret_ty)));

        try gen.exports.append(gen.gpa, @intCast(name.len));
        try gen.exports.appendSlice(gen.gpa, name);
        try gen.exports.appendSlice(gen.gpa, &[_]u8{ @intFromEnum(wasm.ExternalKind.function), gen.curr_func });

        // Populate the func sections.
        try gen.funcs.append(gen.gpa, @intCast(gen.curr_func));

        // Temporarily store the offset into the exprs buffer of where to store the length of the function body.
        const len_idx = gen.exprs.items.len;
        try gen.exprs.append(gen.gpa, std.math.maxInt(u8));

        // Temporarily store the offset into the exprs buffer of where to store the local count.
        const locals_idx = gen.exprs.items.len;
        try gen.exprs.append(gen.gpa, std.math.maxInt(u8));

        // Generate the function body.
        const next = try gen.genExpr(decl.expr);

        // End the function body.
        try gen.exprs.append(gen.gpa, @intFromEnum(wasm.Opcode.end));

        // Now that the length of the function body is the current length minus the length of the tmp placeholder.
        gen.exprs.items[len_idx] = @intCast(gen.exprs.items.len - len_idx - 1);
        // Now that we know how many locals we have, we can store it. Function parameters do not count.
        gen.exprs.items[locals_idx] = @intCast(gen.curr_local - params.len);

        gen.curr_func += 1;

        return next;
    }

    pub fn lower(gen: *Wasm, writer: std.io.AnyWriter) !void {
        // Write magic + version.
        _ = try writer.write(&wasm.magic ++ &wasm.version);

        // Write type section magic.
        _ = try writer.writeByte(@intFromEnum(wasm.Section.type));
        // Write type section len in bytes.
        _ = try writer.writeByte(@intCast(gen.types.items.len + 1));
        // Write the number of types.
        _ = try writer.writeByte(gen.curr_func);
        // Write the type section.
        _ = try writer.write(gen.types.items);

        // Write func section magic.
        _ = try writer.writeByte(@intFromEnum(wasm.Section.function));
        _ = try writer.writeByte(@intCast(gen.funcs.items.len + 1));
        _ = try writer.writeByte(gen.curr_func);
        _ = try writer.write(gen.funcs.items);

        // Write the export section.
        _ = try writer.writeByte(@intFromEnum(wasm.Section.@"export"));
        _ = try writer.writeByte(@intCast(gen.exports.items.len + 1));
        _ = try writer.writeByte(gen.curr_func);

        _ = try writer.write(gen.exports.items);

        // Write code section magic.
        _ = try writer.writeByte(@intFromEnum(wasm.Section.code));
        // Write all the code stuff.
        // _ = try writer.write(&[_]u8{ 9, 1, 7, 0, @intFromEnum(wasm.Opcode.local_get), 0, @intFromEnum(wasm.Opcode.local_get), 0, @intFromEnum(wasm.Opcode.i32_mul), @intFromEnum(wasm.Opcode.end) });

        // Write the length of the code section.
        _ = try writer.writeByte(@intCast(gen.exprs.items.len + 1));

        // Write the number of functions in the code section.
        _ = try writer.writeByte(gen.curr_func);

        // Write the code section.
        _ = try writer.write(gen.exprs.items);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var code = Code.new;
    defer code.data.deinit(allocator);

    const program = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = undefined },
    });

    const decl = try code.addInst(allocator, .{ .tag = .decl, .data = .{ .decl = .{
        .name = "square",
        .type = undefined,
        .expr = undefined,
    } } });

    const func = try code.addInst(allocator, .{
        .tag = .func,
        .data = .{ .func = .{ .params = undefined, .ret_ty = .type_s32 } },
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

    code.getInstRef(params).data.block.len = param - params;

    const expr = try code.addInst(allocator, .{
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

    code.getInstRef(expr).data.bin = .{ .lhs = lhs, .rhs = rhs };
    code.getInstRef(decl).data.decl.expr = expr;

    const add_decl = try code.addInst(allocator, .{
        .tag = .decl,
        .data = .{ .decl = .{
            .name = "add",
            .type = undefined,
            .expr = undefined,
        } },
    });

    const add_func = try code.addInst(allocator, .{
        .tag = .func,
        .data = .{ .func = .{ .params = undefined, .ret_ty = .type_s32 } },
    });

    code.getInstRef(add_decl).data.decl.type = Inst.Key.fromIndex(add_func);

    const add_params = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = undefined },
    });

    code.getInstRef(add_func).data.func.params = add_params;

    _ = try code.addInst(allocator, .{
        .tag = .param,
        .data = .{ .param = .{ .name = "x", .type = .type_s32 } },
    });

    const add_param_y = try code.addInst(allocator, .{
        .tag = .param,
        .data = .{ .param = .{ .name = "y", .type = .type_s32 } },
    });

    code.getInstRef(add_params).data.block.len = add_param_y - add_params;

    const add_expr = try code.addInst(allocator, .{
        .tag = .add,
        .data = .{ .bin = undefined },
    });

    const add_lhs = try code.addInst(allocator, .{
        .tag = .local,
        .data = .{ .local = .{ .name = "x" } },
    });

    const add_rhs = try code.addInst(allocator, .{
        .tag = .local,
        .data = .{ .local = .{ .name = "y" } },
    });

    code.getInstRef(add_expr).data.bin = .{ .lhs = add_lhs, .rhs = add_rhs };
    code.getInstRef(add_decl).data.decl.expr = add_expr;

    const foo_decl = try code.addInst(allocator, .{
        .tag = .decl,
        .data = .{ .decl = .{ .name = "foo", .type = undefined, .expr = undefined } },
    });

    const foo_func = try code.addInst(allocator, .{
        .tag = .func,
        .data = .{ .func = .{ .params = undefined, .ret_ty = .type_s32 } },
    });

    code.getInstRef(foo_decl).data.decl.type = Inst.Key.fromIndex(foo_func);

    const foo_params = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = .{ .len = 0 } },
    });

    code.getInstRef(foo_func).data.func.params = foo_params;

    const foo_expr = try code.addInst(allocator, .{ .tag = .call, .data = .{ .call = .{ .name = "add", .args = undefined } } });

    code.getInstRef(foo_decl).data.decl.expr = foo_expr;

    const foo_args = try code.addInst(allocator, .{
        .tag = .block,
        .data = .{ .block = .{ .len = undefined } },
    });

    code.getInstRef(foo_expr).data.call.args = foo_args;

    _ = try code.addInst(allocator, .{
        .tag = .int,
        .data = .{ .int = 34 },
    });

    const foo_arg2 = try code.addInst(allocator, .{
        .tag = .int,
        .data = .{ .int = 35 },
    });

    code.getInstRef(foo_args).data.block.len = foo_arg2 - foo_args;
    code.getInstRef(program).data.block.len = foo_arg2 - program;

    var gen = Wasm{ .gpa = allocator, .code = &code };
    defer gen.deinit();

    _ = try gen.genExpr(program);

    const file = std.io.getStdOut();
    var buffer = std.io.bufferedWriter(file.writer());
    const writer = buffer.writer();

    try gen.lower(writer.any());
    try buffer.flush();
}
