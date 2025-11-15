const std = @import("std");
const linux = std.os.linux;
const ArrayList = std.ArrayList;

const Queue = @import("../queue.zig").Queue;
const Interrupt = @import("../transport/mmio.zig").Interrupt;
const EventController = @import("../../EventController.zig");
const GuestMemory = @import("../../GuestMemory.zig");

const RECEIVE_Q0: u32 = 0;
const TRANSMIT_Q0: u32 = 1;

const RECEIVE_Q0_EVT: u32 = 0;
const TRANSMIT_Q0_EVT: u32 = 1;
const STDIN_EVT: u32 = 2;

const Features = struct {
    /// Configuration cols and rows are valid.
    const VIRTIO_CONSOLE_F_SIZE: u64 = 1 << 0;
    /// Device has support for multiple ports; max_nr_ports is valid and control virtqueues will be used.
    const VIRTIO_CONSOLE_F_MULTIPORT: u64 = 1 << 1;
    /// Device has support for emergency write. Configuration field emerg_wr is valid.
    const VIRTIO_CONSOLE_F_EMERG_WRITE: u64 = 1 << 2;
};
// struct virtio_console_config {
//         le16 cols;
//         le16 rows;
//         le32 max_nr_ports;
//         le32 emerg_wr;
// };

const Config = extern struct {
    cols: u16,
    rows: u16,
    max_nr_ports: u32,
    emerg_wr: u32,
};

pub const Console = struct {
    gpa: std.mem.Allocator,
    guest_memory: GuestMemory,
    queues: [2]Queue,
    interrupt: Interrupt,
    active: bool = false,

    stdout: std.fs.File,
    stdin: std.fs.File,

    buffer: ArrayList(u8),

    pub fn init(
        gpa: std.mem.Allocator,
        guest_memory: GuestMemory,
        stdout: std.fs.File,
        stdin: std.fs.File,
    ) !Console {
        var flags = try std.posix.fcntl(stdin.handle, std.posix.F.GETFL, 0);
        @as(*std.posix.O, @ptrCast(&flags)).NONBLOCK = true;
        _ = try std.posix.fcntl(stdin.handle, std.posix.F.SETFL, flags);

        var interrupt = try Interrupt.init();
        errdefer interrupt.deinit();

        return .{
            .gpa = gpa,
            .guest_memory = guest_memory,
            .queues = .{
                try Queue.init(256),
                try Queue.init(256),
            },
            .stdout = stdout,
            .stdin = stdin,
            .buffer = try ArrayList(u8).initCapacity(gpa, 4096),
            .interrupt = interrupt,
        };
    }

    pub fn deinit(self: *Console) void {
        self.buffer.deinit(self.gpa);
        self.interrupt.deinit();
    }

    pub fn getQueue(self: *Console, queue: u32) *Queue {
        return &self.queues[@intCast(queue)];
    }

    pub fn getQueues(self: *Console) []Queue {
        return &self.queues;
    }

    pub fn supportedFeatures(self: *Console) u64 {
        _ = self;
        return Features.VIRTIO_CONSOLE_F_EMERG_WRITE;
    }

    pub fn isActive(self: *Console) bool {
        return self.active;
    }

    pub fn activate(self: *Console, guest_memory: GuestMemory) !void {
        for (&self.queues) |*queue| {
            try queue.activate(guest_memory);
        }
    }

    fn handleReceiveQueue(self: *Console) !bool {
        try self.queues[RECEIVE_Q0].eventfd.read();
        var used_desc = false;
        const queue = &self.queues[RECEIVE_Q0];
        while (self.buffer.items.len > 0) {
            const desc = queue.pop() orelse break;

            var writer = desc.writer();
            writer.write(self.guest_memory, self.buffer.items);
            queue.addUsed(desc.idx, writer.bytes_written);
            used_desc = true;

            const new_len = self.buffer.items.len - writer.bytes_written;

            @memmove(self.buffer.items[0..new_len], self.buffer.items[writer.bytes_written..]);
            self.buffer.items.len = new_len;
        }

        return used_desc;
    }

    fn handleTransmitQueue(
        self: *Console,
    ) !bool {
        try self.queues[TRANSMIT_Q0].eventfd.read();

        var used_desc = false;
        var queue = &self.queues[TRANSMIT_Q0];

        var desc = queue.pop();
        while (desc) |d| {
            const buf = self.guest_memory.slice(d.addr, d.len);
            self.stdout.writeAll(buf) catch |err|
                std.log.err("Failed to write to stdout: {}", .{err});
            queue.addUsed(d.idx, 0);
            used_desc = true;

            const next = d.getNext() orelse {
                desc = queue.pop();
                continue;
            };

            if (next.isWriteOnly()) {
                break;
            }
            desc = next;
        }

        return used_desc;
    }

    fn handleStdin(self: *Console) !bool {
        var buffer: [1024]u8 = undefined;
        const count = try self.stdin.read(&buffer);
        try self.buffer.appendSlice(self.gpa, buffer[0..count]);

        return self.handleReceiveQueue();
    }

    pub fn processEvent(
        self: *Console,
        events: u32,
        userdata: u32,
    ) void {
        var desc_used = false;

        if (events != linux.EPOLL.IN) return;

        switch (userdata) {
            RECEIVE_Q0_EVT => {
                desc_used = self.handleReceiveQueue() catch |err| {
                    std.log.err("Failed to handle receive queue: {}", .{err});
                    std.debug.panic("receiv q error", .{});
                    return;
                };
            },
            TRANSMIT_Q0_EVT => {
                desc_used = self.handleTransmitQueue() catch |err| {
                    std.log.err("Failed to handle transmit queue: {}", .{err});
                    std.debug.panic("tx q error", .{});
                    return;
                };
            },
            STDIN_EVT => {
                desc_used = self.handleStdin() catch |err| {
                    std.log.err("Failed to handle stdin: {}", .{err});
                    std.debug.panic("stdin q error", .{});
                    return;
                };
            },
            else => unreachable,
        }

        if (desc_used) {
            self.interrupt.trigger(Interrupt.VIRTIO_MMIO_INT_VRING) catch |err|
                std.log.err("Failed to trigger interrupt: {}", .{err});
        }
    }

    pub fn registerEvents(self: *Console, ec: *EventController) !void {
        try ec.register(
            self.queues[RECEIVE_Q0].eventfd.fd,
            linux.EPOLL.IN,
            self,
            RECEIVE_Q0_EVT,
            &Console.processEvent,
        );
        try ec.register(
            self.queues[TRANSMIT_Q0].eventfd.fd,
            linux.EPOLL.IN,
            self,
            TRANSMIT_Q0_EVT,
            &Console.processEvent,
        );
        try ec.register(
            self.stdin.handle,
            linux.EPOLL.IN,
            self,
            STDIN_EVT,
            &Console.processEvent,
        );
    }
};
