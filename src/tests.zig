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
        fn testOne(_: @This(), smith: *std.testing.Smith) anyerror!void {
            var buf: [4096]u8 = .{0} ** 4096;
            const len = smith.slice(&buf);
            if (len == 0) return;

            var writer = std.Io.Writer.Allocating.init(std.testing.allocator);
            defer writer.deinit();
            Compressor.compress(buf[0..len], &writer.writer, 256) catch {};

            var reader = std.Io.Reader.fixed(writer.written());
            const decompressed = try std.testing.allocator.alloc(u8, len);
            defer std.testing.allocator.free(decompressed);
            Decompressor.decompress(&reader, decompressed) catch {};

            try std.testing.expectEqualSlices(u8, buf[0..len], decompressed);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{ .corpus = &.{@embedFile("./test.gif")[74 .. 74 + 51]} });
}
