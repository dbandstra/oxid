const std = @import("std");
const clap = @import("zig-clap");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const gl = @import("gl");
const inputs = @import("common/inputs.zig");
const ticks_per_second = @import("oxid/constants.zig").ticks_per_second;
const perf = @import("oxid/perf.zig");
const oxid = @import("oxid/oxid.zig");

const sdl = @import("platform/sdl.zig");
const translateKey = @import("platform/sdl_keys.zig").translateKey;

// drivers that other source files can access via @import("root")
pub const passets = @import("platform/assets_native.zig");
pub const pdate = @import("platform/date_libc.zig");
pub const pdraw = @import("platform/draw_opengl.zig");
pub const pstorage_dirname = "Oxid";
pub const pstorage = @import("platform/storage_native.zig");

pub const storagekey_config = "config.json";
pub const storagekey_highscores = "highscore.dat";

// margin to add around the scaled game view (in screen pixels). so far this is
// just a hardcoded constant.
const vmargin = 8;

fn getMaxCanvasScale(screen_w: u31, screen_h: u31) u31 {
    // pick a window size that isn't bigger than the desktop resolution, and
    // is an integer multiple of the virtual window size
    const max_w = screen_w - vmargin * 2;
    const max_h = screen_h - vmargin * 2 - 40; // bias for system menubars/taskbars

    const scale_limit = 8;

    var scale: u31 = 1;
    while (scale < scale_limit) : (scale += 1) {
        const w = (scale + 1) * oxid.vwin_w;
        const h = (scale + 1) * oxid.vwin_h;

        if (w > max_w or h > max_h)
            break;
    }

    return scale;
}

// get the dimensions of the program window. this is not used in fullscreen
// mode.
fn getWindowDimsForScale(scale: u31) WindowDims {
    return .{
        .w = oxid.vwin_w * scale + vmargin * 2,
        .h = oxid.vwin_h * scale + vmargin * 2,
    };
}

// calculate the position and dimensions of the scaled game view within the
// program window.
// TODO add a config option to force whole-number scale.
fn getBlitRect(screen_w_: u31, screen_h_: u31) pdraw.Framebuffer.BlitRect {
    const screen_w = screen_w_ - vmargin * 2;
    const screen_h = screen_h_ - vmargin * 2;

    // scale the game view up as far as possible, maintaining the aspect ratio
    const scaled_w = screen_h * oxid.vwin_w / oxid.vwin_h;
    const scaled_h = screen_w * oxid.vwin_h / oxid.vwin_w;

    if (scaled_w < screen_w) {
        return .{
            .w = scaled_w,
            .h = screen_h,
            .x = vmargin + screen_w / 2 - scaled_w / 2,
            .y = vmargin,
        };
    }
    if (scaled_h < screen_h) {
        return .{
            .w = screen_w,
            .h = scaled_h,
            .x = vmargin,
            .y = vmargin + screen_h / 2 - scaled_h / 2,
        };
    }
    return .{
        .w = screen_w,
        .h = screen_h,
        .x = vmargin,
        .y = vmargin,
    };
}

const FramerateScheme = union(enum) {
    // fixed: assume that tick function is called at this rate. don't even
    // look at delta time
    fixed: usize,
    // free: adapt to delta time
    free,
};

const WindowDims = struct {
    w: u31,
    h: u31,
};

// used to save the original position and dimensions of the game window before
// fullscreen mode was activated. this is what we will return to when
// fullscreen mode is toggled off
const SavedWindowPos = struct {
    x: i32,
    y: i32,
    w: u31,
    h: u31,
};

const Main = struct {
    main_state: oxid.MainState,
    draw_state: pdraw.State,
    framebuffer: pdraw.Framebuffer,
    window: *sdl.SDL_Window,
    display_index: c_int, // used to detect when the window has been moved to another display
    glcontext: sdl.SDL_GLContext,
    window_dims: WindowDims,
    blit_rect: pdraw.Framebuffer.BlitRect,
    audio_sample_rate: u31,
    audio_device: sdl.SDL_AudioDeviceID,
    quit: bool,
    toggle_fullscreen: bool,
    set_canvas_scale: ?u31,
    framerate_scheme: FramerateScheme,
    t: usize,
    saved_window_pos: ?SavedWindowPos, // only set when in fullscreen mode
    requested_vsync: bool,
    requested_framerate_scheme: ?FramerateScheme,
};

const Options = struct {
    audio_sample_rate: u31,
    audio_buffer_size: u16,
    framerate_scheme: ?FramerateScheme,
    vsync: bool, // if disabled, framerate scheme will be ignored
    disable_recording: bool,
};

pub fn main() u8 {
    const temp_space = 100000; // room for temporary allocations
    const audio_assets_size = 220000; // room for audio assets
    const total_memory_size = @sizeOf(Main) + temp_space + audio_assets_size;
    var main_memory = std.heap.page_allocator.alloc(u8, total_memory_size) catch |err| {
        std.log.emerg("Failed to allocate {} bytes: {}", .{ total_memory_size, err });
        return 1;
    };
    defer std.heap.page_allocator.free(main_memory);

    std.log.notice("Allocated {} bytes", .{total_memory_size});

    var hunk = Hunk.init(main_memory);

    const options = parseOptions(&hunk.low()) catch |err| {
        if (err != error.BadArg) // if BadArg, error was already printed
            std.log.err("Failed to parse command-line options: {}", .{err});
        return 1;
    } orelse {
        // --help flag was set, don't start the program
        return 0;
    };

    const self = init(&hunk, options) catch |_| {
        // init prints its own error
        return 1;
    };

    switch (self.framerate_scheme) {
        .fixed => |refresh_rate| {
            while (!self.quit)
                tick(self, refresh_rate);
        },
        .free => {
            const freq: u64 = sdl.SDL_GetPerformanceFrequency();
            var maybe_prev: ?u64 = null;
            while (!self.quit) {
                // how many microseconds have elapsed since the last tick?
                const now: u64 = sdl.SDL_GetPerformanceCounter();
                const delta_microseconds: u64 = if (maybe_prev) |prev|
                    (if (now > prev)
                        (now - prev) * 1_000_000 / freq
                    else
                        0)
                else
                    16667; // first tick's delta corresponds to 60 fps

                if (delta_microseconds < 1000) {
                    // avoid possible divide by zero
                    // note this also has the effect of capping the refresh rate at 1000fps
                    sdl.SDL_Delay(1); // ease up on the cpu
                    continue;
                }

                maybe_prev = now;

                // get the current framerate (refreshes per second)
                const refresh_rate = switch (self.framerate_scheme) {
                    .fixed => |rate| rate,
                    .free => 1_000_000 / delta_microseconds,
                };

                if (refresh_rate == 0) {
                    // delta was >= 1 second. the computer is hitched up on
                    // something. let's just wait.
                    std.log.notice("Refresh took > 1 second, skipping", .{});
                    continue;
                }

                tick(self, refresh_rate);

                // TODO is there more i can do to ease up on CPU? currently i
                // sleep enough to get the fps down to 1000.
            }
        },
    }

    deinit(self);
    return 0;
}

fn parseOptions(hunk_side: *HunkSide) !?Options {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const allocator = &hunk_side.allocator;

    @setEvalBranchQuota(200000);
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-h, --help              Display this help and exit") catch unreachable,
        clap.parseParam("-r, --rate <NUM>        Audio sample rate (default 44100)") catch unreachable,
        clap.parseParam("-b, --bufsize <NUM>     Audio buffer size (default 1024)") catch unreachable,
        clap.parseParam("-f, --refreshrate <NUM> Display refresh rate (number or `free`)") catch unreachable,
        clap.parseParam("--novsync               Disable vsync") catch unreachable,
        clap.parseParam("--nodemo                Don't record games") catch unreachable,
    };

    var args = try clap.parse(clap.Help, &params, allocator, null);
    defer args.deinit();

    const stderr = std.io.getStdErr().writer();

    if (args.flag("--help")) {
        try stderr.print("Usage:\n", .{});
        try clap.help(stderr, &params);
        return null;
    }

    var options: Options = .{
        .audio_sample_rate = 44100,
        .audio_buffer_size = 1024,
        .framerate_scheme = null,
        .vsync = true,
        .disable_recording = false,
    };

    if (args.option("--rate")) |value| {
        options.audio_sample_rate = try std.fmt.parseInt(u31, value, 10);
    }
    if (args.option("--bufsize")) |value| {
        // note: SDL docs say this value must be a power of two, but it still
        // seems to run if you give an arbitrary value
        options.audio_buffer_size = try std.fmt.parseInt(u16, value, 10);
    }
    if (args.option("--refreshrate")) |value| {
        if (std.mem.eql(u8, value, "free")) {
            options.framerate_scheme = .free;
        } else {
            const rate = try std.fmt.parseInt(usize, value, 10);
            if (rate < 1 or rate > 300) {
                std.log.err("Invalid refresh rate: {}", .{rate});
                return error.BadArg;
            }
            options.framerate_scheme = .{ .fixed = rate };
        }
    }
    if (args.flag("--novsync")) {
        options.vsync = false;
    }
    if (args.flag("--nodemo")) {
        options.disable_recording = true;
    }

    return options;
}

// run on startup as well as when the window is moved between displays
fn updateFramerateScheme(self: *Main) void {
    if (self.requested_vsync) {
        if (sdl.SDL_GL_SetSwapInterval(1) != 0)
            std.log.warn("Failed to set vsync.", .{});
    } else {
        if (sdl.SDL_GL_SetSwapInterval(0) != 0)
            std.log.warn("Failed to disable vsync.", .{});
    }

    // this function can return 1 (vsync), 0 (no vsync), or -1 (adaptive
    // vsync). i don't really get what adaptive vsync is but it seems like it
    // should be classed with vsync.
    const vsync_enabled = sdl.SDL_GL_GetSwapInterval() != 0;
    // https://github.com/ziglang/zig/issues/3882
    const vsync_str = if (vsync_enabled) "enabled" else "disabled";
    std.log.notice("Vsync is {s}.", .{vsync_str});

    self.framerate_scheme = blk: {
        if (!vsync_enabled) {
            // if vsync isn't enabled, a fixed framerate scheme never makes sense
            break :blk .free;
        }
        if (self.requested_framerate_scheme) |scheme| {
            // explicit scheme was supplied via command line option. override any
            // auto-detection.
            break :blk scheme;
        }
        // vsync is enabled, so try to identify the display's native refresh rate
        // and use that as our fixed rate
        const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
        var mode: sdl.SDL_DisplayMode = undefined;
        if (sdl.SDL_GetDesktopDisplayMode(display_index, &mode) != 0) {
            std.log.warn("Failed to get refresh rate, defaulting to free framerate.", .{});
            break :blk .free;
        }
        if (mode.refresh_rate <= 0) {
            std.log.warn("Refresh rate reported as {}, defaulting to free framerate.", .{mode.refresh_rate});
            break :blk .free;
        }
        break :blk .{ .fixed = @intCast(usize, mode.refresh_rate) };
    };

    switch (self.framerate_scheme) {
        .fixed => |refresh_rate| std.log.notice("Framerate scheme: fixed {}hz", .{refresh_rate}),
        .free => std.log.notice("Framerate scheme: free", .{}),
    }
}

fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) callconv(.C) void {
    const main_state = @ptrCast(*oxid.MainState, @alignCast(@alignOf(*oxid.MainState), userdata_.?));
    const out_bytes = stream_.?[0..@intCast(usize, len_)];

    oxid.audioPaint(main_state, out_bytes);
}

fn init(hunk: *Hunk, options: Options) !*Main {
    const self = hunk.low().allocator.create(Main) catch unreachable; // FIXME

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO | sdl.SDL_INIT_JOYSTICK) != 0) {
        std.log.emerg("Unable to initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    }
    errdefer sdl.SDL_Quit();

    // determine initial and max canvas scale (note: max canvas scale will be
    // updated on the fly when the window is moved between displays)
    const max_canvas_scale: u31 = blk: {
        // get the usable screen region (for the first display)
        var bounds: sdl.SDL_Rect = undefined;
        if (sdl.SDL_GetDisplayUsableBounds(0, &bounds) < 0) {
            std.log.err("Failed to query desktop display mode.", .{});
            break :blk 1; // stick with a small 1x scale window
        }
        const w = @intCast(u31, std.math.max(1, bounds.w));
        const h = @intCast(u31, std.math.max(1, bounds.h));
        break :blk getMaxCanvasScale(w, h);
    };

    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_CONTEXT_PROFILE_MASK), sdl.SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_CONTEXT_MAJOR_VERSION), 2);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_CONTEXT_MINOR_VERSION), 1);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_DOUBLEBUFFER), 1);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_BUFFER_SIZE), 32);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_RED_SIZE), 8);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_GREEN_SIZE), 8);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_BLUE_SIZE), 8);
    _ = sdl.SDL_GL_SetAttribute(@intToEnum(sdl.SDL_GLattr, sdl.SDL_GL_ALPHA_SIZE), 8);

    const glsl_version: pdraw.GLSLVersion = .v120;

    // start in windowed mode
    const initial_canvas_scale = std.math.min(max_canvas_scale, 4);
    const window_dims = getWindowDimsForScale(initial_canvas_scale);
    const window = sdl.SDL_CreateWindow(
        "Oxid",
        // note: these macros will place the window on the first display
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        window_dims.w,
        window_dims.h,
        sdl.SDL_WINDOW_OPENGL,
    ) orelse {
        std.log.emerg("Unable to create window: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    };
    errdefer sdl.SDL_DestroyWindow(window);

    if (options.audio_sample_rate < 6000 or options.audio_sample_rate > 192000) {
        std.log.emerg("Invalid audio sample rate: {}", .{options.audio_sample_rate});
        return error.Failed;
    }
    if (options.audio_buffer_size < 32 or options.audio_buffer_size > 65535) {
        std.log.emerg("Invalid audio buffer size: {}", .{options.audio_buffer_size});
        return error.Failed;
    }

    if (sdl.SDL_GetCurrentAudioDriver()) |name| {
        std.log.notice("Audio driver: {s}", .{std.mem.spanZ(name)});
    } else {
        std.log.warn("Failed to get audio driver name.", .{});
    }

    var want = std.mem.zeroes(sdl.SDL_AudioSpec);
    want.freq = options.audio_sample_rate;
    want.format = sdl.AUDIO_S16LSB;
    want.channels = 1;
    want.samples = options.audio_buffer_size;
    want.callback = audioCallback;
    want.userdata = &self.main_state;

    var have: sdl.SDL_AudioSpec = undefined;

    const device = sdl.SDL_OpenAudioDevice(
        0, // device name (NULL to let SDL choose)
        0, // non-zero to open for recording instead of playback
        &want,
        &have,
        // tell SDL that we can handle any frequency. however for other
        // properties, like format, we will let SDL do the resampling if the
        // system doesn't support it
        sdl.SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
    );
    if (device == 0) {
        std.log.emerg("Failed to open audio: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    }
    errdefer sdl.SDL_CloseAudioDevice(device);

    std.log.notice("Audio sample rate: {}hz", .{have.freq});

    const glcontext = sdl.SDL_GL_CreateContext(window) orelse {
        std.log.emerg("SDL_GL_CreateContext failed: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    };
    errdefer sdl.SDL_GL_DeleteContext(glcontext);

    _ = sdl.SDL_GL_MakeCurrent(window, glcontext);

    for (gl.extensions) |extension| {
        if (@enumToInt(sdl.SDL_GL_ExtensionSupported(extension)) == 0) {
            std.log.emerg("OpenGL extension \"{s}\" is required.", .{extension});
            return error.Failed;
        }
    }
    for (gl.commands) |command| {
        command.ptr.* = sdl.SDL_GL_GetProcAddress(command.name) orelse {
            std.log.emerg("Failed to load GL function \"{s}\".", .{command.name});
            return error.Failed;
        };
    }

    self.window = window;
    self.requested_vsync = options.vsync;
    self.requested_framerate_scheme = options.framerate_scheme;
    updateFramerateScheme(self); // sets self.framerate_scheme

    {
        const num_joysticks = sdl.SDL_NumJoysticks();
        std.log.notice("{} joystick(s)", .{num_joysticks});
        var i: c_int = 0;
        while (i < 2 and i < num_joysticks) : (i += 1) {
            const joystick = sdl.SDL_JoystickOpen(i);
            if (joystick == null)
                std.log.warn("Failed to open joystick {}", .{i + 1});
        }
    }

    pdraw.init(&self.draw_state, glsl_version, .{
        .hunk = hunk,
        .vwin_w = oxid.vwin_w,
        .vwin_h = oxid.vwin_h,
    }) catch |err| {
        std.log.emerg("pdraw.init failed: {}", .{err});
        return error.Failed;
    };
    errdefer pdraw.deinit(&self.draw_state);

    self.framebuffer = pdraw.Framebuffer.init(oxid.vwin_w, oxid.vwin_h) catch |err| {
        std.log.emerg("pdraw.Framebuffer.init failed: {}", .{err});
        return error.Failed;
    };
    errdefer pdraw.Framebuffer.deinit(&self.framebuffer);

    try oxid.init(&self.main_state, &self.draw_state, .{
        .hunk = hunk,
        .random_seed = @truncate(u32, @bitCast(u64, std.time.milliTimestamp())),
        .audio_buffer_size = options.audio_buffer_size,
        .audio_sample_rate = @intToFloat(f32, have.freq),
        .fullscreen = false,
        .canvas_scale = initial_canvas_scale,
        .max_canvas_scale = max_canvas_scale,
        .sound_enabled = true,
        .disable_recording = options.disable_recording,
    }); // oxid.init prints its own error and returns error.Failed
    errdefer oxid.deinit(&self.main_state);

    // already set:
    // main_state, window, requested_vsync, requested_framerate_scheme,
    // framerate_scheme, framebuffer
    self.display_index = 0;
    self.glcontext = glcontext;
    self.window_dims = window_dims;
    self.blit_rect = getBlitRect(window_dims.w, window_dims.h);
    self.audio_sample_rate = @intCast(u31, have.freq);
    self.audio_device = device;
    self.quit = false;
    self.toggle_fullscreen = false;
    self.set_canvas_scale = null;
    self.t = 0.0;
    self.saved_window_pos = null;

    sdl.SDL_PauseAudioDevice(device, 0); // unpause
    errdefer sdl.SDL_PauseAudioDevice(device, 1);

    std.log.notice("Initialization complete.", .{});

    return self;
}

fn deinit(self: *Main) void {
    std.log.notice("Shutting down.", .{});

    sdl.SDL_PauseAudioDevice(self.audio_device, 1);
    oxid.deinit(&self.main_state);
    pdraw.Framebuffer.deinit(&self.framebuffer);
    pdraw.deinit(&self.draw_state);
    sdl.SDL_GL_DeleteContext(self.glcontext);
    sdl.SDL_CloseAudioDevice(self.audio_device);
    sdl.SDL_DestroyWindow(self.window);
    sdl.SDL_Quit();
}

// simulate a frame, and draw it if requested
fn doFrame(self: *Main, should_draw: bool, clear: bool, alpha: f32) void {
    // run simulation and create events for drawing, playing sounds, etc.
    oxid.frame(&self.main_state, should_draw);

    // draw to framebuffer (from events)
    if (should_draw)
        draw(self, clear, alpha);

    // delete all events except for EventPlaySound
    oxid.frameCleanup(&self.main_state);
}

// this is run once per monitor frame
fn tick(self: *Main, refresh_rate: u64) void {
    const num_frames_to_simulate = blk: {
        self.t += ticks_per_second; // gameplay update rate
        var n: u32 = 0;
        while (self.t >= refresh_rate) {
            self.t -= refresh_rate;
            n += 1;
        }
        break :blk n;
    };

    if (num_frames_to_simulate == 0) {
        // don't call SDL_GL_SwapWindow if we haven't drawn anything
        return;
    }

    var i: usize = 0;
    while (i < num_frames_to_simulate) : (i += 1) {
        var evt: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&evt) != 0) {
            handleSDLEvent(self, evt);
            if (self.quit)
                return;
        }

        // if we're simulating multiple frames for one draw cycle, we only
        // draw the last one of them.
        const should_draw = i == num_frames_to_simulate - 1;

        if (self.main_state.fast_forward and (self.main_state.lshift or self.main_state.rshift)) {
            // 16x speed (super fast forward)
            // simulate 16 frames, but only draw every 4th one
            var frame_index: u32 = 0;
            while (frame_index < 16) : (frame_index += 1) {
                doFrame(
                    self,
                    should_draw and frame_index & 3 == 3,
                    frame_index == 3,
                    1.0 / @intToFloat(f32, (frame_index >> 2) + 1),
                );
            }
        } else if (self.main_state.fast_forward) {
            // 4x speed (fast forward)
            var frame_index: u32 = 0;
            while (frame_index < 4) : (frame_index += 1) {
                doFrame(
                    self,
                    should_draw,
                    frame_index == 0,
                    1.0 / @intToFloat(f32, frame_index + 1),
                );
            }
        } else {
            // 1x speed
            doFrame(self, should_draw, true, 1.0);
        }
    }

    // TODO what's the correct arrangement of the calls to SwapWindow and
    // Lock/UnlockAudioDevice? they both have the possibility of waiting for
    // something else to finish, unless i'm mistaken. would be better if i
    // could get them to go at the same time somehow?

    // (this wraps glxSwapBuffers)
    // this is where commands are flushed, so this may wait for a while. i
    // think it also waits if vsync is enabled.
    sdl.SDL_GL_SwapWindow(self.window);

    // TODO count time and see where we are along the mix buffer...
    // if the audio thread is currently doing a mix, this will wait until it's
    // finished.
    sdl.SDL_LockAudioDevice(self.audio_device);
    if (self.main_state.fast_forward and (self.main_state.lshift or self.main_state.rshift)) {
        // 16x super fast forward
        oxid.audioSync(&self.main_state, @intToFloat(f32, self.audio_sample_rate) / 16.0);
    } else if (self.main_state.fast_forward) {
        // 4x fast forward
        oxid.audioSync(&self.main_state, @intToFloat(f32, self.audio_sample_rate) / 4.0);
    } else {
        oxid.audioSync(&self.main_state, @intToFloat(f32, self.audio_sample_rate));
    }
    sdl.SDL_UnlockAudioDevice(self.audio_device);

    if (self.toggle_fullscreen) {
        toggleFullscreen(self);
    } else if (self.set_canvas_scale) |scale| {
        setCanvasScale(self, scale);
    }
    self.toggle_fullscreen = false;
    self.set_canvas_scale = null;

    perf.display();
}

fn setCanvasScale(self: *Main, scale: u31) void {
    if (self.main_state.fullscreen) return;

    self.main_state.canvas_scale = scale;

    const dims = getWindowDimsForScale(scale);

    const w: i32 = dims.w;
    const h: i32 = dims.h;
    sdl.SDL_SetWindowSize(self.window, w, h);

    self.window_dims = dims;
    self.blit_rect = getBlitRect(dims.w, dims.h);

    // if resizing the window puts part of it off-screen, push it back on-screen
    const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
    if (display_index < 0)
        return;
    var bounds: sdl.SDL_Rect = undefined;
    if (sdl.SDL_GetDisplayUsableBounds(display_index, &bounds) < 0)
        return;

    var x: i32 = undefined;
    var y: i32 = undefined;
    sdl.SDL_GetWindowPosition(self.window, &x, &y);

    const new_x = if (x + w > bounds.x + bounds.w)
        std.math.max(bounds.x, bounds.x + bounds.w - w)
    else
        x;

    const new_y = if (y + h > bounds.y + bounds.h)
        std.math.max(bounds.y, bounds.y + bounds.h - h)
    else
        y;

    if (new_x != x or new_y != y)
        sdl.SDL_SetWindowPosition(self.window, new_x, new_y);
}

fn toggleFullscreen(self: *Main) void {
    if (self.main_state.fullscreen) {
        // disable fullscreen mode
        if (sdl.SDL_SetWindowFullscreen(self.window, 0) < 0) {
            std.log.err("Failed to disable fullscreen mode", .{});
            return;
        }
        // give the window back its original dimensions
        const swp = self.saved_window_pos.?; // this field is always set when fullscreen is true
        sdl.SDL_SetWindowSize(self.window, swp.w, swp.h);
        sdl.SDL_SetWindowPosition(self.window, swp.x, swp.y);
        self.window_dims = .{ .w = swp.w, .h = swp.h };
        self.blit_rect = getBlitRect(swp.w, swp.h);
        self.main_state.fullscreen = false;
        self.saved_window_pos = null;
        return;
    }
    // enabling fullscreen mode. we use SDL's "fake" fullscreen mode to avoid a video mode change.
    // first get the full window dimensions to use
    const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
    if (display_index < 0)
        return;
    var mode: sdl.SDL_DisplayMode = undefined;
    if (sdl.SDL_GetDesktopDisplayMode(display_index, &mode) < 0)
        return;
    const full_w = @intCast(u31, std.math.max(1, mode.w));
    const full_h = @intCast(u31, std.math.max(1, mode.h));
    // save the current window pos and size
    const swp: SavedWindowPos = blk: {
        var x: i32 = undefined;
        var y: i32 = undefined;
        var w: i32 = undefined;
        var h: i32 = undefined;
        sdl.SDL_GetWindowPosition(self.window, &x, &y);
        sdl.SDL_GetWindowSize(self.window, &w, &h);
        break :blk .{
            .x = x,
            .y = y,
            .w = @intCast(u31, std.math.max(1, w)),
            .h = @intCast(u31, std.math.max(1, h)),
        };
    };
    // set new window size and go fullscreen
    sdl.SDL_SetWindowSize(self.window, full_w, full_h);
    if (sdl.SDL_SetWindowFullscreen(self.window, sdl.SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
        std.log.err("Failed to enable fullscreen mode", .{});
        sdl.SDL_SetWindowSize(self.window, swp.w, swp.h); // put it back
        return;
    }
    self.window_dims = .{ .w = full_w, .h = full_h };
    self.blit_rect = getBlitRect(full_w, full_h);
    self.main_state.fullscreen = true;
    self.saved_window_pos = swp;
}

fn inputEvent(self: *Main, source: inputs.Source, down: bool) void {
    switch (oxid.inputEvent(&self.main_state, source, down) orelse return) {
        .noop => {},
        .quit => self.quit = true,
        .toggle_sound => {}, // unused in SDL build
        .toggle_fullscreen => self.toggle_fullscreen = true,
        .set_canvas_scale => |scale| self.set_canvas_scale = scale,
        .config_updated => {}, // do nothing (config is saved when program exits)
    }
}

fn handleSDLEvent(self: *Main, evt: sdl.SDL_Event) void {
    switch (evt.type) {
        sdl.SDL_QUIT => {
            self.quit = true;
        },
        sdl.SDL_KEYDOWN => if (evt.key.repeat == 0) {
            if (translateKey(evt.key.keysym.sym)) |key|
                inputEvent(self, .{ .key = key }, true);
        },
        sdl.SDL_KEYUP => {
            if (translateKey(evt.key.keysym.sym)) |key|
                inputEvent(self, .{ .key = key }, false);
        },
        sdl.SDL_JOYAXISMOTION => {
            const threshold = 16384;
            const joy_axis: inputs.JoyAxis = .{
                .which = @intCast(usize, evt.jaxis.which),
                .axis = evt.jaxis.axis,
            };
            if (evt.jaxis.value < -threshold) {
                inputEvent(self, .{ .joy_axis_neg = joy_axis }, true);
                inputEvent(self, .{ .joy_axis_pos = joy_axis }, false);
            } else if (evt.jaxis.value > threshold) {
                inputEvent(self, .{ .joy_axis_pos = joy_axis }, true);
                inputEvent(self, .{ .joy_axis_neg = joy_axis }, false);
            } else {
                inputEvent(self, .{ .joy_axis_pos = joy_axis }, false);
                inputEvent(self, .{ .joy_axis_neg = joy_axis }, false);
            }
        },
        sdl.SDL_JOYBUTTONDOWN, sdl.SDL_JOYBUTTONUP => {
            const joy_button: inputs.JoyButton = .{
                .which = @intCast(usize, evt.jbutton.which),
                .button = evt.jbutton.button,
            };
            inputEvent(self, .{ .joy_button = joy_button }, evt.type == sdl.SDL_JOYBUTTONDOWN);
        },
        sdl.SDL_WINDOWEVENT => {
            if (evt.window.event == sdl.SDL_WINDOWEVENT_MOVED and !self.main_state.fullscreen) {
                const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
                if (self.display_index != display_index) {
                    // window moved to another display
                    self.display_index = display_index;
                    // update max_canvas_scale based on the new display's dimensions.
                    // (the current canvas scale won't change, but the user won't be
                    // able to increase it beyond the new maximum.)
                    var bounds: sdl.SDL_Rect = undefined;
                    if (sdl.SDL_GetDisplayUsableBounds(display_index, &bounds) >= 0) {
                        const w = @intCast(u31, std.math.max(1, bounds.w));
                        const h = @intCast(u31, std.math.max(1, bounds.h));
                        self.main_state.max_canvas_scale = getMaxCanvasScale(w, h);
                    }
                    // update the framerate scheme (e.g. get the new native refresh
                    // rate if vsync is enabled)
                    updateFramerateScheme(self);
                }
            }
        },
        else => {},
    }
}

fn draw(self: *Main, clear: bool, blit_alpha: f32) void {
    perf.begin(.whole_draw);

    pdraw.Framebuffer.preDraw(&self.framebuffer);

    perf.begin(.draw);
    oxid.draw(&self.main_state, &self.draw_state);
    perf.end(.draw);

    pdraw.Framebuffer.postDraw(
        &self.framebuffer,
        &self.draw_state,
        clear,
        self.window_dims.w,
        self.window_dims.h,
        self.blit_rect,
        blit_alpha,
    );

    perf.end(.whole_draw);
}
