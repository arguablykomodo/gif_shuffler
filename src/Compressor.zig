const std = @import("std");
const Trie = @import("Trie.zig");

const BlockWriter = struct {
    block_buffer: [255]u8 = undefined,
    byte_buffer: u8 = 0,
    block_end: u8 = 0,
    bit_pos: u4 = 0,

    fn write(self: *BlockWriter, writer: *std.Io.Writer, code: Trie.Code, code_table_size: Trie.Size) !void {
        var code_tmp = code;
        var bits = std.math.log2_int_ceil(Trie.Size, code_table_size);
        while (bits > 0) {
            const to_write = @min(bits, 8 - self.bit_pos);
            const mask = (@as(Trie.Code, 1) << to_write) - 1;
            self.byte_buffer |= @intCast((code_tmp & mask) << self.bit_pos);
            code_tmp >>= to_write;
            bits -= to_write;
            self.bit_pos += to_write;
            if (self.bit_pos == 8) {
                if (self.block_end == 255) {
                    try writer.writeByte(255);
                    try writer.writeAll(&self.block_buffer);
                    self.block_end = 0;
                }
                self.block_buffer[self.block_end] = self.byte_buffer;
                self.block_end += 1;
                self.bit_pos = 0;
                self.byte_buffer = 0;
            }
        }
    }

    fn flush(self: *BlockWriter, writer: *std.Io.Writer) !void {
        if (self.bit_pos != 0) {
            if (self.block_end == 255) {
                try writer.writeByte(255);
                try writer.writeAll(&self.block_buffer);
                self.block_end = 0;
            }
            self.block_buffer[self.block_end] = self.byte_buffer;
            self.block_end += 1;
        }
        if (self.block_end != 0) {
            try writer.writeByte(@intCast(self.block_end));
            try writer.writeAll(self.block_buffer[0..self.block_end]);
        }
        try writer.writeByte(0);
    }
};

pub fn compress(
    input: []const u8,
    writer: *std.Io.Writer,
    color_table_size: u9,
) !void {
    var trie = Trie.init(color_table_size);
    var block_writer = BlockWriter{};

    const minimum_code_size = std.math.log2_int_ceil(u9, color_table_size);
    try writer.writeByte(minimum_code_size);
    try block_writer.write(writer, color_table_size, trie.nodes_len);
    var node: *Trie.Node = &trie.nodes[input[0]];
    var index: usize = 1;
    while (index < input.len) : (index += 1) {
        if (node.hasChild(input[index])) |child| {
            node = child;
        } else {
            try block_writer.write(writer, node.code, trie.nodes_len);
            trie.insert(node, input[index]);
            node = &trie.nodes[input[index]];
            if (trie.nodes_len == Trie.MAX_CODES) {
                try block_writer.write(writer, color_table_size, trie.nodes_len);
                trie.reset(color_table_size);
            }
        }
    }
    try block_writer.write(writer, node.code, trie.nodes_len);
    try block_writer.write(writer, color_table_size + 1, trie.nodes_len);
    try block_writer.flush(writer);
}

test "compress" {
    const input: [319]u8 =
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
    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try compress(&input, &output.writer, 8);
    try std.testing.expectEqualSlices(u8, expected, output.written());
}
