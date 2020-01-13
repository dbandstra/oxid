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
const GameFrameContext = @import("oxid/frame.zig").GameFrameContext;
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
const SetFriendlyFire = @import("oxid/functions/set_friendly_fire.zig");

const config_storagekey = "config";
const highscores_storagekey = "highscores";

const Main = struct {
    main_state: common.MainState,
};

pub fn loadConfig(hunk_side: *HunkSide) !config.Config {
    var buffer: [5000]u8 = undefined;
    const bytes_read = try web.getLocalStorage(config_storagekey, buffer[0..]);
    if (bytes_read == 0) {
        return config.default;
    }
    var sis = std.io.SliceInStream.init(buffer[0..bytes_read]);
    return try config.read(std.io.SliceInStream.Error, &sis.stream, bytes_read, hunk_side);
}

pub fn saveConfig(cfg: config.Config) !void {
    var buffer: [5000]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);
    try config.write(std.io.SliceOutStream.Error, &dest.stream, cfg);
    web.setLocalStorage(config_storagekey, dest.getWritten());
}

pub fn loadHighScores(hunk_side: *HunkSide) [Constants.num_high_scores]u32 {
    var buffer: [1000]u8 = undefined;
    const bytes_read = web.getLocalStorage(highscores_storagekey, buffer[0..]) catch |err| {
        // the high scores exist but there was an error loading them. just
        // continue with an empty high scores list, even though that might mean
        // that the user's legitimate high scores might get wiped out (FIXME?)
        warn("Failed to load high scores from local storage: {}\n", .{err});
        return [1]u32{0} ** Constants.num_high_scores;
    };
    var sis = std.io.SliceInStream.init(buffer[0..bytes_read]);
    return datafile.readHighScores(std.io.SliceInStream.Error, &sis.stream);
}

pub fn saveHighScores(hunk_side: *HunkSide, high_scores: [Constants.num_high_scores]u32) !void {
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

// these match same values in web/js/wasm.js
const NOP               = 1;
const TOGGLE_SOUND      = 2;
const TOGGLE_FULLSCREEN = 3;
const SET_CANVAS_SCALE  = 100;

export fn onKeyEvent(keycode: c_int, down: c_int) c_int {
    const key = translateKey(keycode) orelse return 0;
    const source = InputSource { .Key = key };
    const special = common.inputEvent(g, @This(), source, down != 0) orelse return NOP;
    return switch (special) {
        .NoOp => NOP,
        .Quit => NOP, // unused in web build
        .ToggleSound => TOGGLE_SOUND,
        .ToggleFullscreen => TOGGLE_FULLSCREEN,
        .SetCanvasScale => |value| SET_CANVAS_SCALE + @intCast(c_int, value),
    };
}

export fn onSoundEnabledChange(enabled: c_int) void {
    g.main_state.sound_enabled = enabled != 0;
}

export fn onFullscreenChange(enabled: c_int) void {
    g.main_state.fullscreen = enabled != 0;
}

export fn onCanvasScaleChange(scale: c_int) void {
    g.main_state.canvas_scale = std.math.cast(u31, scale) catch 1;
}

var main_memory: []u8 = undefined;
var g: *Main = undefined;

const audio_buffer_size = 1024;

fn init() !void {
    main_memory = std.heap.page_allocator.alloc(u8, @sizeOf(Main) + 200*1024) catch |err| {
        warn("failed to allocate main_memory: {}\n", .{err});
        return error.Failed;
    };
    errdefer std.heap.page_allocator.free(main_memory);

    var hunk = std.heap.page_allocator.create(Hunk) catch |err| {
        warn("failed to allocate hunk: {}\n", .{err});
        return error.Failed;
    };
    errdefer std.heap.page_allocator.destroy(hunk);
    hunk.* = Hunk.init(main_memory);

    g = hunk.low().allocator.create(Main) catch unreachable;

    if (!common.init(&g.main_state, @This(), common.InitParams {
        .hunk = hunk,
        .random_seed = web.getRandomSeed(),
        .audio_buffer_size = audio_buffer_size,
        .fullscreen = false,
        .canvas_scale = 1,
        .max_canvas_scale = 4,
        .sound_enabled = false,
    })) {
        // common.init prints its own errors
        return error.Failed;
    }
}

export fn onInit() bool {
    init() catch return false;
    return true;
}

export fn onDestroy() void {
    common.deinit(&g.main_state);
    std.heap.page_allocator.free(main_memory);
}

export fn getAudioBufferSize() c_int {
    return audio_buffer_size;
}

export fn audioCallback(sample_rate: f32) [*]f32 {
    const buf = g.main_state.audio_module.paint(sample_rate, &g.main_state.session);

    const vol = std.math.min(1.0, @intToFloat(f32, g.main_state.cfg.volume) / 100.0);

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
    const paused = g.main_state.menu_stack.len > 0 and !g.main_state.game_over;

    const frame_context: GameFrameContext = .{
        .friendly_fire = g.main_state.friendly_fire,
    };

    gameFrame(&g.main_state.session, frame_context, draw, paused);

    common.handleGameOver(&g.main_state, @This());

    playSounds();

    if (draw) {
        common.drawMain(&g.main_state);
    }

    gameFrameCleanup(&g.main_state.session);
}

fn playSounds() void {
    if (g.main_state.sound_enabled) {
        // FIXME - impulse_frame being 0 means that sounds will always start
        // playing at the beginning of the mix buffer. need to implement some
        // "syncing" to guess where we are in the middle of a mix frame
        const impulse_frame: usize = 0;

        g.main_state.audio_module.playSounds(&g.main_state.session, impulse_frame);
    } else {
        // prevent a bunch sounds from queueing up when audio is disabled (as
        // the mixing function won't be called to advance them)
        var it = g.main_state.session.iter(c.Voice); while (it.next()) |object| {
            g.main_state.session.markEntityForRemoval(object.entity_id);
        }

        g.main_state.audio_module.resetMenuSounds();
    }
}
