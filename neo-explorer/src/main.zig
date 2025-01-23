const std = @import("std");

const libneo = @embedFile("libneo");

pub fn main() void {
    std.debug.print("Hello from explorer!\n", .{});
    std.debug.print("{s}", .{libneo});
}
