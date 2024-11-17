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
