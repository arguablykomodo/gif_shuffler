const std = @import("std");
const consts = @import("consts.zig");
const CodeTable = @import("CodeTable.zig");

const Decompressor = @This();

block_size: u8,
byte_index: usize,
bit_index: std.math.Log2IntCeil(u8),

code_table: CodeTable,

pub fn init() Decompressor {
    return Decompressor{
        .block_size = undefined,
        .byte_index = undefined,
        .bit_index = undefined,
        .code_table = undefined,
    };
}

fn read(self: *Decompressor, input: [*]const u8) ?consts.Code {
    var bits = @min(std.math.log2_int_ceil(consts.CodeTableSize, @intCast(self.code_table.len() + 1)), 12);
    var bits_written: std.math.Log2IntCeil(consts.Code) = 0;
    var code: consts.Code = 0;
    while (bits > 0) {
        const to_read = @min(bits, 8 - self.bit_index);
        const mask = ((@as(consts.Code, 1) << to_read) - 1) << self.bit_index;
        code |= (input[self.byte_index] & mask) >> self.bit_index << bits_written;
        bits_written += to_read;
        bits -= to_read;
        self.bit_index += to_read;
        if (self.bit_index == 8) {
            self.bit_index = 0;
            self.byte_index += 1;
            self.block_size -= 1;
            if (self.block_size == 0) {
                self.block_size = input[self.byte_index];
                self.byte_index += 1;
                if (self.block_size == 0) return null;
            }
        }
    }
    return code;
}

pub fn decompress(
    self: *Decompressor,
    input: [*]const u8,
    output: []u8,
) !void {
    self.block_size = input[1];
    self.byte_index = 2;
    self.bit_index = 0;
    const color_table_size = @as(consts.ColorTableSize, 1) << @intCast(input[0]);
    self.code_table = CodeTable.init(color_table_size);

    var stream = std.io.fixedBufferStream(output);
    var writer = stream.writer();

    _ = self.read(input) orelse unreachable;
    var last_index = stream.pos;
    try writer.writeAll(self.code_table.get(self.read(input) orelse unreachable));
    while (self.read(input)) |code| {
        if (code == color_table_size) {
            self.code_table.reset(color_table_size);
            last_index = stream.pos;
            try writer.writeAll(self.code_table.get(self.read(input) orelse unreachable));
            continue;
        } else if (code == color_table_size + 1) {
            self.byte_index += self.block_size; // Reach end of block
            self.block_size = input[self.byte_index];
            self.byte_index += 1;
            if (self.block_size != 0) return error.BlockAndStreamEndMismatch;
            break;
        }
        if (code < self.code_table.len()) {
            const new_index = stream.pos;
            try writer.writeAll(self.code_table.get(code));
            if (self.code_table.len() < consts.MAX_CODES) self.code_table.addCode(output[last_index .. new_index + 1]);
            last_index = new_index;
        } else {
            const new_index = stream.pos;
            try writer.writeAll(output[last_index..new_index]);
            try writer.writeByte(output[last_index..new_index][0]);
            self.code_table.addCode(output[last_index .. new_index + 1]);
            last_index = new_index;
        }
    }
}

test "decompress" {
    const input = @embedFile("./test.gif")[74 .. 74 + 51];
    const expected: [319]consts.Color =
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
    var decompressor = Decompressor.init();
    var output = [_]consts.Color{0} ** 319;
    try decompressor.decompress(input, &output);
    try std.testing.expectEqualSlices(consts.Color, &expected, &output);
    try std.testing.expectEqual(@as(usize, 51), decompressor.byte_index);
}
