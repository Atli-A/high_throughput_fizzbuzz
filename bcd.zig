const std = @import("std");

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
/// however we will store it as 1111 0111.
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



fn GoldenSegment(comptime num_len: usize) type {
    const FIZZ: []const u8 = "Fizz";
    const BUZZ: []const u8 = "Buzz";
    const FIZZBUZZ: []const u8 = "FizzBuzz";
    const SEPERATOR: []const u8 = "\n";
    const ZERO: []const u8 = ([1]u8{0})[0..];

    comptime var textLayer: []u8 = &[0]u8{};
    inline for (StandardFizzBuzz) |token| {
        
        const temp: []u8 = switch (token) {
            FizzBuzzToken.Number => ZERO**num_len,
            FizzBuzzToken.Fizz => FIZZ,
            FizzBuzzToken.Buzz => BUZZ,
            FizzBuzzToken.FizzBuzz => FIZZBUZZ,
        };
        textLayer = textLayer ++ temp;
        textLayer = textLayer ++ SEPERATOR;
    }
    @compileLog(textLayer);



    return struct {
        const Self = @This();
    };
}



pub fn main() !void {
    const x: GoldenSegment(1) = undefined;
    _ = x;
}
