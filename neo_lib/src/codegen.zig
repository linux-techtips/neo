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

    curr_func: u8 = 0,

    pub fn deinit(gen: *Wasm) void {
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

    pub fn genExpr(gen: *Wasm, index: Inst.Index) Error!Inst.Index {
        const inst = gen.code.getInstRef(index);

        return switch (inst.tag) {
            .decl => try gen.genDecl(inst),
            .block => {
                const block = inst.data.block;

                var i = index;
                while (i < block.end) {
                    i = try gen.genExpr(i + 1);
                }
            },
        };
    }

    pub fn genFunc(gen: *Wasm, decl: Inst.Index, index: Inst.Index) Error!void {
        const name = gen.code.getInstRef(decl).data.decl.name;
        const func = gen.code.getInstRef(index).data.func;
        const params = gen.code.getInstRef(func.params).data.block;

        const param_len = params.end - func.params;

        // Write function type header.
        try gen.types.append(gen.gpa, wasm.function_type);
        // Write number of function params.
        try gen.types.append(gen.gpa, @intCast(param_len));

        for (func.params + 1..params.end + 1) |i| {
            const param = gen.code.getInstRef(@intCast(i)).data.param;
            // Write the type of param.
            try gen.types.append(gen.gpa, @intFromEnum(toWasmType(param.type)));
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

        gen.curr_func += 1;
    }

    pub fn dump(gen: *Wasm, file: std.fs.File) !void {
        const writer = file.writer();

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
        _ = try writer.write(&[_]u8{ 9, 1, 7, 0, @intFromEnum(wasm.Opcode.local_get), 0, @intFromEnum(wasm.Opcode.local_get), 0, @intFromEnum(wasm.Opcode.i32_mul), @intFromEnum(wasm.Opcode.end) });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var code = Code.new;
    defer code.data.deinit(allocator);

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

    code.getInstRef(params).data.block.end = param;

    var gen = Wasm{ .gpa = allocator, .code = &code };
    defer gen.deinit();

    try gen.genFunc(decl, func);

    const file = std.io.getStdOut();

    try gen.dump(file);
}
