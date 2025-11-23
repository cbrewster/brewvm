const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const ArrayList = std.ArrayList;

const Device = @import("../device.zig").Device;
const Queue = @import("../queue.zig").Queue;
const Interrupt = @import("../transport/mmio.zig").Interrupt;
const EventController = @import("../../EventController.zig");
const GuestMemory = @import("../../GuestMemory.zig");
const EventFd = @import("../../EventFd.zig");

const REQUEST_Q1: u32 = 0;

const REQUEST_Q1_EVT: u32 = 0;
const RING_EVT: u32 = 1;

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

    file: posix.fd_t,
    ring: linux.IoUring,
    ring_evt: EventFd,
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

        var ring = try linux.IoUring.init(1024, 0);
        errdefer ring.deinit();

        var ring_evt = try EventFd.init();
        errdefer ring_evt.close();

        try ring.register_eventfd(ring_evt.fd);

        // We expect the kernel to support stable submission.
        if (ring.features & linux.IORING_FEAT_SUBMIT_STABLE == 0) {
            return error.RequiresStableSubmission;
        }

        const file = try posix.open(
            path,
            .{
                .CLOEXEC = true,
                .NONBLOCK = true,
                .CREAT = true,
                .ACCMODE = .RDWR,
                .DIRECT = true,
            },
            0o755,
        );
        errdefer posix.close(file);

        const stat = try posix.fstat(file);
        if (@rem(stat.size, SECTOR_SIZE_BYTES) != 0) {
            return error.InvalidFileSize;
        }

        var config = std.mem.zeroes(Config);
        config.blk_size = 4096;
        config.capacity = @divExact(@as(u64, @intCast(stat.size)), SECTOR_SIZE_BYTES);
        config.size_max = std.math.maxInt(u32);
        config.seg_max = SEG_MAX;

        self.* = .{
            .gpa = gpa,
            .guest_memory = guest_memory,
            .queues = .{try Queue.init(256)},
            .interrupt = interrupt,
            .file = file,
            .ring = ring,
            .ring_evt = ring_evt,
            .interface = initInterface(),
            .config = config,
        };
    }

    pub fn deinit(self: *Blk) void {
        self.interrupt.deinit();
        self.file.close();
        self.ring.deinit();
        self.ring_evt.close();
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
        var should_submit_ring = false;

        // We must store all the iovecs outside of the loop as they must remain valid
        // until the ring is submitted.
        // TODO: Is this enough iovecs? Maybe we need to allocate at some point.
        var iovecs: [posix.IOV_MAX]posix.iovec = undefined;
        var iovec_idx: usize = 0;

        var ciovecs: [posix.IOV_MAX]posix.iovec_const = undefined;
        var ciovec_idx: usize = 0;

        while (queue.pop()) |d| {
            const buffer = self.guest_memory.slice(d.addr, d.len);
            const req = Request.parse(buffer);

            const offset = req.sector * SECTOR_SIZE_BYTES;

            var writer = d.writer();

            var status = RequestStatus.OK;
            var async = false;
            if (req.type == RequestType.IN) {
                const write_iovec_len = try writer.slice(
                    self.guest_memory,
                    iovecs[iovec_idx..],
                    0,
                    writer.size - 1,
                );

                const write_iovecs = iovecs[iovec_idx..][0..write_iovec_len];
                iovec_idx += write_iovec_len;
                if (write_iovec_len == 0) {
                    return error.FailedToGetIovecs;
                }

                async = true;
                _ = self.ring.read(d.idx, self.file, .{ .iovecs = write_iovecs }, offset) catch |err| blk: {
                    std.log.err("Failed to queue file read: {}", .{err});
                    async = false;
                    status = RequestStatus.IOERR;
                    break :blk null;
                };
                should_submit_ring = true;
            } else if (req.type == RequestType.OUT) {
                var reader = d.reader();

                const read_iovec_len = try reader.slice(
                    self.guest_memory,
                    ciovecs[ciovec_idx..],
                    Request.HEADER_LEN,
                    reader.size - Request.HEADER_LEN,
                );
                if (read_iovec_len == 0) {
                    return error.FailedToGetIovecs;
                }
                const read_iovecs = ciovecs[ciovec_idx..][0..read_iovec_len];
                ciovec_idx += read_iovec_len;

                async = true;
                _ = self.ring.writev(d.idx, self.file, read_iovecs, offset) catch |err| blk: {
                    std.log.err("Failed to queue file write: {}", .{err});
                    async = false;
                    status = RequestStatus.IOERR;
                    break :blk null;
                };
                should_submit_ring = true;
            } else if (req.type == RequestType.FLUSH) {
                async = true;
                _ = self.ring.fsync(d.idx, self.file, 0) catch |err| blk: {
                    std.log.err("Failed to queue file fsync: {}", .{err});
                    async = false;
                    status = RequestStatus.IOERR;
                    break :blk null;
                };
                should_submit_ring = true;
            } else {
                status = RequestStatus.UNSUPP;
            }

            if (!async) {
                // We're just using the iovec to get the address of the status byte.
                // No need to use the shared iovecs array.
                // In the future we can add more ergonomics to the writer to avoid this.
                var status_iovecs: [1]posix.iovec = undefined;
                _ = try writer.slice(self.guest_memory, &status_iovecs, writer.size - 1, 1);
                status_iovecs[0].base[0] = status;
                queue.addUsed(d.idx, @intCast(writer.size));
                used_desc = true;
            }
        }

        if (should_submit_ring) {
            _ = try self.ring.submit();
        }

        return used_desc;
    }

    fn handleRingCompletions(self: *Blk) !bool {
        try self.ring_evt.read();
        var used_desc = false;

        while (true) {
            var cqes: [posix.IOV_MAX]linux.io_uring_cqe = undefined;
            const len = try self.ring.copy_cqes(&cqes, 0);
            if (len == 0) break;

            for (cqes[0..len]) |cqe| {
                const desc_idx: u16 = @intCast(cqe.user_data);
                const queue = &self.queues[REQUEST_Q1];
                var desc = queue.getDesc(desc_idx) orelse return error.MissingDesc;

                var writer = desc.writer();

                var status = RequestStatus.OK;
                switch (cqe.err()) {
                    .SUCCESS => {},
                    else => |errno| {
                        std.log.err("completion error: {}", .{errno});
                        status = RequestStatus.IOERR;
                    },
                }

                var status_iovecs: [1]posix.iovec = undefined;
                _ = try writer.slice(self.guest_memory, &status_iovecs, writer.size - 1, 1);
                status_iovecs[0].base[0] = status;

                queue.addUsed(desc_idx, @intCast(writer.size));
                used_desc = true;
            }
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
            RING_EVT => {
                desc_used = self.handleRingCompletions() catch |err| {
                    std.log.err("Failed to handle ring event: {}", .{err});
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
        try ec.register(
            self.ring_evt.fd,
            linux.EPOLL.IN,
            self,
            RING_EVT,
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
