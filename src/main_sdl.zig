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
const constants = @import("oxid/constants.zig");
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

const datadir = "Oxid";
const config_filename = "config.json";
const highscores_filename = "highscore.dat";

fn openDataFile(
    hunk_side: *HunkSide,
    filename: []const u8,
    mode: enum { read, write },
) !std.fs.File {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, datadir);

    if (mode == .write) {
        std.fs.makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };
    }

    const file_path = try std.fs.path.join(
        &hunk_side.allocator,
        &[_][]const u8 { dir_path, filename },
    );

    return switch (mode) {
        .read => std.fs.cwd().openFile(file_path, .{}),
        .write => std.fs.cwd().createFile(file_path, .{}),
    };
}

pub fn loadConfig(hunk_side: *HunkSide) !config.Config {
    const file = openDataFile(hunk_side, config_filename, .read) catch |err| {
        if (err == error.FileNotFound) {
            return config.getDefault();
        }
        return err;
    };
    defer file.close();

    const size = try std.math.cast(usize, try file.getEndPos());
    return try config.read(
        std.fs.File.InStream.Error,
        &std.fs.File.inStream(file).stream,
        size,
        hunk_side,
    );
}

pub fn saveConfig(cfg: config.Config, hunk_side: *HunkSide) !void {
    const file = try openDataFile(hunk_side, config_filename, .write);
    defer file.close();

    return try config.write(
        std.fs.File.OutStream.Error,
        &std.fs.File.outStream(file).stream,
        cfg,
    );
}

pub fn loadHighScores(hunk_side: *HunkSide) [constants.num_high_scores]u32 {
    const file = openDataFile(hunk_side, highscores_filename, .read) catch |err| {
        if (err == error.FileNotFound) {
            // this is a normal situation (e.g. game is being played for the
            // first time)
        } else {
            // the file exists but there was an error loading it. just continue
            // with an empty high scores list, even though that might mean that
            // the user's legitimate high scores might get wiped out (FIXME?)
            std.debug.warn("Failed to load high scores file: {}\n", .{err});
        }
        return [1]u32{0} ** constants.num_high_scores;
    };
    defer file.close();

    return datafile.readHighScores(
        std.fs.File.InStream.Error,
        &std.fs.File.inStream(file).stream,
    );
}

pub fn saveHighScores(
    hunk_side: *HunkSide,
    high_scores: [constants.num_high_scores]u32,
) !void {
    const file = try openDataFile(hunk_side, highscores_filename, .write);
    defer file.close();

    try datafile.writeHighScores(
        std.fs.File.OutStream.Error,
        &std.fs.File.outStream(file).stream,
        high_scores,
    );
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
    const scaled_w = native_screen_size.height *
        common.virtual_window_width / common.virtual_window_height;
    const scaled_h = native_screen_size.width *
        common.virtual_window_height / common.virtual_window_width;

    return .{
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

    return .{
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
    // fixed: assume that tick function is called at this rate. don't even
    // look at delta time
    fixed: usize,
    // free: adapt to delta time
    free,
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
            std.debug.warn("Failed to parse command-line options: {}\n", .{err});
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
        .fixed => |refresh_rate| {
            while (!self.quit) {
                tick(self, refresh_rate);
            }
        },
        .free => {
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
                    .fixed => |rate| rate,
                    .free => 1000000 / delta_microseconds,
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

                const threshold = 1000000 / (2 * constants.ticks_per_second);
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

    var args = try clap.parse(clap.Help, &params, allocator);
    defer args.deinit();

    if (args.flag("--help")) {
        std.debug.warn("Usage:\n", .{});
        try clap.help(std.debug.getStderrStream(), &params);
        return null;
    }

    var options: Options = .{
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
            options.framerate_scheme = .free;
        } else {
            options.framerate_scheme = .{
                .fixed = try std.fmt.parseInt(usize, value, 10),
            };
        }
    }
    if (args.flag("--novsync")) {
        options.vsync = false;
    }

    return options;
}

fn getFramerateScheme(
    window: *SDL_Window,
    vsync: bool,
    maybe_scheme: ?FramerateScheme,
) !FramerateScheme {
    if (!vsync) {
        // if vsync isn't enabled, a fixed framerate scheme never makes sense
        return .free;
    }

    if (maybe_scheme) |scheme| {
        // explicit scheme was supplied via command line option. override any
        // auto-detection.
        switch (scheme) {
            .fixed => |rate| {
                if (rate < 1 or rate > 300) {
                    std.debug.warn("Invalid refresh rate: {}\n", .{rate});
                    return error.Failed;
                }
            },
            .free => {},
        }
        return scheme;
    }

    // vsync is enabled, so try to identify the display's native refresh rate
    // and use that as our fixed rate
    const display_index = SDL_GetWindowDisplayIndex(window);
    var mode: SDL_DisplayMode = undefined;
    if (SDL_GetDesktopDisplayMode(display_index, &mode) != 0) {
        std.debug.warn(
            "Failed to get refresh rate, defaulting to free framerate.\n", .{});
        return .free;
    }
    if (mode.refresh_rate <= 0) {
        std.debug.warn(
            "Refresh rate reported as {}, defaulting to free framerate.\n",
            .{ mode.refresh_rate });
        return .free;
    }
    // TODO - do i need to update this when the window moves (possibly to
    // another monitor with a different refresh rate)?
    return FramerateScheme {
        .fixed = @intCast(usize, mode.refresh_rate),
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
        std.debug.warn("Unable to initialize SDL: {s}\n", .{SDL_GetError()});
        return error.Failed;
    }
    errdefer SDL_Quit();

    const fullscreen = false;
    var fullscreen_dims: ?WindowDims = null;
    var windowed_dims: WindowDims = .{
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
            std.debug.warn("Failed to query desktop display mode.\n", .{});
        } else {
            native_screen_size = .{
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
        "Oxid",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, windowed_dims.window_width),
        @intCast(c_int, windowed_dims.window_height),
        SDL_WINDOW_OPENGL,
    ) orelse {
        std.debug.warn("Unable to create window: {s}\n", .{SDL_GetError()});
        return error.Failed;
    };
    errdefer SDL_DestroyWindow(window);

    var original_window_x: c_int = undefined;
    var original_window_y: c_int = undefined;
    SDL_GetWindowPosition(window, &original_window_x, &original_window_y);

    if (options.audio_sample_rate < 6000 or options.audio_sample_rate > 192000) {
        std.debug.warn("Invalid audio sample rate: {}\n", .{options.audio_sample_rate});
        return error.Failed;
    }
    if (options.audio_buffer_size < 32 or options.audio_buffer_size > 65535) {
        std.debug.warn("Invalid audio buffer size: {}\n", .{options.audio_buffer_size});
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
        std.debug.warn("Failed to open audio: {s}\n", .{SDL_GetError()});
        return error.Failed;
    }
    errdefer SDL_CloseAudioDevice(device);

    const glcontext = SDL_GL_CreateContext(window) orelse {
        std.debug.warn("SDL_GL_CreateContext failed: {s}\n", .{SDL_GetError()});
        return error.Failed;
    };
    errdefer SDL_GL_DeleteContext(glcontext);

    _ = SDL_GL_MakeCurrent(window, glcontext);

    if (options.vsync) {
        if (SDL_GL_SetSwapInterval(1) != 0) {
            std.debug.warn("Warning: failed to set vsync.\n", .{});
        }
    } else {
        if (SDL_GL_SetSwapInterval(0) != 0) {
            std.debug.warn("Warning: failed to disable vsync.\n", .{});
        }
    }

    // this function can return 1 (vsync), 0 (no vsync), or -1 (adaptive
    // vsync). i don't really get what adaptive vsync is but it seems like it
    // should be classed with vsync.
    const vsync_enabled = SDL_GL_GetSwapInterval() != 0;
    // https://github.com/ziglang/zig/issues/3882
    const vsync_str = if (vsync_enabled) "enabled" else "disabled";
    std.debug.warn("Vsync is {}.\n", .{ vsync_str });

    const framerate_scheme = try getFramerateScheme(
        window,
        vsync_enabled,
        options.framerate_scheme,
    );
    switch (framerate_scheme) {
        .fixed => |refresh_rate|
            std.debug.warn("Framerate scheme: fixed {}hz\n", .{ refresh_rate }),
        .free => std.debug.warn("Framerate scheme: free\n", .{}),
    }

    if (!platform_framebuffer.init(
        &self.framebuffer_state,
        common.virtual_window_width,
        common.virtual_window_height,
    )) {
        std.debug.warn("platform_framebuffer.init failed\n", .{});
        return error.Failed;
    }
    errdefer platform_framebuffer.deinit(&self.framebuffer_state);

    {
        const num_joysticks = SDL_NumJoysticks();
        std.debug.warn("{} joystick(s)\n", .{num_joysticks});
        var i: c_int = 0; while (i < 2 and i < num_joysticks) : (i += 1) {
            const joystick = SDL_JoystickOpen(i);
            if (joystick == null) {
                std.debug.warn("Failed to open joystick {}\n", .{i + 1});
            }
        }
    }

    // FIXME - can't use an anonymous literal here. the compiler says
    // "TODO: type coercion of an anon struct literal to struct"
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

    std.debug.warn("Initialization complete.\n", .{});

    return self;
}

fn deinit(self: *Main) void {
    std.debug.warn("Shutting down.\n", .{});

    saveConfig(self.main_state.cfg, &self.main_state.hunk.low()) catch |err| {
        std.debug.warn("Failed to save config: {}\n", .{err});
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
        self.t += constants.ticks_per_second; // gameplay update rate
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

        const frame_context: GameFrameContext = .{
            .friendly_fire = self.main_state.friendly_fire,
        };

        // when fast forwarding, we'll simulate 4 frames and draw them blended
        // together. we'll also speed up the sound playback rate by 4x
        const num_frames: u32 = if (self.fast_forward) 4 else 1;
        var frame_index: u32 = 0;
        while (frame_index < num_frames) : (frame_index += 1) {
            // if we're simulating multiple frames for one draw cycle, we only
            // need to actually draw for the last one of them
            const draw = i == num_frames_to_simulate - 1;

            // run simulation and create events for drawing, playing sounds, etc.
            const paused = self.main_state.menu_stack.len > 0
                            and !self.main_state.game_over;

            perf.begin(.frame);
            gameFrame(&self.main_state.session, frame_context, draw, paused);
            perf.end(.frame);

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

    perf.display();
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
            std.debug.warn("Failed to disable fullscreen mode", .{});
        } else {
            SDL_SetWindowSize(self.window, self.windowed_dims.window_width, self.windowed_dims.window_height);
            SDL_SetWindowPosition(self.window, self.original_window_x, self.original_window_y);
            self.main_state.fullscreen = false;
        }
    } else {
        if (self.fullscreen_dims) |dims| {
            SDL_SetWindowSize(self.window, dims.window_width, dims.window_height);
            if (SDL_SetWindowFullscreen(self.window, SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
                std.debug.warn("Failed to enable fullscreen mode\n", .{});
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
            .noop => {},
            .quit => self.quit = true,
            .toggle_sound => {}, // unused in SDL build
            .toggle_fullscreen => toggleFullscreen(self),
            .set_canvas_scale => |value| setCanvasScale(self, value),
        }
    }
}

fn handleSDLEvent(self: *Main, evt: SDL_Event) void {
    switch (evt.type) {
        SDL_KEYDOWN => {
            if (evt.key.repeat == 0) {
                if (translateKey(evt.key.keysym.sym)) |key| {
                    inputEvent(self, .{ .key = key }, true);

                    switch (key) {
                        .backquote => {
                            self.fast_forward = true;
                        },
                        .f4 => {
                            perf.toggleSpam();
                        },
                        .f5 => {
                            platform_draw.cycleGlitchMode(
                                &self.main_state.draw_state,
                            );
                        },
                        else => {},
                    }
                }
            }
        },
        SDL_KEYUP => {
            if (translateKey(evt.key.keysym.sym)) |key| {
                inputEvent(self, .{ .key = key }, false);

                switch (key) {
                    .backquote => {
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
        SDL_JOYBUTTONDOWN, SDL_JOYBUTTONUP => {
            const joy_button: JoyButton = .{
                .which = @intCast(usize, evt.jbutton.which),
                .button = evt.jbutton.button,
            };
            inputEvent(
                self,
                .{ .joy_button = joy_button },
                evt.type == SDL_JOYBUTTONDOWN,
            );
        },
        SDL_WINDOWEVENT => {
            if (!self.main_state.fullscreen and
                    evt.window.event == SDL_WINDOWEVENT_MOVED) {
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
    self.audio_sample_rate_current =
        @intToFloat(f32, self.audio_sample_rate) / @intToFloat(f32, num_frames);

    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer. need to implement some
    // "syncing" to guess where we are in the middle of a mix frame
    const impulse_frame: usize = 0;

    self.main_state.audio_module.playSounds(
        &self.main_state.session,
        impulse_frame,
    );
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

    perf.begin(.whole_draw);

    platform_framebuffer.preDraw(&self.framebuffer_state);

    perf.begin(.draw);
    common.drawMain(&self.main_state);
    perf.end(.draw);

    platform_framebuffer.postDraw(
        &self.framebuffer_state,
        &self.main_state.draw_state,
        blit_rect,
        blit_alpha,
    );

    perf.end(.whole_draw);
}

fn translateKey(sym: SDL_Keycode) ?Key {
    return switch (sym) {
        SDLK_RETURN => .@"return",
        SDLK_ESCAPE => .escape,
        SDLK_BACKSPACE => .backspace,
        SDLK_TAB => .tab,
        SDLK_SPACE => .space,
        SDLK_EXCLAIM => .exclaim,
        SDLK_QUOTEDBL => .quotedbl,
        SDLK_HASH => .hash,
        SDLK_PERCENT => .percent,
        SDLK_DOLLAR => .dollar,
        SDLK_AMPERSAND => .ampersand,
        SDLK_QUOTE => .quote,
        SDLK_LEFTPAREN => .leftparen,
        SDLK_RIGHTPAREN => .rightparen,
        SDLK_ASTERISK => .asterisk,
        SDLK_PLUS => .plus,
        SDLK_COMMA => .comma,
        SDLK_MINUS => .minus,
        SDLK_PERIOD => .period,
        SDLK_SLASH => .slash,
        SDLK_0 => .@"0",
        SDLK_1 => .@"1",
        SDLK_2 => .@"2",
        SDLK_3 => .@"3",
        SDLK_4 => .@"4",
        SDLK_5 => .@"5",
        SDLK_6 => .@"6",
        SDLK_7 => .@"7",
        SDLK_8 => .@"8",
        SDLK_9 => .@"9",
        SDLK_COLON => .colon,
        SDLK_SEMICOLON => .semicolon,
        SDLK_LESS => .less,
        SDLK_EQUALS => .equals,
        SDLK_GREATER => .greater,
        SDLK_QUESTION => .question,
        SDLK_AT => .at,
        SDLK_LEFTBRACKET => .leftbracket,
        SDLK_BACKSLASH => .backslash,
        SDLK_RIGHTBRACKET => .rightbracket,
        SDLK_CARET => .caret,
        SDLK_UNDERSCORE => .underscore,
        SDLK_BACKQUOTE => .backquote,
        SDLK_a => .a,
        SDLK_b => .b,
        SDLK_c => .c,
        SDLK_d => .d,
        SDLK_e => .e,
        SDLK_f => .f,
        SDLK_g => .g,
        SDLK_h => .h,
        SDLK_i => .i,
        SDLK_j => .j,
        SDLK_k => .k,
        SDLK_l => .l,
        SDLK_m => .m,
        SDLK_n => .n,
        SDLK_o => .o,
        SDLK_p => .p,
        SDLK_q => .q,
        SDLK_r => .r,
        SDLK_s => .s,
        SDLK_t => .t,
        SDLK_u => .u,
        SDLK_v => .v,
        SDLK_w => .w,
        SDLK_x => .x,
        SDLK_y => .y,
        SDLK_z => .z,
        SDLK_CAPSLOCK => .capslock,
        SDLK_F1 => .f1,
        SDLK_F2 => .f2,
        SDLK_F3 => .f3,
        SDLK_F4 => .f4,
        SDLK_F5 => .f5,
        SDLK_F6 => .f6,
        SDLK_F7 => .f7,
        SDLK_F8 => .f8,
        SDLK_F9 => .f9,
        SDLK_F10 => .f10,
        SDLK_F11 => .f11,
        SDLK_F12 => .f12,
        SDLK_PRINTSCREEN => .printscreen,
        SDLK_SCROLLLOCK => .scrolllock,
        SDLK_PAUSE => .pause,
        SDLK_INSERT => .insert,
        SDLK_HOME => .home,
        SDLK_PAGEUP => .pageup,
        SDLK_DELETE => .delete,
        SDLK_END => .end,
        SDLK_PAGEDOWN => .pagedown,
        SDLK_RIGHT => .right,
        SDLK_LEFT => .left,
        SDLK_DOWN => .down,
        SDLK_UP => .up,
        SDLK_NUMLOCKCLEAR => .numlockclear,
        SDLK_KP_DIVIDE => .kp_divide,
        SDLK_KP_MULTIPLY => .kp_multiply,
        SDLK_KP_MINUS => .kp_minus,
        SDLK_KP_PLUS => .kp_plus,
        SDLK_KP_ENTER => .kp_enter,
        SDLK_KP_1 => .kp_1,
        SDLK_KP_2 => .kp_2,
        SDLK_KP_3 => .kp_3,
        SDLK_KP_4 => .kp_4,
        SDLK_KP_5 => .kp_5,
        SDLK_KP_6 => .kp_6,
        SDLK_KP_7 => .kp_7,
        SDLK_KP_8 => .kp_8,
        SDLK_KP_9 => .kp_9,
        SDLK_KP_0 => .kp_0,
        SDLK_KP_PERIOD => .kp_period,
        SDLK_APPLICATION => .application,
        SDLK_POWER => .power,
        SDLK_KP_EQUALS => .kp_equals,
        SDLK_F13 => .f13,
        SDLK_F14 => .f14,
        SDLK_F15 => .f15,
        SDLK_F16 => .f16,
        SDLK_F17 => .f17,
        SDLK_F18 => .f18,
        SDLK_F19 => .f19,
        SDLK_F20 => .f20,
        SDLK_F21 => .f21,
        SDLK_F22 => .f22,
        SDLK_F23 => .f23,
        SDLK_F24 => .f24,
        SDLK_EXECUTE => .execute,
        SDLK_HELP => .help,
        SDLK_MENU => .menu,
        SDLK_SELECT => .select,
        SDLK_STOP => .stop,
        SDLK_AGAIN => .again,
        SDLK_UNDO => .undo,
        SDLK_CUT => .cut,
        SDLK_COPY => .copy,
        SDLK_PASTE => .paste,
        SDLK_FIND => .find,
        SDLK_MUTE => .mute,
        SDLK_VOLUMEUP => .volumeup,
        SDLK_VOLUMEDOWN => .volumedown,
        SDLK_KP_COMMA => .kp_comma,
        SDLK_KP_EQUALSAS400 => .kp_equalsas400,
        SDLK_ALTERASE => .alterase,
        SDLK_SYSREQ => .sysreq,
        SDLK_CANCEL => .cancel,
        SDLK_CLEAR => .clear,
        SDLK_PRIOR => .prior,
        SDLK_RETURN2 => .return2,
        SDLK_SEPARATOR => .separator,
        SDLK_OUT => .out,
        SDLK_OPER => .oper,
        SDLK_CLEARAGAIN => .clearagain,
        SDLK_CRSEL => .crsel,
        SDLK_EXSEL => .exsel,
        SDLK_KP_00 => .kp_00,
        SDLK_KP_000 => .kp_000,
        SDLK_THOUSANDSSEPARATOR => .thousandsseparator,
        SDLK_DECIMALSEPARATOR => .decimalseparator,
        SDLK_CURRENCYUNIT => .currencyunit,
        SDLK_CURRENCYSUBUNIT => .currencysubunit,
        SDLK_KP_LEFTPAREN => .kp_leftparen,
        SDLK_KP_RIGHTPAREN => .kp_rightparen,
        SDLK_KP_LEFTBRACE => .kp_leftbrace,
        SDLK_KP_RIGHTBRACE => .kp_rightbrace,
        SDLK_KP_TAB => .kp_tab,
        SDLK_KP_BACKSPACE => .kp_backspace,
        SDLK_KP_A => .kp_a,
        SDLK_KP_B => .kp_b,
        SDLK_KP_C => .kp_c,
        SDLK_KP_D => .kp_d,
        SDLK_KP_E => .kp_e,
        SDLK_KP_F => .kp_f,
        SDLK_KP_XOR => .kp_xor,
        SDLK_KP_POWER => .kp_power,
        SDLK_KP_PERCENT => .kp_percent,
        SDLK_KP_LESS => .kp_less,
        SDLK_KP_GREATER => .kp_greater,
        SDLK_KP_AMPERSAND => .kp_ampersand,
        SDLK_KP_DBLAMPERSAND => .kp_dblampersand,
        SDLK_KP_VERTICALBAR => .kp_verticalbar,
        SDLK_KP_DBLVERTICALBAR => .kp_dblverticalbar,
        SDLK_KP_COLON => .kp_colon,
        SDLK_KP_HASH => .kp_hash,
        SDLK_KP_SPACE => .kp_space,
        SDLK_KP_AT => .kp_at,
        SDLK_KP_EXCLAM => .kp_exclam,
        SDLK_KP_MEMSTORE => .kp_memstore,
        SDLK_KP_MEMRECALL => .kp_memrecall,
        SDLK_KP_MEMCLEAR => .kp_memclear,
        SDLK_KP_MEMADD => .kp_memadd,
        SDLK_KP_MEMSUBTRACT => .kp_memsubtract,
        SDLK_KP_MEMMULTIPLY => .kp_memmultiply,
        SDLK_KP_MEMDIVIDE => .kp_memdivide,
        SDLK_KP_PLUSMINUS => .kp_plusminus,
        SDLK_KP_CLEAR => .kp_clear,
        SDLK_KP_CLEARENTRY => .kp_clearentry,
        SDLK_KP_BINARY => .kp_binary,
        SDLK_KP_OCTAL => .kp_octal,
        SDLK_KP_DECIMAL => .kp_decimal,
        SDLK_KP_HEXADECIMAL => .kp_hexadecimal,
        SDLK_LCTRL => .lctrl,
        SDLK_LSHIFT => .lshift,
        SDLK_LALT => .lalt,
        SDLK_LGUI => .lgui,
        SDLK_RCTRL => .rctrl,
        SDLK_RSHIFT => .rshift,
        SDLK_RALT => .ralt,
        SDLK_RGUI => .rgui,
        SDLK_MODE => .mode,
        SDLK_AUDIONEXT => .audionext,
        SDLK_AUDIOPREV => .audioprev,
        SDLK_AUDIOSTOP => .audiostop,
        SDLK_AUDIOPLAY => .audioplay,
        SDLK_AUDIOMUTE => .audiomute,
        SDLK_MEDIASELECT => .mediaselect,
        SDLK_WWW => .www,
        SDLK_MAIL => .mail,
        SDLK_CALCULATOR => .calculator,
        SDLK_COMPUTER => .computer,
        SDLK_AC_SEARCH => .ac_search,
        SDLK_AC_HOME => .ac_home,
        SDLK_AC_BACK => .ac_back,
        SDLK_AC_FORWARD => .ac_forward,
        SDLK_AC_STOP => .ac_stop,
        SDLK_AC_REFRESH => .ac_refresh,
        SDLK_AC_BOOKMARKS => .ac_bookmarks,
        SDLK_BRIGHTNESSDOWN => .brightnessdown,
        SDLK_BRIGHTNESSUP => .brightnessup,
        SDLK_DISPLAYSWITCH => .displayswitch,
        SDLK_KBDILLUMTOGGLE => .kbdillumtoggle,
        SDLK_KBDILLUMDOWN => .kbdillumdown,
        SDLK_KBDILLUMUP => .kbdillumup,
        SDLK_EJECT => .eject,
        SDLK_SLEEP => .sleep,
        SDLK_APP1 => .app1,
        SDLK_APP2 => .app2,
        SDLK_AUDIOREWIND => .audiorewind,
        SDLK_AUDIOFASTFORWARD => .audiofastforward,
        else => null,
    };
}
