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
const gameInit = @import("oxid/frame.zig").gameInit;
const gameFrame = @import("oxid/frame.zig").gameFrame;
const gameFrameCleanup = @import("oxid/frame.zig").gameFrameCleanup;
const p = @import("oxid/prototypes.zig");
const drawGame = @import("oxid/draw.zig").drawGame;
const MenuDrawParams = @import("oxid/draw_menu.zig").MenuDrawParams;
const drawMenu = @import("oxid/draw_menu.zig").drawMenu;
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
            return config.getDefault();
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

    return try config.write(std.fs.File.OutStream.Error, &std.fs.File.outStream(file).stream, cfg);
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
    // pick a window size that isn't bigger than the desktop resolution

    // the actual window size will be an integer multiple of the virtual window
    // size. this value puts a limit on high big it will be scaled (it will
    // also be limited by the user's screen resolution)
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
    draw_state: platform_draw.DrawState,
    framebuffer_state: platform_framebuffer.FramebufferState,
    audio_module: audio.MainModule,
    session: GameSession,
    static: common.GameStatic,
    cfg: config.Config,
    window: *SDL_Window,
    glcontext: SDL_GLContext,
    canvas_scale: u31,
    max_canvas_scale: u31,
    fullscreen: bool,
    fullscreen_dims: ?WindowDims,
    windowed_dims: WindowDims,
    native_screen_size: ?NativeScreenSize,
    original_window_x: i32,
    original_window_y: i32,
    audio_sample_rate: usize,
    audio_sample_rate_current: f32,
    audio_device: SDL_AudioDeviceID,
    high_scores: [Constants.num_high_scores]u32,
    new_high_score: bool,
    game_over: bool,
    menu_stack: menus.MenuStack,
    quit: bool,
    fast_forward: bool,
    framerate_scheme: FramerateScheme,
    t: usize,
    menu_anim_time: u32,
};

const Options = struct {
    audio_sample_rate: usize,
    audio_buffer_size: usize,
    framerate_scheme: ?FramerateScheme,
    vsync: bool, // if disabled, framerate scheme will be ignored
};

fn makeMenuContext(self: *Main) menus.MenuContext {
    return menus.MenuContext {
        .sound_enabled = true, // unused in SDL build
        .fullscreen = self.fullscreen,
        .cfg = self.cfg,
        .high_scores = self.high_scores,
        .new_high_score = self.new_high_score,
        .game_over = self.game_over,
        .anim_time = self.menu_anim_time,
        .canvas_scale = self.canvas_scale,
        .max_canvas_scale = self.max_canvas_scale,
    };
}

// since audio files are loaded at runtime, we need to make room for them in
// the memory buffer
const audio_assets_size = 320700;

var main_memory: [@sizeOf(Main) + 200*1024 + audio_assets_size]u8 = undefined;
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

    self.audio_module = audio.MainModule.init(&hunk, options.audio_buffer_size) catch |err| {
        std.debug.warn("Failed to load audio module: {}\n", err);
        return error.Failed;
    };

    var cfg = blk: {
        // if config couldn't load, warn and fall back to default config
        const cfg_ = loadConfig(&hunk.low()) catch |err| {
            std.debug.warn("Failed to load config: {}\n", err);
            break :blk config.getDefault();
        };
        break :blk cfg_;
    };

    SDL_PauseAudioDevice(device, 0); // unpause
    errdefer SDL_PauseAudioDevice(device, 1);

    self.session.init(rand_seed);
    gameInit(&self.session) catch |err| {
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
    self.canvas_scale = initial_canvas_scale;
    self.max_canvas_scale = max_canvas_scale;
    self.fullscreen = fullscreen;
    self.fullscreen_dims = fullscreen_dims;
    self.windowed_dims = windowed_dims;
    self.native_screen_size = native_screen_size;
    self.original_window_x = original_window_x;
    self.original_window_y = original_window_y;
    self.audio_sample_rate = options.audio_sample_rate;
    self.audio_sample_rate_current = @intToFloat(f32, options.audio_sample_rate);
    self.audio_device = device;
    self.high_scores = initial_high_scores;
    self.new_high_score = false;
    self.game_over = false;
    self.menu_stack = menus.MenuStack {
        .array = undefined,
        .len = 1,
    };
    self.menu_stack.array[0] = menus.Menu {
        .MainMenu = menus.MainMenu.init(),
    };
    self.quit = false;
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

        self.menu_anim_time +%= 1;

        // when fast forwarding, we'll simulate 4 frames and draw them blended
        // together. we'll also speed up the sound playback rate by 4x
        const num_frames = if (self.fast_forward) u32(4) else u32(1);
        var frame_index: u32 = 0; while (frame_index < num_frames) : (frame_index += 1) {
            // if we're simulating multiple frames for one draw cycle, we only
            // need to actually draw for the last one of them
            const draw = i == num_frames_to_simulate - 1;

            // run simulation and create events for drawing, playing sounds, etc.
            const paused = self.menu_stack.len > 0 and !self.game_over;

            perf.begin(&perf.timers.Frame);
            gameFrame(&self.session, draw, paused);
            perf.end(&perf.timers.Frame);

            // middleware response to certain events
            handleGameOver(self);

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
}

fn handleGameOver(self: *Main) void {
    var it = self.session.iter(c.EventPlayerOutOfLives); while (it.next()) |object| {
        finalizeGame(self);
        self.menu_stack.push(menus.Menu {
            .GameOverMenu = menus.GameOverMenu.init(),
        });
    }
}

fn finalizeGame(self: *Main) void {
    self.game_over = true;
    self.new_high_score = false;

    // get player's score
    const pc = self.session.findFirst(c.PlayerController) orelse return;

    // insert the score somewhere in the high score list
    const new_score = pc.score;

    // the list is always sorted highest to lowest
    var i: usize = 0; while (i < Constants.num_high_scores) : (i += 1) {
        if (new_score > self.high_scores[i]) {
            // insert the new score here
            std.mem.copyBackwards(u32,
                self.high_scores[i + 1..Constants.num_high_scores],
                self.high_scores[i..Constants.num_high_scores - 1]
            );

            self.high_scores[i] = new_score;
            if (i == 0) {
                self.new_high_score = true;
            }

            saveHighScores(&hunk.low(), self.high_scores) catch |err| {
                std.debug.warn("Failed to save high scores to disk: {}\n", err);
            };

            break;
        }
    }
}

fn setCanvasScale(self: *Main, scale: u31) void {
    self.windowed_dims = getWindowedDims(scale);

    if (!self.fullscreen) {
        SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);

        if (self.native_screen_size) |native_screen_size| {
            var set = false;
            if (self.original_window_x + i32(self.windowed_dims.window_width) > i32(native_screen_size.width)) {
                self.original_window_x = i32(native_screen_size.width) - i32(self.windowed_dims.window_width);
                if (self.original_window_x < 0) {
                    self.original_window_x = 0;
                }
                set = true;
            }
            if (self.original_window_y + i32(self.windowed_dims.window_height) > i32(native_screen_size.height)) {
                self.original_window_y = i32(native_screen_size.height) - i32(self.windowed_dims.window_height);
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

    self.canvas_scale = scale;
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

fn applyMenuEffect(self: *Main, effect: menus.Effect) void {
    switch (effect) {
        .NoOp => {},
        .Push => |new_menu| {
            self.menu_stack.push(new_menu);
        },
        .Pop => {
            self.menu_stack.pop();
        },
        .StartNewGame => {
            self.menu_stack.clear();
            common.startGame(&self.session);
            self.game_over = false;
            self.new_high_score = false;
        },
        .EndGame => {
            finalizeGame(self);
            common.abortGame(&self.session);

            self.menu_stack.clear();
            self.menu_stack.push(menus.Menu {
                .MainMenu = menus.MainMenu.init(),
            });
        },
        .ToggleSound => {
            // unused in SDL build
        },
        .SetVolume => |value| {
            self.cfg.volume = value;
        },
        .SetCanvasScale => |value| {
            setCanvasScale(self, value);
        },
        .ToggleFullscreen => {
            toggleFullscreen(self);
        },
        .BindGameCommand => |payload| {
            const command_index = @enumToInt(payload.command);
            const in_use =
                if (payload.source) |new_source|
                    for (self.cfg.game_bindings) |maybe_source| {
                        if (if (maybe_source) |source| areInputSourcesEqual(source, new_source) else false) {
                            break true;
                        }
                    } else false
                else false;
            if (!in_use) {
                self.cfg.game_bindings[command_index] = payload.source;
            }
        },
        .ResetAnimTime => {
            self.menu_anim_time = 0;
        },
        .Quit => {
            self.quit = true;
        },
    }
}

fn inputEvent(self: *Main, source: InputSource, down: bool) void {
    if (common.inputEvent(&self.session, self.cfg, source, down, &self.menu_stack, &self.audio_module, makeMenuContext(self))) |effect| {
        applyMenuEffect(self, effect);
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
                            platform_draw.cycleGlitchMode(&self.draw_state);
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
            if (!self.fullscreen and evt.window.event == SDL_WINDOWEVENT_MOVED) {
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
    drawGame(&self.draw_state, &self.static, &self.session, self.cfg, self.high_scores[0]);
    drawMenu(&self.menu_stack, MenuDrawParams {
        .ds = &self.draw_state,
        .static = &self.static,
        .menu_context = makeMenuContext(self),
    });
    perf.end(&perf.timers.Draw);

    platform_framebuffer.postDraw(&self.framebuffer_state, &self.draw_state, blit_rect, blit_alpha);

    perf.end(&perf.timers.WholeDraw);
}
