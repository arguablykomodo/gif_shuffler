const std = @import("std");
const consts = @import("consts.zig");

pub const Node = struct {
    code: consts.Code,
    color: consts.Color,
    children: std.SinglyLinkedList(*Node),

    pub fn init(code: consts.Code, color: consts.Color) Node {
        return Node{
            .code = code,
            .color = color,
            .children = std.SinglyLinkedList(*Node){},
        };
    }

    pub fn findChild(self: *const @This(), color: consts.Color) ?*Node {
        var child = self.children.first;
        while (child) |c| : (child = c.next) if (c.data.color == color) return c.data;
        return null;
    }
};

childs: std.BoundedArray(std.SinglyLinkedList(*Node).Node, consts.MAX_CODES),
nodes: std.BoundedArray(Node, consts.MAX_CODES),

pub fn init(size: consts.CodeTableSize) @This() {
    var nodes = std.BoundedArray(Node, consts.MAX_CODES){};
    for (0..size) |i| nodes.appendAssumeCapacity(Node.init(@intCast(i), @intCast(i)));
    nodes.appendAssumeCapacity(undefined);
    nodes.appendAssumeCapacity(undefined);
    return @This(){
        .nodes = nodes,
        .childs = std.BoundedArray(std.SinglyLinkedList(*Node).Node, consts.MAX_CODES){},
    };
}

pub fn reset(self: *@This(), size: consts.ColorTableSize) void {
    self.childs.resize(0) catch unreachable;
    self.nodes.resize(size + 2) catch unreachable;
    for (self.nodes.buffer[0..size]) |*node| node.children = std.SinglyLinkedList(*Node){};
}

pub fn insert(self: *@This(), node: *Node, color: consts.Color) void {
    const new_node = self.nodes.addOneAssumeCapacity();
    const new_child = self.childs.addOneAssumeCapacity();
    new_child.data = new_node;
    node.children.prepend(new_child);
    new_node.* = Node.init(@intCast(self.nodes.len - 1), color);
}
