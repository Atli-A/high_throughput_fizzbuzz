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
const FizzBuzzToken = {
    Number, 
    Fizz, 
    Buzz, 
    FizzBuzz, 
};

const StandardFizzBuzz = [_]FizzBuzzToken{
    Number, Number, Fizz, Number Buzz,
    Fizz, Number, Number, Fizz, Buzz,
    Number, Fizz, Number, Number, FizzBuzz,
};

fn TokensToSequenceLen(sequence: []FizzBuzzToken, num_len: usize, fizz_len: usize, buzz_len: usize, fizzbuzz_len: usize, sep_len: usize) usize {
    const total: usize = 0;
    for (sequence) |token| {
        total += switch (FizzBuzzToken) {
            Number => num_len,
            Fizz => fizz_len,
            Buzz => buzz_len,
            FizzBuzz => fizzbuzz_len,
        };
    }
    return total;
}



fn GoldenSegment(comptime num_len: usize) type {
    const FIZZ = "Fizz";
    const BUZZ = "Buzz";
    const FIZZBUZZ = "FizzBuzz";


    const textLayer: []u8 = {};
    for (StandardFizzBuzz) |token| {
        textLayer = textLayer ++ switch (token) {
            Number => ([]u8{0})**num_len,
            Fizz => FIZZ,
            Buzz => BUZZ,
            FizzBuzz => FIZZBUZZ,
        }
    }

    @comileLog(textLayer);

    return struct {
        const Self = @This();

        fn init(allocator: std.mem.Allocator, num_len: usize) !Self {
            const segment_len = TokensToSequenceLen(&StandardFizzBuzz, num_len, FIZZ.len, BUZZ.len, FIZZBUZZ.len);

            const segment = try allocator.alloc(segment_len);

            
        }
    }
}


GoldenSegment(1);
