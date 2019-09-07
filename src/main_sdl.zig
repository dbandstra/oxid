usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("epoxy/gl.h");
});

const std = @import("std");
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

const GameState = struct {
    draw_state: platform_draw.DrawState,
    framebuffer_state: platform_framebuffer.FramebufferState,
    audio_module: audio.MainModule,
    session: GameSession,
    static: common.GameStatic,
};

const AudioUserData = struct {
    g: *GameState,
    sample_rate: f32,
    volume: u32,
};

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

extern fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) void {
    const userdata = @ptrCast(*AudioUserData, @alignCast(@alignOf(*AudioUserData), userdata_.?));
    const out_bytes = stream_.?[0..@intCast(usize, len_)];

    const g = userdata.g;

    const buf = g.audio_module.paint(userdata.sample_rate, &g.session);

    const vol = std.math.min(1.0, @intToFloat(f32, userdata.volume) / 100.0);

    zang.mixDown(out_bytes, buf, .S16LSB, 1, 0, vol);
}

var main_memory: [@sizeOf(GameState) + 200*1024]u8 = undefined;

pub fn main() u8 {
    var hunk = Hunk.init(main_memory[0..]);

    const audio_sample_rate = 44100;
    const audio_buffer_size = 1024;

    const g = hunk.low().allocator.create(GameState) catch unreachable;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) != 0) {
        SDL_Log(c"Unable to initialize SDL: %s", SDL_GetError());
        return 1;
    }
    defer SDL_Quit();

    var fullscreen = false;
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
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_DEPTH_SIZE), 24);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_STENCIL_SIZE), 8);

    // start in windowed mode
    const window = SDL_CreateWindow(
        c"Oxid",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, windowed_dims.window_width),
        @intCast(c_int, windowed_dims.window_height),
        SDL_WINDOW_OPENGL,
    ) orelse {
        SDL_Log(c"Unable to create window: %s", SDL_GetError());
        return 1;
    };
    defer SDL_DestroyWindow(window);

    var original_window_x: c_int = undefined;
    var original_window_y: c_int = undefined;
    SDL_GetWindowPosition(window, &original_window_x, &original_window_y);

    var audio_user_data = AudioUserData {
        .g = g,
        .sample_rate = audio_sample_rate,
        .volume = 0,
    };

    var want: SDL_AudioSpec = undefined;
    want.freq = @intCast(c_int, audio_sample_rate);
    want.format = AUDIO_S16LSB;
    want.channels = 1;
    want.samples = audio_buffer_size;
    want.callback = audioCallback;
    want.userdata = &audio_user_data;

    // TODO - allow SDL to pick something different? (make sure to update
    // ps.audio_user_data.sample_rate)
    const device: SDL_AudioDeviceID = SDL_OpenAudioDevice(
        0, // device name (NULL)
        0, // non-zero to open for recording instead of playback
        &want, // desired output format
        0, // obtained output format (NULL)
        0, // allowed changes: 0 means `obtained` will not differ from `want`, and SDL will do any necessary resampling behind the scenes
    );
    if (device == 0) {
        SDL_Log(c"Failed to open audio: %s", SDL_GetError());
        return 1;
    }
    defer SDL_CloseAudioDevice(device);
    defer SDL_CloseAudio();

    const glcontext = SDL_GL_CreateContext(window) orelse {
        SDL_Log(c"SDL_GL_CreateContext failed: %s", SDL_GetError());
        return 1;
    };
    defer SDL_GL_DeleteContext(glcontext);

    _ = SDL_GL_MakeCurrent(window, glcontext);

    platform_draw.init(&g.draw_state, platform_draw.DrawInitParams {
        .hunk = &hunk,
        .virtual_window_width = common.virtual_window_width,
        .virtual_window_height = common.virtual_window_height,
    }) catch |err| {
        std.debug.warn("platform_draw.init failed: {}\n", err);
        return 1;
    };
    defer platform_draw.deinit(&g.draw_state);

    if (!platform_framebuffer.init(&g.framebuffer_state, common.virtual_window_width, common.virtual_window_height)) {
        std.debug.warn("platform_framebuffer.init failed\n");
        return 1;
    }
    defer platform_framebuffer.deinit(&g.framebuffer_state);

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
        return 1;
    };

    if (!common.loadStatic(&g.static, &hunk.low())) {
        // loadStatic prints its own error
        return 1;
    }

    // https://github.com/ziglang/zig/issues/3046
    const blah = audio.MainModule.init(&hunk.low(), audio_buffer_size) catch |err| {
        std.debug.warn("Failed to load audio module: {}\n", err);
        return 1;
    };
    g.audio_module = blah;

    var cfg = blk: {
        // if config couldn't load, warn and fall back to default config
        const cfg_ = loadConfig(&hunk.low()) catch |err| {
            std.debug.warn("Failed to load config: {}\n", err);
            break :blk config.default;
        };
        break :blk cfg_;
    };

    defer saveConfig(cfg, &hunk.low()) catch |err| {
        std.debug.warn("Failed to save config: {}\n", err);
    };

    SDL_PauseAudioDevice(device, 0); // unpause
    defer SDL_PauseAudioDevice(device, 1);

    var fast_forward = false;

    g.session.init(rand_seed);
    gameInit(&g.session, p.MainController.Params {
        .is_fullscreen = fullscreen,
        .volume = cfg.volume,
        .high_scores = initial_high_scores,
    }) catch |err| {
        std.debug.warn("Failed to initialize game: {}\n", err);
        return 1;
    };

    // TODO - this shouldn't be fatal
    perf.init() catch |err| {
        std.debug.warn("Failed to create performance timers: {}\n", err);
        return 1;
    };

    var quit = false;
    while (!quit) {
        var sdl_event: SDL_Event = undefined;

        while (SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                SDL_KEYDOWN => {
                    if (sdl_event.key.repeat == 0) {
                        if (translateKey(sdl_event.key.keysym.sym)) |key| {
                            _ = common.spawnInputEvent(&g.session, &cfg, key, true);

                            switch (key) {
                                .Backquote => {
                                    fast_forward = true;
                                },
                                .F4 => {
                                    perf.toggleSpam();
                                },
                                .F5 => {
                                    platform_draw.cycleGlitchMode(&g.draw_state);
                                },
                                else => {},
                            }
                        }
                    }
                },
                SDL_KEYUP => {
                    if (translateKey(sdl_event.key.keysym.sym)) |key| {
                        _ = common.spawnInputEvent(&g.session, &cfg, key, false);

                        switch (key) {
                            .Backquote => {
                                fast_forward = false;
                            },
                            else => {},
                        }
                    }
                },
                SDL_JOYAXISMOTION => {
                    // TODO - look at sdl_event.jbutton.which (to support multiple joysticks)
                    const threshold = 16384;
                    var i: usize = 0; while (i < 4) : (i += 1) {
                        const neg = switch (i) { 0 => Key.JoyAxis0Neg, 1 => Key.JoyAxis1Neg, 2 => Key.JoyAxis2Neg, 3 => Key.JoyAxis3Neg, else => unreachable };
                        const pos = switch (i) { 0 => Key.JoyAxis0Pos, 1 => Key.JoyAxis1Pos, 2 => Key.JoyAxis2Pos, 3 => Key.JoyAxis3Pos, else => unreachable };
                        if (sdl_event.jaxis.axis == i) {
                            if (sdl_event.jaxis.value < -threshold) {
                                _ = common.spawnInputEvent(&g.session, &cfg, neg, true);
                                _ = common.spawnInputEvent(&g.session, &cfg, pos, false);
                            } else if (sdl_event.jaxis.value > threshold) {
                                _ = common.spawnInputEvent(&g.session, &cfg, pos, true);
                                _ = common.spawnInputEvent(&g.session, &cfg, neg, false);
                            } else {
                                _ = common.spawnInputEvent(&g.session, &cfg, pos, false);
                                _ = common.spawnInputEvent(&g.session, &cfg, neg, false);
                            }
                        }
                    }
                },
                SDL_JOYBUTTONDOWN, SDL_JOYBUTTONUP => {
                    // TODO - look at sdl_event.jbutton.which (to support multiple joysticks)
                    const down = sdl_event.type == SDL_JOYBUTTONDOWN;
                    const maybe_key = switch (sdl_event.jbutton.button) {
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
                        _ = common.spawnInputEvent(&g.session, &cfg, key, down);
                    }
                },
                SDL_WINDOWEVENT => {
                    if (!fullscreen and sdl_event.window.event == SDL_WINDOWEVENT_MOVED) {
                        original_window_x = sdl_event.window.data1;
                        original_window_y = sdl_event.window.data2;
                    }
                },
                SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        const blit_rect = blk: {
            if (fullscreen) {
                if (fullscreen_dims) |dims| {
                    break :blk dims.blit_rect;
                }
            }
            break :blk windowed_dims.blit_rect;
        };

        // copy these system values straight into the MainController.
        // this is kind of a hack, but on the other hand, i'm spawning entities
        // in this file too, it's not that different...
        if (g.session.findFirstObject(c.MainController)) |mc| {
            mc.data.is_fullscreen = fullscreen;
            mc.data.volume = cfg.volume;
        }

        var toggle_fullscreen = false;
        const num_frames = if (fast_forward) u32(4) else u32(1);
        var i: u32 = 0; while (i < num_frames) : (i += 1) {
            perf.begin(&perf.timers.Frame);
            gameFrame(&g.session);
            perf.end(&perf.timers.Frame);

            var it = g.session.iter(c.EventSystemCommand); while (it.next()) |object| {
                switch (object.data) {
                    .SetVolume => |value| cfg.volume = value,
                    .ToggleFullscreen => toggle_fullscreen = true,
                    .BindGameCommand => |payload| {
                        const command_index = @enumToInt(payload.command);
                        const key_in_use =
                            if (payload.key) |new_key|
                                for (cfg.game_key_bindings) |maybe_key| {
                                    if (if (maybe_key) |key| key == new_key else false) {
                                        break true;
                                    }
                                } else false
                            else false;
                        if (!key_in_use) {
                            cfg.game_key_bindings[command_index] = payload.key;
                        }
                    },
                    .SaveHighScores => |high_scores| {
                        saveHighScores(&hunk.low(), high_scores) catch |err| {
                            std.debug.warn("Failed to save high scores to disk: {}\n", err);
                        };
                    },
                    .Quit => quit = true,
                }
            }

            SDL_LockAudioDevice(device);
            // speed up audio mixing frequency if game is being fast forwarded
            audio_user_data.sample_rate = @intToFloat(f32, audio_sample_rate) / @intToFloat(f32, num_frames);
            audio_user_data.volume = cfg.volume;
            playSounds(g);
            SDL_UnlockAudioDevice(device);

            drawMain(g, cfg, blit_rect, 1.0 / @intToFloat(f32, i + 1));

            gameFrameCleanup(&g.session);
        }

        SDL_GL_SwapWindow(window);

        // FIXME - try to detect if vsync is enabled...
        // SDL_Delay(17);

        if (toggle_fullscreen) {
            if (fullscreen) {
                if (SDL_SetWindowFullscreen(window, 0) < 0) {
                    std.debug.warn("Failed to disable fullscreen mode");
                } else {
                    SDL_SetWindowSize(window, windowed_dims.window_width, windowed_dims.window_height);
                    SDL_SetWindowPosition(window, original_window_x, original_window_y);
                    fullscreen = false;
                }
            } else {
                if (fullscreen_dims) |dims| {
                    SDL_SetWindowSize(window, dims.window_width, dims.window_height);
                    if (SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
                        std.debug.warn("Failed to enable fullscreen mode\n");
                        SDL_SetWindowSize(window, windowed_dims.window_width, windowed_dims.window_height);
                    } else {
                        fullscreen = true;
                    }
                } else {
                    // couldn't figure out how to go fullscreen so stay in windowed mode
                }
            }
        }
    }

    return 0;
}

fn playSounds(g: *GameState) void {
    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer. need to implement some
    // "syncing" to guess where we are in the middle of a mix frame
    const impulse_frame: usize = 0;

    g.audio_module.playSounds(&g.session, impulse_frame);
}

fn drawMain(g: *GameState, cfg: config.Config, blit_rect: platform_framebuffer.BlitRect, blit_alpha: f32) void {
    perf.begin(&perf.timers.WholeDraw);

    platform_framebuffer.preDraw(&g.framebuffer_state);
    platform_draw.prepare(&g.draw_state);

    perf.begin(&perf.timers.Draw);

    drawGame(&g.draw_state, &g.static, &g.session, cfg);

    perf.end(&perf.timers.Draw);

    platform_framebuffer.postDraw(&g.framebuffer_state, &g.draw_state, blit_rect, blit_alpha);

    perf.end(&perf.timers.WholeDraw);
}
