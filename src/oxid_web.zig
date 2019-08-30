const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("warn.zig").warn;
const web = @import("web.zig");
const Key = @import("common/key.zig").Key;
const platform_draw = @import("platform/opengl/draw.zig");
const levels = @import("oxid/levels.zig");
const Constants = @import("oxid/constants.zig");
const GameSession = @import("oxid/game.zig").GameSession; 
const gameInit = @import("oxid/frame.zig").gameInit;
const gameFrame = @import("oxid/frame.zig").gameFrame;
const gameFrameCleanup = @import("oxid/frame.zig").gameFrameCleanup;
const p = @import("oxid/prototypes.zig");
const drawGame = @import("oxid/draw.zig").drawGame;
//const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const c = @import("oxid/components.zig");
const virtual_window_width = @import("oxid_constants.zig").virtual_window_width;
const virtual_window_height = @import("oxid_constants.zig").virtual_window_height;
const GameStatic = @import("oxid_common.zig").GameStatic;
const loadStatic = @import("oxid_common.zig").loadStatic;
const spawnInputEvent = @import("oxid_common.zig").spawnInputEvent;

var cfg = config.default_config;

const GameState = struct {
    draw_state: platform_draw.DrawState,
    //audio_module: audio.MainModule,
    static: GameStatic,
    session: GameSession,
    //perf_spam: bool,
};

fn translateKey(keyCode: c_int) ?Key {
    return switch (keyCode) {
        web.KEY_BACKSPACE => Key.Backspace,
        web.KEY_TAB => Key.Tab,
        web.KEY_ENTER => Key.Return,
        web.KEY_SHIFT => Key.LShift, // FIXME?
        web.KEY_CTRL => Key.LCtrl, // FIXME?
        web.KEY_ALT => Key.LAlt, // FIXME?
        web.KEY_PAUSE => Key.Pause,
        web.KEY_CAPS_LOCK => Key.CapsLock,
        web.KEY_ESCAPE => Key.Escape,
        web.KEY_SPACE => Key.Space,
        web.KEY_PAGEUP => Key.PageUp,
        web.KEY_PAGEDOWN => Key.PageDown,
        web.KEY_END => Key.End,
        web.KEY_HOME => Key.Home,
        web.KEY_LEFT => Key.Left,
        web.KEY_UP => Key.Up,
        web.KEY_RIGHT => Key.Right,
        web.KEY_DOWN => Key.Down,
        web.KEY_INSERT => Key.Insert,
        web.KEY_DELETE => Key.Delete,
        web.KEY_0 => Key.N0,
        web.KEY_1 => Key.N1,
        web.KEY_2 => Key.N2,
        web.KEY_3 => Key.N3,
        web.KEY_4 => Key.N4,
        web.KEY_5 => Key.N5,
        web.KEY_6 => Key.N6,
        web.KEY_7 => Key.N7,
        web.KEY_8 => Key.N8,
        web.KEY_9 => Key.N9,
        web.KEY_A => Key.A,
        web.KEY_B => Key.B,
        web.KEY_C => Key.C,
        web.KEY_D => Key.D,
        web.KEY_E => Key.E,
        web.KEY_F => Key.F,
        web.KEY_G => Key.G,
        web.KEY_H => Key.H,
        web.KEY_I => Key.I,
        web.KEY_J => Key.J,
        web.KEY_K => Key.K,
        web.KEY_L => Key.L,
        web.KEY_M => Key.M,
        web.KEY_N => Key.N,
        web.KEY_O => Key.O,
        web.KEY_P => Key.P,
        web.KEY_Q => Key.Q,
        web.KEY_R => Key.R,
        web.KEY_S => Key.S,
        web.KEY_T => Key.T,
        web.KEY_U => Key.U,
        web.KEY_V => Key.V,
        web.KEY_W => Key.W,
        web.KEY_X => Key.X,
        web.KEY_Y => Key.Y,
        web.KEY_Z => Key.Z,
        web.KEY_META_LEFT => null, // ?
        web.KEY_META_RIGHT => null, // ?
        web.KEY_SELECT => null, // ?
        web.KEY_NP0 => Key.Kp0,
        web.KEY_NP1 => Key.Kp1,
        web.KEY_NP2 => Key.Kp2,
        web.KEY_NP3 => Key.Kp3,
        web.KEY_NP4 => Key.Kp4,
        web.KEY_NP5 => Key.Kp5,
        web.KEY_NP6 => Key.Kp6,
        web.KEY_NP7 => Key.Kp7,
        web.KEY_NP8 => Key.Kp8,
        web.KEY_NP9 => Key.Kp9,
        web.KEY_NPMULTIPLY => Key.KpMultiply,
        web.KEY_NPADD => Key.KpPlus,
        web.KEY_NPSUBTRACT => Key.KpMinus,
        web.KEY_NPDECIMAL => Key.KpPeriod,
        web.KEY_NPDIVIDE => Key.KpDivide,
        web.KEY_F1 => Key.F1,
        web.KEY_F2 => Key.F2,
        web.KEY_F3 => Key.F3,
        web.KEY_F4 => Key.F4,
        web.KEY_F5 => Key.F5,
        web.KEY_F6 => Key.F6,
        web.KEY_F7 => Key.F7,
        web.KEY_F8 => Key.F8,
        web.KEY_F9 => Key.F9,
        web.KEY_F10 => Key.F10,
        web.KEY_F11 => Key.F11,
        web.KEY_F12 => Key.F12,
        web.KEY_NUM_LOCK => Key.NumLockClear, // i think?
        web.KEY_SCROLL_LOCK => Key.ScrollLock,
        web.KEY_SEMICOLON => Key.Semicolon,
        web.KEY_EQUAL_SIGN => Key.Equals,
        web.KEY_COMMA => Key.Comma,
        web.KEY_MINUS => Key.Minus,
        web.KEY_PERIOD => Key.Period,
        web.KEY_SLASH => Key.Slash,
        web.KEY_BACKQUOTE => Key.Backquote,
        web.KEY_BRACKET_LEFT => Key.LeftBracket,
        web.KEY_BACKSLASH => Key.Backslash,
        web.KEY_BRAKET_RIGHT => Key.RightBracket,
        web.KEY_QUOTE => Key.Quote,
        else => null,
    };
}

export fn onKeyDown(keyCode: c_int) u8 {
    if (translateKey(keyCode)) |key| {
        spawnInputEvent(&g.session, &cfg, key, true);
        return 1;
    }
    return 0;
}

export fn onKeyUp(keyCode: c_int) u8 {
    if (translateKey(keyCode)) |key| {
        spawnInputEvent(&g.session, &cfg, key, false);
        return 1;
    }
    return 0;
}

var main_memory: []u8 = undefined;
var g: *GameState = undefined;

fn init() !void {
    main_memory = std.heap.wasm_allocator.alloc(u8, @sizeOf(GameState) + 200*1024) catch |err| {
        warn("failed to allocate main_memory: {}\n", err);
        return error.Failed;
    };
    errdefer std.heap.wasm_allocator.free(main_memory);

    var hunk = Hunk.init(main_memory);

    g = hunk.low().allocator.create(GameState) catch unreachable;

    platform_draw.init(&g.draw_state, platform_draw.DrawInitParams {
        .hunk = &hunk,
        .virtual_window_width = virtual_window_width,
        .virtual_window_height = virtual_window_height,
    }) catch |err| {
        warn("platform_draw.init failed: {}\n", err);
        return error.Failed;
    };
    errdefer platform_draw.deinit(&g.draw_state);

    if (!loadStatic(&g.static, &hunk.low())) {
        // loadStatic prints its own error
        return error.Failed;
    }

    const initial_high_scores = [1]u32{0} ** Constants.num_high_scores;
    const rand_seed = web.getRandomSeed();
    g.session.init(rand_seed);
    gameInit(&g.session, p.MainController.Params {
        .is_fullscreen = false, // fullscreen,
        .volume = 100, // cfg.volume,
        .high_scores = initial_high_scores,
    }) catch |err| {
        warn("Failed to initialize game: {}\n", err);
        return error.Failed;
    };

    //perf.init();
}

export fn onInit() bool {
    init() catch return false;
    return true;
}

export fn onDestroy() void {
    platform_draw.deinit(&g.draw_state);
    std.heap.wasm_allocator.free(main_memory);
}

export fn onAnimationFrame(now_time: c_int) void {
    const blit_rect = platform_draw.BlitRect {
        .x = 0,
        .y = 0,
        .w = virtual_window_width,
        .h = virtual_window_height,
    };
    const blit_alpha: f32 = 1.0;

    // copy these system values straight into the MainController.
    // this is kind of a hack, but on the other hand, i'm spawning entities
    // in this file too, it's not that different...
    if (g.session.findFirstObject(c.MainController)) |mc| {
        //mc.data.is_fullscreen = fullscreen;
        mc.data.volume = cfg.volume;
    }

    gameFrame(&g.session);

    var it = g.session.iter(c.EventSystemCommand); while (it.next()) |object| {
        switch (object.data) {
            .SetVolume => |value| cfg.volume = value,
            .ToggleFullscreen => {},//toggle_fullscreen = true,
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
                //datafile.saveHighScores(&hunk.low(), high_scores) catch |err| {
                //    std.debug.warn("Failed to save high scores to disk: {}\n", err);
                //};
            },
            .Quit => {},//quit = true,
        }
    }

    platform_draw.preDraw(&g.draw_state);
    drawGame(&g.draw_state, &g.static, &g.session, cfg);
    platform_draw.postDraw(&g.draw_state, blit_rect, blit_alpha);
    gameFrameCleanup(&g.session);
}
