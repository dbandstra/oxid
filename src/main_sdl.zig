usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("epoxy/gl.h");
});

const std = @import("std");
const clap = @import("zig-clap");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");

const Key = @import("common/key.zig").Key;
const InputSource = @import("common/key.zig").InputSource;
const JoyButton = @import("common/key.zig").JoyButton;
const JoyAxis = @import("common/key.zig").JoyAxis;
const areInputSourcesEqual = @import("common/key.zig").areInputSourcesEqual;
const platform_draw = @import("platform/opengl/draw.zig");
const platform_framebuffer = @import("platform/opengl/framebuffer.zig");
const Constants = @import("oxid/constants.zig");
const menus = @import("oxid/menus.zig");
const GameSession = @import("oxid/game.zig").GameSession;
const GameFrameContext = @import("oxid/frame.zig").GameFrameContext;
const gameFrame = @import("oxid/frame.zig").gameFrame;
const gameFrameCleanup = @import("oxid/frame.zig").gameFrameCleanup;
const p = @import("oxid/prototypes.zig");
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const datafile = @import("oxid/datafile.zig");
const c = @import("oxid/components.zig");
const common = @import("oxid_common.zig");

// See https://github.com/zig-lang/zig/issues/565
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, SDL_WINDOWPOS_UNDEFINED_MASK);

const datadir = "Oxid";
const config_filename = "config.json";
const highscores_filename = "highscore.dat";

fn openDataFile(hunk_side: *HunkSide, filename: []const u8, mode: enum { Read, Write }) !std.fs.File {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, datadir);

    if (mode == .Write) {
        std.fs.makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };
    }

    const file_path = try std.fs.path.join(&hunk_side.allocator, [_][]const u8{dir_path, filename});

    return switch (mode) {
        .Read => std.fs.File.openRead(file_path),
        .Write => std.fs.File.openWrite(file_path),
    };
}

pub fn loadConfig(hunk_side: *HunkSide) !config.Config {
    const file = openDataFile(hunk_side, config_filename, .Read) catch |err| {
        if (err == error.FileNotFound) {
            return config.getDefault();
        }
        return err;
    };
    defer file.close();

    const size = try std.math.cast(usize, try file.getEndPos());
    return try config.read(std.fs.File.InStream.Error, &std.fs.File.inStream(file).stream, size, hunk_side);
}

pub fn saveConfig(cfg: config.Config, hunk_side: *HunkSide) !void {
    const file = try openDataFile(hunk_side, config_filename, .Write);
    defer file.close();

    return try config.write(std.fs.File.OutStream.Error, &std.fs.File.outStream(file).stream, cfg);
}

pub fn loadHighScores(hunk_side: *HunkSide) [Constants.num_high_scores]u32 {
    const file = openDataFile(hunk_side, highscores_filename, .Read) catch |err| {
        if (err == error.FileNotFound) {
            // this is a normal situation (e.g. game is being played for the
            // first time)
        } else {
            // the file exists but there was an error loading it. just continue
            // with an empty high scores list, even though that might mean that
            // the user's legitimate high scores might get wiped out (FIXME?)
            std.debug.warn("Failed to load high scores file: {}\n", err);
        }
        return [1]u32{0} ** Constants.num_high_scores;
    };
    defer file.close();

    return datafile.readHighScores(std.fs.File.InStream.Error, &std.fs.File.inStream(file).stream);
}

pub fn saveHighScores(hunk_side: *HunkSide, high_scores: [Constants.num_high_scores]u32) !void {
    const file = try openDataFile(hunk_side, highscores_filename, .Write);
    defer file.close();

    try datafile.writeHighScores(std.fs.File.OutStream.Error, &std.fs.File.outStream(file).stream, high_scores);
}

const WindowDims = struct {
    // dimensions of the system window
    window_width: u31,
    window_height: u31,
    // coordinates of the viewport to blit to, within the system window
    blit_rect: platform_framebuffer.BlitRect,
};

const NativeScreenSize = struct {
    width: u31,
    height: u31,
};

fn getFullscreenDims(native_screen_size: NativeScreenSize) WindowDims {
    // scale the game view up as far as possible, maintaining the aspect ratio
    const scaled_w = native_screen_size.height * common.virtual_window_width / common.virtual_window_height;
    const scaled_h = native_screen_size.width * common.virtual_window_height / common.virtual_window_width;

    return WindowDims {
        .window_width = native_screen_size.width,
        .window_height = native_screen_size.height,
        .blit_rect =
            if (scaled_w < native_screen_size.width)
                platform_framebuffer.BlitRect {
                    .w = scaled_w,
                    .h = native_screen_size.height,
                    .x = native_screen_size.width / 2 - scaled_w / 2,
                    .y = 0,
                }
            else if (scaled_h < native_screen_size.height)
                platform_framebuffer.BlitRect {
                    .w = native_screen_size.width,
                    .h = scaled_h,
                    .x = 0,
                    .y = native_screen_size.height / 2 - scaled_h / 2,
                }
            else
                platform_framebuffer.BlitRect {
                    .w = native_screen_size.width,
                    .h = native_screen_size.height,
                    .x = 0,
                    .y = 0,
                },
    };
}

fn getMaxCanvasScale(native_screen_size: NativeScreenSize) u31 {
    // pick a window size that isn't bigger than the desktop resolution, and
    // is an integer multiple of the virtual window size
    const max_w = native_screen_size.width;
    const max_h = native_screen_size.height - 40; // bias for system menubars/taskbars

    const scale_limit = 8;

    var scale: u31 = 1; while (scale < scale_limit) : (scale += 1) {
        const w = (scale + 1) * common.virtual_window_width;
        const h = (scale + 1) * common.virtual_window_height;

        if (w > max_w or h > max_h) {
            break;
        }
    }

    return scale;
}

fn getWindowedDims(scale: u31) WindowDims {
    const window_width = common.virtual_window_width * scale;
    const window_height = common.virtual_window_height * scale;

    return WindowDims {
        .window_width = window_width,
        .window_height = window_height,
        .blit_rect = platform_framebuffer.BlitRect {
            .x = 0,
            .y = 0,
            .w = window_width,
            .h = window_height,
        },
    };
}

const FramerateScheme = union(enum) {
    // fixed: assume that tick function is called at this rate. don't even look at delta time
    Fixed: usize,
    // free: adapt to delta time
    Free,
};

const Main = struct {
    main_state: common.MainState,
    framebuffer_state: platform_framebuffer.FramebufferState,
    window: *SDL_Window,
    glcontext: SDL_GLContext,
    fullscreen_dims: ?WindowDims,
    windowed_dims: WindowDims,
    native_screen_size: ?NativeScreenSize,
    original_window_x: i32,
    original_window_y: i32,
    audio_sample_rate: usize,
    audio_sample_rate_current: f32,
    audio_device: SDL_AudioDeviceID,
    quit: bool,
    fast_forward: bool,
    framerate_scheme: FramerateScheme,
    t: usize,
};

const Options = struct {
    audio_sample_rate: usize,
    audio_buffer_size: usize,
    framerate_scheme: ?FramerateScheme,
    vsync: bool, // if disabled, framerate scheme will be ignored
};

// since audio files are loaded at runtime, we need to make room for them in
// the memory buffer
const audio_assets_size = 320700;

var main_memory: [@sizeOf(Main) + 200*1024 + audio_assets_size]u8 = undefined;

pub fn main() u8 {
    var hunk = Hunk.init(main_memory[0..]);

    const self = blk: {
        const options = parseOptions(&hunk.low()) catch |err| {
            std.debug.warn("Failed to parse command-line options: {}\n", err);
            return 1;
        } orelse {
            // --help flag was set, don't start the program
            return 0;
        };

        break :blk init(&hunk, options) catch |_| {
            // init prints its own error
            return 1;
        };
    };

    switch (self.framerate_scheme) {
        .Fixed => |refresh_rate| {
            while (!self.quit) {
                tick(self, refresh_rate);
            }
        },
        .Free => {
            const freq: u64 = SDL_GetPerformanceFrequency();
            var maybe_prev: ?u64 = null;
            while (true) {
                const now: u64 = SDL_GetPerformanceCounter();
                const delta_microseconds: u64 =
                    if (maybe_prev) |prev| (
                        if (now > prev) (
                            (now - prev) * 1000000 / freq
                        ) else (
                            0
                        )
                    ) else (
                        16667 // first tick's delta corresponds to 60 fps
                    );
                maybe_prev = now;

                if (delta_microseconds < 1000) {
                    // avoid possible divide by zero
                    SDL_Delay(1);
                    continue;
                }

                const refresh_rate = switch (self.framerate_scheme) {
                    .Fixed => |rate| rate,
                    .Free => 1000000 / delta_microseconds,
                };

                if (refresh_rate == 0) {
                    // delta was >= 1 second. the computer is hitched up on
                    // something. let's just wait.
                    continue;
                }

                tick(self, refresh_rate);
                if (self.quit) {
                    break;
                }

                const threshold = 1000000 / (2 * Constants.ticks_per_second);
                if (delta_microseconds < threshold) {
                    // try to ease up on cpu usage in case the computer is
                    // capable of running far quicker than the desired
                    // framerate
                    // TODO - think this through. i don't think the 1ms delay
                    // is helping at all. a 5ms delay does help a bit but i
                    // need to be smart about choosing delay values (as well
                    // as the threshold value above)
                    SDL_Delay(1);
                }
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
    const params = comptime [_]clap.Param(clap.Help) {
        clap.parseParam("-h, --help              Display this help and exit") catch unreachable,
        clap.parseParam("-r, --rate <NUM>        Audio sample rate (default 44100)") catch unreachable,
        clap.parseParam("-b, --bufsize <NUM>     Audio buffer size (default 1024)") catch unreachable,
        clap.parseParam("-f, --refreshrate <NUM> Display refresh rate (number or `free`)") catch unreachable,
        clap.parseParam("--novsync               Disable vsync") catch unreachable,
    };

    var iter = try clap.args.OsIterator.init(allocator);
    defer iter.deinit();

    var args = try clap.ComptimeClap(clap.Help, params).parse(allocator, clap.args.OsIterator, &iter);
    defer args.deinit();

    if (args.flag("--help")) {
        std.debug.warn("Usage:\n");
        try clap.help(try std.debug.getStderrStream(), params);
        return null;
    }

    var options = Options {
        .audio_sample_rate = 44100,
        .audio_buffer_size = 1024,
        .framerate_scheme = null,
        .vsync = true,
    };

    if (args.option("--rate")) |value| {
        options.audio_sample_rate = try std.fmt.parseInt(usize, value, 10);
    }
    if (args.option("--bufsize")) |value| {
        options.audio_buffer_size = try std.fmt.parseInt(usize, value, 10);
    }
    if (args.option("--refreshrate")) |value| {
        if (std.mem.eql(u8, value, "free")) {
            options.framerate_scheme = .Free;
        } else {
            options.framerate_scheme = FramerateScheme {
                .Fixed = try std.fmt.parseInt(usize, value, 10),
            };
        }
    }
    if (args.flag("--novsync")) {
        options.vsync = false;
    }

    return options;
}

fn getFramerateScheme(window: *SDL_Window, vsync: bool, maybe_scheme: ?FramerateScheme) !FramerateScheme {
    if (!vsync) {
        // if vsync isn't enabled, a fixed framerate scheme never makes sense
        return FramerateScheme { .Free = {} };
    }

    if (maybe_scheme) |scheme| {
        // explicit scheme was supplied via command line option. override any
        // auto-detection.
        switch (scheme) {
            .Fixed => |rate| {
                if (rate < 1 or rate > 300) {
                    std.debug.warn("Invalid refresh rate: {}\n", rate);
                    return error.Failed;
                }
            },
            .Free => {},
        }
        return scheme;
    }

    // vsync is enabled, so try to identify the display's native refresh rate
    // and use that as our fixed rate
    const display_index = SDL_GetWindowDisplayIndex(window);
    var mode: SDL_DisplayMode = undefined;
    if (SDL_GetDesktopDisplayMode(display_index, &mode) != 0) {
        std.debug.warn("Failed to get refresh rate, defaulting to free framerate.\n");
        return FramerateScheme { .Free = {} };
    }
    if (mode.refresh_rate <= 0) {
        std.debug.warn("Refresh rate reported as {}, defaulting to free framerate.\n", mode.refresh_rate);
        return FramerateScheme { .Free = {} };
    }
    // TODO - do i need to update this when the window moves (possibly to
    // another monitor with a different refresh rate)?
    return FramerateScheme {
        .Fixed = @intCast(usize, mode.refresh_rate),
    };
}

extern fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) void {
    const self = @ptrCast(*Main, @alignCast(@alignOf(*Main), userdata_.?));
    const out_bytes = stream_.?[0..@intCast(usize, len_)];

    const buf = self.main_state.audio_module.paint(self.audio_sample_rate_current, &self.main_state.session);
    const vol = std.math.min(1.0, @intToFloat(f32, self.main_state.cfg.volume) / 100.0);
    zang.mixDown(out_bytes, buf, .S16LSB, 1, 0, vol);
}

fn init(hunk: *Hunk, options: Options) !*Main {
    const self = hunk.low().allocator.create(Main) catch unreachable;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) != 0) {
        std.debug.warn("Unable to initialize SDL: {s}\n", SDL_GetError());
        return error.Failed;
    }
    errdefer SDL_Quit();

    const fullscreen = false;
    var fullscreen_dims: ?WindowDims = null;
    var windowed_dims = WindowDims {
        .window_width = common.virtual_window_width,
        .window_height = common.virtual_window_height,
        .blit_rect = platform_framebuffer.BlitRect {
            .x = 0,
            .y = 0,
            .w = common.virtual_window_width,
            .h = common.virtual_window_height,
        },
    };

    var max_canvas_scale: u31 = 1;
    var initial_canvas_scale: u31 = 1;
    var native_screen_size: ?NativeScreenSize = null;

    {
        // get the desktop resolution (for the first display)
        var dm: SDL_DisplayMode = undefined;

        if (SDL_GetDesktopDisplayMode(0, &dm) != 0) {
            // if this happens we'll just stick with a small 1:1 scale window
            std.debug.warn("Failed to query desktop display mode.\n");
        } else {
            native_screen_size = NativeScreenSize {
                .width = @intCast(u31, dm.w),
                .height = @intCast(u31, dm.h),
            };

            fullscreen_dims = getFullscreenDims(native_screen_size.?);

            max_canvas_scale = getMaxCanvasScale(native_screen_size.?);
            initial_canvas_scale = std.math.min(4, max_canvas_scale);
            windowed_dims = getWindowedDims(initial_canvas_scale);
        }
    }

    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_DOUBLEBUFFER), 1);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_BUFFER_SIZE), 32);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_RED_SIZE), 8);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_GREEN_SIZE), 8);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_BLUE_SIZE), 8);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_ALPHA_SIZE), 8);

    // start in windowed mode
    const window = SDL_CreateWindow(
        c"Oxid",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, windowed_dims.window_width),
        @intCast(c_int, windowed_dims.window_height),
        SDL_WINDOW_OPENGL,
    ) orelse {
        std.debug.warn("Unable to create window: {s}\n", SDL_GetError());
        return error.Failed;
    };
    errdefer SDL_DestroyWindow(window);

    var original_window_x: c_int = undefined;
    var original_window_y: c_int = undefined;
    SDL_GetWindowPosition(window, &original_window_x, &original_window_y);

    if (options.audio_sample_rate < 6000 or options.audio_sample_rate > 192000) {
        std.debug.warn("Invalid audio sample rate: {}\n", options.audio_sample_rate);
        return error.Failed;
    }
    if (options.audio_buffer_size < 32 or options.audio_buffer_size > 65535) {
        std.debug.warn("Invalid audio buffer size: {}\n", options.audio_buffer_size);
        return error.Failed;
    }

    var want: SDL_AudioSpec = undefined;
    want.freq = @intCast(c_int, options.audio_sample_rate);
    want.format = AUDIO_S16LSB;
    want.channels = 1;
    want.samples = @intCast(u16, options.audio_buffer_size);
    want.callback = audioCallback;
    want.userdata = self;

    // TODO - allow SDL to pick something different?
    const device: SDL_AudioDeviceID = SDL_OpenAudioDevice(
        0, // device name (NULL)
        0, // non-zero to open for recording instead of playback
        &want, // desired output format
        0, // obtained output format (NULL)
        0, // allowed changes: 0 means `obtained` will not differ from `want`, and SDL will do any necessary resampling behind the scenes
    );
    if (device == 0) {
        std.debug.warn("Failed to open audio: {s}\n", SDL_GetError());
        return error.Failed;
    }
    errdefer SDL_CloseAudioDevice(device);

    const glcontext = SDL_GL_CreateContext(window) orelse {
        std.debug.warn("SDL_GL_CreateContext failed: {s}\n", SDL_GetError());
        return error.Failed;
    };
    errdefer SDL_GL_DeleteContext(glcontext);

    _ = SDL_GL_MakeCurrent(window, glcontext);

    if (options.vsync) {
        if (SDL_GL_SetSwapInterval(1) != 0) {
            std.debug.warn("Warning: failed to set vsync.\n");
        }
    } else {
        if (SDL_GL_SetSwapInterval(0) != 0) {
            std.debug.warn("Warning: failed to disable vsync.\n");
        }
    }

    // this function can return 1 (vsync), 0 (no vsync), or -1 (adaptive
    // vsync). i don't really get what adaptive vsync is but it seems like it
    // should be classed with vsync.
    const vsync_enabled = SDL_GL_GetSwapInterval() != 0;
    std.debug.warn("Vsync is {}.\n", if (vsync_enabled) "enabled" else "disabled");

    const framerate_scheme = try getFramerateScheme(window, vsync_enabled, options.framerate_scheme);
    switch (framerate_scheme) {
        .Fixed => |refresh_rate| std.debug.warn("Framerate scheme: fixed {}hz\n", refresh_rate),
        .Free => std.debug.warn("Framerate scheme: free\n"),
    }

    if (!platform_framebuffer.init(&self.framebuffer_state, common.virtual_window_width, common.virtual_window_height)) {
        std.debug.warn("platform_framebuffer.init failed\n");
        return error.Failed;
    }
    errdefer platform_framebuffer.deinit(&self.framebuffer_state);

    {
        const num_joysticks = SDL_NumJoysticks();
        std.debug.warn("{} joystick(s)\n", num_joysticks);
        var i: c_int = 0; while (i < 2 and i < num_joysticks) : (i += 1) {
            const joystick = SDL_JoystickOpen(i);
            if (joystick == null) {
                std.debug.warn("Failed to open joystick {}\n", i + 1);
            }
        }
    }

    if (!common.init(&self.main_state, @This(), common.InitParams {
        .hunk = hunk,
        .random_seed = @intCast(u32, std.time.milliTimestamp() & 0xFFFFFFFF),
        .audio_buffer_size = options.audio_buffer_size,
        .fullscreen = fullscreen,
        .canvas_scale = initial_canvas_scale,
        .max_canvas_scale = max_canvas_scale,
        .sound_enabled = true,
    })) {
        // common.init prints its own error
        return error.Failed;
    }
    errdefer common.deinit(&self.main_state);

    // framebuffer_state already set
    self.window = window;
    self.glcontext = glcontext;
    self.fullscreen_dims = fullscreen_dims;
    self.windowed_dims = windowed_dims;
    self.native_screen_size = native_screen_size;
    self.original_window_x = original_window_x;
    self.original_window_y = original_window_y;
    self.audio_sample_rate = options.audio_sample_rate;
    self.audio_sample_rate_current = @intToFloat(f32, options.audio_sample_rate);
    self.audio_device = device;
    self.quit = false;
    self.fast_forward = false;
    self.framerate_scheme = framerate_scheme;
    self.t = 0.0;

    SDL_PauseAudioDevice(device, 0); // unpause
    errdefer SDL_PauseAudioDevice(device, 1);

    std.debug.warn("Initialization complete.\n");

    return self;
}

fn deinit(self: *Main) void {
    std.debug.warn("Shutting down.\n");

    saveConfig(self.main_state.cfg, &self.main_state.hunk.low()) catch |err| {
        std.debug.warn("Failed to save config: {}\n", err);
    };

    SDL_PauseAudioDevice(self.audio_device, 1);
    common.deinit(&self.main_state);
    platform_framebuffer.deinit(&self.framebuffer_state);
    SDL_GL_DeleteContext(self.glcontext);
    SDL_CloseAudioDevice(self.audio_device);
    SDL_DestroyWindow(self.window);
    SDL_Quit();
}

// this is run once per monitor frame
fn tick(self: *Main, refresh_rate: u64) void {
    const num_frames_to_simulate = blk: {
        self.t += Constants.ticks_per_second; // gameplay update rate
        var n: u32 = 0;
        while (self.t >= refresh_rate) {
            self.t -= refresh_rate;
            n += 1;
        }
        break :blk n;
    };

    var toggle_fullscreen = false;

    var i: usize = 0; while (i < num_frames_to_simulate) : (i += 1) {
        var evt: SDL_Event = undefined;
        while (SDL_PollEvent(&evt) != 0) {
            handleSDLEvent(self, evt);
            if (self.quit) {
                return;
            }
        }

        self.main_state.menu_anim_time +%= 1;

        const frame_context = GameFrameContext {
            .friendly_fire = self.main_state.friendly_fire,
        };

        // when fast forwarding, we'll simulate 4 frames and draw them blended
        // together. we'll also speed up the sound playback rate by 4x
        const num_frames = if (self.fast_forward) @as(u32, 4) else @as(u32, 1);
        var frame_index: u32 = 0; while (frame_index < num_frames) : (frame_index += 1) {
            // if we're simulating multiple frames for one draw cycle, we only
            // need to actually draw for the last one of them
            const draw = i == num_frames_to_simulate - 1;

            // run simulation and create events for drawing, playing sounds, etc.
            const paused = self.main_state.menu_stack.len > 0 and !self.main_state.game_over;

            perf.begin(.Frame);
            gameFrame(&self.main_state.session, frame_context, draw, paused);
            perf.end(.Frame);

            // middleware response to certain events
            common.handleGameOver(&self.main_state, @This());

            // update audio (from events)
            playSounds(self, num_frames);

            // draw to framebuffer (from events)
            if (draw) {
                // this alpha value is calculated to end up with an even blend
                // of all fast forward frames
                drawMain(self, 1.0 / @intToFloat(f32, frame_index + 1));
            }

            // delete events
            gameFrameCleanup(&self.main_state.session);
        }
    }

    SDL_GL_SwapWindow(self.window);

    if (toggle_fullscreen) {
        toggleFullscreen(self);
    }
}

fn setCanvasScale(self: *Main, scale: u31) void {
    self.windowed_dims = getWindowedDims(scale);

    if (!self.main_state.fullscreen) {
        SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);

        if (self.native_screen_size) |native_screen_size| {
            // if resizing the window put part of it off-screen, push it back
            // on-screen
            var set = false;
            if (self.original_window_x + @as(i32, self.windowed_dims.window_width) > @as(i32, native_screen_size.width)) {
                self.original_window_x = @as(i32, native_screen_size.width) - @as(i32, self.windowed_dims.window_width);
                if (self.original_window_x < 0) {
                    self.original_window_x = 0;
                }
                set = true;
            }
            if (self.original_window_y + @as(i32, self.windowed_dims.window_height) > @as(i32, native_screen_size.height)) {
                self.original_window_y = @as(i32, native_screen_size.height) - @as(i32, self.windowed_dims.window_height);
                if (self.original_window_y < 0) {
                    self.original_window_y = 0;
                }
                set = true;
            }
            if (set) {
                SDL_SetWindowPosition(self.window, self.original_window_x, self.original_window_y);
            }
        }
    }

    self.main_state.canvas_scale = scale;
}

fn toggleFullscreen(self: *Main) void {
    if (self.main_state.fullscreen) {
        if (SDL_SetWindowFullscreen(self.window, 0) < 0) {
            std.debug.warn("Failed to disable fullscreen mode");
        } else {
            SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);
            SDL_SetWindowPosition(self.window, self.original_window_x, self.original_window_y);
            self.main_state.fullscreen = false;
        }
    } else {
        if (self.fullscreen_dims) |dims| {
            SDL_SetWindowSize(self.window, dims.window_width, dims.window_height);
            if (SDL_SetWindowFullscreen(self.window, SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
                std.debug.warn("Failed to enable fullscreen mode\n");
                SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);
            } else {
                self.main_state.fullscreen = true;
            }
        } else {
            // couldn't figure out how to go fullscreen so stay in windowed mode
        }
    }
}

fn inputEvent(self: *Main, source: InputSource, down: bool) void {
    if (common.inputEvent(self, @This(), source, down)) |special| {
        switch (special) {
            .NoOp => {},
            .Quit => self.quit = true,
            .ToggleSound => {}, // unused in SDL build
            .ToggleFullscreen => toggleFullscreen(self),
            .SetCanvasScale => |value| setCanvasScale(self, value),
        }
    }
}

fn handleSDLEvent(self: *Main, evt: SDL_Event) void {
    switch (evt.type) {
        SDL_KEYDOWN => {
            if (evt.key.repeat == 0) {
                if (translateKey(evt.key.keysym.sym)) |key| {
                    inputEvent(self, InputSource { .Key = key }, true);

                    switch (key) {
                        .Backquote => {
                            self.fast_forward = true;
                        },
                        .F4 => {
                            perf.toggleSpam();
                        },
                        .F5 => {
                            platform_draw.cycleGlitchMode(&self.main_state.draw_state);
                        },
                        else => {},
                    }
                }
            }
        },
        SDL_KEYUP => {
            if (translateKey(evt.key.keysym.sym)) |key| {
                inputEvent(self, InputSource { .Key = key }, false);

                switch (key) {
                    .Backquote => {
                        self.fast_forward = false;
                    },
                    else => {},
                }
            }
        },
        SDL_JOYAXISMOTION => {
            const threshold = 16384;
            const joy_axis = JoyAxis {
                .which = @intCast(usize, evt.jaxis.which),
                .axis = evt.jaxis.axis,
            };
            if (evt.jaxis.value < -threshold) {
                inputEvent(self, InputSource { .JoyAxisNeg = joy_axis }, true);
                inputEvent(self, InputSource { .JoyAxisPos = joy_axis }, false);
            } else if (evt.jaxis.value > threshold) {
                inputEvent(self, InputSource { .JoyAxisPos = joy_axis }, true);
                inputEvent(self, InputSource { .JoyAxisNeg = joy_axis }, false);
            } else {
                inputEvent(self, InputSource { .JoyAxisPos = joy_axis }, false);
                inputEvent(self, InputSource { .JoyAxisNeg = joy_axis }, false);
            }
        },
        SDL_JOYBUTTONDOWN, SDL_JOYBUTTONUP => {
            const joy_button = JoyButton {
                .which = @intCast(usize, evt.jbutton.which),
                .button = evt.jbutton.button,
            };
            inputEvent(self, InputSource { .JoyButton = joy_button }, evt.type == SDL_JOYBUTTONDOWN);
        },
        SDL_WINDOWEVENT => {
            if (!self.main_state.fullscreen and evt.window.event == SDL_WINDOWEVENT_MOVED) {
                self.original_window_x = evt.window.data1;
                self.original_window_y = evt.window.data2;
            }
        },
        SDL_QUIT => {
            self.quit = true;
        },
        else => {},
    }
}

fn playSounds(self: *Main, num_frames: u32) void {
    SDL_LockAudioDevice(self.audio_device);
    defer SDL_UnlockAudioDevice(self.audio_device);

    // speed up audio mixing frequency if game is being fast forwarded
    self.audio_sample_rate_current = @intToFloat(f32, self.audio_sample_rate) / @intToFloat(f32, num_frames);

    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer. need to implement some
    // "syncing" to guess where we are in the middle of a mix frame
    const impulse_frame: usize = 0;

    self.main_state.audio_module.playSounds(&self.main_state.session, impulse_frame);
}

fn drawMain(self: *Main, blit_alpha: f32) void {
    const blit_rect = blk: {
        if (self.main_state.fullscreen) {
            if (self.fullscreen_dims) |dims| {
                break :blk dims.blit_rect;
            }
        }
        break :blk self.windowed_dims.blit_rect;
    };

    perf.begin(.WholeDraw);

    platform_framebuffer.preDraw(&self.framebuffer_state);

    perf.begin(.Draw);
    common.drawMain(&self.main_state);
    perf.end(.Draw);

    platform_framebuffer.postDraw(&self.framebuffer_state, &self.main_state.draw_state, blit_rect, blit_alpha);

    perf.end(.WholeDraw);
}

fn translateKey(sym: SDL_Keycode) ?Key {
    return switch (sym) {
        SDLK_RETURN => Key.Return,
        SDLK_ESCAPE => Key.Escape,
        SDLK_BACKSPACE => Key.Backspace,
        SDLK_TAB => Key.Tab,
        SDLK_SPACE => Key.Space,
        SDLK_EXCLAIM => Key.Exclaim,
        SDLK_QUOTEDBL => Key.QuoteDbl,
        SDLK_HASH => Key.Hash,
        SDLK_PERCENT => Key.Percent,
        SDLK_DOLLAR => Key.Dollar,
        SDLK_AMPERSAND => Key.Ampersand,
        SDLK_QUOTE => Key.Quote,
        SDLK_LEFTPAREN => Key.LeftParen,
        SDLK_RIGHTPAREN => Key.RightParen,
        SDLK_ASTERISK => Key.Asterisk,
        SDLK_PLUS => Key.Plus,
        SDLK_COMMA => Key.Comma,
        SDLK_MINUS => Key.Minus,
        SDLK_PERIOD => Key.Period,
        SDLK_SLASH => Key.Slash,
        SDLK_0 => Key.N0,
        SDLK_1 => Key.N1,
        SDLK_2 => Key.N2,
        SDLK_3 => Key.N3,
        SDLK_4 => Key.N4,
        SDLK_5 => Key.N5,
        SDLK_6 => Key.N6,
        SDLK_7 => Key.N7,
        SDLK_8 => Key.N8,
        SDLK_9 => Key.N9,
        SDLK_COLON => Key.Colon,
        SDLK_SEMICOLON => Key.Semicolon,
        SDLK_LESS => Key.Less,
        SDLK_EQUALS => Key.Equals,
        SDLK_GREATER => Key.Greater,
        SDLK_QUESTION => Key.Question,
        SDLK_AT => Key.At,
        SDLK_LEFTBRACKET => Key.LeftBracket,
        SDLK_BACKSLASH => Key.Backslash,
        SDLK_RIGHTBRACKET => Key.RightBracket,
        SDLK_CARET => Key.Caret,
        SDLK_UNDERSCORE => Key.Underscore,
        SDLK_BACKQUOTE => Key.Backquote,
        SDLK_a => Key.A,
        SDLK_b => Key.B,
        SDLK_c => Key.C,
        SDLK_d => Key.D,
        SDLK_e => Key.E,
        SDLK_f => Key.F,
        SDLK_g => Key.G,
        SDLK_h => Key.H,
        SDLK_i => Key.I,
        SDLK_j => Key.J,
        SDLK_k => Key.K,
        SDLK_l => Key.L,
        SDLK_m => Key.M,
        SDLK_n => Key.N,
        SDLK_o => Key.O,
        SDLK_p => Key.P,
        SDLK_q => Key.Q,
        SDLK_r => Key.R,
        SDLK_s => Key.S,
        SDLK_t => Key.T,
        SDLK_u => Key.U,
        SDLK_v => Key.V,
        SDLK_w => Key.W,
        SDLK_x => Key.X,
        SDLK_y => Key.Y,
        SDLK_z => Key.Z,
        SDLK_CAPSLOCK => Key.CapsLock,
        SDLK_F1 => Key.F1,
        SDLK_F2 => Key.F2,
        SDLK_F3 => Key.F3,
        SDLK_F4 => Key.F4,
        SDLK_F5 => Key.F5,
        SDLK_F6 => Key.F6,
        SDLK_F7 => Key.F7,
        SDLK_F8 => Key.F8,
        SDLK_F9 => Key.F9,
        SDLK_F10 => Key.F10,
        SDLK_F11 => Key.F11,
        SDLK_F12 => Key.F12,
        SDLK_PRINTSCREEN => Key.PrintScreen,
        SDLK_SCROLLLOCK => Key.ScrollLock,
        SDLK_PAUSE => Key.Pause,
        SDLK_INSERT => Key.Insert,
        SDLK_HOME => Key.Home,
        SDLK_PAGEUP => Key.PageUp,
        SDLK_DELETE => Key.Delete,
        SDLK_END => Key.End,
        SDLK_PAGEDOWN => Key.PageDown,
        SDLK_RIGHT => Key.Right,
        SDLK_LEFT => Key.Left,
        SDLK_DOWN => Key.Down,
        SDLK_UP => Key.Up,
        SDLK_NUMLOCKCLEAR => Key.NumLockClear,
        SDLK_KP_DIVIDE => Key.KpDivide,
        SDLK_KP_MULTIPLY => Key.KpMultiply,
        SDLK_KP_MINUS => Key.KpMinus,
        SDLK_KP_PLUS => Key.KpPlus,
        SDLK_KP_ENTER => Key.KpEnter,
        SDLK_KP_1 => Key.Kp1,
        SDLK_KP_2 => Key.Kp2,
        SDLK_KP_3 => Key.Kp3,
        SDLK_KP_4 => Key.Kp4,
        SDLK_KP_5 => Key.Kp5,
        SDLK_KP_6 => Key.Kp6,
        SDLK_KP_7 => Key.Kp7,
        SDLK_KP_8 => Key.Kp8,
        SDLK_KP_9 => Key.Kp9,
        SDLK_KP_0 => Key.Kp0,
        SDLK_KP_PERIOD => Key.KpPeriod,
        SDLK_APPLICATION => Key.Application,
        SDLK_POWER => Key.Power,
        SDLK_KP_EQUALS => Key.KpEquals,
        SDLK_F13 => Key.F13,
        SDLK_F14 => Key.F14,
        SDLK_F15 => Key.F15,
        SDLK_F16 => Key.F16,
        SDLK_F17 => Key.F17,
        SDLK_F18 => Key.F18,
        SDLK_F19 => Key.F19,
        SDLK_F20 => Key.F20,
        SDLK_F21 => Key.F21,
        SDLK_F22 => Key.F22,
        SDLK_F23 => Key.F23,
        SDLK_F24 => Key.F24,
        SDLK_EXECUTE => Key.Execute,
        SDLK_HELP => Key.Help,
        SDLK_MENU => Key.Menu,
        SDLK_SELECT => Key.Select,
        SDLK_STOP => Key.Stop,
        SDLK_AGAIN => Key.Again,
        SDLK_UNDO => Key.Undo,
        SDLK_CUT => Key.Cut,
        SDLK_COPY => Key.Copy,
        SDLK_PASTE => Key.Paste,
        SDLK_FIND => Key.Find,
        SDLK_MUTE => Key.Mute,
        SDLK_VOLUMEUP => Key.VolumeUp,
        SDLK_VOLUMEDOWN => Key.VolumeDown,
        SDLK_KP_COMMA => Key.KpComma,
        SDLK_KP_EQUALSAS400 => Key.KpEqualsAs400,
        SDLK_ALTERASE => Key.AltErase,
        SDLK_SYSREQ => Key.SysReq,
        SDLK_CANCEL => Key.Cancel,
        SDLK_CLEAR => Key.Clear,
        SDLK_PRIOR => Key.Prior,
        SDLK_RETURN2 => Key.Return2,
        SDLK_SEPARATOR => Key.Separator,
        SDLK_OUT => Key.Out,
        SDLK_OPER => Key.Oper,
        SDLK_CLEARAGAIN => Key.ClearAgain,
        SDLK_CRSEL => Key.CrSel,
        SDLK_EXSEL => Key.ExSel,
        SDLK_KP_00 => Key.Kp00,
        SDLK_KP_000 => Key.Kp000,
        SDLK_THOUSANDSSEPARATOR => Key.ThousandsSeparator,
        SDLK_DECIMALSEPARATOR => Key.DecimalSeparator,
        SDLK_CURRENCYUNIT => Key.CurrencyUnit,
        SDLK_CURRENCYSUBUNIT => Key.CurrencySubUnit,
        SDLK_KP_LEFTPAREN => Key.KpLeftParen,
        SDLK_KP_RIGHTPAREN => Key.KpRightParen,
        SDLK_KP_LEFTBRACE => Key.KpLeftBrace,
        SDLK_KP_RIGHTBRACE => Key.KpRightBrace,
        SDLK_KP_TAB => Key.KpTab,
        SDLK_KP_BACKSPACE => Key.KpBackspace,
        SDLK_KP_A => Key.KpA,
        SDLK_KP_B => Key.KpB,
        SDLK_KP_C => Key.KpC,
        SDLK_KP_D => Key.KpD,
        SDLK_KP_E => Key.KpE,
        SDLK_KP_F => Key.KpF,
        SDLK_KP_XOR => Key.KpXor,
        SDLK_KP_POWER => Key.KpPower,
        SDLK_KP_PERCENT => Key.KpPercent,
        SDLK_KP_LESS => Key.KpLess,
        SDLK_KP_GREATER => Key.KpGreater,
        SDLK_KP_AMPERSAND => Key.KpAmpersand,
        SDLK_KP_DBLAMPERSAND => Key.KpDblAmpersand,
        SDLK_KP_VERTICALBAR => Key.KpVerticalBar,
        SDLK_KP_DBLVERTICALBAR => Key.KpDblVerticalBar,
        SDLK_KP_COLON => Key.KpColon,
        SDLK_KP_HASH => Key.KpHash,
        SDLK_KP_SPACE => Key.KpSpace,
        SDLK_KP_AT => Key.KpAt,
        SDLK_KP_EXCLAM => Key.KpExclam,
        SDLK_KP_MEMSTORE => Key.KpMemStore,
        SDLK_KP_MEMRECALL => Key.KpMemRecall,
        SDLK_KP_MEMCLEAR => Key.KpMemClear,
        SDLK_KP_MEMADD => Key.KpMemAdd,
        SDLK_KP_MEMSUBTRACT => Key.KpMemSubtract,
        SDLK_KP_MEMMULTIPLY => Key.KpMemMultiply,
        SDLK_KP_MEMDIVIDE => Key.KpMemDivide,
        SDLK_KP_PLUSMINUS => Key.KpPlusMinus,
        SDLK_KP_CLEAR => Key.KpClear,
        SDLK_KP_CLEARENTRY => Key.KpClearEntry,
        SDLK_KP_BINARY => Key.KpBinary,
        SDLK_KP_OCTAL => Key.KpOctal,
        SDLK_KP_DECIMAL => Key.KpDecimal,
        SDLK_KP_HEXADECIMAL => Key.KpHexadecimal,
        SDLK_LCTRL => Key.LCtrl,
        SDLK_LSHIFT => Key.LShift,
        SDLK_LALT => Key.LAlt,
        SDLK_LGUI => Key.LGui,
        SDLK_RCTRL => Key.RCtrl,
        SDLK_RSHIFT => Key.RShift,
        SDLK_RALT => Key.RAlt,
        SDLK_RGUI => Key.RGui,
        SDLK_MODE => Key.Mode,
        SDLK_AUDIONEXT => Key.AudioNext,
        SDLK_AUDIOPREV => Key.AudioPrev,
        SDLK_AUDIOSTOP => Key.AudioStop,
        SDLK_AUDIOPLAY => Key.AudioPlay,
        SDLK_AUDIOMUTE => Key.AudioMute,
        SDLK_MEDIASELECT => Key.MediaSelect,
        SDLK_WWW => Key.Www,
        SDLK_MAIL => Key.Mail,
        SDLK_CALCULATOR => Key.Calculator,
        SDLK_COMPUTER => Key.Computer,
        SDLK_AC_SEARCH => Key.AcSearch,
        SDLK_AC_HOME => Key.AcHome,
        SDLK_AC_BACK => Key.AcBack,
        SDLK_AC_FORWARD => Key.AcForward,
        SDLK_AC_STOP => Key.AcStop,
        SDLK_AC_REFRESH => Key.AcRefresh,
        SDLK_AC_BOOKMARKS => Key.AcBookmarks,
        SDLK_BRIGHTNESSDOWN => Key.BrightnessDown,
        SDLK_BRIGHTNESSUP => Key.BrightnessUp,
        SDLK_DISPLAYSWITCH => Key.DisplaySwitch,
        SDLK_KBDILLUMTOGGLE => Key.KbdIllumToggle,
        SDLK_KBDILLUMDOWN => Key.KbdIllumDown,
        SDLK_KBDILLUMUP => Key.KbdIllumUp,
        SDLK_EJECT => Key.Eject,
        SDLK_SLEEP => Key.Sleep,
        SDLK_APP1 => Key.App1,
        SDLK_APP2 => Key.App2,
        SDLK_AUDIOREWIND => Key.AudioRewind,
        SDLK_AUDIOFASTFORWARD => Key.AudioFastForward,
        else => null,
    };
}
