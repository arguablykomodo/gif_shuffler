const std = @import("std");
const consts = @import("consts.zig");
const Trie = @import("Trie.zig");

const Compressor = @This();

output: *std.ArrayList(u8),
block_buffer: std.BoundedArray(u8, 255),
byte_buffer: u8,
current_bit: std.math.Log2IntCeil(u8),

trie: Trie,

pub fn init() Compressor {
    return Compressor{
        .trie = undefined,
        .output = undefined,
        .block_buffer = std.BoundedArray(u8, 255).init(0) catch unreachable,
        .byte_buffer = undefined,
        .current_bit = undefined,
    };
}

fn write(self: *Compressor, _code: consts.Code) !void {
    var code = _code;
    var bits = std.math.log2_int_ceil(
        consts.CodeTableSize,
        @intCast(self.trie.nodes.len),
    );
    while (bits > 0) {
        const to_write = @min(bits, 8 - self.current_bit);
        const mask = (@as(consts.Code, 1) << to_write) - 1;
        self.byte_buffer |= @intCast((code & mask) << self.current_bit);
        code >>= to_write;
        bits -= to_write;
        self.current_bit += to_write;
        if (self.current_bit == 8) {
            if (self.block_buffer.len == 255) {
                try self.output.append(255);
                try self.output.appendSlice(self.block_buffer.slice());
                self.block_buffer.resize(0) catch unreachable;
            }
            self.block_buffer.appendAssumeCapacity(self.byte_buffer);
            self.byte_buffer = 0;
            self.current_bit = 0;
        }
    }
}

pub fn compress(
    self: *Compressor,
    input: []const consts.Color,
    output: *std.ArrayList(u8),
    color_table_size: consts.ColorTableSize,
) !void {
    self.trie = Trie.init(color_table_size);
    self.output = output;
    self.block_buffer.resize(0) catch unreachable;
    self.byte_buffer = 0;
    self.current_bit = 0;

    const minimum_code_size = std.math.log2_int_ceil(consts.ColorTableSize, color_table_size);
    try self.output.append(minimum_code_size);
    try self.write(color_table_size);
    var node: *Trie.Node = &self.trie.nodes.slice()[input[0]];
    var index: usize = 1;
    while (index < input.len) : (index += 1) {
        if (node.findChild(input[index])) |child| {
            node = child;
        } else {
            try self.write(node.code);
            self.trie.insert(node, input[index]);
            node = &self.trie.nodes.slice()[input[index]];
            if (self.trie.nodes.len == consts.MAX_CODES) {
                try self.write(color_table_size);
                self.trie.reset(color_table_size);
            }
        }
    }
    try self.write(node.code);
    try self.write(color_table_size + 1);
    if (self.current_bit != 0) {
        if (self.block_buffer.len == 255) {
            try self.output.append(255);
            try self.output.appendSlice(self.block_buffer.slice());
            self.block_buffer.resize(0) catch unreachable;
        }
        self.block_buffer.appendAssumeCapacity(self.byte_buffer);
    }
    if (self.block_buffer.len != 0) {
        try self.output.append(@intCast(self.block_buffer.len));
        try self.output.appendSlice(self.block_buffer.slice());
    }
    try self.output.append(0);
}

test "compress" {
    const input: [319]consts.Color =
        (.{7} ** 11 ** 2 ++
        .{7} ** 4 ++ .{3} ** 3 ++ .{7} ** 4 ++
        .{7} ** 3 ++ .{3} ** 5 ++ .{7} ** 3 ++
        (.{7} ** 2 ++ .{3} ** 7 ++ .{7} ** 2) ** 3 ++
        .{7} ** 3 ++ .{3} ** 5 ++ .{7} ** 3 ++
        .{7} ** 4 ++ .{3} ** 3 ++ .{7} ** 4) ** 2 ++
        .{7} ** 11 ** 2 ++
        .{7} ** 4 ++ .{1} ** 3 ++ .{7} ** 4 ++
        .{7} ** 3 ++ .{1} ** 5 ++ .{7} ** 3 ++
        (.{7} ** 2 ++ .{1} ** 7 ++ .{7} ** 2) ** 3 ++
        .{7} ** 3 ++ .{1} ** 5 ++ .{7} ** 3 ++
        .{7} ** 4 ++ .{1} ** 3 ++ .{7} ** 4 ++
        .{7} ** 11 ** 2;
    const expected = @embedFile("./test.gif")[74 .. 74 + 51];
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var compressor = Compressor.init();
    try compressor.compress(&input, &output, 8);
    try std.testing.expectEqualSlices(u8, expected, output.items);
}
