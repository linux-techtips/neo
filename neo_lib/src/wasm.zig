const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();

    const file = try cwd.createFile("test.wasm", .{});
    defer file.close();

    const wasm = std.wasm;

    // defines a single wasm  function that takes a single i32 as input and returns a single i32 as a result.
    const func_type = [_]u8{
        2,
        wasm.function_type,
        1,
        @intFromEnum(wasm.Valtype.i32),
        1,
        @intFromEnum(wasm.Valtype.i32),
        wasm.function_type,
        2,
        @intFromEnum(wasm.Valtype.i32),
        @intFromEnum(wasm.Valtype.i32),
        1,
        @intFromEnum(wasm.Valtype.i32),
    };
    const type_sect = [_]u8{ @intFromEnum(wasm.Section.type), func_type.len } ++ func_type;

    const func_refs = [_]u8{ 2, 0, 1 };
    const func_sect = [_]u8{ @intFromEnum(wasm.Section.function), func_refs.len } ++ func_refs;

    const square_expr = [_]u8{
        0, // number of locals
        @intFromEnum(wasm.Opcode.local_get),
        0,
        @intFromEnum(wasm.Opcode.local_get),
        0,
        @intFromEnum(wasm.Opcode.i32_mul),
        @intFromEnum(wasm.Opcode.end),
    };

    const add_expr = [_]u8{
        0,
        @intFromEnum(wasm.Opcode.local_get),
        0,
        @intFromEnum(wasm.Opcode.local_get),
        1,
        @intFromEnum(wasm.Opcode.i32_add),
        @intFromEnum(wasm.Opcode.end),
    };

    const code_sect = [_]u8{
        @intFromEnum(wasm.Section.code),
        square_expr.len + add_expr.len + 3, // size of code section.
        2, // number of functions.
        square_expr.len,
    } ++ square_expr ++ [_]u8{add_expr.len} ++ add_expr;

    const export_square_name = "square";
    const export_square = [_]u8{export_square_name.len} ++ export_square_name ++ [_]u8{ @intFromEnum(wasm.ExternalKind.function), 0 };

    const export_add_name = "add";
    const export_add = [_]u8{export_add_name.len} ++ export_add_name ++ [_]u8{ @intFromEnum(wasm.ExternalKind.function), 1 };

    const export_sect = [_]u8{
        @intFromEnum(wasm.Section.@"export"),
        export_square.len + export_add.len + 1,
        2,
    } ++ export_square ++ export_add;

    try file.writeAll(std.wasm.magic ++ std.wasm.version ++ &type_sect ++ &func_sect ++ export_sect ++ &code_sect);
}
