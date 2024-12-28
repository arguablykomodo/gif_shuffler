const std = @import("std");
const consts = @import("consts.zig");

codes: std.BoundedArray([]const consts.Color, consts.MAX_CODES),

const ALPHABET = blk: {
    var colors = [_]consts.Color{0} ** consts.MAX_COLORS;
    for (colors[0..consts.MAX_COLORS], 0..) |*color, i| color.* = i;
    break :blk colors;
};

pub fn init(size: consts.CodeTableSize) @This() {
    var codes = std.BoundedArray([]const consts.Color, consts.MAX_CODES){};
    for (0..size) |i| codes.appendAssumeCapacity(ALPHABET[i .. i + 1]);
    codes.appendAssumeCapacity(undefined);
    codes.appendAssumeCapacity(undefined);
    return @This(){ .codes = codes };
}

pub fn reset(self: *@This(), size: consts.ColorTableSize) void {
    self.codes.resize(size + 2) catch unreachable;
}

pub fn get(self: *const @This(), code: consts.Code) []const consts.Color {
    return self.codes.constSlice()[code];
}

pub fn len(self: *const @This()) usize {
    return self.codes.len;
}

pub fn addCode(self: *@This(), string: []const consts.Color) void {
    self.codes.appendAssumeCapacity(string);
}
