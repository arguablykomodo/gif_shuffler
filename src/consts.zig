const std = @import("std");

pub const MAX_COLORS = 256;
pub const Color = std.math.IntFittingRange(0, MAX_COLORS - 1);
pub const ColorTableSize = std.math.IntFittingRange(0, MAX_COLORS);

pub const MAX_CODES = 4096;
pub const Code = std.math.IntFittingRange(0, MAX_CODES - 1);
pub const CodeTableSize = std.math.IntFittingRange(0, MAX_CODES);
