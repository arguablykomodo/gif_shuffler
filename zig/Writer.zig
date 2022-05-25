const std = @import("std");
const consts = @import("./consts.zig");
const Decompressor = @import("./Decompressor.zig");
const Compressor = @import("./Compressor.zig");
const Parser = @import("./Parser.zig");
const Frame = @import("./Frame.zig");

const Writer = @This();

compressor: *Compressor,
last_frame: ?*Frame,

pub fn init(compressor: *Compressor) Writer {
    return Writer{
        .compressor = compressor,
        .last_frame = undefined,
    };
}

pub fn write(
    self: *Writer,
    allocator: std.mem.Allocator,
    header: []const u8,
    frames: []Frame,
    width: u16,
    height: u16,
    seed: u64,
    delay_time: ?u16,
    output: *std.ArrayList(u8),
) !void {
    self.last_frame = null;

    var rand = std.rand.DefaultPrng.init(seed).random();
    rand.shuffle(Frame, frames);

    try output.appendSlice(header);

    for (frames) |*frame| {
        var number_buffer: [2]u8 = .{ 0, 0 };
        var packed_byte: u8 = 0b00000000;

        // Graphics Control Extension
        try output.appendSlice(&.{ 0x21, 0xF9, 0x04 });
        packed_byte |= @as(u8, frame.disposal) << 2;
        if (frame.transparent_color != null) packed_byte |= 0b00000001;
        try output.append(packed_byte);
        std.mem.writeInt(u16, &number_buffer, delay_time orelse frame.delay_time, .Little);
        try output.appendSlice(&number_buffer);
        try output.append(frame.transparent_color orelse 0);
        try output.append(0);

        // Image Descriptor
        try output.appendSlice(&.{ 0x2C, 0x00, 0x00, 0x00, 0x00 });
        std.mem.writeInt(u16, &number_buffer, width, .Little);
        try output.appendSlice(&number_buffer);
        std.mem.writeInt(u16, &number_buffer, height, .Little);
        try output.appendSlice(&number_buffer);
        if (frame.local_color_table) |color_table| {
            packed_byte = 0b10000000;
            if (frame.sorted_color_table) packed_byte |= 0b00100000;
            packed_byte |= std.math.log2_int(consts.ColorTableSize, frame.color_table_size) - 1;
            try output.append(packed_byte);
            try output.appendSlice(color_table);
        } else try output.append(0);

        if (frame.disposal == 1) {
            if (frame.transparent_color) |transparent_color| {
                if (self.last_frame) |last_frame| {
                    for (frame.data) |color, i| {
                        if (color == last_frame.data[i]) {
                            frame.data[i] = transparent_color;
                        }
                    }
                }
            }
        }

        // Image data
        try self.compressor.compress(allocator, frame.data, output, frame.color_table_size);

        self.last_frame = frame;
    }
    try output.append(0x3B);
}

test "write" {
    var header = std.ArrayList(u8).init(std.testing.allocator);
    defer header.deinit();
    var frames = std.ArrayList(Frame).init(std.testing.allocator);
    defer {
        for (frames.items) |frame| frames.allocator.free(frame.data);
        frames.deinit();
    }

    var decompressor = Decompressor.init();
    var parser = Parser.init(&decompressor);
    try parser.parse(std.testing.allocator, @embedFile("./test.gif"), &header, &frames, 0);

    var compressor = Compressor.init();
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var writer = Writer.init(&compressor);
    try writer.write(std.testing.allocator, header.items, frames.items, parser.width, parser.height, 0, null, &output);

    var new_header = std.ArrayList(u8).init(std.testing.allocator);
    defer new_header.deinit();
    var new_frames = std.ArrayList(Frame).init(std.testing.allocator);
    defer {
        for (new_frames.items) |frame| new_frames.allocator.free(frame.data);
        new_frames.deinit();
    }
    try parser.parse(std.testing.allocator, @ptrCast([*]const u8, output.items), &new_header, &new_frames, 0);
}
