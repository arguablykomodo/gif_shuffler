comptime {
    _ = @import("lib.zig");
    _ = @import("Parser.zig");
    _ = @import("Writer.zig");
    _ = @import("Compressor.zig");
    _ = @import("Decompressor.zig");
}

test "lzw fuzz" {
    const std = @import("std");
    const Compressor = @import("Compressor.zig");
    const Decompressor = @import("Decompressor.zig");

    const Context = struct {
        fn testOne(_: @This(), input: []const u8) anyerror!void {
            if (input.len == 0) return;

            var writer = std.io.Writer.Allocating.init(std.testing.allocator);
            defer writer.deinit();
            Compressor.compress(input, &writer.writer, 256) catch {};

            var reader = std.io.Reader.fixed(writer.written());
            const decompressed = try std.testing.allocator.alloc(u8, input.len);
            defer std.testing.allocator.free(decompressed);
            Decompressor.decompress(&reader, decompressed) catch {};

            try std.testing.expectEqualSlices(u8, input, decompressed);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{ .corpus = &.{@embedFile("./test.gif")[74 .. 74 + 51]} });
}
