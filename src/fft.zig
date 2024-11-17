const std = @import("std");
const c = @import("c_defs.zig").c;

// Modeled after: https://ziggit.dev/t/i-want-to-create-a-complex-lib/3146/5?u=castholm
const circBuf = @import("circularbuf.zig").CircularBuf;

// Original credit: @Tsoding
// Zig version: @deckarep - Ralph Caraveo: https://github.com/tsoding/musializer/blob/master/src/plug.c

const copyStyle = enum {
    memmove,
    copyForwards,
    circularBuf,
};

const selectedCopyStyle = .circularBuf;

// Should be a power of 2: 9 is safe so far.
pub const FFT_SIZE = 1 << 9; // Good enough, CPU is low.

// FFT Analyzer data - aligning all of them to start on a cache line.
const CACHE_LINE_SIZE_BYTES = 8;
var out_raw: [FFT_SIZE]std.math.Complex(f32) align(CACHE_LINE_SIZE_BYTES) = undefined;
var in_raw: [FFT_SIZE]f32 align(CACHE_LINE_SIZE_BYTES) = undefined;
var in_raw_circBuf = circBuf(f32, FFT_SIZE){
    .items = undefined,
};
var in_win: [FFT_SIZE]f32 align(CACHE_LINE_SIZE_BYTES) = undefined;
var out_log: [FFT_SIZE]f32 align(CACHE_LINE_SIZE_BYTES) = undefined;
var out_smooth: [FFT_SIZE]f32 align(CACHE_LINE_SIZE_BYTES) = undefined;
var out_smear: [FFT_SIZE]f32 align(CACHE_LINE_SIZE_BYTES) = undefined;

// Generate the hann window table at comptime.
const hannTable: [FFT_SIZE]f32 align(CACHE_LINE_SIZE_BYTES) = blk: {
    @setEvalBranchQuota(FFT_SIZE + 1);
    var tbl: [FFT_SIZE]f32 = undefined;
    for (0..FFT_SIZE) |i| {
        const t = @as(f32, @floatFromInt(i)) / (FFT_SIZE - 1);
        const hann: f32 = 0.5 - 0.5 * @cos(2 * std.math.pi * t);
        tbl[i] = hann;
    }
    break :blk tbl;
};

// Question: can i align fields of a struct?
const Foo = struct {
    a: u32 align(16) = 0x33,
    b: u8 align(16) = 0xff,
    c: u64 align(16) = 0xee,
};

const Bar = struct {
    a: u32 = 0x33,
    b: u8 = 0xff,
    c: u64 = 0xee,
};

pub const FFT_Analyzer = struct {
    pub fn reset() void {
        // Left off here.
        std.debug.print("Foo\n*********\n", .{});
        const f = Foo{};
        std.log.debug("foo => {}, @sizeOf(foo) => {d}", .{ f, @sizeOf(Foo) });
        std.log.debug("f @bitSize(Foo) => {d}", .{@bitSizeOf(Foo)});
        std.log.debug("@alignOf(Foo.c) => {d}", .{@alignOf(Foo)});
        std.log.debug("f ptr => {*}", .{&f});

        const b = std.mem.asBytes(&f);
        std.log.debug("asBytes(Foo) => {s}", .{std.fmt.fmtSliceHexLower(b)});

        std.debug.print("Bar\n*********\n", .{});
        const bar = Bar{};
        std.log.debug("bar => {}, @sizeOf(bar) => {d}", .{ bar, @sizeOf(Bar) });
        std.log.debug("f @bitSize(Bar) => {d}", .{@bitSizeOf(Bar)});
        std.log.debug("@alignOf(bar.c) => {d}", .{@alignOf(Bar)});
        std.log.debug("bar ptr => {*}", .{&bar});

        const b1 = std.mem.asBytes(&bar);
        std.log.debug("asBytes(bar) => {s}", .{std.fmt.fmtSliceHexLower(b1)});

        const total = @sizeOf(Foo) + @sizeOf(Bar);
        std.log.debug("size of both structs: {d}", .{total});

        const rawData: [*]const u8 = @ptrCast(@alignCast(&f));
        std.log.debug("size of both structs: {d}", .{std.fmt.fmtSliceHexLower(rawData[0..total])});

        in_raw_circBuf.init();
        fft_clean();
    }

    // fft_algorithm is the signature FFT recursive algorithm for doing spectral analysis on audio data.
    fn fft_algorithm(in: []f32, stride: usize, out: []std.math.Complex(f32), n: usize) void {
        std.debug.assert(n > 0);

        if (n == 1) {
            out[0] = std.math.Complex(f32).init(in[0], 0);
            return;
        }

        const stride_dbled = stride * 2;
        const nOver2 = n / 2;
        fft_algorithm(in, stride_dbled, out, nOver2);
        fft_algorithm(in[stride..], stride_dbled, out[nOver2..], nOver2);

        var k: usize = 0;
        while (k < nOver2) : (k += 1) {
            const t: f32 = @as(f32, @floatFromInt(k)) / @as(f32, @floatFromInt(n));
            const complex_calc = std.math.Complex(f32).init(0, -2.0 * std.math.pi * t);
            var v = std.math.complex.exp(complex_calc);
            v = v.mul(out[k + nOver2]);
            const e = out[k];
            out[k] = e.add(v);
            out[k + nOver2] = e.sub(v);
        }
    }

    // smoothed returns a reference to the smoothed out data which makes the audio less jumpy.
    pub fn smoothed() []const f32 {
        return out_smooth[0..];
    }

    // smear returns a reference to the smeared out data which really tames visualizing. I prefer
    // this one much less so far.
    pub fn smeared() []const f32 {
        return out_smear[0..];
    }

    // fft_process_callback matches the Raylib 5.0 callback API: c.AudioCallback, this is responsible
    // for consuming all frames and tracking the data in order to process it.
    pub fn fft_process_callback(bufferData: ?*anyopaque, frames: c_uint) callconv(.C) void {
        const Frame = struct {
            left: f32,
            right: f32,
        };

        const fs: [*]Frame = @ptrCast(@alignCast(bufferData));

        for (0..frames) |i| {
            const lft = fs[i].left;
            push(lft);
        }
    }

    // push, will added one frame of data to the tail-end of the array. Everything left of the
    // new data is shifted over by one.
    // NOTE: this is burdensom on the CPU when FFT_SIZE is large, this can better scale with
    // a ring-buffer or anything that doesn't have to do so much copying.
    inline fn push(frame: f32) void {
        // NOTE: for large FFT_SIZE, c.memmove/circBuf actually is more performant vs Zig's copyForwards.
        // NOTE: in ReleaseSafe/ReleaseFast Zig - is about ~5% faster than c.memmove.
        switch (selectedCopyStyle) {
            .memmove => {
                // Doing a "raw c" memmove because Zig doesn't seem to have an equivalent instruction.
                // When FFT size is 13 => 40%
                const in: [*c]f32 = &in_raw;
                _ = c.memmove(in, in + 1, (FFT_SIZE - 1) * @sizeOf(f32));
                in_raw[FFT_SIZE - 1] = frame;
            },
            .copyForwards => {
                // When FFT size is 13 => 100%
                std.mem.copyForwards(f32, in_raw[0 .. FFT_SIZE - 1], in_raw[1..]);
                in_raw[FFT_SIZE - 1] = frame;
            },
            else => {
                // When FFT size is 13 => 40%
                // Circular buf is neck and neck with c.memmove...at least I can get as fast as C.
                in_raw_circBuf.push(frame);
            },
        }
    }

    // analyze is the entry point into actually processing the audio data by:
    // 0. windowing the input data.
    // 1. invoking the fft_algorithm
    // 2. squashing the resultant data into a logarithmic scale
    // 3. normalizes the frequency range from 0.0 - 1.0
    // 4. finally, smoothing and smearing out the data.
    pub fn analyze(dt: f32) usize {
        // Apply the Hann Window on the Input - https://en.wikipedia.org/wiki/Hann_function
        // @Tsoding explanation: https://youtu.be/ivLIov6ta-8
        // https://download.ni.com/evaluation/pxi/Understanding%20FFTs%20and%20Windowing.pdf

        // NOTE: this is the only spot that touches in_raw (the regular array, or circular buf variant).
        for (0..FFT_SIZE) |i| {
            if (selectedCopyStyle == .circularBuf) {
                in_win[i] = in_raw_circBuf.atIndex(i) * hannTable[i];
            } else {
                in_win[i] = in_raw[i] * hannTable[i];
            }
        }

        // Invoke the recursive FFT algorithm.
        fft_algorithm(&in_win, 1, &out_raw, FFT_SIZE);

        // "Squash" into the Logarithmic Scale
        const step: f32 = 1.06;
        const lowf: f32 = 1.0;
        var m: usize = 0;
        var max_amp: f32 = 1.0;

        var f: f32 = lowf;
        while (f < (FFT_SIZE / 2)) : (f = @ceil(f * step)) {
            const f1: f32 = @ceil(f * step);
            var a: f32 = 0.0;
            var q: usize = @intFromFloat(f);

            const something = @as(usize, @intFromFloat(f1));
            while (q < (FFT_SIZE / 2) and q < something) : (q += 1) {
                const b: f32 = amp(out_raw[q]);
                if (b > a) a = b;
            }
            if (max_amp < a) max_amp = a;
            m += 1;
            out_log[m] = a;
        }

        // Smooth out and smear the values
        const smoothness: f32 = 8;
        const smearness: f32 = 3;
        for (0..m) |i| {
            // Normalize freqs to 0..1 range.
            out_log[i] /= max_amp;
            // Smooth out.
            out_smooth[i] += (out_log[i] - out_smooth[i]) * smoothness * dt;
            // And smear.
            out_smear[i] += (out_smooth[i] - out_smear[i]) * smearness * dt;
        }

        return m;
    }

    fn amp(z: std.math.Complex(f32)) f32 {
        const a = std.math.Complex(f32).init(z.re, 0);
        const b = std.math.Complex(f32).init(0, z.im);
        const sum = a.add(b);
        const result = std.math.complex.log(sum);
        return result.re;
    }

    // fft_settled isn't used currently.
    fn fft_settled() bool {
        const eps: f32 = 1e-3;
        for (0..FFT_SIZE) |i| {
            if (out_smooth[i] > eps) return false;
            if (out_smear[i] > eps) return false;
        }
        return true;
    }

    fn fft_clean() void {
        const zeroComp = std.math.Complex(f32).init(0, 0);
        @memset(&out_raw, zeroComp);

        @memset(&in_raw, 0);
        @memset(&in_win, 0);
        @memset(&out_log, 0);
        @memset(&out_smooth, 0);
        @memset(&out_smear, 0);
    }
};
