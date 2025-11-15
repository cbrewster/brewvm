const std = @import("std");
const linux = std.os.linux;
const c = @import("c.zig").c;

const Vmm = @import("Vmm.zig");

pub fn startVm(gpa: std.mem.Allocator) !void {
    var vmm = try Vmm.init(gpa);
    defer vmm.deinit();

    try vmm.addVirtioConsole();

    try vmm.loadKernel(
        "console=hvc0 earlyprintk=serial loglevel=8 rdinit=/init",
        "result/bzImage",
        "initramfs",
    );

    var sigmask = std.posix.sigemptyset();
    std.posix.sigaddset(&sigmask, std.posix.SIG.INT);
    std.posix.sigaddset(&sigmask, std.posix.SIG.TERM);
    std.posix.sigprocmask(linux.SIG.BLOCK, &sigmask, null);

    const signalfd = try std.posix.signalfd(-1, &sigmask, linux.SFD.CLOEXEC | linux.SFD.NONBLOCK);
    defer std.posix.close(signalfd);

    var context = SignalContext{
        .vmm = &vmm,
        .signalfd = signalfd,
    };
    try vmm.event_controller.register(
        signalfd,
        linux.EPOLL.IN,
        &context,
        0,
        struct {
            fn handler(ctx: *SignalContext, events: u32, userdata: u32) void {
                _ = events;
                _ = userdata;
                std.log.info("Stopping VMM", .{});
                var info: linux.signalfd_siginfo = undefined;
                _ = std.posix.read(ctx.signalfd, @ptrCast(&info)) catch |e| std.log.err("Failed to read signalfd: {}", .{e});
                ctx.vmm.stop() catch |e| std.log.err("Failed to stop vmm: {}", .{e});
            }
        }.handler,
    );

    try vmm.run();

    std.log.info("VMM Exited", .{});
}

const SignalContext = struct {
    vmm: *Vmm,
    signalfd: std.os.linux.fd_t,
};
