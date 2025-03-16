const http = @import("httpz");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = std.process.args();
    _ = args.next();

    var addr: []const u8 = "127.0.0.1";
    var port: u16 = 3000;

    // TODO: We probably should refactor this later
    while (args.next()) |arg| {
        var it = std.mem.tokenizeSequence(u8, arg, "=");
        const key, const val = .{ it.next().?, it.next().? };

        if (std.mem.eql(u8, key, "--port")) {
            port = try std.fmt.parseInt(u16, val, 10);
        } else if (std.mem.eql(u8, key, "--addr")) {
            addr = val;
        }
    }

    var server = try http.Server(void).init(allocator, .{ .address = addr, .port = port }, {});

    const logger = try server.middleware(Logger, .{});
    const cacher = try server.middleware(Cacher, .{});

    var router = try server.router(.{ .middlewares = &.{ logger, cacher } });

    router.get("/", getIndex, .{});
    router.get("/index.html", getIndex, .{});

    router.get("/index.css", getStyles, .{});
    router.get("/index.js", getScript, .{});
    router.get("/neo.wasm", getWasm, .{});

    std.log.info("{s}:{?d}\n", .{ server.config.address orelse "localhost", server.config.port });

    try server.listen();
}

fn getIndex(_: *http.Request, res: *http.Response) !void {
    res.content_type = http.ContentType.HTML;
    res.body = @embedFile("index.html");
}

fn getStyles(_: *http.Request, res: *http.Response) !void {
    res.content_type = http.ContentType.CSS;
    res.body = @embedFile("index.css");
}

fn getScript(_: *http.Request, res: *http.Response) !void {
    res.content_type = http.ContentType.JS;
    res.body = @embedFile("index.js");
}

fn getWasm(_: *http.Request, res: *http.Response) !void {
    res.content_type = http.ContentType.WASM;
    res.body = @embedFile("neo.wasm");
}

const Cacher = struct {
    pub fn init(_: Config) !Cacher {
        return .{};
    }

    pub fn execute(_: *const Cacher, _: *http.Request, res: *http.Response, executor: anytype) !void {
        res.headers.add("Cache-Control", "public, max-age=3600");

        return executor.next();
    }

    pub const Config = struct {};
};

const Logger = struct {
    pub fn init(_: Config) !Logger {
        return .{};
    }

    pub fn execute(_: *const Logger, req: *http.Request, res: *http.Response, executor: anytype) !void {
        const start = std.time.microTimestamp();
        defer {
            const elapsed = std.time.microTimestamp() - start;
            std.log.debug("{s}\t{s}\t{d}\t{d}us", .{ req.url.path, req.url.query, res.status, elapsed });
        }

        return executor.next();
    }

    pub const Config = struct {};
};
