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
        "console=hvc0 earlyprintk=serial loglevel=8 rdinit=/init",
        "result/bzImage",
        "initramfs",
    );

    try vm.setup_paging();

    try vm.run();
}
