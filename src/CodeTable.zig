const std = @import("std");
const consts = @import("consts.zig");

code_buf: [consts.MAX_CODES][]const consts.Color = undefined,
codes: usize = 0,

const ALPHABET = blk: {
    var colors = [_]consts.Color{0} ** consts.MAX_COLORS;
    for (colors[0..consts.MAX_COLORS], 0..) |*color, i| color.* = i;
    break :blk colors;
};

pub fn init(size: consts.CodeTableSize) @This() {
    var code_table = @This(){};
    for (0..@min(size, consts.MAX_COLORS)) |i| code_table.code_buf[i] = ALPHABET[i .. i + 1];
    code_table.codes = size + 2;
    return code_table;
}

pub fn reset(self: *@This(), size: consts.CodeTableSize) void {
    self.codes = size + 2;
}

pub fn get(self: *const @This(), code: consts.Code) []const consts.Color {
    return self.code_buf[code];
}

pub fn len(self: *const @This()) usize {
    return self.codes;
}

pub fn addCode(self: *@This(), string: []const consts.Color) void {
    self.code_buf[self.codes] = string;
    self.codes += 1;
}
