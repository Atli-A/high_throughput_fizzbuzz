const std = @import("std");
const builtin = @import("builtin");

const dprint = std.debug.print;
const assert = std.debug.assert;
const testing = std.testing;

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

        number: UnionType align(1),
        
        const BASE = 10;
        const MIN_INTERNAL: u8 = 0xFF - (BASE - 1);
        const endianness = builtin.target.cpu.arch.endian();

        pub fn init() Self {
            if (@bitSizeOf(IntType) != @bitSizeOf(UnionType) or 
                @bitSizeOf(StrType) != @bitSizeOf(UnionType)) {
                @compileError(std.fmt.comptimePrint("mismatch sizes", .{}));
            }
            return .{ .number = UnionType{ .int = 0 }, };
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

        pub fn assign(self: *Self, comptime x: comptime_int) void {
            self.number.str = comptime blk: {
                var arr_c: []const u8 = std.fmt.comptimePrint("{d}", .{x});
                const factor = length - arr_c.len;
                if (factor < 0) {
                    @compileError(std.fmt.comptimePrint("Cannot assign {d} to StrInt of width {d}", .{x, length}));
                }
                arr_c = "0"**factor ++ arr_c;
                break :blk arr_c[0..length].*;
            };
            self.invariant();
        }

        fn invariant(self: Self) void {
            assert(@reduce(.And, self.number.str <= splat('9')));
            assert(@reduce(.And, self.number.str >= splat('0')));
        }

        pub fn add(self: *Self, x: u8) void {
            if (comptime endianness == .little) {
                self.number.str = byteSwap(self.number.str);
            }

            self.number.str += splat(MIN_INTERNAL - '0');

            // add
            self.number.int +%= x;

            const wrapped_over = self.number.str < splat(MIN_INTERNAL);
            self.number.str -= @select(u8, wrapped_over, splat(0), splat(MIN_INTERNAL));
            self.number.str += splat('0');

            if (comptime endianness == .little) {
                self.number.str = byteSwap(self.number.str);
            }
            
            self.invariant();
        }

        pub fn to_str(self: *Self, out: *ArrType) void {
            out.* = self.number.str;
            self.invariant();
        }
    };
}

test "strs" {
    const T = StrInt(5);
    var x = T.init();
    x.assign(1);

    var out: T.ArrType = undefined;
    x.to_str(&out);

    try testing.expectEqualSlices(u8, &out, "00001");
    

    x.assign(54321);
    x.to_str(&out);
    try testing.expectEqualSlices(u8, &out, "54321");
    
    x.assign(100);
    x.to_str(&out);
    try testing.expectEqualSlices(u8, &out, "00100");
}

test "add" {
    const T = StrInt(5);
    var x = T.init();
    var out: T.ArrType = undefined;


    x.assign(1);
    x.to_str(&out);
    try testing.expectEqualSlices(u8, &out, "00001");

    x.add(1);
    x.to_str(&out);
    try testing.expectEqualSlices(u8, &out, "00002");

    x.add(10);
    x.to_str(&out);
    try testing.expectEqualSlices(u8, &out, "00012");
}



// TODO try u4 based version 
