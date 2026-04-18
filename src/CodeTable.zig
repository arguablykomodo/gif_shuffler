const std = @import("std");

pub const MAX_CODES = 4096;
pub const Code = u12;
pub const Size = u13;

code_buf: [MAX_CODES][]const u8 = undefined,
codes: Size = 0,

const ALPHABET = blk: {
    var colors = [_]u8{0} ** 256;
    for (colors[0..256], 0..) |*color, i| color.* = i;
    break :blk colors;
};

pub fn init(size: Size) @This() {
    var code_table = @This(){};
    for (0..@min(size, 256)) |i| code_table.code_buf[i] = ALPHABET[i .. i + 1];
    code_table.codes = size + 2;
    return code_table;
}

pub fn reset(self: *@This(), size: Size) void {
    self.codes = size + 2;
}

pub fn get(self: *const @This(), code: Code) []const u8 {
    return self.code_buf[code];
}

pub fn len(self: *const @This()) Size {
    return self.codes;
}

pub fn addCode(self: *@This(), string: []const u8) void {
    self.code_buf[self.codes] = string;
    self.codes += 1;
}
