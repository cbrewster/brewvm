const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const ArrayList = std.ArrayList;

const Device = @import("../device.zig").Device;
const Queue = @import("../queue.zig").Queue;
const Interrupt = @import("../transport/mmio.zig").Interrupt;
const EventController = @import("../../EventController.zig");
const GuestMemory = @import("../../GuestMemory.zig");

const REQUEST_Q1: u32 = 0;

const REQUEST_Q1_EVT: u32 = 0;

const SECTOR_SIZE_BYTES = 512;
const SEG_MAX = 128;

const Features = struct {
    /// Maximum size of any single segment is in size_max.
    const VIRTIO_BLK_F_SIZE_MAX: u64 = 1 << 1;
    /// Maximum number of segments in a request is in seg_max.
    const VIRTIO_BLK_F_SEG_MAX: u64 = 1 << 2;
    /// Disk-style geometry specified in geometry.
    const VIRTIO_BLK_F_GEOMETRY: u64 = 1 << 4;
    /// Device is read-only.
    const VIRTIO_BLK_F_RO: u64 = 1 << 5;
    /// Block size of disk is in blk_size.
    const VIRTIO_BLK_F_BLK_SIZE: u64 = 1 << 6;
    /// Cache flush command support.
    const VIRTIO_BLK_F_FLUSH: u64 = 1 << 9;
    /// Device exports information on optimal I/O alignment.
    const VIRTIO_BLK_F_TOPOLOGY: u64 = 1 << 10;
    /// Device can toggle its cache between writeback and writethrough modes.
    const VIRTIO_BLK_F_CONFIG_WCE: u64 = 1 << 11;
    /// Device supports multiqueue.
    const VIRTIO_BLK_F_MQ: u64 = 1 << 12;
    /// Device can support discard command, maximum discard sectors size in max_discard_sectors and maximum discard segment number in max_discard_seg.
    const VIRTIO_BLK_F_DISCARD: u64 = 1 << 13;
    /// Device can support write zeroes command, maximum write zeroes sectors size in max_write_zeroes_sectors and maximum write zeroes segment number in max_write_zeroes_seg.
    const VIRTIO_BLK_F_WRITE_ZEROES: u64 = 1 << 14;
    /// Device supports providing storage lifetime information.
    const VIRTIO_BLK_F_LIFETIME: u64 = 1 << 15;
    /// Device supports secure erase command, maximum erase sectors count in max_secure_erase_sectors and maximum erase segment number in max_secure_erase_seg.
    const VIRTIO_BLK_F_SECURE_ERASE: u64 = 1 << 16;
    /// Device is a Zoned Block Device, that is, a device that follows the zoned storage device behavior that is also supported by industry standards such as the T10 Zoned Block Command standard (ZBC r05) or the NVMe(TM) NVM Express Zoned Namespace Command Set Specification 1.1b (ZNS). For brevity, these standard documents are referred as "ZBD standards" from this point on in the text
    const VIRTIO_BLK_F_ZONED: u64 = 1 << 17;
};

const Config = packed struct {
    capacity: u64,
    size_max: u32,
    seg_max: u32,
    geometry: packed struct {
        cylinders: u16,
        heads: u8,
        sectors: u8,
    },
    blk_size: u32,
    topology: packed struct {
        /// # of logical blocks per physical block (log2)
        physical_block_exp: u8,
        /// offset of first aligned logical block
        alignment_offset: u8,
        /// suggested minimum I/O size in blocks
        min_io_size: u16,
        /// optimal (suggested maximum) I/O size in blocks
        opt_io_size: u32,
    },
    writeback: u8,
    unused0: u8,
    num_queues: u16,
    max_discard_sectors: u32,
    max_discard_seg: u32,
    discard_sector_alignment: u32,
    max_write_zeroes_sectors: u32,
    max_write_zeroes_seg: u32,
    write_zeroes_may_unmap: u8,
    unused1: u24,
    max_secure_erase_sectors: u32,
    max_secure_erase_seg: u32,
    secure_erase_sector_alignment: u32,
    zoned: packed struct {
        zone_sectors: u32,
        max_open_zones: u32,
        max_active_zones: u32,
        max_append_sectors: u32,
        write_granularity: u32,
        model: u8,
        unused2: u24,
    },
};

pub const Blk = struct {
    gpa: std.mem.Allocator,
    guest_memory: GuestMemory,
    queues: [1]Queue,
    interrupt: Interrupt,
    active: bool = false,

    file: std.fs.File,
    config: Config,

    interface: Device,

    pub fn init(
        self: *Blk,
        gpa: std.mem.Allocator,
        guest_memory: GuestMemory,
        path: []const u8,
    ) !void {
        var interrupt = try Interrupt.init();
        errdefer interrupt.deinit();

        const file = try std.fs.cwd().createFile(path, .{
            .read = true,
            .truncate = false,
        });
        errdefer file.close();

        const stat = try file.stat();

        var config = std.mem.zeroes(Config);
        config.blk_size = 4096;
        config.capacity = stat.size / SECTOR_SIZE_BYTES;
        config.size_max = std.math.maxInt(u32);
        config.seg_max = SEG_MAX;

        self.* = .{
            .gpa = gpa,
            .guest_memory = guest_memory,
            .queues = .{try Queue.init(256)},
            .interrupt = interrupt,
            .file = file,
            .interface = initInterface(),
            .config = config,
        };
    }

    pub fn deinit(self: *Blk) void {
        self.interrupt.deinit();
        self.file.close();
    }

    fn initInterface() Device {
        return .{
            .vtable = &.{
                .getInterrupt = getInterrupt,
                .getQueue = getQueue,
                .getQueues = getQueues,
                .readConfig = readConfig,
                .writeConfig = writeConfig,
                .supportedFeatures = supportedFeatures,
                .isActive = isActive,
                .activate = activate,
                .registerEvents = registerEvents,
            },
        };
    }

    pub fn getInterrupt(d: *Device) *Interrupt {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));
        return &self.interrupt;
    }

    pub fn getQueue(d: *Device, queue: u32) *Queue {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));
        return &self.queues[@intCast(queue)];
    }

    pub fn getQueues(d: *Device) []Queue {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));
        return &self.queues;
    }

    pub fn readConfig(d: *Device, offset: u64, data: []u8) Device.Error!void {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));

        const rawData: []u8 = @ptrCast(&self.config);
        @memcpy(data, rawData[offset..][0..data.len]);
    }

    pub fn writeConfig(d: *Device, offset: u64, data: []const u8) Device.Error!void {
        _ = d;
        _ = offset;
        _ = data;
        return error.InvalidRequest;
    }

    pub fn supportedFeatures(d: *Device) u64 {
        _ = d;
        return Features.VIRTIO_BLK_F_BLK_SIZE |
            Features.VIRTIO_BLK_F_FLUSH |
            Features.VIRTIO_BLK_F_SIZE_MAX |
            Features.VIRTIO_BLK_F_SEG_MAX;
    }

    pub fn isActive(d: *Device) bool {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));
        return self.active;
    }

    pub fn activate(d: *Device, guest_memory: GuestMemory) Device.Error!void {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));
        for (&self.queues) |*queue| {
            try queue.activate(guest_memory);
        }
        try self.interrupt.trigger(Interrupt.VIRTIO_MMIO_INT_CONFIG);
    }

    fn handleRequestQueue(self: *Blk) !bool {
        try self.queues[REQUEST_Q1].eventfd.read();
        var used_desc = false;
        var queue = &self.queues[REQUEST_Q1];

        while (queue.pop()) |d| {
            const buffer = self.guest_memory.slice(d.addr, d.len);
            const req = Request.parse(buffer);

            const offset = req.sector * SECTOR_SIZE_BYTES;

            var writer = d.writer();
            var write_iovec: [1024]posix.iovec = undefined;
            const write_iovec_len = try writer.getIovecs(self.guest_memory, &write_iovec);

            if (write_iovec_len == 0) {
                return error.FailedToGetIovecs;
            }

            var len: u64 = 0;
            for (write_iovec[0..write_iovec_len]) |*iov| {
                len += iov.len;
            }

            // Save the last byte of the iovec to write the status.
            var last_iovec = &write_iovec[write_iovec_len - 1];
            last_iovec.len -= 1;

            var status = RequestStatus.OK;
            if (req.type == RequestType.IN) {
                const written = self.file.preadvAll(
                    write_iovec[0..write_iovec_len],
                    offset,
                ) catch |err| blk: {
                    std.log.err("Failed to read from file: {}", .{err});
                    status = RequestStatus.IOERR;
                    break :blk 0;
                };
                std.debug.assert(written == len - 1);
            } else if (req.type == RequestType.OUT) {
                var reader = d.reader();
                var read_iovec: [1024]posix.iovec_const = undefined;
                const read_iovec_len = try reader.getIovecs(self.guest_memory, &read_iovec);
                if (read_iovec_len == 0) {
                    return error.FailedToGetIovecs;
                }

                std.debug.assert(read_iovec[0].len >= Request.HEADER_LEN);
                read_iovec[0].base += Request.HEADER_LEN;
                read_iovec[0].len -= Request.HEADER_LEN;

                self.file.pwritevAll(
                    read_iovec[0..read_iovec_len],
                    offset,
                ) catch |err| {
                    std.log.err("Failed to write to file: {}", .{err});
                    status = RequestStatus.IOERR;
                };
            } else if (req.type == RequestType.FLUSH) {
                self.file.sync() catch |err| {
                    std.log.err("Failed to sync file: {}", .{err});
                    status = RequestStatus.IOERR;
                };
            } else {
                status = RequestStatus.UNSUPP;
            }

            last_iovec.base[last_iovec.len] = status;
            queue.addUsed(d.idx, @intCast(len));
            used_desc = true;
        }

        return used_desc;
    }

    pub fn processEvent(
        self: *Blk,
        events: u32,
        userdata: u32,
    ) void {
        var desc_used = false;

        if (events != linux.EPOLL.IN) return;

        switch (userdata) {
            REQUEST_Q1_EVT => {
                desc_used = self.handleRequestQueue() catch |err| {
                    std.log.err("Failed to handle receive queue: {}", .{err});
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

    pub fn registerEvents(d: *Device, ec: *EventController) EventController.Error!void {
        const self: *Blk = @alignCast(@fieldParentPtr("interface", d));
        try ec.register(
            self.queues[REQUEST_Q1].eventfd.fd,
            linux.EPOLL.IN,
            self,
            REQUEST_Q1_EVT,
            &processEvent,
        );
    }
};

const RequestType = struct {
    const IN: u32 = 0;
    const OUT: u32 = 1;
    const FLUSH: u32 = 4;
    const GET_ID: u32 = 8;
    const GET_LIFETIME: u32 = 10;
    const DISCARD: u32 = 11;
    const WRITE_ZEROES: u32 = 12;
    const SECURE_ERASE: u32 = 13;
};

const RequestStatus = struct {
    const OK: u8 = 0;
    const IOERR: u8 = 1;
    const UNSUPP: u8 = 2;
};

const Request = struct {
    type: u32,
    reserved: u32,
    sector: u64,

    const HEADER_LEN: u64 = 16;

    pub fn parse(buf: []const u8) Request {
        return .{
            .type = std.mem.readInt(u32, buf[0..4], .little),
            .reserved = std.mem.readInt(u32, buf[4..8], .little),
            .sector = std.mem.readInt(u64, buf[8..16], .little),
        };
    }
};
