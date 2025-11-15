const std = @import("std");
const linux = std.os.linux;
const ioctl = @import("ioctl.zig");
const c = @import("c.zig").c;

const Vm = @import("vm.zig").Vm;
const GuestMemory = @import("GuestMemory.zig");

pub const PageTables = struct {
    pub const PML4: usize = 0x1000;
    pub const PDPT: usize = 0x2000;
    pub const PD: usize = 0x3000;
};

const PageFlag = struct {
    const Present: u64 = 1 << 0;
    const ReadWrite: u64 = 1 << 1;
    const UserSupervisor: u64 = 1 << 2;
    const PageWriteThrough: u64 = 1 << 3;
    const PageCacheDisable: u64 = 1 << 4;
    const Accessed: u64 = 1 << 5;
    const Dirty: u64 = 1 << 6;
    const PageSize: u64 = 1 << 7;
    const Global: u64 = 1 << 8;
    const NoExecute: u64 = 1 << 63;
};

const SegmentFlags = struct {
    const Accessed: u8 = 1 << 0;
    const CodeRead: u8 = 1 << 1;
    const CodeSegment: u8 = 1 << 3;

    const DataWrite: u8 = 1 << 1;
};

const Cr0Flags = struct {
    const ProtectionEnable: u64 = 1 << 0;
    const ExtensionType: u64 = 1 << 4;
    const NumericError: u64 = 1 << 5;
    const Paging: u64 = 1 << 31;
};

const Cr4Flags = struct {
    const PageSizeExtension: u64 = 1 << 7;
    const PhysicalAddressExtension: u64 = 1 << 5;
};

const EferFlags = struct {
    const LongModeEnable: u64 = 1 << 8;
    const LongModeActive: u64 = 1 << 10;
};

const CODE_SEGMENT = c.kvm_segment{
    .base = 0,
    .limit = 0xffffffff,
    .selector = 0x10,
    .type = SegmentFlags.CodeRead | SegmentFlags.CodeSegment,
    .present = 1,
    .dpl = 0,
    .db = 0,
    .s = 1,
    .l = 1,
    .g = 1,
    .avl = 0,
    .unusable = 0,
    .padding = 0,
};

const DATA_SEGMENT = c.kvm_segment{
    .base = 0,
    .limit = 0xffffffff,
    .selector = 0x18,
    .type = SegmentFlags.DataWrite,
    .present = 1,
    .dpl = 0,
    .db = 1,
    .s = 1,
    .l = 0,
    .g = 1,
    .avl = 0,
    .unusable = 0,
    .padding = 0,
};

pub fn setup_paging(vm: *Vm, guest_memory: GuestMemory) !c.kvm_sregs {
    const memory_u64: []u64 = @alignCast(std.mem.bytesAsSlice(u64, guest_memory.bytes));

    memory_u64[PageTables.PML4 / @sizeOf(u64)] = PageTables.PDPT | PageFlag.Present | PageFlag.ReadWrite;
    memory_u64[PageTables.PDPT / @sizeOf(u64)] = PageTables.PD | PageFlag.Present | PageFlag.ReadWrite;

    const pd_start = PageTables.PD / @sizeOf(u64);
    for (0..512) |n| {
        memory_u64[pd_start + n] = (@as(u64, @intCast(n)) << 21) | PageFlag.Present | PageFlag.ReadWrite | PageFlag.PageSize;
    }

    // Setup GDT using u64 slice like Rust code
    memory_u64[0x10 / @sizeOf(u64)] = packSegment(CODE_SEGMENT); // memory[2] = CS at offset 0x10
    memory_u64[0x18 / @sizeOf(u64)] = packSegment(DATA_SEGMENT); // memory[3] = DS at offset 0x18

    const mem_region = c.kvm_userspace_memory_region{
        .slot = 0,
        .flags = 0,
        .guest_phys_addr = 0,
        .memory_size = guest_memory.len,
        .userspace_addr = @intCast(@intFromPtr(guest_memory.bytes.ptr)),
    };
    try vm.set_user_memory_region(&mem_region);

    return .{
        .cr3 = @intCast(PageTables.PML4),
        .cr4 = Cr4Flags.PhysicalAddressExtension,
        .efer = EferFlags.LongModeEnable | EferFlags.LongModeActive,
        .cr0 = Cr0Flags.ProtectionEnable | Cr0Flags.Paging,
        .cs = CODE_SEGMENT,
        .ds = DATA_SEGMENT,
        .es = DATA_SEGMENT,
        .fs = DATA_SEGMENT,
        .gs = DATA_SEGMENT,
        .ss = DATA_SEGMENT,
    };
}

fn packSegment(segment: c.kvm_segment) u64 {
    // Bits 8-15: lo_flags (type, s, dpl, present)
    const lo_flags: u64 = @as(u64, segment.type) |
        (@as(u64, segment.s) << 4) |
        (@as(u64, segment.dpl) << 5) |
        (@as(u64, segment.present) << 7);

    // Bits 20-23: hi_flags (avl, l, db, g)
    const hi_flags: u64 = @as(u64, segment.avl) |
        (@as(u64, segment.l) << 1) |
        (@as(u64, segment.db) << 2) |
        (@as(u64, segment.g) << 3);

    // Pack the upper 32 bits: bits 8-15 (lo_flags), 16-19 (limit high 4 bits), 20-23 (hi_flags)
    const packed_segment: u64 = (lo_flags << 8) |
        ((@as(u64, segment.limit) & 0xF) << 16) |
        (hi_flags << 20);

    // Final GDT entry: upper 32 bits contain packed data, lower 32 bits contain limit[31:16]
    return (packed_segment << 32) | (@as(u64, segment.limit) >> 16);
}
