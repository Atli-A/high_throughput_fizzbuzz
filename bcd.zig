const std = @import("std");
const builtin = @import("builtin");

const strint = @import("strint.zig");
const StrInt = strint.StrInt;
const comptime_powi = strint.comptime_powi;

const dprint = std.debug.print;
const assert = std.debug.assert;

const c = @cImport({
    if (builtin.mode == .ReleaseFast) {
        @cDefine("NDEBUG", {}); // needed?
    }
    @cDefine("_GNU_SOURCE", {});
    @cInclude("fcntl.h");
    @cInclude("sys/uio.h");
});

fn vmsplice(fileno: c_int, memory: []u8) c_long {
    const iov = c.iovec{
        .iov_base = memory.ptr,
        .iov_len = memory.len,
    };
    return c.vmsplice(fileno, &iov, 1, c.SPLICE_F_NONBLOCK);
}

// fizzbuzz tokens are seperated by a seperator
const FizzBuzzToken = enum {
    Number,
    Fizz,
    Buzz,
    FizzBuzz,
};

const StandardFizzBuzz = &[_]FizzBuzzToken{
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz,
    FizzBuzzToken.Number, FizzBuzzToken.Buzz,   FizzBuzzToken.Fizz,
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz,
    FizzBuzzToken.Buzz,   FizzBuzzToken.Number, FizzBuzzToken.Fizz,
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.FizzBuzz,
};


/// exists since std.mem.rotate doesn't work at comptime
/// rotates left
fn comptime_rotate_slice(comptime T: type, comptime slice: []const T, comptime by: comptime_int) []const T {
    const position = by % slice.len;
    return slice[position..] ++ slice[0..position];
}


const Config = struct {
    const Fizz = "Fizz";
    const Buzz = "Buzz";
    const FizzBuzz = "FizzBuzz";
    const Seperator = "\n";

    fn segment_length(comptime generator: []const FizzBuzzToken, digits: usize) usize {
        var position: usize = 0;
        inline for (generator) |token| {
            position += (switch (token) {
                .Fizz => Fizz.len,
                .Buzz => Buzz.len,
                .FizzBuzz => FizzBuzz.len,
                .Number => digits,
            });
            position += Seperator.len;
        }
        return position;
    }

    fn write_segment(comptime digits: usize, comptime generator: []const FizzBuzzToken, number: *StrInt(digits), to: []u8) usize {
        var wi: usize = 0; // write index
//        std.debug.print("{s}\n", .{number.string()});
        inline for (generator, 0..) |token, i| {
            _ = i;
            const string = switch (token) {
                .Fizz => Fizz,
                .Buzz => Buzz,
                .FizzBuzz => FizzBuzz,
                .Number => number.string(),
            };
            @memcpy(to[wi .. wi + string.len], string);
            wi += string.len;
            @memcpy(to[wi .. wi + Seperator.len], Seperator);
            wi += Seperator.len;
            number.add(1);
        }
        return wi;
    }
};

const SegmentSetup = struct {
    core_generator: []const FizzBuzzToken,
    segment_count: comptime_int,
    remainder_generator: []const FizzBuzzToken,

    fn from(comptime generator: []const FizzBuzzToken, comptime total_number: comptime_int) SegmentSetup {
        return .{
            .core_generator = generator,
            .segment_count = total_number/generator.len,
            .remainder_generator = generator[0..(total_number % generator.len)],
        };
    }
};

const Synchronizer = struct {
    const Self = @This();
    const MAX_TASK_LEN = 1_000_000;
    const MAX_NUMBER_WIDTH = 32;
    const TaskId = u64;
    const NumType = u64;

    const Task = struct {
        starting_num: NumType,
        ending_num: NumType,
        task_id: TaskId,

        fn dprint(self: Task) void {
            std.debug.print("start: {} end: {} id: {}\n", .{self.starting_num, self.ending_num, self.task_id});
        }
    };

    waiting_task: TaskId,
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    last_task: Task,
    allocator: std.mem.Allocator,


    fn init(allocator: std.mem.Allocator) Synchronizer {
        return .{
            .allocator = allocator,
            .waiting_task = 0,
            .mutex = .{},
            .cond = .{},
            .last_task = .{
                .starting_num = 0,
                .ending_num = 0,
                .task_id = 0,
            },
        };
    }

    fn nextTask(self: *Self) !?Task {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const digits = std.math.log10_int(self.last_task.ending_num+1);

        const above_pow10 = (try std.math.powi(NumType, 10, digits+1)) - 1;

        self.last_task = .{
            .task_id = self.last_task.task_id + 1,
            .starting_num = self.last_task.ending_num + 1,
            .ending_num = @min(above_pow10, self.last_task.ending_num + MAX_TASK_LEN),
        };

        return self.last_task;
    }

    fn thread(self: *Self) void {
    }


    fn start(self: *Self) !void {
        const cpu_count = try std.Thread.getCpuCount();

        const threads = try self.allocator.alloc(cpu_count, std.Thread, cpu_count);

        for (0..cpu_count) |i| {
            threads[i] = try std.Thread.spawn(.{}, Self., .{self});
        }

        for (threads) |thread| {
            thread.join();
        }
    }
};

pub fn main() !void {

    var sync = Synchronizer.init();

    for (0..100) |_| {
        const t = try sync.nextTask();
        t.dprint();
    }

}
