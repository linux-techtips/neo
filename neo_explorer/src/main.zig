const http = @import("httpz");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try http.Server(void).init(allocator, .{ .address = "0.0.0.0", .port = 3000 }, {});

    const logger = try server.middleware(Logger, .{});

    var router = try server.router(.{ .middlewares = &.{logger} });

    router.get("/", getIndex, .{});
    router.get("/index.html", getIndex, .{});

    router.get("/index.css", getStyles, .{});
    router.get("/index.js", getScript, .{});
    router.get("/neo.wasm", getWasm, .{});

    std.log.info("{s}:{d}\n", .{ server.config.address.?, server.config.port.? });

    try server.listen();
}

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
