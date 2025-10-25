const std = @import("std");
const linux = std.os.linux;
const c = @import("c.zig").c;

const Kvm = @import("kvm.zig").Kvm;

pub fn startVm(gpa: std.mem.Allocator) !void {
    var kvm = try Kvm.init(gpa);
    defer kvm.deinit();

    var vm = try kvm.create_vm();
    defer vm.deinit();

    try vm.load_kernel(
        "console=hvc0 console=ttyS0 earlyprintk=ttyS0 rdinit=/init virtio_mmio.device=4k@0xa0000000:48",
        "result/bzImage",
        "initramfs",
    );

    try vm.setup_paging();

    try vm.run();
}
