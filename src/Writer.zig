const std = @import("std");
const Decompressor = @import("Decompressor.zig");
const Compressor = @import("Compressor.zig");
const Parser = @import("Parser.zig");
const Frame = @import("Frame.zig");

pub fn write(
    header: []const u8,
    frames: []Frame,
    width: u16,
    height: u16,
    delay_time: ?u16,
    output: *std.io.Writer,
) !void {
    var last_frame: ?*Frame = null;
    try output.writeAll(header);
    for (frames) |*frame| {
        var number_buffer: [2]u8 = .{ 0, 0 };
        var packed_byte: u8 = 0b00000000;

        // Graphics Control Extension
        try output.writeAll(&.{ 0x21, 0xF9, 0x04 });
        packed_byte |= @as(u8, frame.disposal) << 2;
        if (frame.transparent_color != null) packed_byte |= 0b00000001;
        try output.writeByte(packed_byte);
        std.mem.writeInt(u16, &number_buffer, delay_time orelse frame.delay_time, .little);
        try output.writeAll(&number_buffer);
        try output.writeByte(frame.transparent_color orelse 0);
        try output.writeByte(0);

        // Image Descriptor
        try output.writeAll(&.{ 0x2C, 0x00, 0x00, 0x00, 0x00 });
        std.mem.writeInt(u16, &number_buffer, width, .little);
        try output.writeAll(&number_buffer);
        std.mem.writeInt(u16, &number_buffer, height, .little);
        try output.writeAll(&number_buffer);
        if (frame.local_color_table) |color_table| {
            packed_byte = 0b10000000;
            if (frame.sorted_color_table) packed_byte |= 0b00100000;
            packed_byte |= std.math.log2_int(u9, frame.color_table_size) - 1;
            try output.writeByte(packed_byte);
            try output.writeAll(color_table);
        } else try output.writeByte(0);

        if (frame.disposal == 1) {
            if (frame.transparent_color) |transparent_color| {
                if (last_frame) |last_frame_| {
                    for (frame.data, 0..) |color, i| {
                        if (color == last_frame_.data[i]) {
                            frame.data[i] = transparent_color;
                        }
                    }
                }
            }
        }

        // Image data
        try Compressor.compress(frame.data, output, frame.color_table_size);

        last_frame = frame;
    }
    try output.writeByte(0x3B);
}

test "write" {
    var header = std.ArrayList(u8){};
    defer header.deinit(std.testing.allocator);
    var frames = std.ArrayList(Frame){};
    defer {
        for (frames.items) |frame| std.testing.allocator.free(frame.data);
        frames.deinit(std.testing.allocator);
    }

    var parser = Parser.init();
    try parser.parse(std.testing.allocator, @embedFile("./test.gif"), &header, &frames, 0);

    var output = std.io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try write(header.items, frames.items, parser.width, parser.height, null, &output.writer);

    var new_header = std.ArrayList(u8){};
    defer new_header.deinit(std.testing.allocator);
    var new_frames = std.ArrayList(Frame){};
    defer {
        for (new_frames.items) |frame| std.testing.allocator.free(frame.data);
        new_frames.deinit(std.testing.allocator);
    }
    try parser.parse(std.testing.allocator, @ptrCast(output.written()), &new_header, &new_frames, 0);
}
