const std = @import("std");
const consts = @import("consts.zig");

var code_buf: [consts.MAX_CODES][]const consts.Color = undefined;

codes: std.ArrayList([]const consts.Color),

const ALPHABET = blk: {
    var colors = [_]consts.Color{0} ** consts.MAX_COLORS;
    for (colors[0..consts.MAX_COLORS], 0..) |*color, i| color.* = i;
    break :blk colors;
};

pub fn init(size: consts.CodeTableSize) @This() {
    var codes = std.ArrayList([]const consts.Color).initBuffer(&code_buf);
    for (0..size) |i| codes.appendAssumeCapacity(ALPHABET[i .. i + 1]);
    codes.appendAssumeCapacity(undefined);
    codes.appendAssumeCapacity(undefined);
    return @This(){ .codes = codes };
}

pub fn reset(self: *@This(), size: consts.ColorTableSize) void {
    self.codes.shrinkRetainingCapacity(size + 2);
}

pub fn get(self: *const @This(), code: consts.Code) []const consts.Color {
    return self.codes.items[code];
}

pub fn len(self: *const @This()) usize {
    return self.codes.items.len;
}

pub fn addCode(self: *@This(), string: []const consts.Color) void {
    self.codes.appendAssumeCapacity(string);
}
