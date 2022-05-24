const std = @import("std");
const consts = @import("./consts.zig");
const ALPHABET = @import("./code_table.zig").ALPHABET;

const Compressor = @This();

input: []const consts.Color,
color_table_size: consts.ColorTableSize,
code_table: std.StringHashMap(consts.Code),

output: *std.ArrayList(u8),
block_buffer: std.BoundedArray(u8, 255),
byte_buffer: u8,
current_bit: std.math.Log2IntCeil(u8),

pub fn init() Compressor {
    var compressor = Compressor{
        .input = undefined,
        .color_table_size = undefined,
        .code_table = undefined,
        .output = undefined,
        .block_buffer = std.BoundedArray(u8, 255).init(0) catch unreachable,
        .byte_buffer = undefined,
        .current_bit = undefined,
    };
    return compressor;
}

fn write(self: *Compressor, _code: consts.Code) !void {
    var code = _code;
    var bits = std.math.log2_int_ceil(
        consts.CodeTableSize,
        @intCast(consts.CodeTableSize, self.code_table.count() + 1), // 1 instead of 2 due to getOrPut
    );
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
    self.code_table.clearAndFree();
    var i: consts.Code = 0;
    while (i <= self.color_table_size - 1) : (i += 1) {
        try self.code_table.put(ALPHABET[i .. i + 1], i);
    }
}

pub fn compress(
    self: *Compressor,
    alloc: std.mem.Allocator,
    input: []const consts.Color,
    output: *std.ArrayList(u8),
    color_table_size: consts.ColorTableSize,
) !void {
    self.input = input;
    self.color_table_size = color_table_size;
    self.code_table = std.StringHashMap(consts.Code).init(alloc);
    self.output = output;
    self.block_buffer.resize(0) catch unreachable;
    self.byte_buffer = 0;
    self.current_bit = 0;

    const minimum_code_size = std.math.log2_int_ceil(consts.ColorTableSize, self.color_table_size);
    try self.output.append(minimum_code_size);
    try self.resetTable();
    try self.write(self.color_table_size);
    var index: usize = 0;
    var code_len: usize = 0;
    var code: consts.Code = undefined;
    while (index + code_len < self.input.len) {
        const result = try self.code_table.getOrPut(self.input[index .. index + code_len + 1]);
        if (result.found_existing) {
            code_len += 1;
            code = result.value_ptr.*;
        } else {
            try self.write(code);
            result.value_ptr.* = @intCast(consts.Code, self.code_table.count() + 1); // 1 instead of 2 due to getOrPut
            index += code_len;
            code_len = 0;
            if (self.code_table.count() + 2 == consts.MAX_CODES) {
                try self.write(self.color_table_size);
                try self.resetTable();
            }
        }
    }
    try self.write(code);
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
    self.code_table.deinit();
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
    try compressor.compress(std.testing.allocator, &input, &output, 8);
    try std.testing.expectEqualSlices(u8, expected, output.items);
}
