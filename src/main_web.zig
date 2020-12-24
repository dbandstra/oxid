const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const Key = @import("common/key.zig").Key;
const InputSource = @import("common/key.zig").InputSource;
const constants = @import("oxid/constants.zig");
const game = @import("oxid/game.zig");
const drawGame = @import("oxid/draw.zig").drawGame;
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const c = @import("oxid/components.zig");
const menus = @import("oxid/menus.zig");
const MenuDrawParams = @import("oxid/draw_menu.zig").MenuDrawParams;
const drawMenu = @import("oxid/draw_menu.zig").drawMenu;
const common = @import("oxid_common.zig");
const SetFriendlyFire = @import("oxid/functions/set_friendly_fire.zig");

// drivers that other source files can access via @import("root")
pub const passets = @import("platform/assets_web.zig");
pub const pdraw = @import("platform/opengl/draw.zig");
pub const plog = @import("platform/log_web.zig");
pub const pstorage = @import("platform/storage_web.zig");

pub const storagekey_config = "config";
pub const storagekey_highscores = "highscores";

// extern functions implemented in javascript
extern fn getRandomSeed() c_uint;

const Main = struct {
    main_state: common.MainState,
    draw_state: pdraw.State,
};

fn translateKey(keyCode: c_int) ?Key {
    return switch (keyCode) {
        8 => .backspace,
        9 => .tab,
        13 => .@"return",
        16 => .lshift, // FIXME - 16 is just shift in general?
        17 => .lctrl, // FIXME - 17 is just ctrl in general?
        18 => .lalt, // FIXME - 18 is just alt in general?
        19 => .pause,
        20 => .capslock,
        22 => .quote,
        27 => .escape,
        32 => .space,
        33 => .pageup,
        34 => .pagedown,
        35 => .end,
        36 => .home,
        37 => .left,
        38 => .up,
        39 => .right,
        40 => .down,
        45 => .insert,
        46 => .delete,
        48 => .@"0",
        49 => .@"1",
        50 => .@"2",
        51 => .@"3",
        52 => .@"4",
        53 => .@"5",
        54 => .@"6",
        55 => .@"7",
        56 => .@"8",
        57 => .@"9",
        65 => .a,
        66 => .b,
        67 => .c,
        68 => .d,
        69 => .e,
        70 => .f,
        71 => .g,
        72 => .h,
        73 => .i,
        74 => .j,
        75 => .k,
        76 => .l,
        77 => .m,
        78 => .n,
        79 => .o,
        80 => .p,
        81 => .q,
        82 => .r,
        83 => .s,
        84 => .t,
        85 => .u,
        86 => .v,
        87 => .w,
        88 => .x,
        89 => .y,
        90 => .z,
        91 => null, // META_LEFT? what is this?
        92 => null, // META_RIGHT? what is this?
        93 => null, // SELECT? what is this?
        96 => .kp_0,
        97 => .kp_1,
        98 => .kp_2,
        99 => .kp_3,
        100 => .kp_4,
        101 => .kp_5,
        102 => .kp_6,
        103 => .kp_7,
        104 => .kp_8,
        105 => .kp_9,
        106 => .kp_multiply,
        107 => .kp_plus,
        109 => .kp_minus,
        110 => .kp_period,
        111 => .kp_divide,
        112 => .f1,
        113 => .f2,
        114 => .f3,
        115 => .f4,
        116 => .f5,
        117 => .f6,
        118 => .f7,
        119 => .f8,
        120 => .f9,
        121 => .f10,
        122 => .f11,
        123 => .f12,
        144 => .numlockclear,
        145 => .scrolllock,
        186 => .semicolon,
        187 => .equals,
        188 => .comma,
        189 => .minus,
        190 => .period,
        191 => .slash,
        192 => .backquote,
        219 => .leftbracket,
        220 => .backslash,
        221 => .rightbracket,
        else => null,
    };
}

// these match same values in web/js/wasm.js
const NOP = 1;
const TOGGLE_SOUND = 2;
const TOGGLE_FULLSCREEN = 3;
const SET_CANVAS_SCALE = 100;

export fn onKeyEvent(keycode: c_int, down: c_int) c_int {
    const key = translateKey(keycode) orelse return 0;
    const source: InputSource = .{ .key = key };
    const special = common.inputEvent(&g.main_state, source, down != 0) orelse return NOP;
    return switch (special) {
        .noop => NOP,
        .quit => NOP, // unused in web build
        .toggle_sound => return TOGGLE_SOUND,
        .toggle_fullscreen => return TOGGLE_FULLSCREEN,
        .set_canvas_scale => |value| return SET_CANVAS_SCALE + @intCast(c_int, value),
        .config_updated => {
            config.write(
                &g.main_state.hunk.low(),
                storagekey_config,
                g.main_state.cfg,
            ) catch |err| plog.warn("Failed to save config: {}\n", .{err});
            return NOP;
        },
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
    main_memory = std.heap.page_allocator.alloc(u8, @sizeOf(Main) + 200 * 1024) catch |err| {
        plog.warn("failed to allocate main_memory: {}\n", .{err});
        return error.Failed;
    };
    errdefer std.heap.page_allocator.free(main_memory);

    var hunk = std.heap.page_allocator.create(Hunk) catch |err| {
        plog.warn("failed to allocate hunk: {}\n", .{err});
        return error.Failed;
    };
    errdefer std.heap.page_allocator.destroy(hunk);
    hunk.* = Hunk.init(main_memory);

    g = hunk.low().allocator.create(Main) catch unreachable;

    if (!common.init(&g.main_state, .{
        .hunk = hunk,
        .random_seed = getRandomSeed(),
        .audio_buffer_size = audio_buffer_size,
        .audio_sample_rate = 44100, // will be overridden before first paint
        .fullscreen = false,
        .canvas_scale = 1,
        .max_canvas_scale = 4,
        .sound_enabled = false,
    })) {
        // common.init prints its own errors
        return error.Failed;
    }
    errdefer common.deinit(&g.main_state);

    pdraw.init(&g.draw_state, .{
        .hunk = hunk,
        .virtual_window_width = common.vwin_w,
        .virtual_window_height = common.vwin_h,
        .glsl_version = .webgl,
    }) catch |err| {
        plog.warn("pdraw.init failed: {}\n", .{err});
        return error.Failed;
    };
    errdefer pdraw.deinit(&g.draw_state);
}

export fn onInit() bool {
    init() catch return false;
    return true;
}

export fn onDestroy() void {
    pdraw.deinit(&g.draw_state);
    common.deinit(&g.main_state);
    std.heap.page_allocator.free(main_memory);
}

export fn getAudioBufferSize() c_int {
    return audio_buffer_size;
}

export fn audioCallback(sample_rate: f32) [*]f32 {
    g.main_state.audio_module.sample_rate = sample_rate;
    const buf = g.main_state.audio_module.paint();
    const vol = std.math.min(1.0, @intToFloat(f32, g.main_state.audio_module.volume) / 100.0);

    var i: usize = 0;
    while (i < audio_buffer_size) : (i += 1) {
        buf[i] *= vol;
    }

    return buf.ptr;
}

var t: usize = 0;
var maybe_prev: ?c_int = null;

// `now` is in milliseconds
export fn onAnimationFrame(now: c_int) void {
    const delta = if (maybe_prev) |prev|
        (if (now > prev)
            @intCast(usize, now - prev)
        else
            0)
    else
        16; // first tick's delta corresponds to ~60 fps
    maybe_prev = now;

    if (delta == 0 or delta > 1000) {
        // avoid dividing by zero
        return;
    }
    const refresh_rate = 1000 / delta;

    const num_frames_to_simulate = blk: {
        t += constants.ticks_per_second; // gameplay update rate
        var n: usize = 0;
        while (t >= refresh_rate) {
            t -= refresh_rate;
            n += 1;
        }
        break :blk n;
    };

    var i: usize = 0;
    while (i < num_frames_to_simulate) : (i += 1) {
        // if we're simulating multiple frames for one draw cycle, we only
        // need to actually draw for the last one of them
        const draw = i == num_frames_to_simulate - 1;

        tick(draw);
    }
}

fn tick(draw: bool) void {
    common.frame(&g.main_state, .{
        .spawn_draw_events = draw,
        .friendly_fire = g.main_state.friendly_fire,
    });

    g.main_state.audio_module.sync(
        !g.main_state.sound_enabled,
        g.main_state.cfg.volume,
        g.main_state.audio_module.sample_rate,
        &g.main_state.session,
        &g.main_state.menu_sounds,
    );

    if (draw) {
        common.drawMain(&g.main_state, &g.draw_state);
    }

    game.frameCleanup(&g.main_state.session);
}
