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
) Error![]const u8 {
    var decompressor = Decompressor.init();
    var parser = Parser.init(&decompressor);
    var compressor = Compressor.init();
    var writer = Writer.init(&compressor);

    var header = std.ArrayList(u8).init(alloc);
    defer header.deinit();
    var frames = std.ArrayList(Frame).init(alloc);
    defer {
        for (frames.items) |frame| frames.allocator.free(frame.data);
        frames.deinit();
    }

    try parser.parse(alloc, @ptrCast(data), &header, &frames, loop_count);

    var output = std.ArrayList(u8).init(alloc);
    try writer.write(
        header.items,
        frames.items,
        parser.width,
        parser.height,
        seed,
        delay_time,
        &output,
    );

    return try output.toOwnedSlice();
}

test "shuffle" {
    const buffer = @embedFile("./test.gif");
    const shuffled = try shuffle(std.testing.allocator, buffer, 0, null, null);
    std.testing.allocator.free(shuffled);
}
