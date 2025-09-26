const std = @import("std");
const Frame = @import("Frame.zig");
const Decompressor = @import("Decompressor.zig");
const Parser = @import("Parser.zig");
const Writer = @import("Writer.zig");
const Compressor = @import("Compressor.zig");

const Error = error{
    OutOfMemory,
    NoSpaceLeft,
    WrongHeader,
    UnknownBlock,
    UnknownExtensionBlock,
    MissingColorTable,
    BlockAndStreamEndMismatch,
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
    var decompressor = Decompressor.init();
    var parser = Parser.init(&decompressor);
    var compressor = Compressor.init();

    var header = std.ArrayList(u8).init(alloc);
    defer header.deinit();
    var frames = std.ArrayList(Frame).init(alloc);
    defer {
        for (frames.items) |frame| frames.allocator.free(frame.data);
        frames.deinit();
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

    var output = std.ArrayList(u8).init(alloc);
    try Writer.write(
        &compressor,
        header.items,
        frames.items,
        parser.width,
        parser.height,
        delay_time,
        &output,
    );

    return try output.toOwnedSlice();
}

test "shuffle" {
    const buffer = @embedFile("./test.gif");
    const shuffled = try shuffle(std.testing.allocator, buffer, 0, null, null, 1.0, 50);
    std.testing.allocator.free(shuffled);
}
