const std = @import("std");
const assert = std.debug.assert;

const memmove = std.mem.copyForwards;


const StrNumError = error{
    StringTooLarge,
};

const StrNum = struct {

    /// stores a number in string form as `123`
    string: []u8,

    /// takes in a slice which it may modify
    pub fn init(string: []u8) StrNum {
        @memset(string, '0');
        return StrNum{
            .string = string,
        };
    }

    fn from_str(self: StrNum, from: []const u8) StrNumError!void {
        if (from.len > self.string.len) {
            return error.StringTooLarge;
        }
        @memset(self.string, '0');
        @memcpy(self.string[self.string.len-from.len..self.string.len], from);
    }

    fn str(self: StrNum) []const u8 {
        return self.string;
    }

    const write_increment = write_increment_naive;

    fn write_increment_naive(self: StrNum, to: []u8, increment: usize) usize {
        var increment_remaining = increment;
        var i = self.string.len;
        var carry: usize = 0;
        while (i > 0) : ({i -= 1; increment_remaining /= 10;}) {
            const was = self.string[i-1];
            const write = (was - '0') + (increment_remaining % 10) + carry;
            const digit: u8 = @intCast((write % 10) + '0');
            to[i-1] = digit;
            carry = write/10;
        }
        return self.string.len;
    }

    fn self_increment(self: StrNum, increment: usize) usize {
        return self.write_increment(self.string, increment);
    }
};

const SegmentWriter = struct {
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


    /// This is a segment
    /// 1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz
    /// bcd should be the first entry in our sequence
    /// returns number of chars written
    fn write_segment(bcd: StrNum, at: []u8) usize {
        var write_index: usize = 0;
        inline for (rule, 0..) |wt, i| {
            switch (wt) {
                WriteType.number => {
                    const written = bcd.write_increment(at[write_index..], @intCast(i));
                    at[write_index+written] = '\n';
                    write_index += written+1;
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

const Buzzer = struct {
    const Self = @This();

    const FIZZ_STR = "Fizz\n";
    const BUZZ_STR = "Buzz\n";
    const FIZZBUZZ_STR = "FizzBuzz\n";

    

    /// The total count of numbers considered 
    const considered_numbers = std.math.powi(usize, 10, Self.digits);
        
    allocator: std.mem.Allocator,

    // derived from the length of the numbers and stuff

    // the block size is NOT a multiple of the segment size
    block_size: usize,
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .block_size = (1 << 14),
            .allocator = allocator,
        };
    }

    // all of same length
    fn run(self: Self, digits: usize) void {
        const bcd_buff = try self.allocater.alloc(digits);
        defer self.allocator.free(bcd_buff);
        bcd = StrNum.init();
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    const stdout = std.io.getStdOut().writer();

    var b1: [8]u8 = undefined;
    const bcd = StrNum.init(&b1);
    try bcd.from_str("1");

    const buzzer = Buzzer.init(allocator);
    const mem = try allocator.alloc(u8, 4096);
    defer allocator.free(mem);

    for (0..100) |i| {
        _ = i;
        _ = buzzer.write_block(bcd, mem);
        try stdout.print("{s}", .{mem});
    }



 //   const t: u2048 = 1 << 1024;

//    std.debug.print("{d}\n", .{t});

}
