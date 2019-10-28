const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("warn.zig").warn;
const web = @import("web.zig");
const Key = @import("common/key.zig").Key;
const InputSource = @import("common/key.zig").InputSource;
const areInputSourcesEqual = @import("common/key.zig").areInputSourcesEqual;
const platform_draw = @import("platform/opengl/draw.zig");
const levels = @import("oxid/levels.zig");
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
const menus = @import("oxid/menus.zig");
const MenuDrawParams = @import("oxid/draw_menu.zig").MenuDrawParams;
const drawMenu = @import("oxid/draw_menu.zig").drawMenu;
const common = @import("oxid_common.zig");

const config_storagekey = "config";
const highscores_storagekey = "highscores";

const GameState = struct {
    cfg: config.Config,
    draw_state: platform_draw.DrawState,
    audio_module: audio.MainModule,
    static: common.GameStatic,
    session: GameSession,
    game_over: bool,
    new_high_score: bool,
    high_scores: [Constants.num_high_scores]u32,
    menu_anim_time: u32,
    menu_stack: menus.MenuStack,
    sound_enabled: bool,
    is_fullscreen: bool,
    canvas_scale: u31,
};

fn loadConfig(hunk_side: *HunkSide) !config.Config {
    var buffer: [5000]u8 = undefined;
    const bytes_read = try web.getLocalStorage(config_storagekey, buffer[0..]);
    if (bytes_read == 0) {
        return config.getDefault();
    }
    var sis = std.io.SliceInStream.init(buffer[0..bytes_read]);
    return try config.read(std.io.SliceInStream.Error, &sis.stream, bytes_read, hunk_side);
}

fn saveConfig(hunk_side: *HunkSide, cfg_: config.Config) !void {
    var buffer: [5000]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);
    try config.write(std.io.SliceOutStream.Error, &dest.stream, cfg_, hunk_side);
    web.setLocalStorage(config_storagekey, dest.getWritten());
}

fn loadHighScores(hunk_side: *HunkSide) ![Constants.num_high_scores]u32 {
    var buffer: [1000]u8 = undefined;
    const bytes_read = try web.getLocalStorage(highscores_storagekey, buffer[0..]);
    var sis = std.io.SliceInStream.init(buffer[0..bytes_read]);
    return datafile.readHighScores(std.io.SliceInStream.Error, &sis.stream);
}

fn saveHighScores(hunk_side: *HunkSide, high_scores: [Constants.num_high_scores]u32) !void {
    var buffer: [1000]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);
    try datafile.writeHighScores(std.io.SliceOutStream.Error, &dest.stream, high_scores);
    web.setLocalStorage(highscores_storagekey, dest.getWritten());
}

fn translateKey(keyCode: c_int) ?Key {
    return switch (keyCode) {
        8 => Key.Backspace,
        9 => Key.Tab,
        13 => Key.Return,
        16 => Key.LShift, // FIXME - 16 is just shift in general?
        17 => Key.LCtrl, // FIXME - 17 is just ctrl in general?
        18 => Key.LAlt, // FIXME - 18 is just alt in general?
        19 => Key.Pause,
        20 => Key.CapsLock,
        22 => Key.Quote,
        27 => Key.Escape,
        32 => Key.Space,
        33 => Key.PageUp,
        34 => Key.PageDown,
        35 => Key.End,
        36 => Key.Home,
        37 => Key.Left,
        38 => Key.Up,
        39 => Key.Right,
        40 => Key.Down,
        45 => Key.Insert,
        46 => Key.Delete,
        48 => Key.N0,
        49 => Key.N1,
        50 => Key.N2,
        51 => Key.N3,
        52 => Key.N4,
        53 => Key.N5,
        54 => Key.N6,
        55 => Key.N7,
        56 => Key.N8,
        57 => Key.N9,
        65 => Key.A,
        66 => Key.B,
        67 => Key.C,
        68 => Key.D,
        69 => Key.E,
        70 => Key.F,
        71 => Key.G,
        72 => Key.H,
        73 => Key.I,
        74 => Key.J,
        75 => Key.K,
        76 => Key.L,
        77 => Key.M,
        78 => Key.N,
        79 => Key.O,
        80 => Key.P,
        81 => Key.Q,
        82 => Key.R,
        83 => Key.S,
        84 => Key.T,
        85 => Key.U,
        86 => Key.V,
        87 => Key.W,
        88 => Key.X,
        89 => Key.Y,
        90 => Key.Z,
        91 => null, // META_LEFT? what is this?
        92 => null, // META_RIGHT? what is this?
        93 => null, // SELECT? what is this?
        96 => Key.Kp0,
        97 => Key.Kp1,
        98 => Key.Kp2,
        99 => Key.Kp3,
        100 => Key.Kp4,
        101 => Key.Kp5,
        102 => Key.Kp6,
        103 => Key.Kp7,
        104 => Key.Kp8,
        105 => Key.Kp9,
        106 => Key.KpMultiply,
        107 => Key.KpPlus,
        109 => Key.KpMinus,
        110 => Key.KpPeriod,
        111 => Key.KpDivide,
        112 => Key.F1,
        113 => Key.F2,
        114 => Key.F3,
        115 => Key.F4,
        116 => Key.F5,
        117 => Key.F6,
        118 => Key.F7,
        119 => Key.F8,
        120 => Key.F9,
        121 => Key.F10,
        122 => Key.F11,
        123 => Key.F12,
        144 => Key.NumLockClear,
        145 => Key.ScrollLock,
        186 => Key.Semicolon,
        187 => Key.Equals,
        188 => Key.Comma,
        189 => Key.Minus,
        190 => Key.Period,
        191 => Key.Slash,
        192 => Key.Backquote,
        219 => Key.LeftBracket,
        220 => Key.Backslash,
        221 => Key.RightBracket,
        else => null,
    };
}

fn makeMenuContext() menus.MenuContext {
    return menus.MenuContext {
        .sound_enabled = g.sound_enabled,
        .fullscreen = g.is_fullscreen,
        .cfg = g.cfg,
        .high_scores = g.high_scores,
        .new_high_score = g.new_high_score,
        .game_over = g.game_over,
        .anim_time = g.menu_anim_time,
        .canvas_scale = g.canvas_scale,
        .max_canvas_scale = 4,
    };
}

export fn onKeyEvent(keycode: c_int, down: c_int) c_int {
    const source = InputSource {
        .Key = translateKey(keycode) orelse return 0,
    };

    if (common.inputEvent(&g.session, g.cfg, source, down != 0, &g.menu_stack, &g.audio_module, makeMenuContext())) |effect| {
        return applyMenuEffect(effect);
    }

    return 0;
}

// these match same values in web/js/wasm.js
const NOP               = 1;
const TOGGLE_SOUND      = 2;
const TOGGLE_FULLSCREEN = 3;
const SET_CANVAS_SCALE  = 100;

export fn onSoundEnabledChange(enabled: c_int) void {
    g.sound_enabled = enabled != 0;
}

export fn onFullscreenChange(enabled: c_int) void {
    g.is_fullscreen = enabled != 0;
}

export fn onCanvasScaleChange(scale: c_int) void {
    g.canvas_scale = std.math.cast(u31, scale) catch 1;
}

fn applyMenuEffect(effect: menus.Effect) c_int {
    switch (effect) {
        .NoOp => {},
        .Push => |new_menu| {
            g.menu_stack.push(new_menu);
        },
        .Pop => {
            g.menu_stack.pop();
        },
        .StartNewGame => {
            g.menu_stack.clear();
            common.startGame(&g.session);
            g.game_over = false;
            g.new_high_score = false;
        },
        .EndGame => {
            finalizeGame();
            common.abortGame(&g.session);

            g.menu_stack.clear();
            g.menu_stack.push(menus.Menu {
                .MainMenu = menus.MainMenu.init(),
            });
        },
        .ToggleSound => {
            return TOGGLE_SOUND;
        },
        .SetVolume => |value| {
            g.cfg.volume = value;
            saveConfig(&hunk.low(), g.cfg) catch |err| {
                warn("Failed to save config: {}\n", err);
            };
        },
        .SetCanvasScale => |value| {
            return SET_CANVAS_SCALE + @intCast(c_int, value);
        },
        .ToggleFullscreen => {
            return TOGGLE_FULLSCREEN;
        },
        .BindGameCommand => |payload| {
            const command_index = @enumToInt(payload.command);
            const in_use =
                if (payload.source) |new_source|
                    for (g.cfg.game_bindings) |maybe_source| {
                        if (if (maybe_source) |source| areInputSourcesEqual(source, new_source) else false) {
                            break true;
                        }
                    } else false
                else false;
            if (!in_use) {
                g.cfg.game_bindings[command_index] = payload.source;
            }
            saveConfig(&hunk.low(), g.cfg) catch |err| {
                warn("Failed to save config: {}\n", err);
            };
        },
        .ResetAnimTime => {
            g.menu_anim_time = 0;
        },
        .Quit => {
            // not used in web build
        },
    }

    return NOP;
}

var main_memory: []u8 = undefined;
var hunk: Hunk = undefined;
var g: *GameState = undefined;

const audio_buffer_size = 1024;

fn init() !void {
    main_memory = std.heap.wasm_allocator.alloc(u8, @sizeOf(GameState) + 200*1024) catch |err| {
        warn("failed to allocate main_memory: {}\n", err);
        return error.Failed;
    };
    errdefer std.heap.wasm_allocator.free(main_memory);

    hunk = Hunk.init(main_memory);

    g = hunk.low().allocator.create(GameState) catch unreachable;

    platform_draw.init(&g.draw_state, platform_draw.DrawInitParams {
        .hunk = &hunk,
        .virtual_window_width = common.virtual_window_width,
        .virtual_window_height = common.virtual_window_height,
    }) catch |err| {
        warn("platform_draw.init failed: {}\n", err);
        return error.Failed;
    };
    errdefer platform_draw.deinit(&g.draw_state);

    g.cfg = blk: {
        // if config couldn't load, warn and fall back to default config
        const cfg_ = loadConfig(&hunk.low()) catch |err| {
            warn("Failed to load config: {}\n", err);
            break :blk config.getDefault();
        };
        break :blk cfg_;
    };

    const initial_high_scores = blk: {
        // if high scores couldn't load, warn and fall back to blank list
        const high_scores = loadHighScores(&hunk.low()) catch |err| {
            warn("Failed to load high scores: {}\n", err);
            break :blk [1]u32{0} ** Constants.num_high_scores;
        };
        break :blk high_scores;
    };

    if (!common.loadStatic(&g.static, &hunk.low())) {
        // loadStatic prints its own error
        return error.Failed;
    }

    g.audio_module = audio.MainModule.init(&hunk, audio_buffer_size) catch |err| {
        warn("Failed to load audio module: {}\n", err);
        return error.Failed;
    };

    const rand_seed = web.getRandomSeed();
    g.session.init(rand_seed);
    gameInit(&g.session) catch |err| {
        warn("Failed to initialize game: {}\n", err);
        return error.Failed;
    };

    // TODO - this shouldn't be fatal
    perf.init() catch |err| {
        warn("Failed to create performance timers: {}\n", err);
        return error.Failed;
    };

    g.game_over = false;
    g.new_high_score = false;
    g.high_scores = initial_high_scores;
    g.menu_anim_time = 0;
    g.menu_stack = menus.MenuStack {
        .array = undefined,
        .len = 1,
    };
    g.menu_stack.array[0] = menus.Menu {
        .MainMenu = menus.MainMenu.init(),
    };
    g.sound_enabled = false;
    g.is_fullscreen = false;
    g.canvas_scale = 1;
}

export fn onInit() bool {
    init() catch return false;
    return true;
}

export fn onDestroy() void {
    platform_draw.deinit(&g.draw_state);
    std.heap.wasm_allocator.free(main_memory);
}

export fn getAudioBufferSize() c_int {
    return audio_buffer_size;
}

export fn audioCallback(sample_rate: f32) [*]f32 {
    const buf = g.audio_module.paint(sample_rate, &g.session);

    const vol = std.math.min(1.0, @intToFloat(f32, g.cfg.volume) / 100.0);

    var i: usize = 0; while (i < audio_buffer_size) : (i += 1) {
        buf[i] *= vol;
    }

    return buf.ptr;
}

var t: usize = 0;
var maybe_prev: ?c_int = null;

// `now` is in milliseconds
export fn onAnimationFrame(now: c_int) void {
    const delta =
        if (maybe_prev) |prev| (
            if (now > prev) (
                @intCast(usize, now - prev)
            ) else (
                0
            )
        ) else (
            16 // first tick's delta corresponds to ~60 fps
        );
    maybe_prev = now;

    if (delta == 0 or delta > 1000) {
        // avoid dividing by zero
        return;
    }
    const refresh_rate = 1000 / delta;

    const num_frames_to_simulate = blk: {
        t += Constants.ticks_per_second; // gameplay update rate
        var n: usize = 0;
        while (t >= refresh_rate) {
            t -= refresh_rate;
            n += 1;
        }
        break :blk n;
    };

    var i: usize = 0; while (i < num_frames_to_simulate) : (i += 1) {
        // if we're simulating multiple frames for one draw cycle, we only
        // need to actually draw for the last one of them
        const draw = i == num_frames_to_simulate - 1;

        tick(draw);
    }
}

fn tick(draw: bool) void {
    const paused = g.menu_stack.len > 0 and !g.game_over;

    gameFrame(&g.session, draw, paused);

    handleGameOver();

    playSounds();

    if (draw) {
        platform_draw.prepare(&g.draw_state);
        drawGame(&g.draw_state, &g.static, &g.session, g.cfg, g.high_scores[0]);

        drawMenu(&g.menu_stack, MenuDrawParams {
            .ds = &g.draw_state,
            .static = &g.static,
            .menu_context = makeMenuContext(),
        });
    }

    gameFrameCleanup(&g.session);
}

fn handleGameOver() void {
    var it = g.session.iter(c.EventPlayerOutOfLives); while (it.next()) |object| {
        finalizeGame();
        g.menu_stack.push(menus.Menu {
            .GameOverMenu = menus.GameOverMenu.init(),
        });
    }
}

fn finalizeGame() void {
    g.game_over = true;
    g.new_high_score = false;

    // get player's score
    const pc = g.session.findFirst(c.PlayerController) orelse return;

    // insert the score somewhere in the high score list
    const new_score = pc.score;

    // the list is always sorted highest to lowest
    var i: usize = 0; while (i < Constants.num_high_scores) : (i += 1) {
        if (new_score > g.high_scores[i]) {
            // insert the new score here
            std.mem.copyBackwards(u32,
                g.high_scores[i + 1..Constants.num_high_scores],
                g.high_scores[i..Constants.num_high_scores - 1]
            );

            g.high_scores[i] = new_score;
            if (i == 0) {
                g.new_high_score = true;
            }

            saveHighScores(&hunk.low(), g.high_scores) catch |err| {
                warn("Failed to save high scores to disk: {}\n", err);
            };

            break;
        }
    }
}

fn playSounds() void {
    if (g.sound_enabled) {
        // FIXME - impulse_frame being 0 means that sounds will always start
        // playing at the beginning of the mix buffer. need to implement some
        // "syncing" to guess where we are in the middle of a mix frame
        const impulse_frame: usize = 0;

        g.audio_module.playSounds(&g.session, impulse_frame);
    } else {
        // prevent a bunch sounds from queueing up when audio is disabled (as
        // the mixing function won't be called to advance them)
        var it = g.session.iter(c.Voice); while (it.next()) |object| {
            g.session.markEntityForRemoval(object.entity_id);
        }

        g.audio_module.resetMenuSounds();
    }
}
