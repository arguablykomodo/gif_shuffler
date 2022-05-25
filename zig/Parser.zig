const std = @import("std");
const consts = @import("./consts.zig");
const Decompressor = @import("./Decompressor.zig");
const Frame = @import("./Frame.zig");

const Parser = @This();

input: [*]const u8,
index: usize,

alloc: std.mem.Allocator,

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
        const packed_size = @intCast(u4, byte & 0b00000111);
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
                    self.disposal = @intCast(u3, (packed_byte & 0b00011100) >> 2);
                    const transparent = (packed_byte & 1) == 1;
                    self.delay_time = std.mem.readIntSlice(u16, self.read(2), .Little);
                    const transparent_color = self.read(1)[0];
                    self.transparent_color = if (transparent) transparent_color else null;
                    self.index += 1;
                },
                // Comment Extension, Application Extension
                0xFE, 0xFF => {
                    self.skipSubBlocks();
                    try self.header.appendSlice(self.input[start..self.index]);
                },
                else => return error.UnknownExtensionBlock,
            }
            return true;
        },
        // Image Descriptor
        0x2C => {
            const left = std.mem.readIntSlice(u16, self.read(2), .Little);
            const top = std.mem.readIntSlice(u16, self.read(2), .Little);
            const width = std.mem.readIntSlice(u16, self.read(2), .Little);
            const height = std.mem.readIntSlice(u16, self.read(2), .Little);
            const packed_byte = self.read(1)[0];
            const color_table_size = Parser.colorTableSize(packed_byte);
            const sorted_color_table = (packed_byte & 0b00100000) == 0b00100000;
            const local_color_table = if (color_table_size) |size| self.read(@as(usize, size) * 3) else null;

            var frame = Frame{
                .disposal = self.disposal,
                .transparent_color = self.transparent_color,
                .delay_time = self.delay_time,
                .color_table_size = color_table_size orelse self.color_table_size orelse return error.MissingColorTable,
                .local_color_table = local_color_table,
                .sorted_color_table = sorted_color_table,
                .data = try self.alloc.dupe(consts.Color, self.screen_buffer),
            };

            var new_data = try std.ArrayList(consts.Color).initCapacity(self.alloc, @as(u32, width) * height);
            defer new_data.deinit();
            try self.decompressor.decompress(self.alloc, self.input[self.index..self.index].ptr, &new_data);
            self.index += self.decompressor.byte_index;

            var y: u16 = 0;
            while (y < height) : (y += 1) {
                var x: u16 = 0;
                while (x < width) : (x += 1) {
                    const new_color = new_data.items[@as(u32, y) * width + x];
                    const index = @as(u32, top) * self.width + left + @as(u32, y) * self.width + x;
                    if (self.disposal == 2) self.screen_buffer[index] = self.background_color;
                    if (self.transparent_color != null and self.transparent_color.? == new_color) continue;
                    frame.data[index] = new_color;
                }
            }
            if (self.disposal == 1) std.mem.copy(consts.Color, self.screen_buffer, frame.data);

            try self.frames.append(frame);
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
) !void {
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

    self.width = std.mem.readIntSlice(u16, self.read(2), .Little);
    self.height = std.mem.readIntSlice(u16, self.read(2), .Little);
    self.screen_buffer = try self.alloc.alloc(consts.Color, @as(u32, self.width) * self.height);
    defer self.alloc.free(self.screen_buffer);
    const packed_byte = self.read(1)[0];
    self.color_table_size = Parser.colorTableSize(packed_byte);
    self.background_color = self.read(1)[0];
    std.mem.set(consts.Color, self.screen_buffer, self.background_color);
    self.index += 1; // Pixel aspect ratio
    self.index += @as(usize, self.color_table_size orelse 0) * 3;
    try self.header.appendSlice(self.input[0..self.index]);

    while (try self.nextSection()) {}
}

test "parse" {
    var header = std.ArrayList(u8).init(std.testing.allocator);
    defer header.deinit();
    var frames = std.ArrayList(Frame).init(std.testing.allocator);
    defer {
        for (frames.items) |frame| {
            std.testing.allocator.free(frame.data);
        }
        frames.deinit();
    }
    var decompressor = Decompressor.init();
    var parser = Parser.init(&decompressor);
    try parser.parse(std.testing.allocator, @embedFile("./test.gif"), &header, &frames);
    try std.testing.expectEqual(@as(usize, 3), parser.frames.items.len);
}
