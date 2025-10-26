const std = @import("std");

pub fn main() !void {
    // Just sleep forever so the kernel can continue booting and probe devices
    // This allows us to see virtio-mmio driver initialization
    while (true) {
        std.posix.nanosleep(999999999, 0);
    }
}
