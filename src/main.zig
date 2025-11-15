const std = @import("std");
const brewvm = @import("brewvm");

pub const std_options = std.Options{
    .log_level = .debug,
};

pub fn main() !void {
    const gpa = std.heap.c_allocator;
    try brewvm.startVm(gpa);
}
