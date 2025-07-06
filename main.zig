const std = @import("std");
const assert = std.debug.assert;

const memmove = std.mem.copyForwards;



const BinaryCodedDecimal = struct {
    // represents the 
    mod_15: u8,
    slice: []u8,

    /// takes in a slice which it may modify
    pub fn init(slice: []u8) BinaryCodedDecimal {
        @memset(slice, '0');
        return BinaryCodedDecimal{
            .base_memory = base_memory,
            .slice = base_memory[base_memory.len-1..base_memory.len],
            .mod_15 = 0,
        };
    }

    fn is_last(self: BinaryCodedDecimal) bool {
        for (self.slice) |letter| {
            if (letter != '9') return false;
        }
        return true;
    }

    // increment must be less than 10
    // `to` must be the same length as `self.slice`
    // returns the index of the highest digit changed 
    fn write_increment(self: BinaryCodedDecimal, to: []u8, increment: u8) void {
        assert(increment <= 15);
        
        var i = self.base_memory.len - 1;

        var increment_remaining: u8 = increment;
        var prev_carry: u8 = 0;
        while (true) : ({i -= 1; increment_remaining /= 10;}) {
            const was = self.base_memory[i];
            const next_digit_value = (was - '0') + (increment_remaining % 10) + prev_carry;
            to[i] = '0' + (next_digit_value % 10);
            prev_carry = next_digit_value/10;
        }
    }

    /// `increment <= 15`
    fn self_increment(self: *BinaryCodedDecimal, increment: u8) void {
        self.mod_15 = @intCast((self.mod_15 + increment) % 15);
        const bytes_written = self.write_increment(self.base_memory, increment);
    }
};

const Buzzer = struct {
    const Self = @This();

    const FIZZ_STR = "Fizz\n";
    const BUZZ_STR = "Buzz\n";
    const FIZZBUZZ_STR = "FizzBuzz\n";

    

    /// The total count of numbers considered 
    const considered_numbers = std.math.powi(usize, 10, Self.digits);
        
    allocator: std.mem.Allocator,
    digits: usize,

    // derived from the length of the numbers and stuff
    segment_size: usize,

    // the block size is NOT a multiple of the segment size
    block_size: usize,
    
    pub fn init(allocator: std.mem.Allocator, digits: usize) Self {
        const seg = 8*(digits+1) + 4*FIZZ_STR.len + 2*BUZZ_STR.len + 1*FIZZBUZZ_STR.len;
        return Self{
            .digits = digits,
            .segment_size =  seg,
            .block_size = (1 << 14),
            .allocator = allocator,
        };
    }

    // Forms a bridge between two buffers
//    fn bridge(self: Self, bcd: BinaryCodedDecimal, buffer1: []u8, buffer2: []u8) void {
        
//    }

    fn my_test(self: Self) !void {
        const stdout = std.io.getStdOut().writer();
        const x = try self.allocator.alloc(u8, 10*self.segment_size);
        const bcd_slice = try self.allocator.alloc(u8, self.digits);
        const bcd = BinaryCodedDecimal.init(bcd_slice);
        _ = self.write_segment(bcd, x);
        defer self.allocator.free(x);
        defer self.allocator.free(bcd_slice);
        try stdout.print("{s}", .{x[0..x.len]});
    }


    
    /// This is a segment
    /// 1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz
    /// bcd should be the first entry in our sequence
    /// returns number of chars written
    fn write_segment(self: Self, bcd: BinaryCodedDecimal, at: []u8) usize {

        const WriteType = enum {
            number, fizz, buzz, fizzbuzz,
        };
        const rule = [_]WriteType{
            WriteType.number, WriteType.number, WriteType.fizz, 
            WriteType.number, WriteType.buzz, WriteType.fizz, 
            WriteType.number, WriteType.number, WriteType.fizz,
            WriteType.buzz, WriteType.number, WriteType.fizz,
            WriteType.number, WriteType.number, WriteType.fizzbuzz,
        };
        

        var write_index: usize = 0;
        inline for (rule, 0..) |wt, i| {
            switch (wt) {
                WriteType.number => {
                    _ = bcd.write_increment(at[write_index..write_index+self.digits], @intCast(i));
                    at[write_index+self.digits] = '\n';
                    write_index += self.digits+1;
                },
                WriteType.fizz => {
                    memmove(u8, at[write_index..], FIZZ_STR);
                    write_index += FIZZ_STR.len;
                },
                WriteType.buzz => {
                    memmove(u8, at[write_index..], BUZZ_STR);
                    write_index += BUZZ_STR.len;
                },
                WriteType.fizzbuzz => {
                    memmove(u8, at[write_index..], FIZZBUZZ_STR);
                    write_index += FIZZBUZZ_STR.len;
                },
            }
        }
        return write_index;
    }

};


// 16.8 MiB/s
fn naive2() !void {
    const stdout = std.io.getStdOut().writer();
    var i: usize = 0;
    while (true) : (i += 15) {
        try stdout.print("{d}\n{d}\nFizz\n{d}\nBuzz\nFizz\n{d}\n{d}\nFizz\nBuzz\n{d}\nFizz\n{d}\n{d}\nFizzBuzz\n", .{i+1, i+2, i+4, i+7, i+8, i+11, i+13,i+14});
    }
}

// 9 MiB/s
fn naive() !void {
    const stdout = std.io.getStdOut().writer();
    for (0..100_000_000) |i| {
        if (i % 3 == 0 and i % 5 == 0) {
            try stdout.print("FizzBuzz\n", .{});
        } else if (i % 3 == 0) {
            try stdout.print("Fizz\n", .{});
        } else if (i % 5 == 0) {
            try stdout.print("Buzz\n", .{});
        } else {
            try stdout.print("{d}\n", .{i});
        }
    }
}
    

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    var buzzer = Buzzer.init(allocator, 10);
    try buzzer.my_test();


}
