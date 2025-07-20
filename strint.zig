const std = @import("std");
const builtin = @import("builtin");

const dprint = std.debug.print;
const assert = std.debug.assert;

pub fn comptime_powi(x: comptime_int, y: comptime_int) comptime_int {
    var result = 1;
    for (0..y) |_| {
        result *= x;
    }
    return result;
}

pub fn StrInt(comptime _len: comptime_int) type {
    return struct {
        const Self = @This();
        const length = _len;

        const IntType = std.math.IntFittingRange(0, 1 << (length * 8 - 1));
        const StrType = @Vector(length, u8);
        const ArrType = [length]u8;

        const UnionType = packed union {
            str: StrType,
            int: IntType,
        };

        const byteSwap = if (true) shuffleByteSwap else wrappedByteSwap;

        number: UnionType,

        const ZERO_VALUE: u8 = 0xF6;
        const MIN_INTERNAL: u8 = ZERO_VALUE & 0x0F;
        const endianness = builtin.target.cpu.arch.endian();

        pub fn init() Self {
            if (@bitSizeOf(IntType) != @bitSizeOf(UnionType) or @bitSizeOf(StrType) != @bitSizeOf(UnionType)) {
                @compileError(std.fmt.comptimePrint("mismatch sizes {} {} {}", .{IntType, UnionType, StrType}));
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

        pub fn assign(self: *Self, comptime x: comptime_int) void {
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

        pub fn add(self: *Self, x: u8) void {
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

        pub fn to_str(self: *Self, out: *ArrType) void {
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


