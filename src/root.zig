const std = @import("std");
const linux = std.os.linux;
const c = @import("c.zig").c;

const Kvm = @import("kvm.zig").Kvm;

const PageTables = struct {
    const PML4: usize = 0x1000;
    const PDPT: usize = 0x2000;
    const PD: usize = 0x3000;
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

const KvmUserspaceMemoryRegion = extern struct {
    slot: u32,
    flags: u32,
    guest_phys_addr: u64,
    memory_size: u64, // bytes
    userspace_addr: u64, // start of the userspace allocated memory
};

pub fn startVm(gpa: std.mem.Allocator) !void {
    var kvm = try Kvm.init(gpa);
    defer kvm.deinit();

    var vm = try kvm.create_vm();
    defer vm.deinit();

    try vm.load_kernel(
        "console=ttyS0 earlyprintk=ttyS0 rdinit=/init",
        "result/bzImage",
        "initramfs",
    );

    try vm.setup_paging();

    try vm.run();
}
