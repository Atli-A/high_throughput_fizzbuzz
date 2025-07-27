const std = @import("std");


pub fn microbench(comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function)), iterations: usize) i128 {
    const initial_time = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        _ = @call(.auto, function, args);
    }
    const final_time = std.time.nanoTimestamp();

    return final_time - initial_time;
}
