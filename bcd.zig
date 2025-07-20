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

const BASE = 10;

const FizzBuzzConfig = struct {
    number_len: usize,
    fizz: []const u8,
    buzz: []const u8,
    fizzbuzz: []const u8,
    seperator: []const u8,

    const Self = @This();

    fn tokenToLength(self: Self, token: FizzBuzzToken) usize {
        return switch (token) {
            .Number => self.number_len,
            .Fizz => self.fizz.len,
            .Buzz => self.buzz.len,
            .FizzBuzz => self.fizzbuzz.len,
        };
    }
    
    fn tokenToLengthWithSeperator(self: Self, token: FizzBuzzToken) usize {
        return self.tokenToLength(token) + self.seperator.len;
    }
};


fn segmentData(conf: FizzBuzzConfig, comptime sequence: []const FizzBuzzToken) type {
    var index: usize = 0;
    @setEvalBranchQuota(1 << 16);
    var integer_indices_internal: [std.mem.count(FizzBuzzToken, sequence, &[1]FizzBuzzToken{.Number})]usize = undefined;
    var integer_indices_write_index: usize = 0;
    inline for (sequence) |token| {
        if (token == .Number) {
            integer_indices_internal[integer_indices_write_index] = index;
            integer_indices_write_index += 1;
        }
        index += conf.tokenToLengthWithSeperator(token);
    }
    const x = index;
    const y = integer_indices_internal;
    return struct {
        const segment_bytes = x;
        const integer_indices = y;
    };
}

/// a FizzBuzzer is in charge of printing
///
/// some definitions
/// token: a fizz, buzz, fizzbuzz, or number
/// segment: a continuous list of 15 fizzbuzz elements starting anywhere in the pattern
/// run: a continuous set of tokens where all numbers can be incremented whose factors include at least one 10 to get the next run.
/// block: a piece of memory of BLK_SIZE to be written to stdout
fn FizzBuzzer(comptime _number_len: comptime_int) type {
    const Sequence: []FizzBuzzToken = @constCast(StandardFizzBuzz[0..]);
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
    const run_index: usize = @max(0, @as(comptime_int, conf.number_len) - 2);
    // RUN_LENGTH is in tokens
    //
    const RUN_LENGTH: usize = run_increment * comptime_powi(10, run_index);

    const starting_number = comptime_powi(10, conf.number_len - 1);

    const rotated_sequence: []const FizzBuzzToken = Sequence[(starting_number % Sequence.len)..] ++ Sequence[0..(starting_number % Sequence.len)];

    const segment_count = RUN_LENGTH/rotated_sequence.len;
    const segment_data = segmentData(conf, rotated_sequence);

    const remainder_sequence = rotated_sequence[0..RUN_LENGTH % rotated_sequence.len];
    const remainder_data = segmentData(conf, remainder_sequence);

    // the amount of memory used by a run_length
    const RUN_MEMORY: usize = segment_data.segment_bytes*segment_count + remainder_data.segment_bytes; // TODO use segemnts and remainders to calculate it

    const BLK_SIZE = 1 << 16;
    
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        number: StrInt(conf.number_len),
        // 
        mem: []u8,

        fn init(allocator: std.mem.Allocator) !Self {
            return .{ .allocator = allocator, .number = StrInt(conf.number_len).init(), .mem = try allocator.alloc(u8, RUN_MEMORY), };
        }

        fn create_run(self: *Self) void {
            self.number.assign(starting_number + 1);
            var create_index: usize = 0;
            var write_index: usize = 0;
            // 1. in loop create all the core segments 
            for (0..segment_count) |_| {
                create_index += @call(.always_inline, Self.create_segment, .{self, rotated_sequence, self.mem[create_index..]});
                if (create_index - write_index >= BLK_SIZE) {
                    _ = vmsplice(std.posix.STDOUT_FILENO, self.mem[write_index..][0..BLK_SIZE]);
                    write_index += BLK_SIZE;
                }
            }

            // 2. create remainder segment
            create_index += @call(.always_inline, Self.create_segment, .{self, remainder_sequence, self.mem[create_index..]});
            _ = vmsplice(std.posix.STDOUT_FILENO, self.mem[write_index..create_index]);
        }

        fn increment_run(self: *Self) void {
            var position: usize = 0;
            for (0..segment_count) |_| {
                @call(.always_inline, Self.increment_segment, .{self, segment_data.integer_indices, self.mem[position..]});
                position += segment_data.segment_bytes;
            }
            @call(.always_inline, Self.increment_segment, .{self, remainder_data.integer_indices, self.mem[position..]});
            position += remainder_data.segment_bytes;
        }

        fn create_segment(self: *Self, comptime sequence: []const FizzBuzzToken, memory: []u8) usize {
            var wi: usize = 0;
            var last_i: usize = 0;
            inline for (sequence, 0..) |token, i| {
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
                        self.number.add(@intCast(i - last_i));
                        last_i = i;
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
        
        fn increment_segment(self: *Self, comptime number_indices: []usize, memory: []u8) void {
            inline for (number_indices) |index| {
                @as(StrInt(conf.number_len - run_index), &memory[index]).add(run_increment);
            }
        }

    };
}

pub fn main() !void {
    inline for (3..5) |i| {
        var fb = try FizzBuzzer(i).init(std.heap.page_allocator);
        fb.create_run();
    }
    
}
