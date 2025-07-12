const std = @import("std");
const builtin = @import("builtin");

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


fn StrInt(comptime _len: comptime_int) type {
    return struct {
        const Self = @This();
        const length = _len;

        const IntType = createInt(length*8);
        const StrType = @Vector(length, u8);
        const ArrType = u8[length];

        const UnionType = packed union {
            str: StrType,
            int: IntType,
        };

        number: UnionType,
        const ZERO_VALUE: u8 = 0xF6;
        const MIN_INTERNAL: u8 = ZERO_VALUE & 0x0F;


        fn init() Self {
            if (@bitSizeOf(IntType) != @bitSizeOf(UnionType) or @bitSizeOf(StrType) != @bitSizeOf(UnionType)) {
                @compileError(
                    std.fmt.comptimePrint("mismatch sizes", .{})
                );
           }
            return .{
                .number = UnionType{.int = 0},
            };
        }

        fn splat(x: u8) StrType {
            return @splat(x);
        }

        /// Zeroes the entire UnionType 
        fn zero(self: *Self) void {
            self.number.str = splat(ZERO_VALUE);
        }

        fn debug(self: Self) void {
            for (0..length) |i| {
                dprint("{0X:0<2.2} ", .{self.number.str[i]});
            }
            dprint("\n", .{});
        }

        fn invariant(self: Self) void {
            assert(
                @reduce(.And, ((self.number.str & splat(0x0F)) >= splat(MIN_INTERNAL)))
            );
        }

        fn add(self: *Self, x: comptime_int) void {
            // add
            self.number.int +%= x;

            // enforce internal representation

            // where we need to add 7
            const need_correction = (splat(0x0F) & self.number.str) < splat(MIN_INTERNAL);
            // currect when we need to add 7
            self.number.str +%= @select(u8, need_correction, splat(MIN_INTERNAL), splat(0x00));
            // set upper 4 bits to 1
            self.number.str |= splat(0xF0);
            self.invariant();
        }

        fn to_str(self: *Self, out: *ArrType) void {
            const endianness = builtin.target.cpu.arch.endian();
            comptime if (endianness == .little) {
                self.number.int = @byteSwap(self.number.int);
            }

            out.* = (
                // the lower 4 bits are just the number itself not its internal representation
                (self.number.str & splat(0x0F)) - splat(MIN_INTERNAL)
                // upper bits are just 0x30
                | splat(0x30) 
            );

            comptime if (endianness == .little) {
                self.number.int = @byteSwap(self.number.int);
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
    FizzBuzzToken.Number, FizzBuzzToken.Buzz, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Buzz, FizzBuzzToken.Number, FizzBuzzToken.Fizz, 
    FizzBuzzToken.Number, FizzBuzzToken.Number, FizzBuzzToken.FizzBuzz,
};





/// a FizzBuzzer is in charge of printing 
fn FizzBuzzer(
    comptime number_length: comptime_int,
    ) type {

    // TODO this usize will be a problem
    
    const Sequence: []FizzBuzzToken = StandardFizzBuzz;
    const Fizz: u8[] = "Fizz";
    const Buzz: u8[] = "Buzz";
    const FizzBuzz: u8[] = "FizzBuzz";
    const Seperator: u8[] = "|"; // should be newline
    


    /// currently comptime only
    fn buildSegmentTemplate(FizzBuzzSequence: []FizzBuzzToken) []u8 {
        var result: u8[] = "";
        const zero_arr: u8[] = {0x00};
        inline for (Sequence) |Token| {
            result = result ++ switch (Token) {
                .Number => zero_arr**number_length,
                .Fizz => Fizz,
                .Buzz => Buzz,
                .FizzBuzz => FizzBuzz,
            };
            result = result ++ Seperator
        }
        return result;
    }
    
    const starting_number = try std.math.powi(comptime_int, 10, number_length-1);
    const segment_start_pos = (starting_number - 1) % Sequence.len;
    // 9 since we are in base 10
    const segment_count = (9*starting_number)/Sequence.len;
    /// the remainder segment is the very last one which (may) not be full length
    const remainder_segment_length = (9*starting_number) % Sequence.len;

    const template = buildSegmentTemplate(
        Sequence[segment_start_pos..Sequence.len] ++ Sequence[0..segment_start_pos]
    );
//    const remainder_template = buildSegmentTemplate(
//        Sequence[segment_start_pos..segment_start_pos+remainder_segment_length]
//    );

}



pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const digits = 5;
    const T = StrInt(digits);
    var n = T.init();

    n.zero();
    n.invariant();
    var vec: T.ArrType = undefined;
    for (0..99999) |_| {
        n.to_str(&vec);
        try stdout.print("{s}\n", .{vec});
        n.add(1);
    }
}
