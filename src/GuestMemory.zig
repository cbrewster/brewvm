const std = @import("std");
const posix = std.posix;

const Self = @This();

len: usize,
bytes: []align(4096) u8,

pub fn init(len: usize) !Self {
    const ptr = try std.posix.mmap(
        null,
        len,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED, .ANONYMOUS = true },
        -1,
        0,
    );

    return .{
        .len = len,
        .bytes = ptr,
    };
}

pub fn deinit(self: *Self) void {
    std.posix.munmap(self.bytes);
}

pub fn slice(self: *const Self, offset: usize, len: usize) []u8 {
    std.debug.assert(offset + len <= self.len);
    return self.bytes[offset..][0..len];
}

pub fn writeAt(self: *const Self, offset: usize, buf: []const u8) void {
    std.debug.assert(offset + buf.len <= self.len);
    @memcpy(self.bytes[offset..][0..buf.len], buf);
}
