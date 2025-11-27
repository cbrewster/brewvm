/// MMIO Transport for virtio.
/// Based on the virtio specification v1.2, section 4.2.2
const std = @import("std");

const ioctl = @import("../../ioctl.zig");
const c = @import("../../c.zig").c;
const EventController = @import("../../EventController.zig");
const EventFd = @import("../../EventFd.zig");
const GuestMemory = @import("../../GuestMemory.zig");
const Vm = @import("../../vm.zig").Vm;
const Device = @import("../device.zig").Device;

const linux = std.os.linux;

const kvm_irq_line = ioctl.IoctlW(c.KVM_IRQ_LINE, *const c.kvm_irq_level);
const kvm_ioeventfd = ioctl.IoctlW(c.KVM_IOEVENTFD, *const c.kvm_ioeventfd);
const kvm_irqfd = ioctl.IoctlW(c.KVM_IRQFD, *const c.kvm_irqfd);

const DeviceFeatures = @import("../devices/flags.zig").DeviceFeatures;

/// Virtio MMIO register offsets (from the spec)
/// These are the memory-mapped registers that the guest OS will access
pub const Registers = struct {
    /// Magic value - always returns 0x74726976 ('virt' in little-endian)
    pub const MAGIC_VALUE: u64 = 0x000;
    /// Device version - we'll use version 2 (0x2)
    pub const VERSION: u64 = 0x004;
    /// Device ID - identifies the type of virtio device (1=net, 2=block, etc)
    pub const DEVICE_ID: u64 = 0x008;
    /// Vendor ID
    pub const VENDOR_ID: u64 = 0x00c;
    /// Device features (bits 0-31)
    pub const DEVICE_FEATURES: u64 = 0x010;
    /// Device features selector
    pub const DEVICE_FEATURES_SEL: u64 = 0x014;
    /// Driver features (bits 0-31)
    pub const DRIVER_FEATURES: u64 = 0x020;
    /// Driver features selector
    pub const DRIVER_FEATURES_SEL: u64 = 0x024;
    /// Queue selector
    pub const QUEUE_SEL: u64 = 0x030;
    /// Maximum queue size
    pub const QUEUE_NUM_MAX: u64 = 0x034;
    /// Queue size
    pub const QUEUE_NUM: u64 = 0x038;
    /// Queue ready bit
    pub const QUEUE_READY: u64 = 0x044;
    /// Queue notifier
    pub const QUEUE_NOTIFY: u64 = 0x050;
    /// Interrupt status
    pub const INTERRUPT_STATUS: u64 = 0x060;
    /// Interrupt ACK
    pub const INTERRUPT_ACK: u64 = 0x064;
    /// Device status
    pub const STATUS: u64 = 0x070;
    /// Queue descriptor area (low 32 bits)
    pub const QUEUE_DESC_LOW: u64 = 0x080;
    /// Queue descriptor area (high 32 bits)
    pub const QUEUE_DESC_HIGH: u64 = 0x084;
    /// Queue driver area (low 32 bits)
    pub const QUEUE_DRIVER_LOW: u64 = 0x090;
    /// Queue driver area (high 32 bits)
    pub const QUEUE_DRIVER_HIGH: u64 = 0x094;
    /// Queue device area (low 32 bits)
    pub const QUEUE_DEVICE_LOW: u64 = 0x0a0;
    /// Queue device area (high 32 bits)
    pub const QUEUE_DEVICE_HIGH: u64 = 0x0a4;
    /// Configuration atomicity value
    pub const CONFIG_GENERATION: u64 = 0x0fc;
    /// Device-specific configuration starts at 0x100
    pub const CONFIG: u64 = 0x100;
};

pub const DeviceId = struct {
    /// Network device
    pub const NETWORK: u32 = 0x1;
    /// Block device
    pub const BLOCK: u32 = 0x2;
    /// Console device
    pub const CONSOLE: u32 = 0x3;
};

const DeviceStatus = struct {
    /// Indicates that the guest OS has found the device and recognized it as a valid virtio device.
    const ACKNOWLEDGE: u32 = 1 << 0;
    /// Indicates that the guest OS knows how to drive the device. Note: There could be a significant (or infinite) delay before setting this bit. For example, under Linux, drivers can be loadable modules.
    const DRIVER: u32 = 1 << 1;
    /// Indicates that the driver is set up and ready to drive the device.
    const DRIVER_OK: u32 = 1 << 2;
    /// Indicates that the driver has acknowledged all the features it understands, and feature negotiation is complete.
    const FEATURES_OK: u32 = 1 << 3;
    /// Indicates that the device has experienced an error from which it can’t recover.
    const NEEDS_RESET: u32 = 1 << 7;
    /// Indicates that something went wrong in the guest, and it has given up on the device. This could be an internal error, or the driver didn’t like the device for some reason, or even a fatal error during device operation.
    const FAILED: u32 = 1 << 8;
};

pub const Interrupt = struct {
    pub const VIRTIO_MMIO_INT_VRING: u32 = 0x01;
    pub const VIRTIO_MMIO_INT_CONFIG: u32 = 0x02;

    irq: u32,
    irq_evt: EventFd,
    irq_status: u32,

    pub fn init() !Interrupt {
        return .{
            .irq = 0,
            .irq_status = 0,
            .irq_evt = try EventFd.init(),
        };
    }

    pub fn deinit(self: *Interrupt) void {
        self.irq_evt.close();
    }

    pub fn trigger(self: *Interrupt, status: u32) !void {
        std.log.debug("    <- IRQ Trigger\n", .{});
        self.irq_status = status;
        try self.irq_evt.write();
    }

    fn register(self: *Interrupt, vm: *Vm, irq: u32) !void {
        try vm.irqfd(&.{ .fd = @intCast(self.irq_evt.fd), .gsi = irq });
    }
};

// TODO: Decide if we want a single transport for all devices
// or if we want to have a transport per device.

pub const MmioTransport = struct {
    /// Base address of this device in guest physical memory
    base_addr: u64,

    /// Device ID (e.g., 1=network, 2=block, 3=console, etc.)
    device_id: u32,

    /// Vendor ID
    vendor_id: u32,

    /// Current device status
    status: u32,

    /// Which feature bits word is selected (0 or 1)
    device_features_sel: u32,
    driver_features_sel: u32,
    driver_features: [2]u32,

    queue_sel: u32,
    queue_size: u32,

    irq: u32,
    guest_memory: GuestMemory,

    device_lock: std.Thread.Mutex,
    device: *Device,

    pub fn init(
        guest_memory: GuestMemory,
        irq: u32,
        base_addr: u64,
        device_id: u32,
        device: *Device,
    ) MmioTransport {
        return .{
            .base_addr = base_addr,
            .device_id = device_id,
            .vendor_id = 0x57455242, // "BREW" in little-endian
            .device_features_sel = 0,
            .driver_features_sel = 0,
            .driver_features = [_]u32{ 0, 0 },
            .status = 0,
            .queue_sel = 0,
            .queue_size = 0,
            .guest_memory = guest_memory,
            .irq = irq,
            .device = device,
            .device_lock = .{},
        };
    }

    pub fn registerIoEventFd(self: *MmioTransport, vm: *Vm) !void {
        try self.device.getInterrupt().register(vm, self.irq);
        for (self.device.getQueues(), 0..) |*queue, i| {
            try vm.ioeventfd(&.{
                .addr = self.base_addr + Registers.QUEUE_NOTIFY,
                .datamatch = i,
                .len = 4,
                .fd = queue.eventfd.fd,
                .flags = c.KVM_IOEVENTFD_FLAG_DATAMATCH,
            });
        }
    }

    pub fn registerEvents(self: *MmioTransport, ec: *EventController) !void {
        try self.device.registerEvents(ec);
    }

    pub fn set_device_status(self: *MmioTransport, new_status: u32) void {
        const diff = new_status ^ self.status;
        if (diff == DeviceStatus.ACKNOWLEDGE and self.status == 0) {
            self.status = new_status;
        } else if (diff == DeviceStatus.DRIVER and self.status == DeviceStatus.ACKNOWLEDGE) {
            self.status = new_status;
        } else if (diff == DeviceStatus.FEATURES_OK and
            self.status == DeviceStatus.DRIVER | DeviceStatus.ACKNOWLEDGE)
        {
            self.status = new_status;
        } else if (diff == DeviceStatus.DRIVER_OK and
            self.status == DeviceStatus.FEATURES_OK | DeviceStatus.DRIVER | DeviceStatus.ACKNOWLEDGE)
        {
            self.status = new_status;

            self.device_lock.lock();
            defer self.device_lock.unlock();

            if (!self.device.isActive()) {
                self.device.activate(self.guest_memory) catch |err| {
                    std.log.err("failed to activate device {}", .{err});
                    self.status |= DeviceStatus.NEEDS_RESET;
                    // TODO: Trigger config interrupt
                };
            }
        } else if (new_status & DeviceStatus.FAILED != 0) {
            self.status |= DeviceStatus.FAILED;
        } else if (new_status == 0) {
            // TODO: reset device
            self.status = 0;
        } else {
            std.log.err("Invalid device status change: 0x{X} -> 0x{X}", .{
                self.status,
                new_status,
            });
        }
    }

    /// Handle MMIO read from the guest
    /// Returns the value to return to the guest
    pub fn read(self: *MmioTransport, offset: u64, data: []u8) !void {
        if (offset >= Registers.CONFIG) {
            try self.device.readConfig(offset - Registers.CONFIG, data);
            return;
        }

        // All registers are 4 bytes.
        std.debug.assert(data.len == 4);
        const value = self.readResgiter(offset);
        std.mem.writeInt(u32, @ptrCast(data), value, .little);
    }

    fn readResgiter(self: *MmioTransport, offset: u64) u32 {
        switch (offset) {
            Registers.MAGIC_VALUE => {
                std.log.debug("    <- MAGIC_VALUE = 0x74726976\n", .{});
                return 0x74726976; // 'virt' in little-endian
            },
            Registers.VERSION => {
                std.log.debug("    <- VERSION = 2\n", .{});
                return 2; // Version 2
            },
            Registers.DEVICE_ID => {
                std.log.debug("    <- DEVICE_ID = {}\n", .{self.device_id});
                return self.device_id;
            },
            Registers.VENDOR_ID => {
                std.log.debug("    <- VENDOR_ID = 0x{X}\n", .{self.vendor_id});
                return self.vendor_id;
            },
            Registers.DEVICE_FEATURES => {
                const features = self.getFeatures();
                std.log.debug("    <- DEVICE_FEATURES[{}] = 0x{X}\n", .{
                    self.device_features_sel,
                    features,
                });
                return features;
            },
            Registers.QUEUE_NUM_MAX => {
                const max_size = self.device.getQueue(self.queue_sel).max_size;
                std.log.debug("    <- QUEUE_NUM_MAX = {}\n", .{max_size});
                return max_size; // Maximum queue size
            },
            Registers.QUEUE_READY => {
                const ready = self.device.getQueue(self.queue_sel).ready;
                std.log.debug("    <- QUEUE_READY = {}\n", .{ready});
                if (ready) return 1 else return 0;
            },
            Registers.INTERRUPT_STATUS => {
                const irq_status = self.device.getInterrupt().irq_status;
                std.log.debug("    <- INTERRUPT_STATUS = 0x{X}\n", .{irq_status});
                return irq_status;
            },
            Registers.STATUS => {
                std.log.debug("    <- STATUS = 0b{b}\n", .{self.status});
                return self.status;
            },
            Registers.CONFIG_GENERATION => {
                std.log.debug("    <- CONFIG_GENERATION = 0\n", .{});
                return 0;
            },
            else => {
                std.log.err("UNHANDLED offset 0x{X:0>3} = 0\n", .{offset});
                return 0;
            },
        }
    }

    /// Handle MMIO write from the guest
    pub fn write(self: *MmioTransport, offset: u64, value: []const u8) !void {
        if (offset >= Registers.CONFIG) {
            try self.device.writeConfig(offset - Registers.CONFIG, value);
            return;
        }

        // All registers are 4 bytes.
        std.debug.assert(value.len == 4);
        self.writeRegister(offset, std.mem.readInt(u32, @ptrCast(value), .little));
    }

    fn writeRegister(self: *MmioTransport, offset: u64, value: u32) void {
        switch (offset) {
            Registers.DEVICE_FEATURES_SEL => {
                std.log.debug("    -> DEVICE_FEATURES_SEL\n", .{});
                self.device_features_sel = value;
            },
            Registers.DRIVER_FEATURES => {
                std.log.debug("    -> DRIVER_FEATURES[{}] = 0x{X}\n", .{
                    self.driver_features_sel,
                    value,
                });
                self.device.setAckedFeaturesPartial(
                    value,
                    if (self.driver_features_sel == 0) .low else .high,
                );
                self.driver_features[self.driver_features_sel] = value;
            },
            Registers.DRIVER_FEATURES_SEL => {
                std.log.debug("    -> DRIVER_FEATURES_SEL\n", .{});
                self.driver_features_sel = value;
            },
            Registers.QUEUE_SEL => {
                std.log.debug("    -> QUEUE_SEL = {}\n", .{value});
                self.queue_sel = value;
            },
            Registers.QUEUE_NUM => {
                std.log.debug("    -> QUEUE_NUM = {}\n", .{value});
                self.device.getQueue(self.queue_sel).size = @intCast(value);
            },
            Registers.QUEUE_READY => {
                std.log.debug("    -> QUEUE_READY = {}\n", .{value != 0});
                self.device.getQueue(self.queue_sel).ready = value != 0;
            },
            Registers.INTERRUPT_ACK => {
                std.log.debug("    -> INTERRUPT_ACK\n", .{});
                self.device.getInterrupt().irq_status &= ~value;
            },
            Registers.STATUS => {
                std.log.debug("    -> STATUS = 0b{b}\n", .{value});
                self.set_device_status(value);
            },
            Registers.QUEUE_DESC_LOW => {
                std.log.debug("    -> QUEUE_DESC_LOW = 0x{X}\n", .{value});
                self.device.getQueue(self.queue_sel).setField("desc_table_address", value, .low);
            },
            Registers.QUEUE_DESC_HIGH => {
                std.log.debug("    -> QUEUE_DESC_HIGH = 0x{X}\n", .{value});
                self.device.getQueue(self.queue_sel).setField("desc_table_address", value, .high);
            },
            Registers.QUEUE_DRIVER_LOW => {
                std.log.debug("    -> QUEUE_DRIVER_LOW = 0x{X}\n", .{value});
                self.device.getQueue(self.queue_sel).setField("avail_ring_address", value, .low);
            },
            Registers.QUEUE_DRIVER_HIGH => {
                std.log.debug("    -> QUEUE_DRIVER_HIGH = 0x{X}\n", .{value});
                self.device.getQueue(self.queue_sel).setField("avail_ring_address", value, .high);
            },
            Registers.QUEUE_DEVICE_LOW => {
                std.log.debug("    -> QUEUE_DEVICE_LOW = 0x{X}\n", .{value});
                self.device.getQueue(self.queue_sel).setField("used_ring_address", value, .low);
            },
            Registers.QUEUE_DEVICE_HIGH => {
                std.log.debug("    -> QUEUE_DEVICE_HIGH = 0x{X}\n", .{value});
                self.device.getQueue(self.queue_sel).setField("used_ring_address", value, .high);
            },
            else => {
                std.log.err("    -> UNHANDLED\n", .{});
            },
        }
    }

    /// Gets the selected 32-bit feature word.
    fn getFeatures(self: *MmioTransport) u32 {
        const features: u64 = self.device.supportedFeatures() | DeviceFeatures.VIRTIO_F_VERSION_1;
        if (self.device_features_sel == 0) {
            return @truncate(features);
        } else {
            return @truncate(features >> 32);
        }
    }
};
