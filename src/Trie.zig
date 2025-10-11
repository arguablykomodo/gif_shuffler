const std = @import("std");
const consts = @import("consts.zig");

// Singly linked list
pub const Child = struct {
    next: ?*Child,
    data: *Node,
};

pub const Node = struct {
    code: consts.Code,
    color: consts.Color,
    children: ?*Child = null,

    pub fn hasChild(self: *const @This(), color: consts.Color) ?*Node {
        var child_node = self.children;
        while (child_node) |c| : (child_node = c.next) {
            if (c.data.color == color) return c.data;
        }
        return null;
    }
};

children: [consts.MAX_CODES]Child = undefined,
children_len: usize = 0,
nodes: [consts.MAX_CODES]Node = undefined,
nodes_len: usize = 0,

pub fn init(size: consts.CodeTableSize) @This() {
    var self = @This(){};
    for (0..size) |i| self.nodes[i] = Node{ .code = @intCast(i), .color = @intCast(i) };
    self.nodes_len = size + 2;
    return self;
}

pub fn reset(self: *@This(), size: consts.ColorTableSize) void {
    self.children_len = 0;
    self.nodes_len = size + 2;
    for (self.nodes[0..size]) |*node| node.children = null;
}

pub fn insert(self: *@This(), node: *Node, color: consts.Color) void {
    self.children[self.children_len] = Child{
        .data = &self.nodes[self.nodes_len],
        .next = node.children,
    };
    node.children = &self.children[self.children_len];
    self.children_len += 1;
    self.nodes[self.nodes_len] = Node{ .code = @intCast(self.nodes_len), .color = color };
    self.nodes_len += 1;
}
