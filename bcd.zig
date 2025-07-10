const std = @import("std");

const dprint = std.debug.print;
const assert = std.debug.assert;

/// if implementation fails
/// https://stackoverflow.com/questions/55802309/is-there-a-256-bit-integer-type-in-c

/// Golden Sequence:
///
/// Consider one fizzbuzz segment which matches the following 
/// where every number is the same width.
/// Example (' ' = '\n', '#' = number, 'F' = 'Fizz', B = 'Buzz', FB = 'FizzBuzz'):
/// # # F # B F # # F B # F # # FB
///
/// Since all the numbers are of known width the length of this string is 
/// comptime known when len(#) is comptime known.
///
/// Additionally, we treat the whole string as a large number
/// 
/// since the ascii digits 0 to 9 are in binary as ?011 XXXX
/// so '0' is naturally stored as 0011 0000
/// however we will store it as 1111 0111. (adding 7 to the original)
/// This allows for adding to overflow to the next byte.
/// All non number bytes are stored as 1111 1111
///
/// For example the segment matching the string "11 Fizz 13 14 FizzBuzz" becomes
/// parantheses group words
/// 
/// '11 '   1111_1000 1111_1000 1111_1111 
/// 'Fizz ' 1111_1111 1111_1111 1111_1111 1111_1111 1111_1111  
/// '13 '   1111_1000 1111_1010 1111_1111 
/// '14 '   1111_1000 1111_1011 1111_1111 
/// 'FizzBuzz ' 1111_1111 1111_1111 1111_1111 1111_1111 1111_1111 1111_1111 1111_1111 1111_1111 1111_1111 
///
///
/// to convert these stored numbers to their string version we must perform 
/// several operations 
///
/// what we do for letters does not matter
/// but for each byte we do the following
/// 1111_XXXX -> 0011_(XXXX - 7)
/// 
/// 1 = 1111_1000 => 0011_0001 = '1'


// fizzbuzz tokens are seperated by a seperator
const FizzBuzzToken = enum {
    Number, 
    Fizz, 
    Buzz, 
    FizzBuzz, 
};

const StandardFizzBuzz = [_]FizzBuzzToken{
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Number, FizzBuzzToken.Buzz, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Buzz, FizzBuzzToken.Number, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.FizzBuzz,
};

fn TokensToSequenceLen(sequence: []FizzBuzzToken, num_len: usize, fizz_len: usize, buzz_len: usize, fizzbuzz_len: usize, sep_len: usize) usize {
    const total: usize = 0;
    for (sequence) |token| {
        total += switch (token) {
            FizzBuzzToken.Number => num_len,
            FizzBuzzToken.Fizz => fizz_len,
            FizzBuzzToken.Buzz => buzz_len,
            FizzBuzzToken.FizzBuzz => fizzbuzz_len,
        };
        total += sep_len;
    }
    return total;
}


fn createInt(bits: comptime_int) type {
    return @Type(
        std.builtin.Type{
            .@"int"=std.builtin.Type.Int{
                .signedness=std.builtin.Signedness.unsigned,
                .bits=bits,
            }
        }
    );
}


fn GoldenSegment(comptime num_len: comptime_int) type {

    const FIZZ: []const u8 = "Fizz";
    const BUZZ: []const u8 = "Buzz";
    const FIZZBUZZ: []const u8 = "FizzBuzz";
    const SEPERATOR: []const u8 = "|";
    const NULLCHAR: []const u8 = &[1]u8{0x00};
    const ZERO: []const u8 = NULLCHAR**num_len;
    const EMPTY: []const u8 = "";



    comptime var textLayerSlice = EMPTY;
    inline for (StandardFizzBuzz) |token| {
        textLayerSlice = textLayerSlice ++ switch (token) {
            FizzBuzzToken.Number => ZERO,
            FizzBuzzToken.Fizz => FIZZ,
            FizzBuzzToken.Buzz => BUZZ,
            FizzBuzzToken.FizzBuzz => FIZZBUZZ,
        };
        textLayerSlice = textLayerSlice ++ SEPERATOR;
    }

    const num_bytes = textLayerSlice.len;

    const NumberType = createInt(num_bytes*8);
//    const NumberStrInt = createInt(num_len*8);
    const VectorType = @Vector(num_bytes, u8);
    const VectorBoolType = @Vector(num_bytes, bool);
//    const ArrayType = [num_bytes]u8;

    const textLayer: VectorType = textLayerSlice[0..].*;

    // true when byte is text not number
    const textMask: VectorBoolType = textLayer != @as(VectorType, @splat(0x00));

    // the default starting number and stuff
    const number_default = @as(VectorType, @splat(0b1111_0110));
    const text_default = @as(VectorType, @splat(0xFF));
    const default_value = @select(u8, textMask, text_default, number_default);
    

    return struct {
        const Self = @This();

        const UnionType = packed union {
            number: NumberType,
            vector: VectorType,
//            array: ArrayType,
        };
        const len_bytes = num_bytes;

        data: UnionType,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator) !Self {
//            dprint("{s}\n", .{textLayer});
//            dprint("{s}\n", .{textMask});

            // TODO align
            const memory = try allocator.alloc(u8, num_bytes);
            // so the compiler knows its aligned
            const vector: VectorType = memory[0..num_bytes].*;
            return .{
                .allocator = allocator,
                .data = UnionType{ .vector = vector},
            };
        }

        /// initializes to the zero value for our internal number
        fn initial(self: *Self) void {
            self.data.vector = default_value;
        }

        fn splat(comptime n: comptime_int) VectorType {
            return @as(VectorType, @splat(n));
        }

        fn to_str(self: Self) VectorType {
            const safe_version = true;
            var reformed_numbers: VectorType = undefined;
            if (safe_version) {
                reformed_numbers = (
                    (
                     // isolate lower 4 bits and subtract
                     (splat(0x0F) & self.data.vector) - splat(6)
                     & splat(0x0F) // re-isolate to be safe
                    )
                    // upper 4 bits
                    | splat(0x30)
                );
            } else {
                // unsafe because i'm not confident it works but its (prolly) faster
                reformed_numbers = (
                    // remove 6 this is a safe subtraction since we add 
                    //   seven to the base of any wont affect to the least four
                    //   significant bits other than subtraction
                    (self.data.vector - splat(6))
                    // forcibly set the upper bits
                    | splat(0x30)
                );
            }
            // mix in words
            return @select(u8, textMask, textLayer, reformed_numbers);
        }


        /// destructive
        fn add(self: *Self, adding: u64) void {

            // add to the number 
            self.data.number = @byteSwap(@byteSwap(self.data.number) + @as(NumberType, @intCast(adding)));

            // restore rules so this stuff can be used again
            // this allows us to |= the internal representation with reset_mask to make it ready to be added to again
            const less_than_seven: VectorBoolType = self.data.vector <= splat(6);
            const seven_corrected = self.data.vector + @select(u8, less_than_seven, splat(6), splat(0));
            self.data.vector = @select(u8, 
                textMask, 
                splat(0xFF), 
                seven_corrected | splat(0x30)
            );
        }

        fn verify_internal_representation(self: Self) void {
            // TODO @reduce over internal vector and verify that lower 4 bits always >= 7
            // assert();
            _ = self;
        }
        
        /// destructive
        fn free(self: Self) void {
            self.allocator.free(self.data.vector);
        }
    };
}



pub fn main() !void {
    const T = GoldenSegment(5);
    var x = try T.init(std.heap.page_allocator);
    x.initial();
    var asdf: [T.len_bytes]u8 = x.to_str();
    asdf = x.to_str();
    dprint("{s}\n", .{asdf});
    for (0..10000) |_| {
        asdf = x.to_str();
    }
    dprint("{s}\n", .{asdf});


}



// the current problem and how to fix it 
// currently realized a problem with how this is done
// right now we are adding to the whole block like it is one thing.
// this is close to but not correct
// however, i think this is saveable
// first start using the newlines and other text as buffers
// then add to the first byte of a number but not the whole thing
// this can be done comptime at the begginning
//
//
//
//
// problem endianness when adding:
// 
//
// u4 version:
// 1111 
//
//
//
//
//
//
