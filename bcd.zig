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
fn comptime_rotate_slice(comptime T: type, comptime slice: []T, comptime by: comptime_int) []T {
    const position = by % slice.len;
    return slice[position..] ++ slice[0..position];
}

fn write_segment(comptime generator: []const FizzBuzzToken, to: []u8) usize {
    const Fizz = "Fizz";
    const Buzz = "Buzz";
    const FizzBuzz = "FizzBuzz";
    const Seperator = "\n";

    var last_i: usize = 0;
    var wi: usize = 0; // write index
    inline for (generator, 0..) |token, i| {
        if (token == .Number) {
            // ugly syntax from here
            // https://ziggit.dev/t/coercing-a-slice-to-an-array/2416/5
            self.number.to_str(&(memory[wi..][0..conf.number_len].*));
            self.number.add(@intCast(i - last_i));
            last_i = i;
        } else {
            const string = switch (token) {
                .Fizz => Fizz,
                .Buzz => Buzz,
                .FizzBuzz => FizzBuzz,
                else => unreachable,
            };
            @memcpy(memory[wi .. wi + string.len], string);
            wi += string.len;
        }
        @memcpy(memory[wi .. wi + Seperator.len], Seperator);
        wi += Seperator.len;
    }
    return wi;
}



const SegmentSetup = struct {
    core_generator: []const FizzBuzzToken,
    segment_count: comptime_int,
    remainder_generator: []const FizzBuzzToken,

    fn from(comptime generator: []const FizzBuzzToken, comptime total_number: comptime_int) SegmentSetup {
        return .{
            .core_generator = generator,
            .segment_count = total_number/generator.len,
            .remainder_generator = generator[total_number % generator.len],
        };
    }
};

const FizzBuzzer = struct {
    const Self = @This();
    mem: []u8,
    allocator: std.mem.Allocator,
    write_index: usize,


    fn init(allocator: std.mem.Allocator) Self {
        return .{
            .mem = try allocator.alloc(u8, 10000),
            .allocator = allocator,
            .write_index = 0,
        };
    }

    fn start(self: *Self) void {
        inline for (0..20) |i| {
            self.create(i);
        }
    }

    fn create(self: *Self, comptime digits: usize) void {
        const starting_number = comptime_powi(10, digits-1);
        const ending_number = comptime_powi(10, digits) - 1;
        const generator = comptime_rotate_slice(FizzBuzzToken, StandardFizzBuzz, starting_number);
        const segment_setup = SegmentSetup.from(generator, ending_number - starting_number);
       
        for (0..segment_setup.segment_count) |_| {
            self.write_index += write_segment(segment_setup.core_generator, self.mem[write_index..])
        }
        self.write_index += write_segment(segment_setup.remainder_generator, self.mem[write_index..])

    }

    fn cleanup(self: Self) void {
        self.allocator.free(self.mem);
    }

};

pub fn main() !void {
    strint.time_adds(); 
}
