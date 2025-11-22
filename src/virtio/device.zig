const std = @import("std");
const Queue = @import("queue.zig").Queue;
const EventController = @import("../EventController.zig");
const GuestMemory = @import("../GuestMemory.zig");
const Interrupt = @import("transport/mmio.zig").Interrupt;

pub const Device = @This();

vtable: *const VTable,

pub const VTable = struct {
    getInterrupt: *const fn (d: *Device) *Interrupt,
    getQueue: *const fn (d: *Device, queue: u32) *Queue,
    getQueues: *const fn (d: *Device) []Queue,
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

pub fn readConfig(d: *Device, offset: u64, data: []u8) Error!void {
    return d.vtable.readConfig(d, offset, data);
}

pub fn writeConfig(d: *Device, offset: u64, data: []const u8) Error!void {
    return d.vtable.writeConfig(d, offset, data);
}

pub fn supportedFeatures(d: *Device) u64 {
    return d.vtable.supportedFeatures(d);
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
