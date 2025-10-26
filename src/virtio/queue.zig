const std = @import("std");
const linux = std.os.linux;

const USED_SIZE: u32 = 2 * @sizeOf(u32);
const AVAILABLE_SIZE: u32 = @sizeOf(u16);

pub const Queue = struct {
    const Self = @This();

    eventfd: std.posix.fd_t,

    // Max size offered by the device
    max_size: u16,

    // Size of the queue as configured by the driver
    size: u16 = 0,

    // Indicates if the queue has been configured by the driver
    ready: bool = false,

    desc_table_address: u64 = 0,
    avail_ring_address: u64 = 0,
    used_ring_address: u64 = 0,

    desc_table_ptr: []volatile Descriptor = undefined,
    avail_ring_ptr: []align(2) volatile u16 = undefined,
    used_ring_ptr: []align(4) volatile u8 = undefined,

    next_avail: u16 = 0,
    next_used: u16 = 0,

    pub fn init(max_size: u16) !Self {
        const eventfd = try std.posix.eventfd(0, linux.EFD.CLOEXEC | linux.EFD.NONBLOCK);

        return .{
            .eventfd = eventfd,
            .max_size = max_size,
            .size = max_size,
            .ready = false,
        };
    }

    pub fn registerEpoll(self: *Self, epoll_fd: linux.fd_t, user_data: u64) !void {
        var event = linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .u64 = user_data },
        };
        try std.posix.epoll_ctl(epoll_fd, linux.EPOLL.CTL_ADD, self.eventfd, &event);
    }

    pub fn activate(
        self: *Self,
        guest_memory: []align(4096) u8,
    ) !void {
        if (!self.ready) {
            return error.QueueNotReady;
        }

        // Queue must be a power of two, must be non-zero, and must not be larger than the max size.
        if (self.size > self.max_size or self.size == 0 or (self.size & (self.size - 1)) != 0) {
            return error.InvalidQueueSize;
        }

        self.desc_table_ptr = @ptrCast(@alignCast(guest_memory[self.desc_table_address..][0..self.descTableSize()]));
        self.avail_ring_ptr = @ptrCast(@alignCast(guest_memory[self.avail_ring_address..][0..self.availRingSize()]));
        self.used_ring_ptr = @ptrCast(@alignCast(guest_memory[self.used_ring_address..][0..self.usedRingSize()]));
    }

    fn descTableSize(self: *const Self) u32 {
        return @sizeOf(Descriptor) * self.size;
    }

    fn availRingSize(self: *const Self) u32 {
        return 3 * @sizeOf(u16) + AVAILABLE_SIZE * self.size;
    }

    fn usedRingSize(self: *const Self) u32 {
        return 3 * @sizeOf(u16) + USED_SIZE * self.size;
    }

    /// Get avail_ring.idx
    pub fn availRingGetIdx(self: *const Self) u16 {
        return @atomicLoad(u16, &self.avail_ring_ptr[1], .acquire);
    }

    pub fn usedRingSetIdx(self: *Self, idx: u16) void {
        std.log.debug("set used ring idx={}", .{idx});
        const idx_ptr: *volatile u16 = @ptrCast(self.used_ring_ptr[@sizeOf(u16)..]);
        @atomicStore(u16, idx_ptr, idx, .release);
    }

    pub fn addUsed(self: *Self, idx: u32, len: u32) void {
        const used_idx = self.next_used % self.size;

        const offset = 2 * @sizeOf(u16) + USED_SIZE * used_idx;
        const id_ptr: *align(4) volatile u32 = @ptrCast(@alignCast(self.used_ring_ptr[offset..]));
        id_ptr.* = idx;
        const len_ptr: *align(4) volatile u32 = @ptrCast(@alignCast(self.used_ring_ptr[offset + @sizeOf(u32) ..]));
        len_ptr.* = len;

        self.next_used +%= 1;
        self.usedRingSetIdx(self.next_used);
    }

    pub fn availRingGetDescIdx(self: *const Self, idx: u16) u16 {
        return self.avail_ring_ptr[idx + 2];
    }

    pub fn availLen(self: *Self) u16 {
        return self.availRingGetIdx() -% self.next_avail;
    }

    pub fn pop(self: *Self) ?DescriptorChain {
        const len = self.availLen();
        std.debug.assert(len <= self.size);

        if (len == 0) return null;

        const idx = self.next_avail % self.size;
        self.next_avail +%= 1;
        return DescriptorChain.init(self.desc_table_ptr, self.availRingGetDescIdx(idx));
    }

    pub fn setField(
        self: *Self,
        comptime field_name: []const u8,
        value: u32,
        part: enum { low, high },
    ) void {
        const parts: *[2]u64 = @ptrCast(&@field(self, field_name));
        if (part == .low) {
            parts[0] = @intCast(value);
        } else {
            parts[1] = @intCast(value);
        }
    }
};

pub const DescriptorFlags = packed struct {
    /// This marks a buffer as continuing via the next field.
    virtq_desc_f_next: bool = false,
    /// This marks a buffer as device write-only (otherwise device read-only).
    virtq_desc_f_write: bool = false,
    /// This means the buffer contains a list of buffer descriptors.
    virtq_desc_f_indirect: bool = false,

    _: u13 = 0,

    comptime {
        std.debug.assert(@bitSizeOf(@This()) == 16);
    }
};

pub const Descriptor = packed struct {
    /// Address (guest-physical)
    addr: u64,
    /// Length
    len: u32,
    /// Descriptor flags
    flags: DescriptorFlags,
    /// Next field if flags & NEXT
    next: u16,

    comptime {
        std.debug.assert(@alignOf(@This()) == 16);
    }
};

pub const DescriptorChain = struct {
    desc_table: []volatile Descriptor,

    addr: u64 = 0,
    len: u32,
    idx: u16,
    next: u16,
    flags: DescriptorFlags,

    fn init(desc_table: []volatile Descriptor, idx: u16) DescriptorChain {
        const desc = &desc_table[idx];
        return .{
            .desc_table = desc_table,
            .idx = idx,
            .addr = desc.addr,
            .len = desc.len,
            .next = desc.next,
            .flags = desc.flags,
        };
    }

    pub fn hasNext(self: DescriptorChain) bool {
        return self.flags.virtq_desc_f_next;
    }

    pub fn isWriteOnly(self: DescriptorChain) bool {
        return self.flags.virtq_desc_f_write;
    }

    pub fn getNext(self: *const DescriptorChain) ?DescriptorChain {
        if (self.hasNext()) {
            return DescriptorChain.init(self.desc_table, self.next);
        }
        return null;
    }
};
