const std = @import("std");
const CodeTable = @import("CodeTable.zig");

const BlockReader = struct {
    reader: *std.Io.Reader,
    block_size: u8,
    byte: u8,
    bit_index: u4,

    fn init(reader: *std.Io.Reader) !BlockReader {
        const block_size = try reader.takeByte();
        if (block_size == 0) return error.Malformed;
        return BlockReader{
            .reader = reader,
            .block_size = block_size - 1,
            .byte = try reader.takeByte(),
            .bit_index = 0,
        };
    }

    fn read(self: *BlockReader, code_table_size: CodeTable.Size) !?CodeTable.Code {
        var bits = @min(std.math.log2_int_ceil(CodeTable.Size, code_table_size + 1), 12);
        var bits_written: std.math.Log2IntCeil(CodeTable.Code) = 0;
        var code: CodeTable.Code = 0;
        while (bits > 0) {
            const to_read = @min(bits, 8 - self.bit_index);
            const mask = ((@as(CodeTable.Code, 1) << to_read) - 1) << self.bit_index;
            code |= (self.byte & mask) >> self.bit_index << bits_written;
            bits_written += to_read;
            bits -= to_read;
            self.bit_index += to_read;
            if (self.bit_index == 8) {
                self.bit_index = 0;
                if (self.block_size == 0) {
                    self.block_size = try self.reader.takeByte();
                    if (self.block_size == 0) return null;
                }
                self.byte = try self.reader.takeByte();
                self.block_size -= 1;
            }
        }
        return code;
    }

    fn end(self: *BlockReader) !void {
        try self.reader.discardAll(self.block_size);
        self.block_size = try self.reader.takeByte();
        if (self.block_size != 0) return error.Malformed;
    }
};

pub fn decompress(
    input: *std.Io.Reader,
    output: []u8,
) !void {
    const min_code_size = try input.takeByte();
    if (min_code_size > 12) return error.Malformed;
    var block_reader = try BlockReader.init(input);
    const code_table_size = @as(CodeTable.Size, 1) << @intCast(min_code_size);
    var code_table = CodeTable.init(code_table_size);

    var writer = std.Io.Writer.fixed(output);

    _ = try block_reader.read(code_table.len()) orelse return error.Malformed;
    var last_index = writer.end;
    const first_code = try block_reader.read(code_table.len()) orelse return error.Malformed;
    if (first_code > code_table.len()) return error.Malformed;
    try writer.writeAll(code_table.get(first_code));
    while (try block_reader.read(code_table.len())) |code| {
        if (code == code_table_size) {
            code_table.reset(code_table_size);
            last_index = writer.end;
            const new_code = try block_reader.read(code_table.len()) orelse return error.Malformed;
            if (new_code > code_table.len()) return error.Malformed;
            try writer.writeAll(code_table.get(new_code));
            continue;
        } else if (code == code_table_size + 1) {
            try block_reader.end();
            break;
        } else if (code < code_table.len()) {
            const new_index = writer.end;
            const codee = code_table.get(code);
            try writer.writeAll(codee);
            if (code_table.len() < CodeTable.MAX_CODES) code_table.addCode(output[last_index .. new_index + 1]);
            last_index = new_index;
        } else {
            const new_index = writer.end;
            if (new_index <= last_index) return error.Malformed; // First code cannot be new.
            try writer.writeAll(output[last_index..new_index]);
            try writer.writeByte(output[last_index..new_index][0]);
            code_table.addCode(output[last_index .. new_index + 1]);
            last_index = new_index;
        }
    }
}

test "decompress" {
    const input = @embedFile("./test.gif")[74 .. 74 + 51];
    const expected: [319]u8 =
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
    var output = [_]u8{0} ** 319;
    var reader = std.Io.Reader.fixed(input);
    try decompress(&reader, &output);
    try std.testing.expectEqualSlices(u8, &expected, &output);
    try std.testing.expectEqual(@as(usize, 51), reader.seek);
}
