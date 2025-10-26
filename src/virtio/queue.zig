const std = @import("std");

const USED_SIZE: u32 = 2 * @sizeOf(u32);
const AVAILABLE_SIZE: u32 = @sizeOf(u16);

pub const Queue = struct {
    const Self = @This();

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

    pub fn initialize(
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

        self.desc_table_ptr = @ptrCast(@alignCast(guest_memory[self.desc_table_address..][0..self.desc_table_size()]));
        self.avail_ring_ptr = @ptrCast(@alignCast(guest_memory[self.avail_ring_address..][0..self.avail_ring_size()]));
        self.used_ring_ptr = @ptrCast(@alignCast(guest_memory[self.used_ring_address..][0..self.used_ring_size()]));
    }

    fn desc_table_size(self: *const Self) u32 {
        return @sizeOf(Descriptor) * self.size;
    }

    fn avail_ring_size(self: *const Self) u32 {
        return 3 * @sizeOf(u16) + AVAILABLE_SIZE * self.size;
    }

    fn used_ring_size(self: *const Self) u32 {
        return 3 * @sizeOf(u16) + USED_SIZE * self.size;
    }

    /// Get avail_ring.idx
    pub fn avail_ring_get_idx(self: *const Self, comptime fence: bool) u16 {
        if (fence) return @atomicLoad(u16, self.avail_ring_ptr[1].ptr, .acquire);

        return self.avail_ring_ptr[1];
    }

    pub fn used_ring_set_idx(self: *Self, idx: u16) void {
        std.log.debug("set used ring idx={}", .{idx});
        const idx_ptr: *volatile u16 = @ptrCast(self.used_ring_ptr[@sizeOf(u16)..]);
        idx_ptr.* = idx;
    }

    pub fn add_used(self: *Self, idx: u32, len: u32) void {
        const used_idx = self.next_used % self.size;

        const offset = 2 * @sizeOf(u16) + USED_SIZE * used_idx % self.size;
        const id_ptr: *align(4) volatile u32 = @ptrCast(@alignCast(self.used_ring_ptr[offset..]));
        id_ptr.* = idx;
        const len_ptr: *align(4) volatile u32 = @ptrCast(@alignCast(self.used_ring_ptr[offset + @sizeOf(u32) ..]));
        len_ptr.* = len;

        self.next_used +%= 1;
        self.used_ring_set_idx(self.next_used);
    }

    /// Get descriptor at index avail_ring.ring[idx]
    pub fn avail_ring_get_desc(self: *const Self, idx: u16) *volatile Descriptor {
        const desc_idx = self.avail_ring_ptr[idx + 2];
        return &self.desc_table_ptr[desc_idx];
    }

    pub fn avail_len(self: *Self) u16 {
        return self.avail_ring_get_idx(false) -% self.next_avail;
    }

    pub fn pop(self: *Self) ?DescriptorChain {
        const len = self.avail_len();
        std.debug.assert(len <= self.size);

        if (len == 0) return null;

        const idx = self.next_avail % self.size;
        const desc = self.avail_ring_get_desc(idx);
        self.next_avail +%= 1;
        return DescriptorChain.init(desc, idx);
    }

    pub fn set_field(
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
    descriptor_ptr: *volatile Descriptor,

    addr: u64,
    len: u32,
    idx: u16,

    fn init(desc_ptr: *volatile Descriptor, idx: u16) DescriptorChain {
        return .{
            .descriptor_ptr = desc_ptr,
            .idx = idx,
            .addr = desc_ptr.addr,
            .len = desc_ptr.len,
        };
    }
};
