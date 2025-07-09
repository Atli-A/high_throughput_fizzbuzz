const std = @import("std");

const dprint = std.debug.print;

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


fn IntegerFromSliceWidth(slice: []const u8) type {
    return @Type(
        std.builtin.Type.Int{
            .signedness=std.builtin.Signedness.unsigned,
            .bits=8*slice.len,
        }
    );
}


fn GoldenSegment(comptime num_len: comptime_int) type {

    const FIZZ: []const u8 = "Fizz";
    const BUZZ: []const u8 = "Buzz";
    const FIZZBUZZ: []const u8 = "FizzBuzz";
    const SEPERATOR: []const u8 = "|";
    const NULLCHAR: []const u8 = &[1]u8{0};
    const ZERO: []const u8 = NULLCHAR**num_len;
    const EMPTY: []const u8 = "";



    comptime var textLayer = EMPTY;
    inline for (StandardFizzBuzz) |token| {
        textLayer = textLayer ++ switch (token) {
            FizzBuzzToken.Number => ZERO,
            FizzBuzzToken.Fizz => FIZZ,
            FizzBuzzToken.Buzz => BUZZ,
            FizzBuzzToken.FizzBuzz => FIZZBUZZ,
        };
        textLayer = textLayer ++ SEPERATOR;
    }

    const num_bytes = textLayer.len;
    
    // this variable is a bitmask for the text 
    comptime var textMask = EMPTY;
    inline for (textLayer) |byte| {
        textMask = textMask ++ &[1]u8{(if (byte == 0x00) 0x00 else 0xFF)};
    }

    return struct {
        const Self = @This();
        const NumberType = IntegerFromSliceWidth(textLayer);
        const VectorType = @Vector(u8, num_bytes);
        const ArrayType = [num_bytes]u8;

        const UnionType = packed union {
            number: NumberType,
            vector: VectorType,
            array: ArrayType,
        };

        data: UnionType,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator) Self {
            dprint("{s}\n", .{textLayer});
            dprint("{s}\n", .{textMask});

            // TODO align
            const memory = try allocator.alloc(u8, num_bytes);
            return .{
                .allocator = allocator,
                .data = UnionType{ .vector = @as(VectorType, memory)},
            };
        }

        fn initial(self: Self) void {
            for (0..self.num_bytes) |i| {
                self.data.array[i] = if (textLayer == 0x00) 0xF7 else 0xFF;
            }
            // last one 
            // self.data.array[self.data.array.len-1] = 1;
        }

        fn to_str(self: Self, vector: VectorType) VectorType {
            comptime const safe_version = false;
            if (safe_version) {
                return (
                    (
                     // isolate lower 4 bits and subtract
                     ((@splat(0x0F) & vector) - @splat(7))
                     & @splat(0x0F) // re-isolate to be safe
                    )
                    // upper 4 bits
                    | @splat(0x30) 
                );
            } else {
                // unsafe because i'm not confident it works but its (prolly) faster
                return (
                    // remove 7 this is a safe subtraction since we add 
                    //   seven to the base of any wont affect to the least four
                    //   significant bits other than subtraction
                    (vector - @splat(7)) 
                    // forcibly set the upper bits
                    | @splat(0x30)
                );
            }
        }


        fn build(self: Self) void {
            // should maybe use select instead @select()
             const result = (textLayer & textMask) | (self.data.vector & ~textMask);
        }

        fn free(self: Self) {
            self.allocator.free(self.data.vector);
        }
    };
}



pub fn main() !void {
    const x = GoldenSegment(3).init(std.heap.page_allocator);
    x.build();
}
