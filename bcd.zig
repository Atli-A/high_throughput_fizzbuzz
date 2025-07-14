const std = @import("std");
const builtin = @import("builtin");

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

fn comptime_powi(x: comptime_int, y: comptime_int) comptime_int {
    var result = 1;
    for (0..y) |_| {
        result *= x;
    }
    return result;
}

fn createInt(bits: comptime_int) type {
    return @Type(std.builtin.Type{ .int = std.builtin.Type.Int{
        .signedness = std.builtin.Signedness.unsigned,
        .bits = bits,
    } });
}

fn StrInt(comptime _len: comptime_int) type {
    return struct {
        const Self = @This();
        const length = _len;

        const IntType = createInt(length * 8);
        const StrType = @Vector(length, u8);
        const ArrType = [length]u8;

        const UnionType = packed union {
            str: StrType,
            int: IntType,
        };

        const byteSwap = if (false) shuffleByteSwap else wrappedByteSwap;

        number: UnionType,
        const ZERO_VALUE: u8 = 0xF6;
        const MIN_INTERNAL: u8 = ZERO_VALUE & 0x0F;
        const endianness = builtin.target.cpu.arch.endian();

        fn init() Self {
            if (@bitSizeOf(IntType) != @bitSizeOf(UnionType) or @bitSizeOf(StrType) != @bitSizeOf(UnionType)) {
                @compileError(std.fmt.comptimePrint("mismatch sizes", .{}));
            }
            return .{
                .number = UnionType{ .int = 0 },
            };
        }

        fn splat(x: u8) StrType {
            return @splat(x);
        }

        fn wrappedByteSwap(s: StrType) StrType {
            return @byteSwap(s);
        }

        fn shuffleByteSwap(s: StrType) StrType {
            comptime var mask_arr: [length]i32 = undefined;
            comptime {
                for (0..mask_arr.len) |i| {
                    mask_arr[i] = length - 1 - i;
                }
            }
            const mask: @Vector(length, i32) = mask_arr;
            const unused: StrType = undefined;
            
            return @shuffle(u8, s, unused, mask);
        }

        /// Zeroes the entire UnionType
        fn zero(self: *Self) void {
            self.number.str = splat(ZERO_VALUE);
        }

        /// sets itself to the smallest number utilizing all its digits
        fn smallest_full_len(self: *Self) void {
            self.zero();

            var x: ArrType = undefined;
            @memset(&x, 0);
            x[x.len - 1] = 1;
            self.number.str += @as(StrType, x);
        }

        fn assign(self: *Self, comptime x: comptime_int) void {
            self.zero();
            // this section sucks
            const vec: StrType = comptime blk: {
                var arr_c: []const u8 = std.fmt.comptimePrint("{d}", .{x});
                const factor = length - arr_c.len;
                if (factor < 0) {
                    @compileError(std.fmt.comptimePrint("Cannot assign constant {d} to StrInt of width {d}", ));
                }
                arr_c = "0"**factor ++ arr_c;
                break :blk arr_c[0..length].*;
            };
            assert(@reduce(.And, splat('0') <= vec) and @reduce(.And, vec <= splat('9')));
            self.number.str += byteSwap(vec) - splat('0');
        }

        fn debug(self: Self) void {
            for (0..length) |i| {
                dprint("{0X:0<2.2} ", .{self.number.str[i]});
            }
            dprint("\n", .{});
        }

        fn invariant(self: Self) void {
            assert(@reduce(.And, ((self.number.str & splat(0x0F)) >= splat(MIN_INTERNAL))));
        }

        fn add(self: *Self, x: u8) void {
            // add
            self.number.int +%= x;

            // where we need to add 7
            const need_correction = (splat(0x0F) & self.number.str) < splat(MIN_INTERNAL);
            // currect when we need to add 7
            self.number.str +%= @select(u8, need_correction, splat(MIN_INTERNAL), splat(0x00));
            // set upper 4 bits to 1
            self.number.str |= splat(0xF0);
            self.invariant();
        }


        fn to_str(self: *Self, out: *ArrType) void {
            if (comptime endianness == .little) {
                self.number.str = byteSwap(self.number.str);
            }

            out.* = (
                // the lower 4 bits are just the number itself not its internal representation
                (self.number.str & splat(0x0F)) - splat(MIN_INTERNAL)
                    // upper bits are just 0x30
                | splat(0x30));

            if (comptime endianness == .little) {
                self.number.str = byteSwap(self.number.str);
            }
        }
    };
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

const FizzBuzzConfig = struct {
    number_len: usize,
    fizz: []const u8,
    buzz: []const u8,
    fizzbuzz: []const u8,
    seperator: []const u8,
};

const Template = struct {
    const Number = struct {
        increment: u8, // the increment from the previous number (0) for the first
        index_in_template: usize,
    };

    template: []const u8,
    numbers: []const Number,
    trailing_increment: usize,

};

fn buildSegmentTemplate(Sequence: []const FizzBuzzToken, conf: FizzBuzzConfig) Template {
    const zero_arr: []const u8 = &.{0x00};

    var result: Template = undefined;

    result.template = "";
    result.numbers = &.{};

    var last_i = 0;
    inline for (Sequence, 0..) |Token, i| {
        const to_add = switch (Token) {
            .Number => blk: {
                const to_add: Template.Number = .{
                    .increment = @intCast(@as(comptime_int, i) - last_i), 
                    .index_in_template = result.template.len,
                };
                result.numbers = result.numbers ++ &[1]Template.Number{to_add};
                last_i = i;
                break :blk zero_arr ** conf.number_len;
            },
            .Fizz => conf.fizz,
            .Buzz => conf.buzz,
            .FizzBuzz => conf.fizzbuzz,
        };
        result.trailing_increment = Sequence.len - last_i;
        result.template = result.template ++ to_add ++ conf.seperator;
    }
    return result;
}

/// a FizzBuzzer is in charge of printing
fn FizzBuzzer(comptime _number_len: comptime_int) type {

    // TODO this usize will be a problem

    const Sequence: []const FizzBuzzToken = &StandardFizzBuzz;
    const conf = FizzBuzzConfig{
        .number_len = _number_len,
        .fizz = "Fizz",
        .buzz = "Buzz",
        .fizzbuzz = "FizzBuzz",
        .seperator = "\n", // should be newline
    };

    const starting_number = comptime_powi(10, conf.number_len - 1);
    // currently comptime only
    const segment_start_pos = (starting_number - 1) % Sequence.len;
    // 9 since we are in base 10
    const segment_count = (9 * starting_number) / Sequence.len;

    // the remainder segment is the very last one which (may) not be full length
    const remainder_segment_length = (9 * starting_number) % Sequence.len;

    const segment_sequence = Sequence[segment_start_pos..Sequence.len] ++ Sequence[0..segment_start_pos];
    const remainder_sequence = segment_sequence[0..remainder_segment_length];

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        number: StrInt(conf.number_len),

        fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .number = StrInt(conf.number_len).init() };
        }

        fn start(self: *Self) !void {
            const BLK_SIZE = 65536;
            //const BLK_SIZE = 1 << 18;
            var mem = try self.allocator.alloc(u8, 2 * BLK_SIZE);
            var wi: usize = 0;

            // to account for the fact that the writer wants to add on its very first number,
            // we must subtract by how many previous sequential tokens were not numbers

            self.number.smallest_full_len();

            for (0..segment_count) |_| {
                wi += self.write_segment_v2(segment_sequence, mem[wi..]);

                if (wi >= BLK_SIZE) {
                    _ = vmsplice(std.posix.STDOUT_FILENO, mem[0..BLK_SIZE]);
                    const unwritten = wi - BLK_SIZE;
                    @memcpy(mem[0..unwritten], mem[BLK_SIZE..wi]);
                    wi = unwritten;
                }
            }
            wi += self.write_segment_v2(remainder_sequence, mem[wi..]);
            _ = vmsplice(std.posix.STDOUT_FILENO, mem[0..wi]);
        }

        fn write_segment(self: *Self, comptime sequence: []const FizzBuzzToken, memory: []u8) usize {
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

        fn write_segment_v2(self: *Self, comptime sequence: []const FizzBuzzToken, memory: []u8) usize {

            const template = comptime buildSegmentTemplate(sequence, conf);
            @memcpy(memory[0..template.template.len], template.template);
           
            inline for (template.numbers) |num| {
                self.number.add(num.increment);
                self.number.to_str(memory[num.index_in_template..num.index_in_template+conf.number_len]);
            }
            self.number.add(template.trailing_increment);
            return template.template.len;
        }

    };
}

pub fn main() !void {
    inline for (1..20) |i| {
        var fb = FizzBuzzer(i).init(std.heap.page_allocator);
        try fb.start();
    }

}
