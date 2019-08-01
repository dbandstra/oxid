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
const draw = @import("common/draw.zig");
const Font = @import("common/font.zig").Font;
const loadFont = @import("common/font.zig").loadFont;
const loadTileset = @import("oxid/graphics.zig").loadTileset;
const levels = @import("oxid/levels.zig");
const GameSession = @import("oxid/game.zig").GameSession;
const gameInit = @import("oxid/frame.zig").gameInit;
const gameFrame = @import("oxid/frame.zig").gameFrame;
const gameFrameCleanup = @import("oxid/frame.zig").gameFrameCleanup;
const input = @import("oxid/input.zig");
const p = @import("oxid/prototypes.zig");
const drawGame = @import("oxid/draw.zig").drawGame;
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const datafile = @import("oxid/datafile.zig");
const c = @import("oxid/components.zig");

// See https://github.com/zig-lang/zig/issues/565
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_MASK    0x1FFF0000u
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, SDL_WINDOWPOS_UNDEFINED_MASK);

// this many pixels is added to the top of the window for font stuff
// TODO - move to another file
pub const hud_height = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const virtual_window_width: u31 = levels.width * levels.pixels_per_tile; // 320
pub const virtual_window_height: u31 = levels.height * levels.pixels_per_tile + hud_height; // 240

// this is a global singleton
pub const GameState = struct {
    draw_state: platform_draw.DrawState,
    audio_module: audio.MainModule,
    tileset: draw.Tileset,
    palette: [48]u8,
    font: Font,
    session: GameSession,
    perf_spam: bool,
};

pub const AudioUserData = struct {
    g: *GameState,
    sample_rate: u32,
};

extern fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) void {
    const userdata = @ptrCast(*AudioUserData, @alignCast(@alignOf(*AudioUserData), userdata_.?));
    const out_bytes = stream_.?[0..@intCast(usize, len_)];

    const g = userdata.g;
    const sample_rate = userdata.sample_rate;

    if (g.audio_module.initialized) {
        const buf = g.audio_module.paint(sample_rate, &g.session);

        zang.mixDown(out_bytes, buf, .S16LSB, 1, 0, 0.5);
    } else {
        // note to self: change this if we ever use an unsigned audio format
        std.mem.set(u8, out_bytes, 0);
    }
}

fn translateKey(sym: SDL_Keycode) ?Key {
    return switch (sym) {
        SDLK_ESCAPE => Key.Escape,
        SDLK_BACKSPACE => Key.Backspace,
        SDLK_RETURN => Key.Return,
        SDLK_F2 => Key.F2,
        SDLK_F3 => Key.F3,
        SDLK_F4 => Key.F4,
        SDLK_F5 => Key.F5,
        SDLK_UP => Key.Up,
        SDLK_DOWN => Key.Down,
        SDLK_LEFT => Key.Left,
        SDLK_RIGHT => Key.Right,
        SDLK_SPACE => Key.Space,
        SDLK_BACKQUOTE => Key.Backquote,
        SDLK_f => Key.F,
        SDLK_m => Key.M,
        SDLK_n => Key.N,
        SDLK_y => Key.Y,
        else => null,
    };
}

const WindowDims = struct {
    // dimensions of the system window
    window_width: u31,
    window_height: u31,
    // coordinates of the viewport to blit to, within the system window
    blit_rect: platform_draw.BlitRect,
};

fn getFullscreenDims(native_w: u31, native_h: u31) WindowDims {
    // scale the game view up as far as possible, maintaining the
    // aspect ratio
    const scaled_w = native_h * virtual_window_width / virtual_window_height;
    const scaled_h = native_w * virtual_window_height / virtual_window_width;

    return WindowDims {
        .window_width = native_w,
        .window_height = native_h,
        .blit_rect =
            if (scaled_w < native_w)
                platform_draw.BlitRect {
                    .w = scaled_w,
                    .h = native_h,
                    .x = native_w / 2 - scaled_w / 2,
                    .y = 0,
                }
            else if (scaled_h < native_h)
                platform_draw.BlitRect {
                    .w = native_w,
                    .h = scaled_h,
                    .x = 0,
                    .y = native_h / 2 - scaled_h / 2,
                }
            else
                platform_draw.BlitRect {
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

    var window_width = virtual_window_width;
    var window_height = virtual_window_height;

    var scale: u31 = 1; while (scale <= max_scale) : (scale += 1) {
        const w = scale * virtual_window_width;
        const h = scale * virtual_window_height;

        if (w > max_w or h > max_h) {
            break;
        }

        window_width = w;
        window_height = h;
    }

    return WindowDims {
        .window_width = window_width,
        .window_height = window_height,
        .blit_rect = platform_draw.BlitRect {
            .x = 0,
            .y = 0,
            .w = window_width,
            .h = window_height,
        },
    };
}

// this is only global because GameState is pretty big, and i didn't want to
// use an allocator. don't access it outside of the main function.
var game_state: GameState = undefined;

pub fn main() void {
    var memory: [200*1024]u8 = undefined;
    var hunk = Hunk.init(memory[0..]);

    const audio_sample_rate = 44100;
    const audio_buffer_size = 1024;

    const g = &game_state;
    g.audio_module.initialized = false;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        SDL_Log(c"Unable to initialize SDL: %s", SDL_GetError());
        return;
    }
    defer SDL_Quit();

    var fullscreen = false;
    var fullscreen_dims: ?WindowDims = null;
    var windowed_dims = WindowDims {
        .window_width = virtual_window_width,
        .window_height = virtual_window_height,
        .blit_rect = platform_draw.BlitRect {
            .x = 0,
            .y = 0,
            .w = virtual_window_width,
            .h = virtual_window_height,
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
        return;
    };
    defer SDL_DestroyWindow(window);

    var audio_user_data = AudioUserData {
        .g = g,
        .sample_rate = audio_sample_rate,
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
        return; // error.SDLInitializationFailed;
    }
    defer SDL_CloseAudio();

    const glcontext = SDL_GL_CreateContext(window) orelse {
        SDL_Log(c"SDL_GL_CreateContext failed: %s", SDL_GetError());
        return; // error.SDLInitializationFailed;
    };
    defer SDL_GL_DeleteContext(glcontext);

    _ = SDL_GL_MakeCurrent(window, glcontext);

    platform_draw.init(&g.draw_state, platform_draw.DrawInitParams {
        .hunk = &hunk,
        .virtual_window_width = virtual_window_width,
        .virtual_window_height = virtual_window_height,
    }) catch {
        std.debug.warn("platform_draw.init failed\n");
        // FIXME - gotta call all those errdefers!
        return;
    };
    defer platform_draw.deinit(&g.draw_state);

    // FIXME can i move this lower down and get rid of the `initialized` field in the audio module
    SDL_PauseAudioDevice(device, 0); // unpause

    defer {
        SDL_PauseAudioDevice(device, 1);
        SDL_CloseAudioDevice(device);
    }

    const rand_seed = @intCast(u32, std.time.milliTimestamp() & 0xFFFFFFFF);

    // TODO - is it really a good idea to set high score to 0 if it failed to
    // load? i think we should disable high score functionality for this session
    // instead. otherwise the real high score could get overwritten by a lower
    // score.
    const initial_high_score = datafile.loadHighScore(&hunk.low()) catch |err| blk: {
        std.debug.warn("Failed to load high score from disk: {}.\n", err);
        break :blk 0;
    };

    loadFont(&hunk.low(), &g.font) catch |err| {
        std.debug.warn("Failed to load font.\n"); // TODO - print error (see above)
        return;
    };

    loadTileset(&hunk.low(), &g.tileset, g.palette[0..]) catch |err| {
        std.debug.warn("Failed to load tileset.\n"); // TODO - print error (see above)
        return;
    };

    g.audio_module = audio.MainModule.init(&hunk.low(), audio_buffer_size) catch |err| {
        std.debug.warn("Failed to load audio module.\n"); // TODO - print error (see above)
        return;
    };

    g.perf_spam = false;

    g.session.init(rand_seed);
    gameInit(&g.session, initial_high_score) catch |err| {
        std.debug.warn("Failed to initialize game.\n"); // TODO - print error (see above)
        return;
    };

    perf.init();

    var fast_forward = false;
    var muted = false;

    var quit = false;
    while (!quit) {
        var sdl_event: SDL_Event = undefined;

        while (SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                SDL_KEYDOWN => {
                    if (sdl_event.key.repeat == 0) {
                        if (translateKey(sdl_event.key.keysym.sym)) |key| {
                            spawnInputEvent(&g.session, key, true);

                            switch (key) {
                                .Backquote => {
                                    fast_forward = true;
                                },
                                .F4 => {
                                    g.perf_spam = !g.perf_spam;
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
                        spawnInputEvent(&g.session, key, false);

                        switch (key) {
                            .Backquote => {
                                fast_forward = false;
                            },
                            else => {},
                        }
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

        var toggle_fullscreen = false;
        const num_frames = if (fast_forward) u32(4) else u32(1);
        var i: u32 = 0; while (i < num_frames) : (i += 1) {
            perf.begin(&perf.timers.Frame);
            gameFrame(&g.session);
            perf.end(&perf.timers.Frame, g.perf_spam);

            var it = g.session.iter(c.EventSystemCommand); while (it.next()) |object| {
                switch (object.data) {
                    .ToggleMute => muted = !muted,
                    .ToggleFullscreen => toggle_fullscreen = true,
                    .SaveHighScore => |score| {
                        datafile.saveHighScore(&hunk.low(), score) catch |err| {
                            std.debug.warn("Failed to save high score to disk: {}\n", err);
                        };
                    },
                    .Quit => quit = true,
                }
            }

            SDL_LockAudioDevice(device);
            playSounds(g, muted, @intToFloat(f32, num_frames));
            SDL_UnlockAudioDevice(device);

            drawMain(g, blit_rect, 1.0 / @intToFloat(f32, i + 1));

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
}

fn spawnInputEvent(gs: *GameSession, key: Key, down: bool) void {
    const game_command = input.getGameCommandForKey(key);
    const menu_command = input.getMenuCommandForKey(key);

    if (game_command != null or menu_command != null) {
        _ = p.EventRawInput.spawn(gs, c.EventRawInput {
            .game_command = game_command,
            .menu_command = menu_command,
            .down = down,
        }) catch undefined;
    }
}

fn playSounds(g: *GameState, muted: bool, speed: f32) void {
    g.audio_module.muted = muted;
    g.audio_module.speed = speed;

    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer. need to implement some
    // "syncing" to guess where we are in the middle of a mix frame
    const impulse_frame: usize = 0;

    g.audio_module.playSounds(&g.session, impulse_frame);
}

fn drawMain(g: *GameState, blit_rect: platform_draw.BlitRect, blit_alpha: f32) void {
    perf.begin(&perf.timers.WholeDraw);

    platform_draw.preDraw(&g.draw_state);

    perf.begin(&perf.timers.Draw);

    drawGame(g);

    perf.end(&perf.timers.Draw, g.perf_spam);

    platform_draw.postDraw(&g.draw_state, blit_rect, blit_alpha);

    perf.end(&perf.timers.WholeDraw, g.perf_spam);
}
