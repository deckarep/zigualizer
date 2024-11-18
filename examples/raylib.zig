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
pub const c = @import("c_defs.zig").c;
const fft = @import("zigualizer");

const codebase = "All your codebase are belong to us.";
const WIN_WIDTH = 1280;
const WIN_HEIGHT = 768;

const trackPath = "resources/audio/Tick of the Clock.mp3";

var frames: usize = undefined;
var tickOfTheClock: c.Music = undefined;

pub fn main() !void {
    try visualizer();
}

fn visualizer() !void {
    fft.FFT_Analyzer.reset();

    c.SetConfigFlags(c.FLAG_VSYNC_HINT | c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(WIN_WIDTH, WIN_HEIGHT, codebase);
    c.InitAudioDevice();
    c.SetTargetFPS(60);

    c.PollInputEvents();

    // Load Music
    // First grab the path to the exe.
    var buff: [512]u8 = undefined;
    const exeDir = try std.fs.selfExeDirPath(&buff);

    const adjustPath = std.mem.endsWith(u8, exeDir, "examples/zig-out/bin");
    const tickOfTheClockPath = if (adjustPath) "../" ++ trackPath else trackPath;

    tickOfTheClock = c.LoadMusicStream(tickOfTheClockPath);
    defer c.UnloadMusicStream(tickOfTheClock);

    c.AttachAudioStreamProcessor(tickOfTheClock.stream, fft.FFT_Analyzer.fft_process_callback);
    c.PlayMusicStream(tickOfTheClock);

    while (!c.WindowShouldClose()) {
        update();
        draw();
    }
}

fn update() void {
    c.UpdateMusicStream(tickOfTheClock);
    frames = fft.FFT_Analyzer.analyze(c.GetFrameTime());
}

fn draw() void {
    c.BeginDrawing();
    defer c.EndDrawing();
    c.ClearBackground(c.BLACK);

    renderFFT(400, 200);

    c.DrawFPS(10, 10);
    c.DrawText("wait for it...", (WIN_WIDTH / 2) - 50, (WIN_HEIGHT / 2) + 40, 20, c.GRAY);
}

fn renderFFT(bottomY: c_int, height: c_int) void {
    const leftX = 15;
    const width: c_int = @intCast((WIN_WIDTH) / frames);
    const xSpacing = 30;
    const full_degrees: f32 = 360.0 / @as(f32, @floatFromInt(frames));

    // This translation was just to slightly shifter over the FFT bars.
    c.rlPushMatrix();
    defer c.rlPopMatrix();
    c.rlTranslatef(-20, 0, 0);
    for (0..frames) |idx| {
        const t = if (true) fft.FFT_Analyzer.smoothed()[idx] else fft.FFT_Analyzer.smeared()[idx];
        const inverse_height = (@as(f32, @floatFromInt(height)) * t);
        const h: c_int = @intFromFloat(inverse_height);
        var clr = c.ColorFromHSV(@as(f32, @floatFromInt(idx)) * full_degrees, 1.0, 1.0);
        clr = c.Fade(clr, 0.7);
        const x = @as(c_int, @intCast(leftX + (idx) * xSpacing));
        c.DrawRectangle(x, bottomY - h, width, h, clr);
    }
}
