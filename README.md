# zigualizer
Zigualizer: A music visualizer built with Zig, powered by the FFT algorithm.

## Details
This implementation was originally based on the [Musializer project by @Tsoding](https://github.com/tsoding/musializer/blob/master/src/plug.c).
This version as it stands has been tested to work with Raylib 5.0.

## Raylib integration
For a more thorough example see raylib.zig in the examples/ folder.

```zig
// Import the lib.
const fft = @import("zigualizer");

// Initialize it by calling reset.
fft.FFT_Analyzer.reset();

// After loading up a Raylib Music stream.
track = c.LoadMusicStream(pathToTrack);
defer c.UnloadMusicStream(track);

// Attach an audio stream processor pointing to the fft callback.
c.AttachAudioStreamProcessor(track.stream, fft.FFT_Analyzer.fft_process_callback);
c.PlayMusicStream(track);

// In your update loop
fn update() void {
    c.UpdateMusicStream(track);
    frames = fft.FFT_Analyzer.analyze(c.GetFrameTime());
}

// In your draw loop render the FFT however you like!
fn draw() void {
    c.BeginDrawing();
    defer c.EndDrawing();
    c.ClearBackground(c.BLACK);

    renderFFT(400, 200);
}
```

## Building the examples
```sh
# Run the Raylib demo.
zig build -Dexample-name=raylib.zig && zig-out/example/raylib
```
