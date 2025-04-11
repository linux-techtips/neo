const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();

    const file = try cwd.createFile("test.wasm", .{});
    defer file.close();

    const wasm = std.wasm;

    const func_type = [_]u8{ 1, wasm.function_type, 1, @intFromEnum(wasm.Valtype.i32), 1, @intFromEnum(wasm.Valtype.i32) };
    const type_sect = [_]u8{ @intFromEnum(wasm.Section.type), func_type.len } ++ func_type;

    const func_refs = [_]u8{ 1, 0 };
    const func_sect = [_]u8{ @intFromEnum(wasm.Section.function), func_refs.len } ++ func_refs;

    const code_expr = [_]u8{
        0, // number of locals
        @intFromEnum(wasm.Opcode.local_get),
        0,
        @intFromEnum(wasm.Opcode.local_get),
        0,
        @intFromEnum(wasm.Opcode.i32_mul),
        @intFromEnum(wasm.Opcode.end),
    };
    const code_sect = [_]u8{
        @intFromEnum(wasm.Section.code),
        code_expr.len + 2, // size of code section.
        1, // number of functions.
        code_expr.len,
    } ++ code_expr;

    const export_name = "square";
    const export_elem = [_]u8{export_name.len} ++ export_name ++ [_]u8{ @intFromEnum(wasm.ExternalKind.function), 0 };

    const export_sect = [_]u8{
        @intFromEnum(wasm.Section.@"export"),
        export_elem.len + 1,
        1,
    } ++ export_elem;

    try file.writeAll(std.wasm.magic ++ std.wasm.version ++ &type_sect ++ &func_sect ++ export_sect ++ &code_sect);
}
