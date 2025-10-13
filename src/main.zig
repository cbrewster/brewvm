const std = @import("std");
const brewvm = @import("brewvm");

pub fn main() !void {
    const gpa = std.heap.c_allocator;
    try brewvm.startVm(gpa);
}
