pub const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdarg.h");
    @cInclude("string.h");
    @cInclude("time.h");
    // @cInclude("raylib.h");
    // @cInclude("rlgl.h");
});
