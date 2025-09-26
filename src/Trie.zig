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
    children: ?*Child,

    pub fn init(code: consts.Code, color: consts.Color) Node {
        return Node{
            .code = code,
            .color = color,
            .children = null,
        };
    }

    pub fn findChild(self: *const @This(), color: consts.Color) ?*Node {
        var child_node = self.children;
        while (child_node) |c| : (child_node = c.next) {
            if (c.data.color == color) return c.data;
        }
        return null;
    }
};

childs_buf: [consts.MAX_CODES]Child,
childs: std.ArrayList(Child),
nodes_buf: [consts.MAX_CODES]Node,
nodes: std.ArrayList(Node),

pub fn init(size: consts.CodeTableSize) @This() {
    var this = @This(){
        .childs_buf = undefined,
        .childs = undefined,
        .nodes_buf = undefined,
        .nodes = undefined,
    };
    this.nodes = std.ArrayList(Node).initBuffer(&this.nodes_buf);
    for (0..size) |i| this.nodes.appendAssumeCapacity(Node.init(@intCast(i), @intCast(i)));
    this.nodes.appendAssumeCapacity(undefined);
    this.nodes.appendAssumeCapacity(undefined);
    this.childs = std.ArrayList(Child).initBuffer(&this.childs_buf);
    return this;
}

pub fn reset(self: *@This(), size: consts.ColorTableSize) void {
    self.childs.shrinkRetainingCapacity(0);
    self.nodes.shrinkRetainingCapacity(size + 2);
    for (self.nodes.items[0..size]) |*node| node.children = null;
}

pub fn insert(self: *@This(), node: *Node, color: consts.Color) void {
    const new_node = self.nodes.addOneAssumeCapacity();
    const new_child = self.childs.addOneAssumeCapacity();
    new_child.data = new_node;
    new_child.next = node.children;
    node.children = new_child;
    new_node.* = Node.init(@intCast(self.nodes.items.len - 1), color);
}
