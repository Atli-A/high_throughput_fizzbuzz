const std = @import("std");
const assert = std.debug.assert;

const memmove = std.mem.copyForwards;



const BinaryCodedDecimal = struct {
    
    slice: []u8,

    /// takes in a slice which it may modify
    pub fn init(slice: []u8) BinaryCodedDecimal {
        return BinaryCodedDecimal{
            .slice = slice,
        };
    }

    fn first_of_length(self: BinaryCodedDecimal) void {
        self.zero();
        self.slice[0] = '1';
    }

    fn zero(self: BinaryCodedDecimal) void {
        @memset(self.slice, '0');
    }

    fn is_last(self: BinaryCodedDecimal) bool {
        for (self.slice) |letter| {
            if (letter != '9') return false;
        }
        return true;
    }

    // increment must be less than 10
    // `to` must be the same length as `self.slice`
    fn write_increment(self: BinaryCodedDecimal, to: []u8, increment: usize) void {
        assert(self.slice.len == to.len);
        
        var i = self.slice.len - 1;
        var carry: u8 = 0;
        var increment_remaining = increment;
        while (i >= 0) : ({i -= 1; increment_remaining /= 10;}) {
            carry += @intCast(increment_remaining % 10);
            const was = self.slice[i];
            to[i] = (((was - '0') + carry) % 10) + '0';
            // saturating subtraction intentional
            carry = (carry + was) -| ('0' + 10);
            if (increment_remaining == 0 and carry == 0) break;
            
        }

        // copy rest
        if (self.slice.ptr != to.ptr) memmove(u8, to, self.slice[0..i]);
    }

    fn self_increment(self: BinaryCodedDecimal, increment: usize) void {
        self.write_increment(self.slice, increment);
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

    // the block size is a multiple of the segment size
    block_size: usize,
    
    pub fn init(allocator: std.mem.Allocator, digits: usize) Self {
        const seg = 8*(digits+1) + 4*FIZZ_STR.len + 2*BUZZ_STR.len + 1*FIZZBUZZ_STR.len;
        return Self{
            .digits = digits,
            .segment_size =  seg,
            .block_size = (1 << 10)*seg,
            .allocator = allocator,
        };
    }

    // Forms a bridge between two buffers
//    fn bridge(self: Self, bcd: BinaryCodedDecimal, buffer1: []u8, buffer2: []u8) void {
        
//    }

    fn my_test(self: Self) !void {
        const stdout = std.io.getStdOut().writer();
        const x = try self.allocator.alloc(u8, 10000*self.segment_size);
        const bcd_slice = try self.allocator.alloc(u8, self.digits);
        const bcd = BinaryCodedDecimal.init(bcd_slice);
        bcd.first_of_length();
        bcd.self_increment(1);
        const written_bytes = self.write_block(x, bcd, 0);
        defer self.allocator.free(x);
        defer self.allocator.free(bcd_slice);
        try stdout.print("{s}", .{x[0..written_bytes]});
    }


    
    /// This is a segment
    /// 1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz
    /// bcd should be the first entry in our sequence
    /// returns number of chars written
    fn write_segment(self: Self, bcd: BinaryCodedDecimal, at: []u8, start_index: usize, end_index: usize) usize {
        assert(start_index <= 15);
        assert(end_index <= 15);

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
        for (rule[start_index..end_index], start_index..) |wt, i| { // nice as inline :(
            switch (wt) {
                WriteType.number => {
                    bcd.write_increment(at[write_index..write_index+self.digits], i);
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

    /// returns what block number it ended on 
    fn write_block(self: Self, block: []u8, bcd_starter: BinaryCodedDecimal, previous_block_ended_on: usize) usize {
        assert(previous_block_ended_on <= 15);

        var write_index: usize = 0;

        var end = previous_block_ended_on;
        //const start_offset = 15 - previous_block_ended_on;
        while (write_index <= block.len - self.segment_size) {
            write_index += self.write_segment(bcd_starter, block[write_index..write_index+self.segment_size], end, 15);
            end = 0;
            bcd_starter.self_increment(15);
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
//    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//    const allocator = gpa.allocator();

//    defer {
//        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
//        if (deinit_status == .leak) @panic("TEST FAIL");
//    }

//    var buzzer = Buzzer.init(allocator, 10);
    //try buzzer.my_test();


    var x: [10]u8 = undefined;
    const bcd = BinaryCodedDecimal.init(x[0..(x.len)]);
    bcd.first_of_length();
    std.debug.print("{s}\n", .{bcd.slice});
    bcd.self_increment(98);
    std.debug.print("{s}\n", .{bcd.slice});
    bcd.self_increment(98);
    std.debug.print("{s}\n", .{bcd.slice});
}
