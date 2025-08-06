const std = @import("std");

pub export fn svc16_expansion_api_version() callconv(.C) usize {
    return 1;
}

pub export fn svc16_expansion_on_init() void {}
pub export fn svc16_expansion_on_deinit() void {}

pub export fn svc16_expansion_triggered(buffer: *[std.math.pow(usize, 2, 16)]u16) void {
    buffer[0] = 'H';
    buffer[1] = 'e';
    buffer[2] = 'l';
    buffer[3] = 'l';
    buffer[4] = 'o';
}
