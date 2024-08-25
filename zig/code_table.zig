const std = @import("std");
const consts = @import("consts.zig");

pub const CodeTable = std.BoundedArray([]const consts.Color, consts.MAX_CODES);

pub const ALPHABET = blk: {
    var colors = [_]consts.Color{0} ** consts.MAX_COLORS;
    for (colors[0..consts.MAX_COLORS], 0..) |*color, i| color.* = i;
    break :blk colors;
};

pub fn setup(self: *CodeTable, color_table_size: consts.ColorTableSize) void {
    self.resize(color_table_size + 2) catch unreachable;
    for (self.slice()[0..color_table_size], 0..) |*code, i| code.* = ALPHABET[i .. i + 1];
    self.slice()[color_table_size] = ALPHABET[0..0];
    self.slice()[color_table_size + 1] = ALPHABET[0..0];
}
