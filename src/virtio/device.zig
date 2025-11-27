const std = @import("std");
const Queue = @import("queue.zig").Queue;
const EventController = @import("../EventController.zig");
const GuestMemory = @import("../GuestMemory.zig");
const Interrupt = @import("transport/mmio.zig").Interrupt;
const DeviceFeatures = @import("devices/flags.zig").DeviceFeatures;

pub const Device = @This();

vtable: *const VTable,

pub const VTable = struct {
    getInterrupt: *const fn (d: *Device) *Interrupt,
    getQueue: *const fn (d: *Device, queue: u32) *Queue,
    getQueues: *const fn (d: *Device) []Queue,
    getAckedFeatures: *const fn (d: *Device) u64,
    setAckedFeatures: *const fn (d: *Device, features: u64) void,
    readConfig: *const fn (d: *Device, offset: u64, data: []u8) Error!void,
    writeConfig: *const fn (d: *Device, offset: u64, data: []const u8) Error!void,
    supportedFeatures: *const fn (d: *Device) u64,
    isActive: *const fn (d: *Device) bool,
    activate: *const fn (d: *Device, guest_memory: GuestMemory) Error!void,
    registerEvents: *const fn (d: *Device, ec: *EventController) EventController.Error!void,
};

pub const Error = error{
    InvalidRequest,
} || Queue.Error || std.posix.WriteError || std.posix.ReadError;

pub fn getInterrupt(d: *Device) *Interrupt {
    return d.vtable.getInterrupt(d);
}

pub fn getQueue(d: *Device, queue: u32) *Queue {
    return d.vtable.getQueue(d, queue);
}

pub fn getQueues(d: *Device) []Queue {
    return d.vtable.getQueues(d);
}

pub fn getAckedFeatures(d: *Device) u64 {
    return d.vtable.getAckedFeatures(d);
}

pub fn setAckedFeatures(d: *Device, features: u64) void {
    return d.vtable.setAckedFeatures(d, features);
}

pub fn setAckedFeaturesPartial(
    d: *Device,
    features: u32,
    part: enum { low, high },
) void {
    var new_acked: u64 = switch (part) {
        .low => @intCast(features),
        .high => @as(u64, @intCast(features)) << 32,
    };

    const avail = d.supportedFeatures();
    const unrequested_features = new_acked & ~avail;
    if (unrequested_features != 0) {
        std.log.warn("Driver acked unknown feature: 0b{b}", .{
            unrequested_features,
        });
        new_acked &= ~unrequested_features;
    }

    const old_acked: u64 = d.getAckedFeatures();
    d.setAckedFeatures(old_acked | new_acked);
}

pub fn readConfig(d: *Device, offset: u64, data: []u8) Error!void {
    return d.vtable.readConfig(d, offset, data);
}

pub fn writeConfig(d: *Device, offset: u64, data: []const u8) Error!void {
    return d.vtable.writeConfig(d, offset, data);
}

pub fn supportedFeatures(d: *Device) u64 {
    return d.vtable.supportedFeatures(d) | DeviceFeatures.VIRTIO_F_VERSION_1;
}

pub fn isActive(d: *Device) bool {
    return d.vtable.isActive(d);
}

pub fn activate(d: *Device, guest_memory: GuestMemory) Error!void {
    return d.vtable.activate(d, guest_memory);
}

pub fn registerEvents(d: *Device, ec: *EventController) EventController.Error!void {
    return d.vtable.registerEvents(d, ec);
}
