const std = @import("std");
const lib = @import("lib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    _ = args.next();
    const path = args.next();
    if (path) |p| {
        const file = try std.fs.openFileAbsolute(p, .{});
        defer file.close();
        const data = try file.readToEndAlloc(alloc, 1024 * 1024 * 100);
        defer alloc.free(data);
        const shuffled = try lib.shuffle(alloc, data, 0, null, null);
        _ = shuffled;
    }
}
