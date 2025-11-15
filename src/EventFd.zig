/// A wrapper around an [eventfd](https://man7.org/linux/man-pages/man2/eventfd.2.html).
///
/// The event is always in non-blocking mode and writes only write 1 to the event.
/// Reads always discard the counter of the eventfd.
///
/// This is used for various events in the VM:
/// - Setting IRQ interrupts
/// - Receiving virtioqueue kicks from the guest
/// - Exiting the VM
/// - etc...
const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const Self = @This();

fd: posix.fd_t,

/// Create a new eventfd.
pub fn init() !Self {
    const fd = try posix.eventfd(0, linux.EFD.CLOEXEC | linux.EFD.NONBLOCK);
    return .{ .fd = fd };
}

/// Closes the eventfd.
pub fn close(self: *const Self) void {
    posix.close(self.fd);
}

/// Writes 1 to the eventfd.
pub fn write(self: *const Self) !void {
    _ = posix.write(self.fd, &[8]u8{ 0, 0, 0, 0, 0, 0, 0, 1 }) catch |e| switch (e) {
        error.WouldBlock => {},
        else => |err| return err,
    };
}

/// Reads the eventfd.
pub fn read(self: *const Self) !void {
    var buf: [8]u8 = undefined;
    _ = posix.read(self.fd, &buf) catch |e| switch (e) {
        error.WouldBlock => {},
        else => |err| return err,
    };
}
