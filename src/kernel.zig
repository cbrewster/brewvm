const std = @import("std");
const c = @import("c.zig").c;

pub fn getBootParams(
    vm_linux_file: *const std.fs.File,
    cmdline_addr: u32,
    initramfs_addr: ?u32,
    initramfs_size: ?u32,
    e820_entries: []const c.boot_e820_entry,
) !c.boot_params {
    var boot_params: c.boot_params = undefined;

    try vm_linux_file.seekTo(0);
    var reader = vm_linux_file.reader(&.{});

    reader.interface.readSliceAll(@as([]u8, @ptrCast(&boot_params))) catch |err|
        return switch (err) {
            error.EndOfStream => error.ImageTooSmall,
            else => err,
        };

    if (boot_params.hdr.boot_flag != 0xAA55 or
        boot_params.hdr.header != 0x53726448 or
        (boot_params.hdr.jump >> 8) != 106)
    {
        return error.InvalidImage;
    }

    boot_params.hdr.vid_mode = 0xFFFF; // VGA display
    boot_params.hdr.type_of_loader = 0xFF; // booted by kvm
    boot_params.hdr.loadflags |= c.LOADED_HIGH | c.CAN_USE_HEAP;

    boot_params.hdr.ramdisk_image = initramfs_addr orelse 0;
    boot_params.hdr.ramdisk_size = initramfs_size orelse 0;

    boot_params.hdr.heap_end_ptr = 0xde00;

    boot_params.hdr.cmd_line_ptr = cmdline_addr;
    boot_params.ext_cmd_line_ptr = 0;

    boot_params.e820_entries = std.math.cast(u8, e820_entries.len) orelse
        return error.TooManyE820Entries;

    @memcpy(
        boot_params.e820_table[0..e820_entries.len],
        e820_entries,
    );

    return boot_params;
}
