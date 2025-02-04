const std = @import("std");

const Source = @This();

pub const Chunk = @Vector(std.simd.suggestVectorLength(u8).?, u8);
pub const ChunkAlign = @alignOf(Chunk);
pub const ChunkSize = @sizeOf(Chunk);

// TODO: Explain this.
pub const FrontPad = "\n";
pub const BackPad = FrontPad ++ "\x00" ** 63;

buffer: [:0]align(ChunkSize) const u8,
path: []const u8,

pub fn fromFile(allocator: std.mem.Allocator, path: []const u8) !Source {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();
    const over_size = FrontPad.len + file_size + BackPad.len + (ChunkSize - 1);
    const buff_size = std.mem.alignBackward(usize, over_size, ChunkSize);

    var buffer = try allocator.alignedAlloc(u8, ChunkSize, buff_size);
    errdefer allocator.free(buffer);

    const write_size = try file.readAll(buffer[FrontPad.len..]);

    @memcpy(buffer[0..FrontPad.len], FrontPad[0..]);
    @memcpy(buffer[FrontPad.len + write_size ..][0..BackPad.len], BackPad[0..]);
    @memset(buffer[FrontPad.len + write_size + BackPad.len ..], 0);

    return .{
        .buffer = buffer[0 .. FrontPad.len + write_size + 1 :0],
        .path = path,
    };
}

pub fn fromText(allocator: std.mem.Allocator, source: [:0]const u8) !Source {
    const over_size = FrontPad.len + source.len + BackPad.len + (ChunkSize - 1);
    const buff_size = std.mem.alignBackward(usize, over_size, ChunkSize);

    var buffer = try allocator.alignedAlloc(u8, ChunkSize, buff_size);
    errdefer allocator.free(buffer);

    @memcpy(buffer[0..FrontPad.len], FrontPad[0..]);
    @memcpy(buffer[FrontPad.len..][0..source.len], source[0..]);
    @memcpy(buffer[FrontPad.len + source.len ..][0..BackPad.len], BackPad[0..]);
    @memset(buffer[FrontPad.len + source.len + BackPad.len ..], 0);

    return .{
        .buffer = buffer[0 .. FrontPad.len + source.len + 1 :0],
        .path = "(anonymous)",
    };
}

pub fn text(self: *const Source) [:0]const u8 {
    return self.buffer[FrontPad.len .. self.buffer.len - FrontPad.len + 1 :0];
}

pub fn estimatedTokenSize(self: *const Source) usize {
    return self.buffer.len;
}

pub fn deinit(self: *const Source, allocator: std.mem.Allocator) void {
    allocator.free(self.buffer.ptr[0..std.mem.alignForward(usize, self.buffer.len + BackPad.len, ChunkSize)]);
}
