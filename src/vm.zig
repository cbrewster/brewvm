const std = @import("std");
const linux = std.os.linux;
const ioctl = @import("ioctl.zig");
const Vcpu = @import("vcpu.zig").Vcpu;
const getBootParams = @import("kernel.zig").getBootParams;
const paging = @import("paging.zig");
const PageTables: usize = paging.PageTables;
const layout = @import("layout.zig");
const c = @import("c.zig").c;
const mmio = @import("virtio/transport/mmio.zig");
const Console = @import("virtio/devices/console.zig").Console;

const kvm_create_irqchip = ioctl.Ioctl(c.KVM_CREATE_IRQCHIP);
const kvm_crate_pit2 = ioctl.IoctlW(c.KVM_CREATE_PIT2, *const c.kvm_pit_config);
const kvm_set_identity_map_addr = ioctl.IoctlW(c.KVM_SET_IDENTITY_MAP_ADDR, *const usize);
const kvm_create_vcpu = ioctl.Ioctl(c.KVM_CREATE_VCPU);
const kvm_set_regs = ioctl.IoctlW(c.KVM_SET_REGS, *const c.kvm_regs);
const kvm_set_sregs = ioctl.IoctlW(c.KVM_SET_SREGS, *const c.kvm_sregs);
const kvm_get_supported_cpuid = ioctl.IoctlR(c.KVM_GET_SUPPORTED_CPUID, *c.kvm_cpuid2);
const kvm_set_tss_addr = ioctl.IoctlW(c.KVM_SET_TSS_ADDR, usize);

const MAPPING_SIZE: usize = 1 << 30;

const ADDR_BOOT_PARAMS: usize = 0x10000;
const ADDR_CMDLINE: usize = 0x20000;
const ADDR_KERNEL32: usize = 0x100000;
const ADDR_INITRAMFS: usize = 0xf000000;

const E820_RAM: u32 = 0x1;
const E820_RESERVED: u32 = 0x2;

pub const Vm = struct {
    gpa: std.mem.Allocator,
    vm_fd: std.os.linux.fd_t,
    vcpu: Vcpu,
    guest_memory: []align(4096) u8,
    supported_cpuid: *c.kvm_cpuid2,
    mmio_device: mmio.MmioTransport,
    epoll_fd: linux.fd_t,

    pub fn init(
        gpa: std.mem.Allocator,
        vm_fd: linux.fd_t,
        vcpu_mmap_size: usize,
        supported_cpuid: *c.kvm_cpuid2,
    ) !Vm {
        // Create the irqchip
        _ = try kvm_create_irqchip(vm_fd);

        // Create the PIT
        _ = try kvm_crate_pit2(vm_fd, &.{});

        // Set the identity map address
        const idmap_addr: usize = 0xFFFFC000;
        _ = try kvm_set_identity_map_addr(vm_fd, &idmap_addr);

        _ = try kvm_set_tss_addr(vm_fd, 0xFFFFD000);

        const vcpu_fd: linux.fd_t = @intCast(try kvm_create_vcpu(vm_fd));
        errdefer std.posix.close(vcpu_fd);

        const vcpu = try Vcpu.init(vcpu_fd, vcpu_mmap_size, supported_cpuid);
        errdefer vcpu.deinit();

        const guest_memory = try std.posix.mmap(
            null,
            MAPPING_SIZE,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED, .ANONYMOUS = true },
            -1,
            0,
        );
        errdefer std.posix.munmap(guest_memory);

        const stdout = std.fs.File.stdout();
        const stdin = std.fs.File.stdin();

        // Initialize a virtio console device (device ID = 3)
        var mmio_device = try mmio.MmioTransport.init(
            guest_memory,
            vm_fd,
            5,
            layout.VIRTIO_MMIO_BASE,
            mmio.DeviceId.CONSOLE,
            try Console.init(gpa, stdout, stdin),
        );
        errdefer mmio_device.deinit();

        const epoll_fd = try std.posix.epoll_create1(linux.EPOLL.CLOEXEC);
        errdefer std.posix.close(epoll_fd);

        try mmio_device.registerIoEventFd(vm_fd);
        try mmio_device.registerEpoll(epoll_fd);

        return .{
            .gpa = gpa,
            .vm_fd = vm_fd,
            .vcpu = vcpu,
            .guest_memory = guest_memory,
            .supported_cpuid = supported_cpuid,
            .mmio_device = mmio_device,
            .epoll_fd = epoll_fd,
        };
    }

    pub fn deinit(self: *Vm) void {
        self.mmio_device.deinit();
        std.posix.close(self.epoll_fd);
        std.posix.munmap(self.guest_memory);
        self.vcpu.deinit();
        std.posix.close(self.vm_fd);
    }

    pub fn load_kernel(
        self: *Vm,
        base_cmdline: []const u8,
        kernel_path: []const u8,
        initramfs_path: []const u8,
    ) !void {
        // Build full command line with virtio device parameters
        var cmdline_buf: [2048]u8 = undefined;
        const virtio_params = try std.fmt.bufPrint(&cmdline_buf, "{s} virtio_mmio.device=0x{X}@0x{X}:{d}", .{
            base_cmdline,
            layout.VIRTIO_MMIO_DEVICE_SIZE,
            self.mmio_device.base_addr,
            5, // IRQ number (must be 0-23 for KVM irqchip)
        });
        const cmdline = virtio_params;
        const vmlinux_file = try std.fs.cwd().openFile(kernel_path, .{ .mode = .read_only });
        defer vmlinux_file.close();
        const vmlinux_stat = try vmlinux_file.stat();

        const initram_file = try std.fs.cwd().openFile(initramfs_path, .{ .mode = .read_only });
        defer initram_file.close();
        const initram_stat = try initram_file.stat();

        const boot_params = try getBootParams(
            &vmlinux_file,
            ADDR_CMDLINE,
            ADDR_INITRAMFS,
            std.math.cast(u32, initram_stat.size) orelse return error.InitramfsTooLarge,
            &.{
                .{
                    .addr = 0,
                    .size = layout.SYSTEM_MEM_START,
                    .type = E820_RAM,
                },
                .{
                    .addr = layout.SYSTEM_MEM_START,
                    .size = layout.SYSTEM_MEM_SIZE,
                    .type = E820_RESERVED,
                },
                .{
                    .addr = layout.HIMEM_START,
                    .size = @as(u64, @intCast(MAPPING_SIZE)) - layout.HIMEM_START,
                    .type = 1,
                },
            },
        );

        // Load the kernel into memory.
        const kernel_offset = (switch (boot_params.hdr.setup_sects) {
            0 => 4,
            else => |sects| @as(u64, @intCast(sects)),
        } + 1) * 512;

        if (vmlinux_stat.size - kernel_offset + ADDR_KERNEL32 > MAPPING_SIZE) {
            return error.NotEnoughMemoryToLoadKernel;
        }
        try vmlinux_file.seekTo(kernel_offset);

        const kernel_size = vmlinux_stat.size - kernel_offset;
        var bytes_copied = try vmlinux_file.readAll(self.guest_memory[ADDR_KERNEL32..][0..@intCast(kernel_size)]);
        if (bytes_copied != kernel_size) {
            return error.FailedToLoadKernel;
        }

        // Load the initramfs into memory.
        bytes_copied = try initram_file.readAll(self.guest_memory[ADDR_INITRAMFS..][0..@intCast(initram_stat.size)]);
        if (bytes_copied != initram_stat.size) {
            return error.FailedToLoadKernel;
        }

        // Copy in cmdline
        @memcpy(self.guest_memory[ADDR_CMDLINE..][0..cmdline.len], cmdline);
        self.guest_memory[ADDR_CMDLINE + cmdline.len] = 0;

        // Copy in boot params
        const boot_params_bytes: *const [@sizeOf(@TypeOf(boot_params))]u8 = @ptrCast(&boot_params);
        @memcpy(
            self.guest_memory[ADDR_BOOT_PARAMS..][0..@sizeOf(@TypeOf(boot_params))],
            boot_params_bytes,
        );
    }

    pub fn setup_paging(self: *Vm) !void {
        const sreg = try paging.setup_paging(self.vm_fd, self.guest_memory);

        try self.vcpu.set_regs(.{
            .rflags = 1 << 1,
            .rip = ADDR_KERNEL32 + 0x200,
            .rsi = ADDR_BOOT_PARAMS,
        });

        try self.vcpu.set_sregs(sreg);
    }

    pub fn run(self: *Vm) !void {
        const io_thread = try std.Thread.spawn(.{}, ioThread, .{self});
        defer io_thread.join();

        try self.vcpu.run(self);
    }

    fn ioThread(self: *Vm) !void {
        while (true) {
            var events: [1]linux.epoll_event = undefined;
            while (true) {
                const n = std.posix.epoll_wait(self.epoll_fd, &events, -1);
                if (n == 0) continue;

                for (events) |event| {
                    self.mmio_device.handleEvent(event) catch |err|
                        std.log.err("Failed to handle event: {}", .{err});
                }
            }
        }
    }
};
