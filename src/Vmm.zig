const std = @import("std");
const ArrayList = std.ArrayList;

const Kvm = @import("kvm.zig").Kvm;
const Vm = @import("vm.zig").Vm;
const Vcpu = @import("vcpu.zig").Vcpu;
const EventController = @import("EventController.zig");
const GuestMemory = @import("GuestMemory.zig");
const layout = @import("layout.zig");
const paging = @import("paging.zig");
const mmio = @import("virtio/transport/mmio.zig");
const Console = @import("virtio/devices/console.zig").Console;
const getBootParams = @import("kernel.zig").getBootParams;
const c = @import("c.zig").c;

const Self = @This();

const MAPPING_SIZE: usize = 1 << 30;

const ADDR_BOOT_PARAMS: usize = 0x10000;
const ADDR_CMDLINE: usize = 0x20000;
const ADDR_KERNEL32: usize = 0x100000;
const ADDR_INITRAMFS: usize = 0xf000000;

const E820_RAM: u32 = 0x1;
const E820_RESERVED: u32 = 0x2;

gpa: std.mem.Allocator,
kvm: Kvm,
vm: Vm,
vcpu: Vcpu,
guest_memory: GuestMemory,
event_controller: EventController,
mmio_devices: ArrayList(*mmio.MmioTransport),

pub fn init(gpa: std.mem.Allocator) !Self {
    const kvm = try Kvm.init(gpa);
    errdefer kvm.deinit();

    var vm = try Vm.init(&kvm);
    errdefer vm.deinit();

    try vm.create_irqchip();
    try vm.create_pit2();
    try vm.set_identity_map_addr(0xFFFFC000);
    try vm.set_tss_addr(0xFFFFD000);

    var guest_memory = try GuestMemory.init(MAPPING_SIZE);
    errdefer guest_memory.deinit();

    var vcpu = try Vcpu.init(&vm, kvm.vcpu_mmap_size, kvm.supported_cpuid);
    errdefer vcpu.deinit();

    const sreg = try paging.setup_paging(&vm, guest_memory);
    try vcpu.set_regs(.{
        .rflags = 1 << 1,
        .rip = ADDR_KERNEL32 + 0x200,
        .rsi = ADDR_BOOT_PARAMS,
    });
    try vcpu.set_sregs(sreg);

    var event_controller = try EventController.init(gpa);
    errdefer event_controller.deinit();

    return .{
        .gpa = gpa,
        .kvm = kvm,
        .vm = vm,
        .vcpu = vcpu,
        .guest_memory = guest_memory,
        .event_controller = event_controller,
        .mmio_devices = ArrayList(*mmio.MmioTransport).empty,
    };
}

pub fn loadKernel(
    self: *Self,
    base_cmdline: []const u8,
    kernel_path: []const u8,
    initramfs_path: []const u8,
) !void {
    // Build full command line with virtio device parameters
    var cmdline_buf: [2048]u8 = undefined;
    var index: usize = 0;

    index += (try std.fmt.bufPrint(cmdline_buf[index..], "{s}", .{base_cmdline})).len;

    for (self.mmio_devices.items) |mmio_device| {
        index += (try std.fmt.bufPrint(cmdline_buf[index..], " virtio_mmio.device=0x{X}@0x{X}", .{
            layout.VIRTIO_MMIO_DEVICE_SIZE,
            mmio_device.base_addr,
        })).len;
    }

    const cmdline = cmdline_buf[0..index];
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
    var bytes_copied = try vmlinux_file.readAll(self.guest_memory.slice(ADDR_KERNEL32, @intCast(
        kernel_size,
    )));
    if (bytes_copied != kernel_size) {
        return error.FailedToLoadKernel;
    }

    // Load the initramfs into memory.
    bytes_copied = try initram_file.readAll(self.guest_memory.slice(
        ADDR_INITRAMFS,
        @intCast(initram_stat.size),
    ));
    if (bytes_copied != initram_stat.size) {
        return error.FailedToLoadKernel;
    }

    // Copy in cmdline
    self.guest_memory.writeAt(ADDR_CMDLINE, cmdline);
    self.guest_memory.writeAt(ADDR_CMDLINE + cmdline.len, &.{0});

    // Copy in boot params
    const boot_params_bytes: *const [@sizeOf(@TypeOf(boot_params))]u8 = @ptrCast(&boot_params);
    self.guest_memory.writeAt(ADDR_BOOT_PARAMS, boot_params_bytes);
}

pub fn addVirtioConsole(self: *Self) !void {
    var mmio_device = try self.gpa.create(mmio.MmioTransport);
    errdefer self.gpa.destroy(mmio_device);

    var console = try Console.init(
        self.gpa,
        self.guest_memory,
        std.fs.File.stdin(),
        std.fs.File.stdout(),
    );
    errdefer console.deinit();

    try mmio_device.init(
        self.guest_memory,
        5,
        layout.VIRTIO_MMIO_BASE,
        mmio.DeviceId.CONSOLE,
        console,
    );
    errdefer mmio_device.deinit();

    // TODO: Errdefer dergister events.
    try mmio_device.registerIoEventFd(&self.vm);
    try mmio_device.registerEvents(&self.event_controller);

    try self.mmio_devices.append(self.gpa, mmio_device);
}

pub fn deinit(self: *Self) void {
    for (self.mmio_devices.items) |mmio_device| {
        mmio_device.deinit();
        self.gpa.destroy(mmio_device);
    }
    self.mmio_devices.deinit(self.gpa);
    self.event_controller.deinit();
    self.vcpu.deinit();
    self.vm.deinit();
    self.kvm.deinit();
    // Make sure all references to the guest memory are dropped before freeing it.
    self.guest_memory.deinit();
}

pub fn stop(self: *Self) !void {
    try self.event_controller.stop();
}

pub fn run(self: *Self) !void {
    // TODO: Handle graceful shutdown...
    _ = try std.Thread.spawn(.{}, vcpu_thread, .{ self, &self.vcpu });

    try self.event_controller.run();
}

pub fn vcpu_thread(self: *Self, vcpu: *Vcpu) !void {
    var buffer: [4096]u8 = undefined;
    var buffer_len: usize = 0;

    while (true) {
        const kvm_run_data = try vcpu.run();

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
                const mmio_data = &kvm_run_data.*.unnamed_0.mmio;
                const phys_addr = mmio_data.phys_addr;
                const is_write = mmio_data.is_write != 0;

                for (self.mmio_devices.items) |mmio_device| {
                    // Check if this is accessing our virtio-mmio device
                    if (phys_addr >= mmio_device.base_addr and
                        phys_addr < mmio_device.base_addr + layout.VIRTIO_MMIO_DEVICE_SIZE)
                    {
                        const offset = phys_addr - layout.VIRTIO_MMIO_BASE;

                        // We assume all MMIO read and writes are word-sized.
                        std.debug.assert(mmio_data.len == 4);

                        if (is_write) {
                            // Handle MMIO write
                            var value: u32 = 0;
                            for (0..@min(mmio_data.len, 4)) |i| {
                                value |= @as(u32, mmio_data.data[i]) << @intCast(i * 8);
                            }
                            mmio_device.write(offset, value);
                        } else {
                            // Handle MMIO read
                            const value = mmio_device.read(offset);
                            // Write the value back to the guest
                            std.mem.writeInt(u32, mmio_data.data[0..4], value, .little);
                        }
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
