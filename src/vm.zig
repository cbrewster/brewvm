const std = @import("std");
const linux = std.os.linux;
const ioctl = @import("ioctl.zig");
const c = @import("c.zig").c;
const Kvm = @import("kvm.zig").Kvm;

const kvm_create_irqchip = ioctl.Ioctl(c.KVM_CREATE_IRQCHIP);
const kvm_create_pit2 = ioctl.IoctlW(c.KVM_CREATE_PIT2, *const c.kvm_pit_config);
const kvm_set_identity_map_addr = ioctl.IoctlW(c.KVM_SET_IDENTITY_MAP_ADDR, *const usize);
const kvm_create_vcpu = ioctl.Ioctl(c.KVM_CREATE_VCPU);
const kvm_set_regs = ioctl.IoctlW(c.KVM_SET_REGS, *const c.kvm_regs);
const kvm_set_sregs = ioctl.IoctlW(c.KVM_SET_SREGS, *const c.kvm_sregs);
const kvm_get_supported_cpuid = ioctl.IoctlR(c.KVM_GET_SUPPORTED_CPUID, *c.kvm_cpuid2);
const kvm_set_tss_addr = ioctl.IoctlW(c.KVM_SET_TSS_ADDR, usize);
const kvm_irq_line = ioctl.IoctlW(c.KVM_IRQ_LINE, *const c.kvm_irq_level);
const kvm_ioeventfd = ioctl.IoctlW(c.KVM_IOEVENTFD, *const c.kvm_ioeventfd);
const kvm_irqfd = ioctl.IoctlW(c.KVM_IRQFD, *const c.kvm_irqfd);
const kvm_set_user_memory_region = ioctl.IoctlW(c.KVM_SET_USER_MEMORY_REGION, *const c.kvm_userspace_memory_region);

pub const Vm = struct {
    vm_fd: std.os.linux.fd_t,

    pub fn init(kvm: *const Kvm) !Vm {
        const vm_fd = try kvm.create_vm();
        errdefer std.posix.close(vm_fd);

        return .{
            .vm_fd = vm_fd,
        };
    }

    pub fn deinit(self: *Vm) void {
        std.posix.close(self.vm_fd);
    }

    pub fn create_irqchip(self: *const Vm) !void {
        _ = try kvm_create_irqchip(self.vm_fd);
    }

    pub fn create_pit2(self: *const Vm) !void {
        _ = try kvm_create_pit2(self.vm_fd, &.{});
    }

    pub fn set_identity_map_addr(self: *const Vm, addr: usize) !void {
        _ = try kvm_set_identity_map_addr(self.vm_fd, &addr);
    }

    pub fn set_tss_addr(self: *const Vm, addr: usize) !void {
        _ = try kvm_set_tss_addr(self.vm_fd, addr);
    }

    pub fn create_vcpu(self: *const Vm) !linux.fd_t {
        return @intCast(try kvm_create_vcpu(self.vm_fd));
    }

    pub fn set_user_memory_region(
        self: *const Vm,
        region: *const c.kvm_userspace_memory_region,
    ) !void {
        _ = try kvm_set_user_memory_region(self.vm_fd, region);
    }

    pub fn set_sregs(self: *const Vm, sregs: c.kvm_sregs) !void {
        _ = try kvm_set_sregs(self.vm_fd, &sregs);
    }

    pub fn set_regs(self: *const Vm, regs: c.kvm_regs) !void {
        _ = try kvm_set_regs(self.vm_fd, &regs);
    }

    pub fn irq_line(self: *const Vm, req: *const c.kvm_irq_level) !void {
        _ = try kvm_irq_line(self.vm_fd, req);
    }

    pub fn ioeventfd(self: *const Vm, req: *const c.kvm_ioeventfd) !void {
        _ = try kvm_ioeventfd(self.vm_fd, req);
    }

    pub fn irqfd(self: *const Vm, req: *const c.kvm_irqfd) !void {
        _ = try kvm_irqfd(self.vm_fd, req);
    }
};
