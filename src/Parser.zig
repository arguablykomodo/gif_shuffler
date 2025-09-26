const std = @import("std");
const consts = @import("consts.zig");
const Decompressor = @import("Decompressor.zig");
const Frame = @import("Frame.zig");

const Parser = @This();

input: [*]const u8,
index: usize,

alloc: std.mem.Allocator,

loop_count: ?u16,

// Data in Logical Screen Descriptor
width: u16,
height: u16,
color_table_size: ?consts.ColorTableSize,
background_color: consts.Color,

// Data in Graphics Control Extension
disposal: u3,
transparent_color: ?consts.Color,
delay_time: u16,

header: *std.ArrayList(u8),
frames: *std.ArrayList(Frame),
last_frame: ?*Frame,
screen_buffer: []consts.Color,

decompressor: *Decompressor,

pub fn init(decompressor: *Decompressor) Parser {
    return Parser{
        .loop_count = undefined,
        .input = undefined,
        .index = undefined,
        .alloc = undefined,
        .width = undefined,
        .height = undefined,
        .color_table_size = undefined,
        .background_color = undefined,
        .disposal = undefined,
        .transparent_color = undefined,
        .delay_time = undefined,
        .header = undefined,
        .frames = undefined,
        .last_frame = undefined,
        .screen_buffer = undefined,
        .decompressor = decompressor,
    };
}

fn colorTableSize(byte: u8) ?consts.ColorTableSize {
    const has_table = byte & 0b10000000;
    if (has_table >> 7 == 1) {
        const packed_size: u4 = @intCast(byte & 0b00000111);
        return (@as(consts.ColorTableSize, 1) << (packed_size + 1));
    } else return null;
}

fn read(self: *Parser, n: usize) []const u8 {
    const slice = self.input[self.index .. self.index + n];
    self.index += n;
    return slice;
}

fn skipSubBlocks(self: *Parser) void {
    while (true) {
        const length = self.read(1)[0];
        if (length == 0) break else self.index += length;
    }
}

fn nextSection(self: *Parser) !bool {
    const start = self.index;
    const marker = self.read(1)[0];
    switch (marker) {
        0x21 => {
            const extension = self.read(1)[0];
            switch (extension) {
                // Graphics Control Extension
                0xF9 => {
                    self.index += 1;
                    const packed_byte = self.read(1)[0];
                    self.disposal = @intCast((packed_byte & 0b00011100) >> 2);
                    const transparent = (packed_byte & 1) == 1;
                    self.delay_time = std.mem.readInt(u16, self.read(2)[0..2], .little);
                    const transparent_color = self.read(1)[0];
                    self.transparent_color = if (transparent) transparent_color else null;
                    self.index += 1;
                },
                // Comment Extension
                0xFE => {
                    self.skipSubBlocks();
                    try self.header.appendSlice(self.alloc, self.input[start..self.index]);
                },
                // Application Extension
                0xFF => {
                    const name = self.read(self.read(1)[0]);
                    self.skipSubBlocks();
                    if (self.loop_count) |loop_count| {
                        if (std.mem.eql(u8, name, "NETSCAPE2.0")) {
                            try self.header.append(self.alloc, marker);
                            try self.header.append(self.alloc, extension);
                            try self.header.append(self.alloc, 11);
                            try self.header.appendSlice(self.alloc, "NETSCAPE2.0");
                            try self.header.append(self.alloc, 3);
                            try self.header.append(self.alloc, 1);
                            var number_buffer: [2]u8 = .{ 0, 0 };
                            std.mem.writeInt(u16, &number_buffer, loop_count, .little);
                            try self.header.appendSlice(self.alloc, &number_buffer);
                            try self.header.append(self.alloc, 0);
                        } else try self.header.appendSlice(self.alloc, self.input[start..self.index]);
                    } else try self.header.appendSlice(self.alloc, self.input[start..self.index]);
                },
                else => return error.UnknownExtensionBlock,
            }
            return true;
        },
        // Image Descriptor
        0x2C => {
            const left = std.mem.readInt(u16, self.read(2)[0..2], .little);
            const top = std.mem.readInt(u16, self.read(2)[0..2], .little);
            const width = std.mem.readInt(u16, self.read(2)[0..2], .little);
            const height = std.mem.readInt(u16, self.read(2)[0..2], .little);
            const packed_byte = self.read(1)[0];
            const color_table_size = Parser.colorTableSize(packed_byte);
            const sorted_color_table = (packed_byte & 0b00100000) == 0b00100000;
            const local_color_table = if (color_table_size) |size| self.read(@as(usize, size) * 3) else null;

            if (self.transparent_color) |transparent_color| {
                if (self.last_frame) |last_frame| {
                    if (last_frame.transparent_color) |old_transparent_color| {
                        for (self.screen_buffer, 0..) |color, i| {
                            if (color == old_transparent_color) {
                                self.screen_buffer[i] = transparent_color;
                            }
                        }
                    }
                } else {
                    @memset(self.screen_buffer, transparent_color);
                }
            }

            var frame = Frame{
                .disposal = self.disposal,
                .transparent_color = self.transparent_color,
                .delay_time = self.delay_time,
                .color_table_size = color_table_size orelse self.color_table_size orelse return error.MissingColorTable,
                .local_color_table = local_color_table,
                .sorted_color_table = sorted_color_table,
                .data = try self.alloc.dupe(consts.Color, self.screen_buffer),
            };

            const new_data = try self.alloc.alloc(consts.Color, @as(u32, width) * height);
            defer self.alloc.free(new_data);
            try self.decompressor.decompress(self.input[self.index..self.index].ptr, new_data);
            self.index += self.decompressor.byte_index;

            var y: u16 = 0;
            while (y < height) : (y += 1) {
                var x: u16 = 0;
                while (x < width) : (x += 1) {
                    const new_color = new_data[@as(u32, y) * width + x];
                    const index = @as(u32, top) * self.width + left + @as(u32, y) * self.width + x;
                    if (frame.disposal == 2) self.screen_buffer[index] = frame.transparent_color orelse self.background_color;
                    if (frame.transparent_color) |transparent_color| if (new_color == transparent_color) continue;
                    frame.data[index] = new_color;
                }
            }
            if (self.disposal == 1) @memcpy(self.screen_buffer, frame.data);

            try self.frames.append(self.alloc, frame);
            self.last_frame = &self.frames.items[self.frames.items.len - 1];
            return true;
        },
        0x3B => return false,
        else => return error.UnknownBlock,
    }
}

pub fn parse(
    self: *Parser,
    alloc: std.mem.Allocator,
    input: [*]const u8,
    header: *std.ArrayList(u8),
    frames: *std.ArrayList(Frame),
    loop_count: ?u16,
) !void {
    self.loop_count = loop_count;
    self.input = input;
    self.index = 0;
    self.alloc = alloc;
    self.disposal = 0;
    self.transparent_color = null;
    self.delay_time = 0;
    self.header = header;
    self.frames = frames;
    self.last_frame = null;

    const magic = self.read(6);
    if (!std.mem.eql(u8, magic[0..4], "GIF8") or
        !(magic[4] == '7' or magic[4] == '9') or
        magic[5] != 'a') return error.WrongHeader;

    self.width = std.mem.readInt(u16, self.read(2)[0..2], .little);
    self.height = std.mem.readInt(u16, self.read(2)[0..2], .little);
    self.screen_buffer = try self.alloc.alloc(consts.Color, @as(u32, self.width) * self.height);
    defer self.alloc.free(self.screen_buffer);
    const packed_byte = self.read(1)[0];
    self.color_table_size = Parser.colorTableSize(packed_byte);
    self.background_color = self.read(1)[0];
    @memset(self.screen_buffer, self.background_color);
    self.index += 1; // Pixel aspect ratio
    self.index += @as(usize, self.color_table_size orelse 0) * 3;
    try self.header.appendSlice(self.alloc, self.input[0..self.index]);

    while (try self.nextSection()) {}
}

test "parse" {
    var header = std.ArrayList(u8){};
    defer header.deinit(std.testing.allocator);
    var frames = std.ArrayList(Frame){};
    defer {
        for (frames.items) |frame| {
            std.testing.allocator.free(frame.data);
        }
        frames.deinit(std.testing.allocator);
    }
    var decompressor = Decompressor.init();
    var parser = Parser.init(&decompressor);
    try parser.parse(std.testing.allocator, @embedFile("./test.gif"), &header, &frames, 0);
    try std.testing.expectEqual(@as(usize, 3), parser.frames.items.len);
}
