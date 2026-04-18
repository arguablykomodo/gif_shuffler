const std = @import("std");
const Frame = @import("Frame.zig");
const Decompressor = @import("Decompressor.zig");
const Parser = @import("Parser.zig");
const Writer = @import("Writer.zig");
const Compressor = @import("Compressor.zig");

const Error = error{
    OutOfMemory,
    ReadFailed,
    WriteFailed,
    EndOfStream,
    Malformed,
};

pub fn shuffle(
    alloc: std.mem.Allocator,
    data: []const u8,
    seed: u64,
    delay_time: ?u16,
    loop_count: ?u16,
    swap_ratio: f32,
    swap_distance: u32,
) Error![]const u8 {
    var parser = Parser.init();

    var header = std.ArrayList(u8).empty;
    defer header.deinit(alloc);
    var frames = std.ArrayList(Frame).empty;
    defer {
        for (frames.items) |frame| alloc.free(frame.data);
        frames.deinit(alloc);
    }

    try parser.parse(alloc, @ptrCast(data), &header, &frames, loop_count);

    const swaps: usize = @intFromFloat(swap_ratio * @as(f32, @floatFromInt(frames.items.len)));
    var rand = std.Random.DefaultPrng.init(seed);
    for (0..swaps) |_| {
        const i = rand.random().uintLessThan(usize, frames.items.len);
        const a = i -| swap_distance + 1;
        const b = @min(i + swap_distance, frames.items.len - 1);
        std.mem.swap(Frame, &frames.items[a], &frames.items[b]);
    }

    var output = std.Io.Writer.Allocating.init(alloc);
    try Writer.write(
        header.items,
        frames.items,
        parser.width,
        parser.height,
        delay_time,
        &output.writer,
    );

    return try output.toOwnedSlice();
}

test "shuffle" {
    const buffer = @embedFile("./test.gif");
    const shuffled = try shuffle(std.testing.allocator, buffer, 0, null, null, 1.0, 50);
    std.testing.allocator.free(shuffled);
}
