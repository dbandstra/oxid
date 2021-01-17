const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const inputs = @import("common/inputs.zig");
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
const SetFriendlyFire = @import("oxid/functions/set_friendly_fire.zig");
const oxid = @import("oxid/oxid.zig");

// drivers that other source files can access via @import("root")
pub const passets = @import("platform/assets_web.zig");
pub const pdraw = @import("platform/draw_opengl.zig");
pub const pstorage = @import("platform/storage_web.zig");

pub const storagekey_config = "config";
pub const storagekey_highscores = "highscores";

// extern functions implemented in javascript
extern fn consoleLog(message_ptr: [*]const u8, message_len: c_uint) void;
extern fn getRandomSeed() c_uint;

fn logLine(message: []const u8) void {
    consoleLog(message.ptr, message.len);
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    var buf: [1000]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, format, args) catch {
        logLine("warn: bufPrint failed. too long? format string:");
        logLine(format);
        return;
    };
    logLine(text);
}

const Main = struct {
    main_state: oxid.MainState,
    draw_state: pdraw.State,
};

fn translateKey(keyCode: c_int) ?inputs.Key {
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
    // note: if this function returns a non-zero value, event.preventDefault
    // will be called on the javascript side. so we return zero for anything
    // that the game doesn't handle. this allows most default browser behaviors
    // to still work
    const key = translateKey(keycode) orelse return 0;
    const source: inputs.Source = .{ .key = key };
    const special = oxid.inputEvent(&g.main_state, source, down != 0) orelse return 0;
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
            ) catch |err| std.log.err("Failed to save config: {}", .{err});
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
        std.log.emerg("failed to allocate main_memory: {}", .{err});
        return error.Failed;
    };
    errdefer std.heap.page_allocator.free(main_memory);

    var hunk = std.heap.page_allocator.create(Hunk) catch |err| {
        std.log.emerg("failed to allocate hunk: {}", .{err});
        return error.Failed;
    };
    errdefer std.heap.page_allocator.destroy(hunk);
    hunk.* = Hunk.init(main_memory);

    g = hunk.low().allocator.create(Main) catch unreachable;

    pdraw.init(&g.draw_state, .webgl, .{
        .hunk = hunk,
        .vwin_w = oxid.vwin_w,
        .vwin_h = oxid.vwin_h,
    }) catch |err| {
        std.log.emerg("pdraw.init failed: {}", .{err});
        return error.Failed;
    };
    errdefer pdraw.deinit(&g.draw_state);

    try oxid.init(&g.main_state, &g.draw_state, .{
        .hunk = hunk,
        .random_seed = getRandomSeed(),
        .audio_buffer_size = audio_buffer_size,
        .audio_sample_rate = 44100, // will be overridden before first paint
        .fullscreen = false,
        .canvas_scale = 1,
        .max_canvas_scale = 4,
        .sound_enabled = false,
    }); // oxid.init prints its own errors and returns error.Failed
    errdefer oxid.deinit(&g.main_state);
}

export fn onInit() bool {
    init() catch return false;
    return true;
}

export fn onDestroy() void {
    oxid.deinit(&g.main_state);
    pdraw.deinit(&g.draw_state);
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
        const should_draw = i == num_frames_to_simulate - 1;

        tick(should_draw);
    }
}

fn tick(should_draw: bool) void {
    oxid.frame(&g.main_state, .{
        .spawn_draw_events = should_draw,
        .friendly_fire = g.main_state.friendly_fire,
    });

    g.main_state.audio_module.sync(
        !g.main_state.sound_enabled,
        g.main_state.cfg.volume,
        g.main_state.audio_module.sample_rate,
        &g.main_state.session,
        &g.main_state.menu_sounds,
    );

    if (should_draw) {
        oxid.draw(&g.main_state, &g.draw_state);
    }

    game.frameCleanup(&g.main_state.session);
}
