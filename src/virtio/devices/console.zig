const std = @import("std");
const linux = std.os.linux;
const Queue = @import("../queue.zig").Queue;
const Interrupt = @import("../transport/mmio.zig").Interrupt;
const ArrayList = std.ArrayList;

const RECEIVE_Q0: u32 = 0;
const TRANSMIT_Q0: u32 = 1;

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
    queues: [2]Queue,
    active: bool = false,

    stdout: std.fs.File,
    stdin: std.fs.File,

    buffer: ArrayList(u8),

    pub fn init(
        gpa: std.mem.Allocator,
        stdout: std.fs.File,
        stdin: std.fs.File,
    ) !Console {
        var flags = try std.posix.fcntl(stdin.handle, std.posix.F.GETFL, 0);
        @as(*std.posix.O, @ptrCast(&flags)).NONBLOCK = true;
        _ = try std.posix.fcntl(stdin.handle, std.posix.F.SETFL, flags);

        var console = Console{
            .gpa = gpa,
            .queues = undefined,
            .stdout = stdout,
            .stdin = stdin,
            .buffer = try ArrayList(u8).initCapacity(gpa, 4096),
        };
        for (&console.queues) |*queue| {
            queue.* = try Queue.init(256);
        }
        return console;
    }

    pub fn deinit(self: *Console) void {
        self.stdout.close();
        self.stdin.close();
        self.buffer.deinit(self.gpa);
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

    pub fn activate(self: *Console, guest_memory: []align(4096) u8) !void {
        for (&self.queues) |*queue| {
            try queue.activate(guest_memory);
        }
    }

    fn handleReceiveQueue(
        self: *Console,
        guest_memory: []align(4096) u8,
    ) !bool {
        var used_desc = false;
        const queue = &self.queues[RECEIVE_Q0];
        while (self.buffer.items.len > 0) {
            const desc = queue.pop() orelse break;

            var writer = desc.writer();
            writer.write(guest_memory, self.buffer.items);
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
        guest_memory: []align(4096) u8,
    ) !bool {
        var used_desc = false;
        var queue = &self.queues[TRANSMIT_Q0];

        var desc = queue.pop();
        while (desc) |d| {
            const buf = guest_memory[d.addr..][0..d.len];
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

    fn handleStdin(self: *Console, guest_memory: []align(4096) u8) !bool {
        var buffer: [1024]u8 = undefined;
        const count = try self.stdin.read(&buffer);
        try self.buffer.appendSlice(self.gpa, buffer[0..count]);

        return self.handleReceiveQueue(guest_memory);
    }

    pub fn processEvent(
        self: *Console,
        event_id: u64,
        guest_memory: []align(4096) u8,
        interrupt: *Interrupt,
    ) !void {
        var desc_used = false;

        switch (event_id) {
            RECEIVE_Q0 => {
                desc_used = try self.handleReceiveQueue(guest_memory);
            },
            TRANSMIT_Q0 => {
                desc_used = try self.handleTransmitQueue(guest_memory);
            },
            3 => {
                desc_used = try self.handleStdin(guest_memory);
            },
            else => unreachable,
        }

        if (desc_used) {
            interrupt.trigger(Interrupt.VIRTIO_MMIO_INT_VRING) catch |err|
                std.log.err("Failed to trigger interrupt: {}", .{err});
        }
    }

    pub fn registerEpoll(self: *Console, epoll_fd: linux.fd_t) !void {
        for (&self.queues, 0..) |*queue, i| {
            try queue.registerEpoll(epoll_fd, i);
        }
        var event = linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .u64 = 3 },
        };
        try std.posix.epoll_ctl(epoll_fd, linux.EPOLL.CTL_ADD, self.stdin.handle, &event);
    }
};
