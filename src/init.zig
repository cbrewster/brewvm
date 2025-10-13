const std = @import("std");

pub fn main() !void {
    var msg: [4096]u8 = undefined;
    var idx: usize = 0;

    // Mount devtmpfs
    if (std.os.linux.mount("dev", "/dev", "devtmpfs", 0, 0) == -1) {
        return error.MountFailed;
    }

    // Open /dev/kmsg
    const kmsg = try std.fs.openFileAbsolute("/dev/kmsg", .{ .mode = .write_only });
    defer _ = kmsg.close();

    // Open /dev directory
    var dir = try std.fs.openDirAbsolute("/dev", .{});
    defer dir.close();

    // Write the original message once before overwriting it
    _ = try kmsg.write("Hello from userspace!");

    // Read directory entries and build message, leaving space for the trailing NUL
    const capacity = msg.len;
    var iterator = dir.iterate();
    outer: while (try iterator.next()) |entry| {
        const name = entry.name;
        for (name) |c| {
            if (idx + 1 >= capacity) break :outer;
            msg[idx] = c;
            idx += 1;
        }
        if (idx + 1 >= capacity) break :outer;
        msg[idx] = ' ';
        idx += 1;
    }

    if (idx >= capacity) idx = capacity - 1;

    msg[idx] = 0;
    idx += 1;

    // Write the final message
    _ = try kmsg.write(msg[0..idx]);
}
