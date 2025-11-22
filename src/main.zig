const std = @import("std");
const brewvm = @import("brewvm");

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = logFn,
};

fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime level.asText();
    const scope_txt = comptime if (scope == .default) "" else "(" ++ @tagName(scope) ++ ") ";

    const full_fmt = comptime "[" ++ level_txt ++ "] " ++ scope_txt ++ format ++ "\r\n";

    const stderr = std.fs.File.stderr().deprecatedWriter();
    std.fmt.format(stderr, full_fmt, args) catch return;
}

pub fn main() !void {
    const gpa = std.heap.c_allocator;
    try brewvm.startVm(gpa);
}
