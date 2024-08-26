const std = @import("std");
const consts = @import("consts.zig");

const String = struct {
    code: consts.Color,
    parent: ?*const String,

    pub fn init(code: consts.Color) String {
        return String{
            .code = code,
            .parent = null,
        };
    }

    pub fn write(self: String, writer: anytype) !void {
        if (self.parent) |p| try p.write(writer);
        try writer.writeByte(self.code);
    }

    pub fn first(self: String) consts.Color {
        return if (self.parent) |p| return p.first() else return self.code;
    }
};

codes: std.BoundedArray(String, consts.MAX_CODES),

pub fn init(size: consts.CodeTableSize) @This() {
    var codes = std.BoundedArray(String, consts.MAX_CODES){};
    for (0..size) |i| codes.appendAssumeCapacity(String.init(@intCast(i)));
    codes.appendAssumeCapacity(undefined);
    codes.appendAssumeCapacity(undefined);
    return @This(){ .codes = codes };
}

pub fn reset(self: *@This(), size: consts.ColorTableSize) void {
    self.codes.resize(size + 2) catch unreachable;
}

pub fn get(self: *const @This(), code: consts.Code) *const String {
    return &self.codes.constSlice()[code];
}

pub fn len(self: *const @This()) usize {
    return self.codes.len;
}

pub fn addCode(self: *@This(), tail: consts.Code, head: consts.Code) *const String {
    const string = self.codes.addOneAssumeCapacity();
    string.* = String{
        .parent = &self.codes.slice()[tail],
        .code = self.get(head).first(),
    };
    return string;
}
