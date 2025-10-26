const std = @import("std");
const Queue = @import("../queue.zig").Queue;
const Interrupt = @import("../transport/mmio.zig").Interrupt;

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

const Config = packed struct {
    cols: u16,
    rows: u16,
    max_nr_ports: u32,
    emerg_wr: u32,
};

pub const Console = struct {
    queues: [2]Queue = [_]Queue{.{ .max_size = 1 }} ** 2,
    active: bool = false,

    stdout: std.fs.File = undefined,
    stdin: std.fs.File = undefined,

    pub fn getQueue(self: *Console, queue: u32) *Queue {
        return &self.queues[@intCast(queue)];
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
            try queue.initialize(guest_memory);
        }
        self.stdout = std.fs.File.stdout();
        self.stdin = std.fs.File.stdin();
    }

    pub fn processQueue(
        self: *Console,
        queue_idx: u32,
        guest_memory: []align(4096) u8,
        interrupt: *Interrupt,
    ) void {
        const queue = &self.queues[queue_idx];

        std.log.debug("avail ring len={}", .{queue.avail_len()});
        var stdoutWriter = self.stdout.writer(&.{});

        while (queue.pop()) |desc| {
            std.log.debug("[{}] got desc {}", .{ queue_idx, desc });
            const buf = guest_memory[desc.addr..][0..desc.len];

            if (queue_idx == TRANSMIT_Q0) {
                stdoutWriter.interface.writeAll(buf) catch |err|
                    std.log.err("Failed to write to stdout: {}", .{err});
                queue.add_used(desc.idx, 0);
            }
        }

        interrupt.trigger(Interrupt.VIRTIO_MMIO_INT_VRING) catch |err|
            std.log.err("Failed to trigger interrupt: {}", .{err});
    }
};
