const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Source = @import("Source.zig");
const Token = tokenizer.Token;

pub const Error = Allocator.Error || error{};

pub const Inst = struct {
    token: u32,
    data: Data,
    tag: Tag,

    pub const Index = u32;

    pub const Data = struct {
        bin: struct {
            lhs: Index,
            rhs: Index,
        },
        int: u64,
    };

    const Tag = enum(u8) {
        add,
        int,
    };
};

pub const Module = struct {
    code: std.MultiArrayList(Inst),

    pub const new = Module{ .code = .empty };

    pub fn addInst(self: *Module, allocator: Allocator, inst: Inst) Error!Inst.Index {
        try self.code.append(allocator, inst);

        return @enumFromInt(self.code.len - 1);
    }

    pub fn getDataRef(self: *Module, index: Inst.Index) *Inst.Data {
        return &self.code.items(.data)[index];
    }
};

test "generate" {
    const allocator = std.testing.allocator;

    const source = try Source.fromText(allocator, "2 + 2");
    defer source.deinit(allocator);

    const tokens = try tokenizer.tokenize(allocator, source);
    defer allocator.free(tokens);

    const tree = try parser.parse(allocator, tokens);
    defer allocator.free(tree);

    var generator = Generator.init(source, tree);

    var module = try generator.generate(allocator);
    defer module.code.deinit(allocator);
}

pub const Generator = @import("nir/Generator.zig");
