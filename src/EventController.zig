/// An event controller that can be used to register callbacks to be called when certain events are triggered.
const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const EventFd = @import("EventFd.zig");

const Self = @This();

const Callback = struct {
    context: ?*anyopaque,
    callback: *const fn (?*anyopaque, events: u32, userdata: u32) void,
};

epoll_fd: posix.fd_t,
exit_evt: EventFd,
handlers: std.AutoHashMap(posix.fd_t, Callback),

/// Initializes the event controller.
pub fn init(gpa: std.mem.Allocator) !Self {
    const epoll_fd = try posix.epoll_create1(linux.EPOLL.CLOEXEC);
    errdefer posix.close(epoll_fd);

    var exit_evt = try EventFd.init();
    errdefer exit_evt.close();

    const exit_data = (@as(u64, @intCast(exit_evt.fd)) << 32);
    var event = linux.epoll_event{ .events = linux.EPOLL.IN, .data = .{ .u64 = exit_data } };
    try posix.epoll_ctl(epoll_fd, linux.EPOLL.CTL_ADD, exit_evt.fd, &event);

    return .{
        .epoll_fd = epoll_fd,
        .exit_evt = exit_evt,
        .handlers = std.AutoHashMap(posix.fd_t, Callback).init(gpa),
    };
}

/// Deinitializes the event controller.
pub fn deinit(self: *Self) void {
    posix.close(self.epoll_fd);
    self.exit_evt.close();
    self.handlers.deinit();
}

/// Signals the event controller to stop. This will cause the run() function to return.
pub fn stop(self: *Self) !void {
    try self.exit_evt.write();
}

/// Registers a callback to be called when the specified events are triggered on the specified fd.
pub fn register(
    self: *Self,
    fd: posix.fd_t,
    events: u32,
    context: anytype,
    userdata: u32,
    callback: *const fn (@TypeOf(context), userdata: u32, events: u32) void,
) !void {
    try self.handlers.put(fd, .{ .context = context, .callback = @ptrCast(callback) });
    const data = (@as(u64, @intCast(fd)) << 32) | userdata;
    var event = linux.epoll_event{ .events = events, .data = .{ .u64 = data } };
    try std.posix.epoll_ctl(self.epoll_fd, linux.EPOLL.CTL_ADD, fd, &event);
}

/// Runs the event controller until the stop() function is called.
/// Calls the registered callbacks for each event that is triggered.
pub fn run(self: *Self) !void {
    var events: [1024]linux.epoll_event = undefined;
    while (true) {
        const n = std.posix.epoll_wait(self.epoll_fd, &events, -1);
        if (n == 0) continue;

        for (events[0..n]) |event| {
            const fd: posix.fd_t = @intCast(event.data.u64 >> 32);
            const userdata: u32 = @intCast(event.data.u64 & 0xFFFFFFFF);
            if (fd == self.exit_evt.fd) {
                std.log.info("Exiting EventController", .{});
                return;
            }

            const handler = self.handlers.get(fd) orelse continue;
            handler.callback(handler.context, event.events, userdata);
        }
    }
}

test "EventController" {
    const testing = std.testing;

    var ec = try Self.init(testing.allocator);
    defer ec.deinit();

    const Handler = struct {
        set: bool = false,
        ec: *Self,
        fn handle(self: *@This(), events: u32) void {
            _ = events;
            self.set = true;
            _ = self.ec.stop() catch unreachable;
        }
    };

    var handler = Handler{ .set = false, .ec = &ec };

    var test_evt = try EventFd.init();
    defer test_evt.close();

    try ec.register(test_evt.fd, linux.EPOLL.IN, &handler, Handler.handle);

    try test_evt.write();

    try ec.run();

    try testing.expect(handler.set);
}
