/// Open Source Initiative OSI - The MIT License (MIT):Licensing
/// The MIT License (MIT)
/// Copyright (c) 2024 Ralph Caraveo (deckarep@gmail.com)
/// Permission is hereby granted, free of charge, to any person obtaining a copy of
/// this software and associated documentation files (the "Software"), to deal in
/// the Software without restriction, including without limitation the rights to
/// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
/// of the Software, and to permit persons to whom the Software is furnished to do
/// so, subject to the following conditions:
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///
const std = @import("std");

/// A generic circular buffer built on top of a fixed-size array.
pub fn CircularBuf(comptime T: type, S: comptime_int) type {
    return struct {
        const Self = @This();

        head: usize = 0,
        tail: usize = 0,
        size: usize = 0,

        items: [S]T align(64),

        // init, initializes the circular buffer by filling it with zeroes.
        pub fn init(self: *Self) void {
            for (0..S) |_| {
                self.push(0);
            }
        }

        // Push a new value onto the circular array
        pub inline fn push(self: *Self, value: T) void {
            if (self.size == S) {
                // The array is full, overwrite the oldest value
                self.head = (self.head + 1) % S;
            } else {
                self.size += 1;
            }
            self.items[self.tail] = value;
            self.tail = (self.tail + 1) % S;
        }

        pub fn debug(self: *const Self) void {
            std.log.debug(
                "self.size: {d}, self.head: {d}, self.tail: {d}",
                .{
                    self.size,
                    self.head,
                    self.tail,
                },
            );
        }

        pub inline fn atIndex(self: *const Self, val: usize) T {
            const idx = (self.head + val) % S;
            return self.items[idx];
        }

        // Function to iterate over the circular array from the oldest value
        pub fn print(self: *Self) void {
            std.log.debug("Start:--------", .{});
            for (0..self.size) |i| {
                const idx = (self.head + i) % S;
                std.log.debug("val => {d}", .{self.items[idx]});
            }
            std.log.debug("End:--------", .{});
        }
    };
}
