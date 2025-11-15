const std = @import("std");
const linux = std.os.linux;
const ioctl = @import("ioctl.zig");
const Vm = @import("vm.zig").Vm;
const c = @import("c.zig").c;

const kvm_create_vm = ioctl.Ioctl(c.KVM_CREATE_VM);
const kvm_get_vcpu_mmap_size = ioctl.Ioctl(c.KVM_GET_VCPU_MMAP_SIZE);
const kvm_get_supported_cpuid = ioctl.IoctlR(c.KVM_GET_SUPPORTED_CPUID, c.kvm_cpuid2);

pub const Kvm = struct {
    kvm_fd: linux.fd_t,
    vcpu_mmap_size: usize,
    supported_cpuid_buf: []align(4) u8,
    supported_cpuid: *c.kvm_cpuid2,
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) !Kvm {
        const dev_kvm_fd = try std.posix.open("/dev/kvm", .{ .ACCMODE = .RDWR }, 0);
        errdefer std.posix.close(dev_kvm_fd);

        const vcpu_mmap_size = try kvm_get_vcpu_mmap_size(dev_kvm_fd);

        const supported_cpuid_entries = 80;
        const supported_cpuid_buf = try gpa.allocWithOptions(
            u8,
            @sizeOf(c.kvm_cpuid2) + @sizeOf(c.kvm_cpuid_entry2) * (supported_cpuid_entries),
            std.mem.Alignment.of(c.kvm_cpuid2).max(std.mem.Alignment.of(c.kvm_cpuid_entry2)),
            null,
        );
        errdefer gpa.free(supported_cpuid_buf);

        const supported_cpuid: *c.kvm_cpuid2 = @ptrCast(supported_cpuid_buf.ptr);
        supported_cpuid.* = .{ .nent = supported_cpuid_entries };
        for (supported_cpuid.entries()[0..supported_cpuid.nent]) |*entry| {
            entry.* = .{ .function = 0, .index = 0 };
        }

        _ = try kvm_get_supported_cpuid(dev_kvm_fd, supported_cpuid);

        return .{
            .kvm_fd = dev_kvm_fd,
            .vcpu_mmap_size = vcpu_mmap_size,
            .supported_cpuid_buf = supported_cpuid_buf,
            .supported_cpuid = supported_cpuid,
            .gpa = gpa,
        };
    }

    pub fn create_vm(self: *const Kvm) !linux.fd_t {
        const vm_fd: std.posix.fd_t = @intCast(try kvm_create_vm(self.kvm_fd));
        errdefer std.posix.close(vm_fd);

        return vm_fd;
    }

    pub fn deinit(self: *const Kvm) void {
        self.gpa.free(self.supported_cpuid_buf);
        std.posix.close(self.kvm_fd);
    }
};
