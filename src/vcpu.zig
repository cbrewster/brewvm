const std = @import("std");
const linux = std.os.linux;
const ioctl = @import("ioctl.zig");
const c = @import("c.zig").c;
const layout = @import("layout.zig");
const Vm = @import("vm.zig").Vm;

const kvm_run = ioctl.Ioctl(c.KVM_RUN);
const kvm_set_cpuid2 = ioctl.IoctlW(c.KVM_SET_CPUID2, *const c.kvm_cpuid2);
const kvm_set_regs = ioctl.IoctlW(c.KVM_SET_REGS, *const c.kvm_regs);
const kvm_set_sregs = ioctl.IoctlW(c.KVM_SET_SREGS, *const c.kvm_sregs);

pub const Vcpu = struct {
    vcpu_fd: std.os.linux.fd_t,
    kvm_run_mapping: []align(4096) u8,

    pub fn init(
        vcpu_fd: std.os.linux.fd_t,
        vcpu_mmap_size: usize,
        cpuid: *c.kvm_cpuid2,
    ) !Vcpu {
        _ = try kvm_set_cpuid2(vcpu_fd, cpuid);

        const kvm_run_mapping = try std.posix.mmap(
            null,
            vcpu_mmap_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED },
            vcpu_fd,
            0,
        );
        errdefer std.posix.munmap(kvm_run_mapping);

        return .{
            .kvm_run_mapping = kvm_run_mapping,
            .vcpu_fd = vcpu_fd,
        };
    }

    pub fn deinit(self: *const Vcpu) void {
        std.posix.munmap(self.kvm_run_mapping);
        std.posix.close(self.vcpu_fd);
    }

    pub fn set_regs(self: *Vcpu, regs: c.kvm_regs) !void {
        _ = try kvm_set_regs(self.vcpu_fd, &regs);
    }

    pub fn set_sregs(self: *Vcpu, sregs: c.kvm_sregs) !void {
        _ = try kvm_set_sregs(self.vcpu_fd, &sregs);
    }

    pub fn run(self: *Vcpu, vm: *Vm) !void {
        var buffer: [4096]u8 = undefined;
        var buffer_len: usize = 0;

        const kvm_run_data = self.get_kvm_run();

        while (true) {
            _ = try kvm_run(self.vcpu_fd);

            switch (kvm_run_data.exit_reason) {
                c.KVM_EXIT_HLT, c.KVM_EXIT_SHUTDOWN => {
                    break;
                },
                c.KVM_EXIT_IO => {
                    const io = kvm_run_data.*.unnamed_0.io;
                    const port = io.port;
                    const offset = io.data_offset;
                    const data_ptr: [*]u8 = @ptrFromInt(@intFromPtr(kvm_run_data) + offset);

                    if (port == 0x3f8) {
                        const byte = data_ptr[0];
                        switch (byte) {
                            '\r', '\n' => {
                                if (buffer_len > 0) {
                                    std.debug.print("{s}\n", .{buffer[0..buffer_len]});
                                    buffer_len = 0;
                                }
                            },
                            else => {
                                if (buffer_len < buffer.len) {
                                    buffer[buffer_len] = byte;
                                    buffer_len += 1;
                                }
                            },
                        }
                    }

                    if (io.direction == 0) {
                        data_ptr[0] = 0x20;
                    }
                },
                c.KVM_EXIT_MMIO => {
                    const mmio = &kvm_run_data.*.unnamed_0.mmio;
                    const phys_addr = mmio.phys_addr;
                    const is_write = mmio.is_write != 0;

                    // Check if this is accessing our virtio-mmio device
                    if (phys_addr >= vm.mmio_device.base_addr and
                        phys_addr < vm.mmio_device.base_addr + layout.VIRTIO_MMIO_DEVICE_SIZE)
                    {
                        const offset = phys_addr - layout.VIRTIO_MMIO_BASE;

                        // We assume all MMIO read and writes are word-sized.
                        std.debug.assert(mmio.len == 4);

                        if (is_write) {
                            // Handle MMIO write
                            var value: u32 = 0;
                            for (0..@min(mmio.len, 4)) |i| {
                                value |= @as(u32, mmio.data[i]) << @intCast(i * 8);
                            }
                            vm.mmio_device.write(offset, value);
                        } else {
                            // Handle MMIO read
                            const value = vm.mmio_device.read(offset);
                            // Write the value back to the guest
                            std.mem.writeInt(u32, mmio.data[0..4], value, .little);
                        }
                    }
                },
                else => {
                    std.debug.print("Unhandled KVM exit reason: {}\n", .{kvm_run_data.exit_reason});
                    return error.UnhandledKvmExit;
                },
            }
        }
    }

    fn get_kvm_run(self: *Vcpu) *c.kvm_run {
        return @ptrCast(self.kvm_run_mapping.ptr);
    }
};
