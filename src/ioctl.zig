const std = @import("std");
const linux = std.os.linux;

pub const IoctlError = error{
    InvalidArgument,
    BadFileDescriptor,
    Unexpected,
};

pub fn Ioctl(comptime req: u32) fn (fd: linux.fd_t) IoctlError!usize {
    return struct {
        fn ioctl(fd: linux.fd_t) IoctlError!usize {
            const ret: usize = linux.ioctl(fd, req, 0);
            return try handleErrno(ret);
        }
    }.ioctl;
}

pub fn IoctlR(comptime req: u32, comptime ArgType: type) fn (fd: linux.fd_t, out: *ArgType) IoctlError!usize {
    return struct {
        fn ioctl(fd: linux.fd_t, out: *ArgType) IoctlError!usize {
            const ret: usize = linux.ioctl(fd, req, @intFromPtr(out));
            return try handleErrno(ret);
        }
    }.ioctl;
}

pub fn IoctlW(comptime req: u32, comptime ArgType: type) fn (fd: linux.fd_t, in: ArgType) IoctlError!usize {
    return struct {
        fn ioctl(fd: linux.fd_t, in: ArgType) IoctlError!usize {
            const arg = switch (@typeInfo(ArgType)) {
                inline .pointer => @intFromPtr(in),
                inline .int => @as(usize, @intCast(in)),
                else => @compileError("ArgType must be a pointer or int type"),
            };

            const ret: usize = linux.ioctl(fd, req, arg);
            return try handleErrno(ret);
        }
    }.ioctl;
}

fn handleErrno(ret: usize) IoctlError!usize {
    const signed_ret: isize = @bitCast(ret);
    if (signed_ret >= 0) return ret;
    return switch (@as(std.posix.E, @enumFromInt(-signed_ret))) {
        .INVAL => error.InvalidArgument,
        .BADFD => error.BadFileDescriptor,
        else => |err| {
            return std.posix.unexpectedErrno(err);
        },
    };
}
