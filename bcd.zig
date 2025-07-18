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

    fn calculateRepeatLength(conf: FizzBuzzConfig, sequence: []FizzBuzzToken) usize {
        // determines the smallest number such that
        // you can add a 10^x to every number and the sequence remained the same

    }
};

/// a FizzBuzzer is in charge of printing
fn FizzBuzzer(comptime _number_len: comptime_int) type {
    const Sequence: []const FizzBuzzToken = &StandardFizzBuzz;
    const conf = FizzBuzzConfig{
        .number_len = _number_len,
        .fizz = "Fizz",
        .buzz = "Buzz",
        .fizzbuzz = "FizzBuzz",
        .seperator = "\n", // should be newline
    };

    const BLK_SIZE = 1 << 16;
    const REPEAT_SIZE = 1 << 24;

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        number: StrInt(conf.number_len),
        mem: []u8,

        fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .number = StrInt(conf.number_len).init() };
        }

        fn alloc(self: *Self) !void {
            self.mem = try self.allocator.alloc(u8, 2 * BLK_SIZE);
        }

        fn start(self: *Self) void {
            
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
