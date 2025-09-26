const consts = @import("consts.zig");

disposal: u3,
transparent_color: ?consts.Color,
delay_time: u16,

color_table_size: consts.ColorTableSize,
local_color_table: ?[]const u8,
sorted_color_table: bool,
data: []consts.Color,
