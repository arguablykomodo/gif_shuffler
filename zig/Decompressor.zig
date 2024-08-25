const std = @import("std");
const consts = @import("consts.zig");
const setupTable = @import("code_table.zig").setup;
const CodeTable = @import("code_table.zig").CodeTable;

const Decompressor = @This();

alloc: std.mem.Allocator,

input: [*]const u8,
block_size: u8,
byte_index: usize,
bit_index: std.math.Log2IntCeil(u8),

output: *std.ArrayList(consts.Color),
color_table_size: consts.ColorTableSize,
code_table: CodeTable,

pub fn init() Decompressor {
    return Decompressor{
        .alloc = undefined,
        .input = undefined,
        .block_size = undefined,
        .byte_index = undefined,
        .bit_index = undefined,
        .output = undefined,
        .color_table_size = undefined,
        .code_table = CodeTable.init(0) catch unreachable,
    };
}

fn read(self: *Decompressor) ?consts.Code {
    var bits = @min(std.math.log2_int_ceil(consts.CodeTableSize, @intCast(self.code_table.len + 1)), 12);
    var bits_written: std.math.Log2IntCeil(consts.Code) = 0;
    var code: consts.Code = 0;
    while (bits > 0) {
        const to_read = @min(bits, 8 - self.bit_index);
        const mask = ((@as(consts.Code, 1) << to_read) - 1) << self.bit_index;
        code |= (self.input[self.byte_index] & mask) >> self.bit_index << bits_written;
        bits_written += to_read;
        bits -= to_read;
        self.bit_index += to_read;
        if (self.bit_index == 8) {
            self.bit_index = 0;
            self.byte_index += 1;
            self.block_size -= 1;
            if (self.block_size == 0) {
                self.block_size = self.input[self.byte_index];
                self.byte_index += 1;
                if (self.block_size == 0) return null;
            }
        }
    }
    return code;
}

fn resetTable(self: *Decompressor) void {
    for (self.code_table.slice()[self.color_table_size + 2 ..]) |string| {
        self.alloc.free(string);
    }
    self.code_table.resize(self.color_table_size + 2) catch unreachable;
}

pub fn decompress(
    self: *Decompressor,
    alloc: std.mem.Allocator,
    input: [*]const u8,
    output: *std.ArrayList(consts.Color),
) !void {
    self.input = input;
    self.alloc = alloc;
    self.block_size = input[1];
    self.byte_index = 2;
    self.bit_index = 0;
    self.output = output;
    self.color_table_size = @as(consts.ColorTableSize, 1) << @intCast(input[0]);
    setupTable(&self.code_table, self.color_table_size);
    defer self.resetTable();

    _ = self.read() orelse unreachable;
    var last_code: consts.Code = self.read() orelse unreachable;
    try self.output.appendSlice(self.code_table.slice()[last_code]);
    while (self.read()) |code| {
        if (code == self.color_table_size) {
            self.resetTable();
            last_code = self.read() orelse unreachable;
            try self.output.appendSlice(self.code_table.slice()[last_code]);
            continue;
        } else if (code == self.color_table_size + 1) {
            self.byte_index += self.block_size; // Reach end of block
            self.block_size = self.input[self.byte_index];
            self.byte_index += 1;
            if (self.block_size != 0) return error.BlockAndStreamEndMismatch;
            break;
        }
        if (code < self.code_table.len) {
            if (self.code_table.len < consts.MAX_CODES) {
                const new_code = try std.mem.concat(self.alloc, consts.Color, &.{
                    self.code_table.slice()[last_code],
                    self.code_table.slice()[code][0..1],
                });
                self.code_table.appendAssumeCapacity(new_code);
            }
            try self.output.appendSlice(self.code_table.slice()[code]);
        } else {
            const new_code = try std.mem.concat(self.alloc, consts.Color, &.{
                self.code_table.slice()[last_code],
                self.code_table.slice()[last_code][0..1],
            });
            try self.output.appendSlice(new_code);
            self.code_table.appendAssumeCapacity(new_code);
        }
        last_code = code;
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
    var output = std.ArrayList(consts.Color).init(std.testing.allocator);
    defer output.deinit();
    var decompressor = Decompressor.init();
    try decompressor.decompress(std.testing.allocator, input, &output);
    try std.testing.expectEqualSlices(consts.Color, &expected, output.items);
    try std.testing.expectEqual(@as(usize, 51), decompressor.byte_index);
}
