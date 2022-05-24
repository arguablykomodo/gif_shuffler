const std = @import("std");
const consts = @import("./consts.zig");
const setupTable = @import("./code_table.zig").setup;
const CodeTable = @import("./code_table.zig").CodeTable;

const Compressor = @This();

input: []const consts.Color,
color_table_size: consts.ColorTableSize,
code_table: CodeTable,

output: *std.ArrayList(u8),
block_buffer: std.BoundedArray(u8, 255),
byte_buffer: u8,
current_bit: std.math.Log2IntCeil(u8),

pub fn init() Compressor {
    var compressor = Compressor{
        .input = undefined,
        .color_table_size = undefined,
        .code_table = CodeTable.init(0) catch unreachable,
        .output = undefined,
        .block_buffer = std.BoundedArray(u8, 255).init(0) catch unreachable,
        .byte_buffer = undefined,
        .current_bit = undefined,
    };
    return compressor;
}

fn write(self: *Compressor, _code: consts.Code) !void {
    var code = _code;
    var bits = std.math.log2_int_ceil(consts.CodeTableSize, @intCast(consts.CodeTableSize, self.code_table.len));
    while (bits > 0) {
        const to_write = @minimum(bits, 8 - self.current_bit);
        const mask = (@as(consts.Code, 1) << to_write) - 1;
        self.byte_buffer |= @intCast(u8, (code & mask) << self.current_bit);
        code >>= to_write;
        bits -= to_write;
        self.current_bit += to_write;
        if (self.current_bit == 8) {
            if (self.block_buffer.len == 255) {
                try self.output.append(255);
                try self.output.appendSlice(self.block_buffer.slice());
                try self.block_buffer.resize(0);
            }
            try self.block_buffer.append(self.byte_buffer);
            self.byte_buffer = 0;
            self.current_bit = 0;
        }
    }
}

fn resetTable(self: *Compressor) !void {
    try self.write(self.color_table_size);
    try self.code_table.resize(self.color_table_size + 2);
}

pub fn compress(
    self: *Compressor,
    input: []const consts.Color,
    output: *std.ArrayList(u8),
    color_table_size: consts.ColorTableSize,
) !void {
    self.input = input;
    self.color_table_size = color_table_size;
    setupTable(&self.code_table, color_table_size);
    self.output = output;
    self.block_buffer.resize(0) catch unreachable;
    self.byte_buffer = 0;
    self.current_bit = 0;

    const minimum_code_size = std.math.log2_int_ceil(consts.ColorTableSize, self.color_table_size);
    try self.output.append(minimum_code_size);
    try self.write(self.color_table_size);
    var start: usize = 0;
    var code: consts.Code = undefined;
    var code_len: usize = 0;
    while (true) {
        if (self.code_table.len == consts.MAX_CODES) {
            code_len = 0;
            try self.resetTable();
            continue;
        }
        for (self.code_table.slice()) |string, i| {
            if (string.len > code_len and
                std.mem.startsWith(consts.Color, self.input[start..], string))
            {
                code = @intCast(consts.Code, i);
                code_len = string.len;
            }
        }
        try self.write(code);
        if (start + code_len >= self.input.len) break;
        try self.code_table.append(self.input[start .. start + code_len + 1]);
        start += code_len;
        code_len = 0;
    }
    try self.write(self.color_table_size + 1);
    if (self.current_bit != 0) {
        if (self.block_buffer.len == 255) {
            try self.output.append(255);
            try self.output.appendSlice(self.block_buffer.slice());
            try self.block_buffer.resize(0);
        }
        try self.block_buffer.append(self.byte_buffer);
    }
    if (self.block_buffer.len != 0) {
        try self.output.append(@intCast(u8, self.block_buffer.len));
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
