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

const Synchornizer = struct {
    const Task = struct {
        task_id: usize,
    };
};

const FizzBuzzer = struct {
    const BLK_SIZE = 1 << 15;
    const Self = @This();
    mem: []u8,
    allocator: std.mem.Allocator,
    pipe_index: usize,
    write_index: usize,


    fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .mem = try allocator.alloc(u8, 10000),
            .allocator = allocator,
            .write_index = 0,
            .pipe_index = 0,
        };
    }

    fn start(self: *Self) !void {
        inline for (1..20) |i| {
            try self.create(i);
        }
    }

    fn pipe(self: *Self, block: bool) void {
        if (block) {
            if (self.write_index - self.pipe_index >= BLK_SIZE) {
                _ = vmsplice(std.posix.STDOUT_FILENO, self.mem[self.pipe_index..self.pipe_index + BLK_SIZE]);
                self.pipe_index += BLK_SIZE;
            }
        } else {
            _ = vmsplice(std.posix.STDOUT_FILENO, self.mem[self.pipe_index..self.write_index]);
            self.pipe_index = self.write_index;
        }
    }

    fn create(self: *Self, comptime digits: usize) !void {
        const starting_number = comptime_powi(10, digits-1);
        const ending_number = comptime_powi(10, digits) - 1;
        const generator = comptime comptime_rotate_slice(FizzBuzzToken, StandardFizzBuzz, starting_number - 1);
        const segment_setup = SegmentSetup.from(generator, ending_number - starting_number);
        

        const byte_length = (
            segment_setup.segment_count * Config.segment_length(segment_setup.core_generator, digits)
            + Config.segment_length(segment_setup.remainder_generator, digits)
        );
        self.mem = try self.allocator.alloc(u8, byte_length);
        self.write_index = 0;
        self.pipe_index = 0;

        var number = StrInt(digits).init();
        number.assign(starting_number);
       
        for (0..segment_setup.segment_count) |_| {
            self.write_index += Config.write_segment(digits, segment_setup.core_generator, &number, self.mem[self.write_index..]);
            self.pipe(true);

        }
        self.write_index += Config.write_segment(digits, segment_setup.remainder_generator, &number, self.mem[self.write_index..]);
        self.pipe(false);
        std.time.sleep(10);
        self.allocator.free(self.mem);
    }

    fn cleanup(self: Self) void {
        self.allocator.free(self.mem);
    }

};

pub fn main() !void {
//    var fb = try FizzBuzzer.init(std.heap.page_allocator);
//    try fb.start();
    strint.time_adds();
}
