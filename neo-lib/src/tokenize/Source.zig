const std = @import("std");
const tokenize = @import("../tokenize.zig");

const Source = @This();

buffer: [:0]align(tokenize.ChunkSize) const u8,
path: []const u8,

pub fn fromFile(allocator: std.mem.Allocator, path: []const u8) !Source {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();
    const over_size = tokenize.FrontPad.len + file_size + tokenize.BackPad.len + (tokenize.ChunkSize - 1);
    const buff_size = std.mem.alignBackward(usize, over_size, tokenize.ChunkSize);

    var buffer = try allocator.alignedAlloc(u8, tokenize.ChunkSize, buff_size);
    errdefer allocator.free(buffer);

    const write_size = try file.readAll(buffer[tokenize.FrontPad.len..]);

    @memcpy(buffer[0..tokenize.FrontPad.len], tokenize.FrontPad[0..]);
    @memcpy(buffer[tokenize.FrontPad.len + write_size ..][0..tokenize.BackPad.len], tokenize.BackPad[0..]);
    @memset(buffer[tokenize.FrontPad.len + write_size + tokenize.BackPad.len ..], 0);

    return .{
        .buffer = buffer[0 .. tokenize.FrontPad.len + write_size + 1 :0],
        .path = path,
    };
}

pub fn fromText(allocator: std.mem.Allocator, source: [:0]const u8) !Source {
    const over_size = tokenize.FrontPad.len + source.len + tokenize.BackPad.len + (tokenize.ChunkSize - 1);
    const buff_size = std.mem.alignBackward(usize, over_size, tokenize.ChunkSize);

    var buffer = try allocator.alignedAlloc(u8, tokenize.ChunkSize, buff_size);
    errdefer allocator.free(buffer);

    @memcpy(buffer[0..tokenize.FrontPad.len], tokenize.FrontPad[0..]);
    @memcpy(buffer[tokenize.FrontPad.len..][0..source.len], source[0..]);
    @memcpy(buffer[tokenize.FrontPad.len + source.len ..][0..tokenize.BackPad.len], tokenize.BackPad[0..]);
    @memset(buffer[tokenize.FrontPad.len + source.len + tokenize.BackPad.len ..], 0);

    return .{
        .buffer = buffer[0 .. tokenize.FrontPad.len + source.len + 1 :0],
        .path = "(anonymous)",
    };
}

pub fn text(self: *const Source) [:0]const u8 {
    return self.buffer[tokenize.FrontPad.len .. self.buffer.len - tokenize.FrontPad.len + 1 :0];
}

pub fn estimatedTokenSize(self: *const Source) usize {
    return self.buffer.len;
}

pub fn deinit(self: *const Source, allocator: std.mem.Allocator) void {
    allocator.free(self.buffer.ptr[0..std.mem.alignForward(usize, self.buffer.len + tokenize.BackPad.len, tokenize.ChunkSize)]);
}
