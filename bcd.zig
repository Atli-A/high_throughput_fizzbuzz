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

const StandardFizzBuzz = [_]FizzBuzzToken{
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz,
    FizzBuzzToken.Number, FizzBuzzToken.Buzz,   FizzBuzzToken.Fizz,
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz,
    FizzBuzzToken.Buzz,   FizzBuzzToken.Number, FizzBuzzToken.Fizz,
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.FizzBuzz,
};

const BASE = 10

const FizzBuzzConfig = struct {
    number_len: usize,
    fizz: []const u8,
    buzz: []const u8,
    fizzbuzz: []const u8,
    seperator: []const u8,
};

/// a FizzBuzzer is in charge of printing
///
/// some definitions
/// token: a fizz, buzz, fizzbuzz, or number
/// segment: a continuous list of 15 fizzbuzz elements starting anywhere in the pattern
/// run: a continuous set of tokens where all numbers can be incremented whose factors include at least one 10 to get the next run.
/// block: a piece of memory of BLK_SIZE to be written to stdout
fn FizzBuzzer(comptime _number_len: comptime_int) type {
    const Sequence: []const FizzBuzzToken = &StandardFizzBuzz;
    const conf = FizzBuzzConfig{
        .number_len = _number_len,
        .fizz = "Fizz",
        .buzz = "Buzz",
        .fizzbuzz = "FizzBuzz",
        .seperator = "\n", // should be newline
    };


    // NOTE FOR SELF BENCHMARKING
    // we want to minimize total_cost
    // total_cost = create_cost_per_part*RUN_LENGTH + increment_cost_per_part*(total_length/RUN_LENGTH)
    // total_length = 10^(number_len-1)
    // RUN_LENGTH = run_increment * 10^(run_index)
    // when self benchmarking, this allows us to quickly calculate the optimal run length by minimizing total cost with respoect to total length in the above equation.
    const run_increment: usize = 3;
    const run_index: usize = 7
    const RUN_LENGTH: usize = run_increment * comptime_powi(10, run_index);
    // the amount of memory used by a run_length
    const RUN_MEMORY: usize = @compileError("TODO"); // TODO use segemnts and remainders to calculate it

    const BLK_SIZE = 1 << 16;
    
    // rationale: must be 3*10^x since we start at 10^(conf.number_len - 2) and then we can add 10^(conf.number_len - 3) 3 times to write
    const REPEAT_SIZE = 1 << 24;

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        number: StrInt(conf.number_len),
        // 
        mem: []u8,

        fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .number = StrInt(conf.number_len).init() };
        }

        fn alloc(self: *Self) !void { 
            self.mem = try self.allocator.alloc(u8, RUN_MEMORY);
        }

        fn create_run(self: *Self) void {
            // 1. in loop create all the core segments 
            @call(.always_inline, self.create_segment, .{0, 0, 0});

            // 2. create remainder segment
            @call(.always_inline, self.create_segment, .{0, 0, 0});
        }

        fn increment_run(self: *Self) void {

        }

        fn write_block_if_possible(self: *Self) void {
                        
        }

        fn create_segment(self: *Self, comptime sequence: []const FizzBuzzToken, memory: []u8) usize {
            var wi: usize = 0;
            inline for (sequence) |token| {
                wi += switch (token) {
                    .Fizz => blk: {
                        @memcpy(memory[wi .. wi + conf.fizz.len], conf.fizz);
                        break :blk conf.fizz.len;
                    },
                    .Buzz => blk: {
                        @memcpy(memory[wi .. wi + conf.buzz.len], conf.buzz);
                        break :blk conf.buzz.len;
                    },
                    .FizzBuzz => blk: {
                        @memcpy(memory[wi .. wi + conf.fizzbuzz.len], conf.fizzbuzz);
                        break :blk conf.fizzbuzz.len;
                    },
                    .Number => blk: {
                        // ugly syntax from here
                        // https://ziggit.dev/t/coercing-a-slice-to-an-array/2416/5
                        self.number.to_str(&(memory[wi..][0..conf.number_len].*));
                        break :blk conf.number_len;
                    },
                };
                @memcpy(memory[wi .. wi + conf.seperator.len], conf.seperator);
                wi += conf.seperator.len;
            }

            return wi;
        }

    };
}

pub fn main() !void {
    inline for (1..20) |i| {
        var fb = FizzBuzzer(i).init(std.heap.page_allocator);
        try fb.start();
    }
    
}
