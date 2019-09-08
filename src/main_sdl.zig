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
const platform_draw = @import("platform/opengl/draw.zig");
const platform_framebuffer = @import("platform/opengl/framebuffer.zig");
const Constants = @import("oxid/constants.zig");
const GameSession = @import("oxid/game.zig").GameSession;
const gameInit = @import("oxid/frame.zig").gameInit;
const gameFrame = @import("oxid/frame.zig").gameFrame;
const gameFrameCleanup = @import("oxid/frame.zig").gameFrameCleanup;
const p = @import("oxid/prototypes.zig");
const drawGame = @import("oxid/draw.zig").drawGame;
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const datafile = @import("oxid/datafile.zig");
const c = @import("oxid/components.zig");
const common = @import("oxid_common.zig");
const translateKey = @import("main_sdl/translate_key.zig").translateKey;

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

fn loadConfig(hunk_side: *HunkSide) !config.Config {
    const file = openDataFile(hunk_side, config_filename, .Read) catch |err| {
        if (err == error.FileNotFound) {
            return config.default;
        }
        return err;
    };
    defer file.close();

    const size = try std.math.cast(usize, try file.getEndPos());
    return try config.read(std.fs.File.InStream.Error, &std.fs.File.inStream(file).stream, size, hunk_side);
}

fn saveConfig(cfg: config.Config, hunk_side: *HunkSide) !void {
    const file = try openDataFile(hunk_side, config_filename, .Write);
    defer file.close();

    return try config.write(std.fs.File.OutStream.Error, &std.fs.File.outStream(file).stream, cfg, hunk_side);
}

fn loadHighScores(hunk_side: *HunkSide) ![Constants.num_high_scores]u32 {
    const file = openDataFile(hunk_side, highscores_filename, .Read) catch |err| {
        if (err == error.FileNotFound) {
            return [1]u32{0} ** Constants.num_high_scores;
        }
        return err;
    };
    defer file.close();

    return datafile.readHighScores(std.fs.File.InStream.Error, &std.fs.File.inStream(file).stream);
}

fn saveHighScores(hunk_side: *HunkSide, high_scores: [Constants.num_high_scores]u32) !void {
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

fn getFullscreenDims(native_w: u31, native_h: u31) WindowDims {
    // scale the game view up as far as possible, maintaining the
    // aspect ratio
    const scaled_w = native_h * common.virtual_window_width / common.virtual_window_height;
    const scaled_h = native_w * common.virtual_window_height / common.virtual_window_width;

    return WindowDims {
        .window_width = native_w,
        .window_height = native_h,
        .blit_rect =
            if (scaled_w < native_w)
                platform_framebuffer.BlitRect {
                    .w = scaled_w,
                    .h = native_h,
                    .x = native_w / 2 - scaled_w / 2,
                    .y = 0,
                }
            else if (scaled_h < native_h)
                platform_framebuffer.BlitRect {
                    .w = native_w,
                    .h = scaled_h,
                    .x = 0,
                    .y = native_h / 2 - scaled_h / 2,
                }
            else
                platform_framebuffer.BlitRect {
                    .w = native_w,
                    .h = native_h,
                    .x = 0,
                    .y = 0,
                },
    };
}

fn getWindowedDims(native_w: u31, native_h: u31) WindowDims {
    // pick a window size that isn't bigger than the desktop
    // resolution

    // the actual window size will be an integer multiple of the
    // virtual window size. this value puts a limit on high big it
    // will be scaled (it will also be limited by the user's screen
    // resolution)
    const max_scale = 4;
    const max_w = native_w;
    const max_h = native_h - 40; // bias for system menubars/taskbars

    var window_width: u31 = common.virtual_window_width;
    var window_height: u31 = common.virtual_window_height;

    var scale: u31 = 1; while (scale <= max_scale) : (scale += 1) {
        const w = scale * common.virtual_window_width;
        const h = scale * common.virtual_window_height;

        if (w > max_w or h > max_h) {
            break;
        }

        window_width = w;
        window_height = h;
    }

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
    draw_state: platform_draw.DrawState,
    framebuffer_state: platform_framebuffer.FramebufferState,
    audio_module: audio.MainModule,
    session: GameSession,
    static: common.GameStatic,
    cfg: config.Config,
    window: *SDL_Window,
    glcontext: SDL_GLContext,
    fullscreen: bool,
    fullscreen_dims: ?WindowDims,
    windowed_dims: WindowDims,
    original_window_x: c_int,
    original_window_y: c_int,
    audio_sample_rate: usize,
    audio_sample_rate_current: f32,
    audio_device: SDL_AudioDeviceID,
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

var main_memory: [@sizeOf(Main) + 200*1024]u8 = undefined;
var hunk = Hunk.init(main_memory[0..]);

pub fn main() u8 {
    const self = blk: {
        const options = parseOptions() catch |err| {
            std.debug.warn("Failed to parse command-line options: {}\n", err);
            return 1;
        } orelse {
            // --help flag was set, don't start the program
            return 0;
        };

        break :blk init(options) catch |_| {
            // init prints its own error
            return 1;
        };
    };

    switch (self.framerate_scheme) {
        .Fixed => |refresh_rate| {
            while (tick(self, refresh_rate)) {}
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

                if (!tick(self, refresh_rate)) {
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

fn parseOptions() !?Options {
    const allocator = &hunk.low().allocator;

    @setEvalBranchQuota(200000);
    const params = comptime [_]clap.Param(clap.Help) {
        clap.parseParam("-h, --help              Display this help and exit") catch unreachable,
        clap.parseParam("-r, --rate <NUM>        Audio sample rate (default 44100)") catch unreachable,
        clap.parseParam("-b, --bufsize <NUM>     Audio buffer size (default 1024)") catch unreachable,
        clap.parseParam("-f, --refreshrate <NUM> Display refresh rate (number or `free`)") catch unreachable,
        clap.parseParam("--novsync               Disable vsync") catch unreachable,
    };

    var iter = clap.args.OsIterator.init(allocator);
    defer iter.deinit();

    _ = try iter.next(); // exe

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

    const buf = self.audio_module.paint(self.audio_sample_rate_current, &self.session);
    const vol = std.math.min(1.0, @intToFloat(f32, self.cfg.volume) / 100.0);
    zang.mixDown(out_bytes, buf, .S16LSB, 1, 0, vol);
}

fn init(options: Options) !*Main {
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

    {
        // get the desktop resolution (for the first display)
        var dm: SDL_DisplayMode = undefined;

        if (SDL_GetDesktopDisplayMode(0, &dm) != 0) {
            // if this happens we'll just stick with a small 1:1 scale window
            std.debug.warn("Failed to query desktop display mode.\n");
        } else {
            const native_w = @intCast(u31, dm.w);
            const native_h = @intCast(u31, dm.h);

            fullscreen_dims = getFullscreenDims(native_w, native_h);
            windowed_dims = getWindowedDims(native_w, native_h);
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

    platform_draw.init(&self.draw_state, platform_draw.DrawInitParams {
        .hunk = &hunk,
        .virtual_window_width = common.virtual_window_width,
        .virtual_window_height = common.virtual_window_height,
    }) catch |err| {
        std.debug.warn("platform_draw.init failed: {}\n", err);
        return error.Failed;
    };
    errdefer platform_draw.deinit(&self.draw_state);

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

    const rand_seed = @intCast(u32, std.time.milliTimestamp() & 0xFFFFFFFF);

    const initial_high_scores = loadHighScores(&hunk.low()) catch |err| {
        std.debug.warn("Failed to load high scores from disk: {}\n", err);
        return error.Failed;
    };

    if (!common.loadStatic(&self.static, &hunk.low())) {
        // loadStatic prints its own error
        return error.Failed;
    }

    // https://github.com/ziglang/zig/issues/3046
    const blah = audio.MainModule.init(&hunk.low(), options.audio_buffer_size) catch |err| {
        std.debug.warn("Failed to load audio module: {}\n", err);
        return error.Failed;
    };
    self.audio_module = blah;

    var cfg = blk: {
        // if config couldn't load, warn and fall back to default config
        const cfg_ = loadConfig(&hunk.low()) catch |err| {
            std.debug.warn("Failed to load config: {}\n", err);
            break :blk config.default;
        };
        break :blk cfg_;
    };

    SDL_PauseAudioDevice(device, 0); // unpause
    errdefer SDL_PauseAudioDevice(device, 1);

    self.session.init(rand_seed);
    gameInit(&self.session, p.MainController.Params {
        .is_fullscreen = fullscreen,
        .volume = cfg.volume,
        .high_scores = initial_high_scores,
    }) catch |err| {
        std.debug.warn("Failed to initialize game: {}\n", err);
        return error.Failed;
    };

    // TODO - this shouldn't be fatal
    perf.init() catch |err| {
        std.debug.warn("Failed to create performance timers: {}\n", err);
        return error.Failed;
    };

    std.debug.warn("Initialization complete.\n");

    self.cfg = cfg;
    self.window = window;
    self.glcontext = glcontext;
    self.fullscreen = fullscreen;
    self.fullscreen_dims = fullscreen_dims;
    self.windowed_dims = windowed_dims;
    self.original_window_x = original_window_x;
    self.original_window_y = original_window_y;
    self.audio_sample_rate = options.audio_sample_rate;
    self.audio_sample_rate_current = @intToFloat(f32, options.audio_sample_rate);
    self.audio_device = device;
    self.fast_forward = false;
    self.framerate_scheme = framerate_scheme;
    self.t = 0.0;

    return self;
}

fn deinit(self: *Main) void {
    std.debug.warn("Shutting down.\n");

    saveConfig(self.cfg, &hunk.low()) catch |err| {
        std.debug.warn("Failed to save config: {}\n", err);
    };

    SDL_PauseAudioDevice(self.audio_device, 1);
    platform_framebuffer.deinit(&self.framebuffer_state);
    platform_draw.deinit(&self.draw_state);
    SDL_GL_DeleteContext(self.glcontext);
    SDL_CloseAudioDevice(self.audio_device);
    SDL_DestroyWindow(self.window);
    SDL_Quit();
}

// this is run once per monitor frame
fn tick(self: *Main, refresh_rate: u64) bool {
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
            if (!handleSDLEvent(self, evt)) {
                return false;
            }
        }

        // copy these system values straight into the MainController (this is
        // context for the menus).
        // this is kind of a hack, but on the other hand, i'm spawning entities
        // in this file too, it's not that different...
        if (self.session.findFirstObject(c.MainController)) |mc| {
            mc.data.is_fullscreen = self.fullscreen;
            mc.data.volume = self.cfg.volume;
        }

        // when fast forwarding, we'll simulate 4 frames and draw them blended
        // together. we'll also speed up the sound playback rate by 4x
        const num_frames = if (self.fast_forward) u32(4) else u32(1);
        var frame_index: u32 = 0; while (frame_index < num_frames) : (frame_index += 1) {
            // if we're simulating multiple frames for one draw cycle, we only
            // need to actually draw for the last one of them
            const draw = i == num_frames_to_simulate - 1;

            // run simulation and create events for drawing, playing sounds, etc.
            perf.begin(&perf.timers.Frame);
            gameFrame(&self.session, draw);
            perf.end(&perf.timers.Frame);

            // middleware response to certain events (mostly from the menu)
            if (!handleSystemCommands(self, &toggle_fullscreen)) {
                return false;
            }

            // update audio (from events)
            playSounds(self, num_frames);

            // draw to framebuffer (from events)
            if (draw) {
                // this alpha value is calculated to end up with an even blend
                // of all fast forward frames
                drawMain(self, 1.0 / @intToFloat(f32, frame_index + 1));
            }

            // delete events
            gameFrameCleanup(&self.session);
        }
    }

    SDL_GL_SwapWindow(self.window);

    if (toggle_fullscreen) {
        toggleFullscreen(self);
    }

    return true;
}

fn toggleFullscreen(self: *Main) void {
    if (self.fullscreen) {
        if (SDL_SetWindowFullscreen(self.window, 0) < 0) {
            std.debug.warn("Failed to disable fullscreen mode");
        } else {
            SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);
            SDL_SetWindowPosition(self.window, self.original_window_x, self.original_window_y);
            self.fullscreen = false;
        }
    } else {
        if (self.fullscreen_dims) |dims| {
            SDL_SetWindowSize(self.window, dims.window_width, dims.window_height);
            if (SDL_SetWindowFullscreen(self.window, SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
                std.debug.warn("Failed to enable fullscreen mode\n");
                SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);
            } else {
                self.fullscreen = true;
            }
        } else {
            // couldn't figure out how to go fullscreen so stay in windowed mode
        }
    }
}

fn handleSDLEvent(self: *Main, evt: SDL_Event) bool {
    switch (evt.type) {
        SDL_KEYDOWN => {
            if (evt.key.repeat == 0) {
                if (translateKey(evt.key.keysym.sym)) |key| {
                    _ = common.spawnInputEvent(&self.session, self.cfg, key, true);

                    switch (key) {
                        .Backquote => {
                            self.fast_forward = true;
                        },
                        .F4 => {
                            perf.toggleSpam();
                        },
                        .F5 => {
                            platform_draw.cycleGlitchMode(&self.draw_state);
                        },
                        else => {},
                    }
                }
            }
        },
        SDL_KEYUP => {
            if (translateKey(evt.key.keysym.sym)) |key| {
                _ = common.spawnInputEvent(&self.session, self.cfg, key, false);

                switch (key) {
                    .Backquote => {
                        self.fast_forward = false;
                    },
                    else => {},
                }
            }
        },
        SDL_JOYAXISMOTION => {
            // TODO - look at evt.jbutton.which (to support multiple joysticks)
            const threshold = 16384;
            var i: usize = 0; while (i < 4) : (i += 1) {
                const neg = switch (i) { 0 => Key.JoyAxis0Neg, 1 => Key.JoyAxis1Neg, 2 => Key.JoyAxis2Neg, 3 => Key.JoyAxis3Neg, else => unreachable };
                const pos = switch (i) { 0 => Key.JoyAxis0Pos, 1 => Key.JoyAxis1Pos, 2 => Key.JoyAxis2Pos, 3 => Key.JoyAxis3Pos, else => unreachable };
                if (evt.jaxis.axis == i) {
                    if (evt.jaxis.value < -threshold) {
                        _ = common.spawnInputEvent(&self.session, self.cfg, neg, true);
                        _ = common.spawnInputEvent(&self.session, self.cfg, pos, false);
                    } else if (evt.jaxis.value > threshold) {
                        _ = common.spawnInputEvent(&self.session, self.cfg, pos, true);
                        _ = common.spawnInputEvent(&self.session, self.cfg, neg, false);
                    } else {
                        _ = common.spawnInputEvent(&self.session, self.cfg, pos, false);
                        _ = common.spawnInputEvent(&self.session, self.cfg, neg, false);
                    }
                }
            }
        },
        SDL_JOYBUTTONDOWN, SDL_JOYBUTTONUP => {
            // TODO - look at evt.jbutton.which (to support multiple joysticks)
            const down = evt.type == SDL_JOYBUTTONDOWN;
            const maybe_key = switch (evt.jbutton.button) {
                0 => Key.JoyButton0,
                1 => Key.JoyButton1,
                2 => Key.JoyButton2,
                3 => Key.JoyButton3,
                4 => Key.JoyButton4,
                5 => Key.JoyButton5,
                6 => Key.JoyButton6,
                7 => Key.JoyButton7,
                8 => Key.JoyButton8,
                9 => Key.JoyButton9,
                10 => Key.JoyButton10,
                11 => Key.JoyButton11,
                else => null,
            };
            if (maybe_key) |key| {
                _ = common.spawnInputEvent(&self.session, self.cfg, key, down);
            }
        },
        SDL_WINDOWEVENT => {
            if (!self.fullscreen and evt.window.event == SDL_WINDOWEVENT_MOVED) {
                self.original_window_x = evt.window.data1;
                self.original_window_y = evt.window.data2;
            }
        },
        SDL_QUIT => {
            return false;
        },
        else => {},
    }
    return true;
}

fn handleSystemCommands(self: *Main, toggle_fullscreen: *bool) bool {
    var it = self.session.iter(c.EventSystemCommand); while (it.next()) |object| {
        switch (object.data) {
            .SetVolume => |value| self.cfg.volume = value,
            .ToggleFullscreen => toggle_fullscreen.* = true,
            .BindGameCommand => |payload| {
                const command_index = @enumToInt(payload.command);
                const key_in_use =
                    if (payload.key) |new_key|
                        for (self.cfg.game_key_bindings) |maybe_key| {
                            if (if (maybe_key) |key| key == new_key else false) {
                                break true;
                            }
                        } else false
                    else false;
                if (!key_in_use) {
                    self.cfg.game_key_bindings[command_index] = payload.key;
                }
            },
            .SaveHighScores => |high_scores| {
                saveHighScores(&hunk.low(), high_scores) catch |err| {
                    std.debug.warn("Failed to save high scores to disk: {}\n", err);
                };
            },
            .Quit => return false,
        }
    }
    return true;
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

    self.audio_module.playSounds(&self.session, impulse_frame);
}

fn drawMain(self: *Main, blit_alpha: f32) void {
    const blit_rect = blk: {
        if (self.fullscreen) {
            if (self.fullscreen_dims) |dims| {
                break :blk dims.blit_rect;
            }
        }
        break :blk self.windowed_dims.blit_rect;
    };

    perf.begin(&perf.timers.WholeDraw);

    platform_framebuffer.preDraw(&self.framebuffer_state);
    platform_draw.prepare(&self.draw_state);

    perf.begin(&perf.timers.Draw);
    drawGame(&self.draw_state, &self.static, &self.session, self.cfg);
    perf.end(&perf.timers.Draw);

    platform_framebuffer.postDraw(&self.framebuffer_state, &self.draw_state, blit_rect, blit_alpha);

    perf.end(&perf.timers.WholeDraw);
}
