const std = @import("std");
const zap = @import("zap");

const libneo = @embedFile("neo");

const Neo = struct {
    ep: zap.Endpoint = undefined,

    pub fn init(path: []const u8) Neo {
        return .{
            .ep = zap.Endpoint.init(.{ .path = path, .get = get }),
        };
    }

    pub fn endpoint(self: *Neo) *zap.Endpoint {
        return &self.ep;
    }

    fn get(e: *zap.Endpoint, r: zap.Request) void {
        _ = e;

        r.setHeader("Content-Type", "application/wasm") catch unreachable;
        r.sendBody(libneo) catch return;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var listener = zap.Endpoint.Listener.init(
        allocator,
        .{
            .port = 3000,
            .on_request = on_request,
            .log = true,
            .public_folder = "./public",
            .max_clients = 100000,
            .max_body_size = 100 * 1024 * 1024,
        },
    );
    defer listener.deinit();

    var neo = Neo.init("/neo.wasm");
    try listener.register(neo.endpoint());

    try listener.listen();

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}

fn on_request(r: zap.Request) void {
    if (r.path) |path| std.debug.print("[path] {s}", .{path});
}
