const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");

const c = @import("platform/c.zig");

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
const components = @import("oxid/components.zig");

// See https://github.com/zig-lang/zig/issues/565
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_MASK    0x1FFF0000u
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

// this many pixels is added to the top of the window for font stuff
// TODO - move to another file
pub const HUD_HEIGHT = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const VWIN_W: u31 = levels.W * levels.PIXELS_PER_TILE; // 320
pub const VWIN_H: u31 = levels.H * levels.PIXELS_PER_TILE + HUD_HEIGHT; // 240

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

        zang.mixDown(out_bytes, buf, zang.AudioFormat.S16LSB, 1, 0, 0.5);
    } else {
        // note to self: change this if we ever use an unsigned audio format
        std.mem.set(u8, out_bytes, 0);
    }
}

fn translateKey(sym: c.SDL_Keycode) ?Key {
    return switch (sym) {
        c.SDLK_ESCAPE => Key.Escape,
        c.SDLK_BACKSPACE => Key.Backspace,
        c.SDLK_RETURN => Key.Return,
        c.SDLK_F2 => Key.F2,
        c.SDLK_F3 => Key.F3,
        c.SDLK_F4 => Key.F4,
        c.SDLK_F5 => Key.F5,
        c.SDLK_UP => Key.Up,
        c.SDLK_DOWN => Key.Down,
        c.SDLK_LEFT => Key.Left,
        c.SDLK_RIGHT => Key.Right,
        c.SDLK_SPACE => Key.Space,
        c.SDLK_BACKQUOTE => Key.Backquote,
        c.SDLK_m => Key.M,
        c.SDLK_n => Key.N,
        c.SDLK_y => Key.Y,
        else => null,
    };
}

// this is only global because GameState is pretty big, and i didn't want to
// use an allocator. don't access it outside of the main function.
pub var game_state: GameState = undefined;

pub fn main() void {
    var memory: [200*1024]u8 = undefined;
    var hunk = Hunk.init(memory[0..]);

    const audio_sample_rate = 44100;
    const audio_buffer_size = 1024;

    const g = &game_state;
    g.audio_module.initialized = false;

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
        c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
        return;
    }
    defer c.SDL_Quit();

    const virtual_window_width: u32 = VWIN_W;
    const virtual_window_height: u32 = VWIN_H;
    var window_width = virtual_window_width;
    var window_height = virtual_window_height;
    // the actual window size will be a multiple of the virtual window size. this
    // value puts a limit on high big it will be scaled (it will also be limited
    // by the user's screen resolution)
    const max_scale = 4;

    // get the desktop resolution (for the first display)
    var dm: c.SDL_DisplayMode = undefined;

    if (c.SDL_GetDesktopDisplayMode(0, &dm) != 0) {
        std.debug.warn("Failed to query desktop display mode.\n");
    } else {
        // pick a window size that isn't bigger than the desktop resolution
        const max_w = @intCast(u32, dm.w);
        const max_h = @intCast(u32, dm.h) - 40; // bias for menubars/taskbars

        var scale: u32 = 1; while (scale <= max_scale) : (scale += 1) {
            const w = scale * virtual_window_width;
            const h = scale * virtual_window_height;

            if (w > max_w or h > max_h) {
                break;
            }

            window_width = w;
            window_height = h;
        }
    }

    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_DOUBLEBUFFER), 1);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_BUFFER_SIZE), 32);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_RED_SIZE), 8);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_GREEN_SIZE), 8);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_BLUE_SIZE), 8);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_ALPHA_SIZE), 8);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_DEPTH_SIZE), 24);
    _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_STENCIL_SIZE), 8);

    const window = c.SDL_CreateWindow(
        c"Oxid",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        @intCast(c_int, window_width),
        @intCast(c_int, window_height),
        c.SDL_WINDOW_OPENGL,
    ) orelse {
        c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
        return;
    };
    defer c.SDL_DestroyWindow(window);

    var audio_user_data = AudioUserData {
        .g = g,
        .sample_rate = audio_sample_rate,
    };

    var want: c.SDL_AudioSpec = undefined;
    want.freq = @intCast(c_int, audio_sample_rate);
    want.format = c.AUDIO_S16LSB;
    want.channels = 1;
    want.samples = audio_buffer_size;
    want.callback = audioCallback;
    want.userdata = &audio_user_data;

    // TODO - allow SDL to pick something different? (make sure to update
    // ps.audio_user_data.sample_rate)
    const device: c.SDL_AudioDeviceID = c.SDL_OpenAudioDevice(
        0, // device name (NULL)
        0, // non-zero to open for recording instead of playback
        &want, // desired output format
        0, // obtained output format (NULL)
        0, // allowed changes: 0 means `obtained` will not differ from `want`, and SDL will do any necessary resampling behind the scenes
    );
    if (device == 0) {
        c.SDL_Log(c"Failed to open audio: %s", c.SDL_GetError());
        return; // error.SDLInitializationFailed;
    }
    defer c.SDL_CloseAudio();

    const glcontext = c.SDL_GL_CreateContext(window) orelse {
        c.SDL_Log(c"SDL_GL_CreateContext failed: %s", c.SDL_GetError());
        return; // error.SDLInitializationFailed;
    };
    defer c.SDL_GL_DeleteContext(glcontext);

    _ = c.SDL_GL_MakeCurrent(window, glcontext);

    platform_draw.init(&g.draw_state, platform_draw.DrawInitParams {
        .hunk = &hunk,
        .virtual_window_width = virtual_window_width,
        .virtual_window_height = virtual_window_height,
    }, window_width, window_height) catch {
        std.debug.warn("platform_draw.init failed\n");
        // FIXME - gotta call all those errdefers!
        return;
    };
    defer platform_draw.deinit(&g.draw_state);

    // FIXME can i move this lower down and get rid of the `initialized` field in the audio module
    c.SDL_PauseAudioDevice(device, 0); // unpause

    defer {
        c.SDL_PauseAudioDevice(device, 1);
        c.SDL_CloseAudioDevice(device);
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
        var sdl_event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_KEYDOWN => {
                    if (sdl_event.key.repeat == 0) {
                        if (translateKey(sdl_event.key.keysym.sym)) |key| {
                            if (input.getCommandForKey(key)) |command| {
                                _ = p.EventInput.spawn(&g.session, components.EventInput {
                                    .command = command,
                                    .down = true,
                                }) catch undefined;
                            }
                            switch (key) {
                                Key.Backquote => {
                                    fast_forward = true;
                                },
                                Key.F4 => {
                                    g.perf_spam = !g.perf_spam;
                                },
                                Key.F5 => {
                                    platform_draw.cycleGlitchMode(&g.draw_state);
                                },
                                Key.M => {
                                    muted = !muted;
                                },
                                else => {},
                            }
                        }
                    }
                },
                c.SDL_KEYUP => {
                    if (translateKey(sdl_event.key.keysym.sym)) |key| {
                        if (input.getCommandForKey(key)) |command| {
                            _ = p.EventInput.spawn(&g.session, components.EventInput {
                                .command = command,
                                .down = false,
                            }) catch undefined;
                        }
                        switch (key) {
                            Key.Backquote => {
                                fast_forward = false;
                            },
                            else => {},
                        }
                    }
                },
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        const num_frames = if (fast_forward) u32(4) else u32(1);
        var i: u32 = 0; while (i < num_frames) : (i += 1) {
            perf.begin(&perf.timers.Frame);
            gameFrame(&g.session);
            perf.end(&perf.timers.Frame, g.perf_spam);

            if (g.session.findFirst(components.EventQuit) != null) {
                quit = true;
                break;
            }

            saveHighScore(g, &hunk.low());

            c.SDL_LockAudioDevice(device);
            playSounds(g, muted, @intToFloat(f32, num_frames));
            c.SDL_UnlockAudioDevice(device);

            drawMain(g, 1.0 / @intToFloat(f32, i + 1));

            gameFrameCleanup(&g.session);
        }

        c.SDL_GL_SwapWindow(window);

        // FIXME - try to detect if vsync is enabled...
        // c.SDL_Delay(17);
    }
}

fn saveHighScore(g: *GameState, hunk_side: *HunkSide) void {
    var it = g.session.iter(components.EventSaveHighScore); while (it.next()) |object| {
        datafile.saveHighScore(hunk_side, object.data.high_score) catch |err| {
            std.debug.warn("Failed to save high score to disk: {}\n", err);
        };
    }
}

fn playSounds(g: *GameState, muted: bool, speed: f32) void {
    g.audio_module.muted = muted;
    g.audio_module.speed = speed;

    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer
    const impulse_frame = 0;

    var it = g.session.iter(components.Voice); while (it.next()) |object| {
        switch (object.data.wrapper) {
            .Accelerate => |*wrapper| updateVoice(wrapper, impulse_frame),
            .Coin =>       |*wrapper| updateVoice(wrapper, impulse_frame),
            .Explosion =>  |*wrapper| updateVoice(wrapper, impulse_frame),
            .Laser =>      |*wrapper| updateVoice(wrapper, impulse_frame),
            .WaveBegin =>  |*wrapper| updateVoice(wrapper, impulse_frame),
            .Sample =>     |*wrapper| {
                if (wrapper.initial_sample) |sample| {
                    wrapper.iq.push(impulse_frame, g.audio_module.getSampleParams(sample));
                    wrapper.initial_sample = null;
                }
            },
        }
    }
}

fn updateVoice(wrapper: var, impulse_frame: usize) void {
    if (wrapper.initial_params) |params| {
        wrapper.iq.push(impulse_frame, params);
        wrapper.initial_params = null;
    }
}

fn drawMain(g: *GameState, blit_alpha: f32) void {
    perf.begin(&perf.timers.WholeDraw);

    platform_draw.preDraw(&g.draw_state);

    perf.begin(&perf.timers.Draw);

    drawGame(g);

    perf.end(&perf.timers.Draw, g.perf_spam);

    platform_draw.postDraw(&g.draw_state, blit_alpha);

    perf.end(&perf.timers.WholeDraw, g.perf_spam);
}
