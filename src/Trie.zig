const std = @import("std");

pub const MAX_CODES = @import("CodeTable.zig").MAX_CODES;
pub const Code = @import("CodeTable.zig").Code;
pub const Size = @import("CodeTable.zig").Size;

// Singly linked list
pub const Child = struct {
    next: ?*Child,
    data: *Node,
};

pub const Node = struct {
    code: Code,
    color: u8,
    children: ?*Child = null,

    pub fn hasChild(self: *const @This(), color: u8) ?*Node {
        var child_node = self.children;
        while (child_node) |c| : (child_node = c.next) {
            if (c.data.color == color) return c.data;
        }
        return null;
    }
};

children: [MAX_CODES]Child = undefined,
children_len: Size = 0,
nodes: [MAX_CODES]Node = undefined,
nodes_len: Size = 0,

pub fn init(size: Size) @This() {
    var self = @This(){};
    for (0..size) |i| self.nodes[i] = Node{ .code = @intCast(i), .color = @intCast(i) };
    self.nodes_len = size + 2;
    return self;
}

pub fn reset(self: *@This(), size: u9) void {
    self.children_len = 0;
    self.nodes_len = size + 2;
    for (self.nodes[0..size]) |*node| node.children = null;
}

pub fn insert(self: *@This(), node: *Node, color: u8) void {
    self.children[self.children_len] = Child{
        .data = &self.nodes[self.nodes_len],
        .next = node.children,
    };
    node.children = &self.children[self.children_len];
    self.children_len += 1;
    self.nodes[self.nodes_len] = Node{ .code = @intCast(self.nodes_len), .color = color };
    self.nodes_len += 1;
}
