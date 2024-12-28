const std = @import("std");
const lib = @import("lib.zig");

const allocator = std.heap.wasm_allocator;

extern fn ret(ptr: usize, len: usize) void;

export fn alloc(n: usize) usize {
    const buf = allocator.alloc(u8, n) catch return 0;
    return @intFromPtr(buf.ptr);
}

export fn free(ptr: [*]const u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

export fn main(
    ptr: usize,
    len: usize,
    seed: u64,
    override_delay: bool,
    delay_time: u16,
    override_loop: bool,
    loop_count: u16,
    swap_ratio: f32,
    swap_distance: u32,
) usize {
    if (lib.shuffle(
        allocator,
        @as([*]const u8, @ptrFromInt(ptr))[0..len],
        seed,
        if (override_delay) delay_time else null,
        if (override_loop) loop_count else null,
        swap_ratio,
        swap_distance,
    )) |data| {
        ret(@intFromPtr(data.ptr), data.len);
        return 0;
    } else |err| {
        return @intFromPtr(@errorName(err).ptr);
    }
}
