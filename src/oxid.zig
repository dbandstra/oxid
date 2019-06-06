const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const zang = @import("zang");

const platform = @import("platform.zig");
const Event = @import("common/event.zig").Event;
const Key = @import("common/event.zig").Key;
const draw = @import("common/draw.zig");
const Font = @import("common/font.zig").Font;
const loadFont = @import("common/font.zig").loadFont;
const gbe = @import("gbe.zig");
const loadTileset = @import("oxid/graphics.zig").loadTileset;
const GRIDSIZE_PIXELS = @import("oxid/level.zig").GRIDSIZE_PIXELS;
const LEVEL = @import("oxid/level.zig").LEVEL;
const GameSession = @import("oxid/game.zig").GameSession;
const gameInit = @import("oxid/frame.zig").gameInit;
const gameFrame = @import("oxid/frame.zig").gameFrame;
const gameFrameCleanup = @import("oxid/frame.zig").gameFrameCleanup;
const input = @import("oxid/input.zig");
const Prototypes = @import("oxid/prototypes.zig");
const drawGame = @import("oxid/draw.zig").drawGame;
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const datafile = @import("oxid/datafile.zig");
const C = @import("oxid/components.zig");

// this many pixels is added to the top of the window for font stuff
pub const HUD_HEIGHT = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const VWIN_W: u31 = LEVEL.w * GRIDSIZE_PIXELS; // 320
pub const VWIN_H: u31 = LEVEL.h * GRIDSIZE_PIXELS + HUD_HEIGHT; // 240

// this is a global singleton
pub const GameState = struct {
    platform_state: platform.State,
    audio_module: audio.MainModule,
    tileset: draw.Tileset,
    palette: [48]u8,
    font: Font,
    session: GameSession,
    perf_spam: bool,
    mute: bool,
};
// this is only global because GameState is pretty big, and i didn't want to
// use an allocator. don't access it outside of the main function.
pub var game_state: GameState = undefined;

fn audioCallback(g: *GameState, out_bytes: []u8, sample_rate: u32) void {
    if (g.audio_module.initialized) {
        const buf = g.audio_module.paint(sample_rate, &g.session);

        zang.mixDown(out_bytes, buf, zang.AudioFormat.S16LSB, 1, 0, 0.5);
    } else {
        // note to self: change this if we ever use an unsigned audio format
        std.mem.set(u8, out_bytes, 0);
    }
}

pub fn main() void {
    var memory: [200*1024]u8 = undefined;
    var hunk = Hunk.init(memory[0..]);

    const audio_sample_rate = 44100;
    const audio_buffer_size = 1024;

    const g = &game_state;
    g.audio_module.initialized = false;
    platform.init(&g.platform_state, g, audioCallback, platform.InitParams{
        .window_title = "Oxid",
        .virtual_window_width = VWIN_W,
        .virtual_window_height = VWIN_H,
        .max_scale = 4,
        .audio_sample_rate = audio_sample_rate,
        .audio_buffer_size = audio_buffer_size,
        .hunk = &hunk,
    }) catch |err| {
        // this causes runaway allocation in the compiler!
        // https://github.com/ziglang/zig/issues/1753
        // std.debug.warn("platform.init failed: {}.\n", err);
        std.debug.warn("platform init failed.\n");
        return;
    };
    defer platform.deinit(&g.platform_state);

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
    g.mute = false;

    g.session.init(rand_seed);
    gameInit(&g.session, initial_high_score) catch |err| {
        std.debug.warn("Failed to initialize game.\n"); // TODO - print error (see above)
        return;
    };

    perf.init();

    var fast_forward = false;

    var quit = false;
    while (!quit) {
        while (platform.pollEvent(&g.platform_state)) |event| {
            switch (event) {
                Event.KeyDown => |key| {
                    if (input.getCommandForKey(key)) |command| {
                        _ = Prototypes.EventInput.spawn(&g.session, C.EventInput {
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
                            platform.cycleGlitchMode(&g.platform_state);
                            g.platform_state.clear_screen = true;
                        },
                        Key.M => {
                            g.mute = !g.mute;
                        },
                        else => {},
                    }
                },
                Event.KeyUp => |key| {
                    if (input.getCommandForKey(key)) |command| {
                        _ = Prototypes.EventInput.spawn(&g.session, C.EventInput {
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
                },
                Event.Quit => {
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

            if (g.session.findFirst(C.EventQuit) != null) {
                quit = true;
                break;
            }

            saveHighScore(g);
            playSounds(g, @intToFloat(f32, num_frames));
            drawMain(g, 1.0 / @intToFloat(f32, i + 1));

            gameFrameCleanup(&g.session);
        }

        platform.swapWindow(&g.platform_state);
    }
}

// "middleware"

fn saveHighScore(g: *GameState) void {
    var it = g.session.iter(C.EventSaveHighScore); while (it.next()) |object| {
        datafile.saveHighScore(&g.platform_state.hunk.low(), object.data.high_score) catch |err| {
            std.debug.warn("Failed to save high score to disk: {}\n", err);
        };
    }
}

fn playSounds(g: *GameState, speed: f32) void {
    platform.lockAudio(&g.platform_state);

    g.audio_module.muted = g.mute;
    g.audio_module.speed = speed;

    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer
    const impulse_frame = 0;

    var it = g.session.iter(C.Voice); while (it.next()) |object| {
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

    platform.unlockAudio(&g.platform_state);
}

fn updateVoice(wrapper: var, impulse_frame: usize) void {
    if (wrapper.initial_params) |params| {
        wrapper.iq.push(impulse_frame, params);
        wrapper.initial_params = null;
    }
}

fn drawMain(g: *GameState, blit_alpha: f32) void {
    perf.begin(&perf.timers.WholeDraw);
    platform.preDraw(&g.platform_state);
    perf.begin(&perf.timers.Draw);
    drawGame(g);
    perf.end(&perf.timers.Draw, g.perf_spam);
    platform.postDraw(&g.platform_state, blit_alpha);
    perf.end(&perf.timers.WholeDraw, g.perf_spam);
}
