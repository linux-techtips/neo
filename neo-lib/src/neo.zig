fn lex(x: usize, y: usize) callconv(.C) usize {
    return x + y;
}

comptime {
    @export(&lex, .{ .name = "Neo_Lex", .linkage = .strong });
}
