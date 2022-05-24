const std = @import("std");
const Frame = @import("./Frame.zig");
const Decompressor = @import("./Decompressor.zig");
const Parser = @import("./Parser.zig");
const Writer = @import("./Writer.zig");
const Compressor = @import("./Compressor.zig");

const allocator = if (@import("builtin").is_test) std.testing.allocator else std.heap.page_allocator;

extern fn ret(ptr: usize, len: usize) void;

export fn alloc(n: usize) usize {
    const buf = allocator.alloc(u8, n) catch return 0;
    return @ptrToInt(buf.ptr);
}

export fn free(ptr: [*]const u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

var decompressor = Decompressor.init();
var parser = Parser.init(&decompressor);
var compressor = Compressor.init();
var writer = Writer.init(&compressor);

export fn shuffle(ptr: usize, len: usize, seed: u64, override_delay: bool, delay_time: u16) void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var header = std.ArrayList(u8).init(arena.allocator());
    defer header.deinit();
    var frames = std.ArrayList(Frame).init(arena.allocator());
    defer {
        for (frames.items) |frame| frames.allocator.free(frame.data);
        frames.deinit();
    }

    parser.parse(
        arena.allocator(),
        @intToPtr([*]const u8, ptr),
        &header,
        &frames,
    ) catch @panic("parse error");

    var output = std.ArrayList(u8).init(allocator);
    writer.write(
        arena.allocator(),
        header.items,
        frames.items,
        parser.width,
        parser.height,
        seed,
        if (override_delay) delay_time else null,
        &output,
    ) catch @panic("write error");

    free(@intToPtr([*]const u8, ptr), len);

    if (@import("builtin").is_test) {
        free(output.items.ptr, output.items.len);
    } else {
        ret(@ptrToInt(output.items.ptr), output.items.len);
    }
}

test "shuffle" {
    const buffer = @embedFile("./test.gif");
    const ptr = alloc(buffer.len);
    std.mem.copy(u8, @intToPtr([*]u8, ptr)[0..buffer.len], buffer);
    shuffle(ptr, buffer.len, 0, false, 0);
}
