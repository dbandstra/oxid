usingnamespace @import("platform/sdl.zig");
const translateKey = @import("platform/sdl_keys.zig").translateKey;
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const zang = @import("zang");
const inputs = @import("common/inputs.zig");
const game = @import("oxid/game.zig");
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const oxid = @import("oxid/oxid.zig");

// drivers that other source files can access via @import("root")
pub const passets = @import("platform/assets_native.zig");
pub const pdraw = @import("platform/draw_sdl.zig");
pub const plog = @import("platform/log_native.zig");
pub const pstorage_dirname = "Oxid";
pub const pstorage = @import("platform/storage_native.zig");

pub const storagekey_config = "config.json";
pub const storagekey_highscores = "highscore.dat";

fn getMaxCanvasScale(screen_w: u31, screen_h: u31) u31 {
    // pick a window size that isn't bigger than the desktop resolution, and
    // is an integer multiple of the virtual window size
    const max_w = screen_w;
    const max_h = screen_h - 40; // bias for system menubars/taskbars

    const scale_limit = 8;

    var scale: u31 = 1;
    while (scale < scale_limit) : (scale += 1) {
        const w = (scale + 1) * oxid.vwin_w;
        const h = (scale + 1) * oxid.vwin_h;

        if (w > max_w or h > max_h) {
            break;
        }
    }

    return scale;
}

fn getWindowDimsForScale(scale: u31) struct { w: u31, h: u31 } {
    return .{
        .w = oxid.vwin_w * scale,
        .h = oxid.vwin_h * scale,
    };
}

// used to save the original position and dimensions of the game window before
// fullscreen mode was activated. this is what we will return to when
// fullscreen mode is toggled off
const SavedWindowPos = struct {
    x: i32,
    y: i32,
    w: u31,
    h: u31,
};

const Main = struct {
    main_state: oxid.MainState,
    draw_state: pdraw.State,
    window: *SDL_Window,
    renderer: *SDL_Renderer,
    display_index: c_int, // used to detect when the window has been moved to another display
    toggle_fullscreen: bool,
    set_canvas_scale: ?u31,
    audio_sample_rate: u31,
    audio_device: SDL_AudioDeviceID,
    saved_window_pos: ?SavedWindowPos, // only set when in fullscreen mode
    quit: bool,
};

// since audio files are loaded at runtime, we need to make room for them in
// the memory buffer
const audio_assets_size = 320700;

var main_memory: [@sizeOf(Main) + 200 * 1024 + audio_assets_size]u8 = undefined;

pub fn main() u8 {
    var hunk = Hunk.init(&main_memory);

    const self = init(&hunk) catch return 1; // init prints its own error

    while (!self.quit)
        tick(self);

    deinit(self);
    return 0;
}

fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) callconv(.C) void {
    const audio_module = @ptrCast(*audio.MainModule, @alignCast(@alignOf(*audio.MainModule), userdata_.?));
    const out_bytes = stream_.?[0..@intCast(usize, len_)];

    const buf = audio_module.paint();
    const vol = std.math.min(1.0, @intToFloat(f32, audio_module.volume) / 100.0);
    zang.mixDown(out_bytes, buf, .signed16_lsb, 1, 0, vol);
}

fn init(hunk: *Hunk) !*Main {
    const self = hunk.low().allocator.create(Main) catch unreachable;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        std.debug.warn("Unable to initialize SDL: {s}\n", .{SDL_GetError()});
        return error.Failed;
    }
    errdefer SDL_Quit();

    // determine initial and max canvas scale (note: max canvas scale will be
    // updated on the fly when the window is moved between displays)
    const max_canvas_scale: u31 = blk: {
        // get the usable screen region (for the first display)
        var bounds: SDL_Rect = undefined;
        if (SDL_GetDisplayUsableBounds(0, &bounds) < 0) {
            std.debug.warn("Failed to query desktop display mode.\n", .{});
            break :blk 1; // stick with a small 1x scale window
        }
        const w = @intCast(u31, std.math.max(1, bounds.w));
        const h = @intCast(u31, std.math.max(1, bounds.h));
        break :blk getMaxCanvasScale(w, h);
    };

    const initial_canvas_scale = std.math.min(max_canvas_scale, 4);
    const window_dims = getWindowDimsForScale(initial_canvas_scale);
    const window = SDL_CreateWindow(
        "Oxid",
        // note: these macros will place the window on the first display
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        window_dims.w,
        window_dims.h,
        0,
    ) orelse {
        std.debug.warn("Unable to create window: {s}\n", .{SDL_GetError()});
        return error.Failed;
    };
    errdefer SDL_DestroyWindow(window);

    // print available render drivers (just out of curiosity; there's no way
    // for the user to pick one currently)
    {
        const num_drivers = SDL_GetNumRenderDrivers();
        if (num_drivers < 0) {
            std.debug.warn("Failed to get number of SDL render drivers: {s}\n", .{SDL_GetError()});
        } else if (num_drivers == 0) {
            std.debug.warn("No available SDL render drivers.\n", .{});
        } else blk: {
            std.debug.warn("Available SDL render drivers: ", .{});
            var driver_index: c_int = 0;
            while (driver_index < num_drivers) : (driver_index += 1) {
                var info: SDL_RendererInfo = undefined;
                if (SDL_GetRenderDriverInfo(driver_index, &info) != 0) {
                    std.debug.warn("\nFailed to get SDL render driver info: {s}\n", .{SDL_GetError()});
                    break :blk;
                } else {
                    if (driver_index > 0)
                        std.debug.warn(", ", .{});
                    std.debug.warn("{}", .{std.mem.spanZ(info.name)});
                }
            }
            std.debug.warn("\n", .{});
        }
    }

    // ask for vsync support (and hope it's 60hz), because framerate control is
    // not implemented in this build
    const renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC) orelse {
        std.debug.warn("Unable to create SDL renderer: {s}\n", .{SDL_GetError()});
        return error.Failed;
    };
    errdefer SDL_DestroyRenderer(renderer);

    // print the name of the render driver that SDL picked
    {
        var info: SDL_RendererInfo = undefined;
        if (SDL_GetRendererInfo(renderer, &info) == 0) {
            std.debug.warn("Chosen SDL render driver: {}\n", .{std.mem.spanZ(info.name)});
        } else {
            std.debug.warn("Failed to get SDL renderer info: {s}\n", .{SDL_GetError()});
        }
    }

    _ = SDL_RenderSetLogicalSize(renderer, oxid.vwin_w, oxid.vwin_h);
    // _ = SDL_RenderSetIntegerScale(renderer, @intToEnum(SDL_bool, SDL_TRUE));

    self.window = window;
    self.renderer = renderer;

    if (SDL_GetCurrentAudioDriver()) |name| {
        std.debug.warn("Audio driver: {}\n", .{std.mem.spanZ(name)});
    } else {
        std.debug.warn("Failed to get audio driver name.\n", .{});
    }

    var want = std.mem.zeroes(SDL_AudioSpec);
    want.freq = 44100;
    want.format = AUDIO_S16LSB;
    want.channels = 1;
    want.samples = 1024;
    want.callback = audioCallback;
    want.userdata = &self.main_state.audio_module;

    var have: SDL_AudioSpec = undefined;

    const device = SDL_OpenAudioDevice(
        0, // device name (NULL to let SDL choose)
        0, // non-zero to open for recording instead of playback
        &want,
        &have,
        // tell SDL that we can handle any frequency. however for other
        // properties, like format, we will let SDL do the resampling if the
        // system doesn't support it
        SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
    );
    if (device == 0) {
        std.debug.warn("Failed to open audio: {s}\n", .{SDL_GetError()});
        return error.Failed;
    }
    errdefer SDL_CloseAudioDevice(device);

    std.debug.warn("Audio sample rate: {}hz\n", .{have.freq});

    pdraw.init(&self.draw_state, renderer);
    // note: platform/draw_sdl has no deinit function

    try oxid.init(&self.main_state, &self.draw_state, .{
        .hunk = hunk,
        .random_seed = @intCast(u32, std.time.milliTimestamp() & 0xFFFFFFFF),
        .audio_buffer_size = have.samples,
        .audio_sample_rate = @intToFloat(f32, have.freq),
        .fullscreen = false,
        .canvas_scale = initial_canvas_scale,
        .max_canvas_scale = max_canvas_scale,
        .sound_enabled = true,
    }); // oxid.init prints its own error and returns error.Failed
    errdefer oxid.deinit(&self.main_state);

    self.display_index = 0;
    self.toggle_fullscreen = false;
    self.set_canvas_scale = null;
    self.audio_sample_rate = @intCast(u31, have.freq);
    self.audio_device = device;
    self.quit = false;
    self.saved_window_pos = null;

    SDL_PauseAudioDevice(device, 0); // unpause
    errdefer SDL_PauseAudioDevice(device, 1);

    std.debug.warn("Initialization complete.\n", .{});

    return self;
}

fn deinit(self: *Main) void {
    std.debug.warn("Shutting down.\n", .{});

    config.write(
        &self.main_state.hunk.low(),
        storagekey_config,
        self.main_state.cfg,
    ) catch |err| {
        std.debug.warn("Failed to save config: {}\n", .{err});
    };

    SDL_PauseAudioDevice(self.audio_device, 1);
    oxid.deinit(&self.main_state);
    SDL_CloseAudioDevice(self.audio_device);
    SDL_DestroyRenderer(self.renderer);
    SDL_DestroyWindow(self.window);
    SDL_Quit();
}

fn tick(self: *Main) void {
    var evt: SDL_Event = undefined;
    while (SDL_PollEvent(&evt) != 0) {
        handleSDLEvent(self, evt);
        if (self.quit) {
            return;
        }
    }

    self.main_state.menu_anim_time +%= 1;

    oxid.frame(&self.main_state, .{
        .spawn_draw_events = true,
        .friendly_fire = self.main_state.friendly_fire,
    });

    perf.begin(.whole_draw);
    perf.begin(.draw);
    oxid.draw(&self.main_state, &self.draw_state);
    perf.end(.draw);
    perf.end(.whole_draw);

    game.frameCleanup(&self.main_state.session);

    SDL_RenderPresent(self.renderer);

    SDL_LockAudioDevice(self.audio_device);
    self.main_state.audio_module.sync(
        false,
        self.main_state.cfg.volume,
        @intToFloat(f32, self.audio_sample_rate),
        &self.main_state.session,
        &self.main_state.menu_sounds,
    );
    SDL_UnlockAudioDevice(self.audio_device);

    if (self.toggle_fullscreen) {
        toggleFullscreen(self);
    } else if (self.set_canvas_scale) |scale| {
        setCanvasScale(self, scale);
    }
    self.toggle_fullscreen = false;
    self.set_canvas_scale = null;

    perf.display();
}

fn setCanvasScale(self: *Main, scale: u31) void {
    if (self.main_state.fullscreen) return;

    self.main_state.canvas_scale = scale;

    const dims = getWindowDimsForScale(scale);

    const w: i32 = dims.w;
    const h: i32 = dims.h;
    SDL_SetWindowSize(self.window, w, h);

    // if resizing the window puts part of it off-screen, push it back on-screen
    const display_index = SDL_GetWindowDisplayIndex(self.window);
    if (display_index < 0)
        return;
    var bounds: SDL_Rect = undefined;
    if (SDL_GetDisplayUsableBounds(display_index, &bounds) < 0)
        return;

    var x: i32 = undefined;
    var y: i32 = undefined;
    SDL_GetWindowPosition(self.window, &x, &y);

    const new_x = if (x + w > bounds.x + bounds.w)
        std.math.max(bounds.x, bounds.x + bounds.w - w)
    else
        x;

    const new_y = if (y + h > bounds.y + bounds.h)
        std.math.max(bounds.y, bounds.y + bounds.h - h)
    else
        y;

    if (new_x != x or new_y != y)
        SDL_SetWindowPosition(self.window, new_x, new_y);
}

fn toggleFullscreen(self: *Main) void {
    if (self.main_state.fullscreen) {
        // disable fullscreen mode
        if (SDL_SetWindowFullscreen(self.window, 0) < 0) {
            std.debug.warn("Failed to disable fullscreen mode", .{});
            return;
        }
        // give the window back its original dimensions
        const swp = self.saved_window_pos.?; // this field is always set when fullscreen is true
        SDL_SetWindowSize(self.window, swp.w, swp.h);
        SDL_SetWindowPosition(self.window, swp.x, swp.y);
        self.main_state.fullscreen = false;
        self.saved_window_pos = null;
        return;
    }
    // enabling fullscreen mode. we use SDL's "fake" fullscreen mode to avoid a video mode change.
    // first get the full window dimensions to use
    const display_index = SDL_GetWindowDisplayIndex(self.window);
    if (display_index < 0)
        return;
    var mode: SDL_DisplayMode = undefined;
    if (SDL_GetDesktopDisplayMode(display_index, &mode) < 0)
        return;
    const full_w = @intCast(u31, std.math.max(1, mode.w));
    const full_h = @intCast(u31, std.math.max(1, mode.h));
    // save the current window pos and size
    const swp: SavedWindowPos = blk: {
        var x: i32 = undefined;
        var y: i32 = undefined;
        var w: i32 = undefined;
        var h: i32 = undefined;
        SDL_GetWindowPosition(self.window, &x, &y);
        SDL_GetWindowSize(self.window, &w, &h);
        break :blk .{
            .x = x,
            .y = y,
            .w = @intCast(u31, std.math.max(1, w)),
            .h = @intCast(u31, std.math.max(1, h)),
        };
    };
    // set new window size and go fullscreen
    SDL_SetWindowSize(self.window, full_w, full_h);
    if (SDL_SetWindowFullscreen(self.window, SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
        std.debug.warn("Failed to enable fullscreen mode\n", .{});
        SDL_SetWindowSize(self.window, swp.w, swp.h); // put it back
        return;
    }
    self.main_state.fullscreen = true;
    self.saved_window_pos = swp;
}

fn inputEvent(self: *Main, source: inputs.Source, down: bool) void {
    switch (oxid.inputEvent(&self.main_state, source, down) orelse return) {
        .noop => {},
        .quit => self.quit = true,
        .toggle_sound => {}, // unused
        .toggle_fullscreen => self.toggle_fullscreen = true,
        .set_canvas_scale => |scale| self.set_canvas_scale = scale,
        .config_updated => {}, // do nothing (config is saved when program exits)
    }
}

fn handleSDLEvent(self: *Main, evt: SDL_Event) void {
    switch (evt.type) {
        SDL_KEYDOWN => {
            if (evt.key.repeat == 0) {
                if (translateKey(evt.key.keysym.sym)) |key| {
                    inputEvent(self, .{ .key = key }, true);

                    if (key == .f4) perf.toggleSpam();
                }
            }
        },
        SDL_KEYUP => {
            if (translateKey(evt.key.keysym.sym)) |key| {
                inputEvent(self, .{ .key = key }, false);
            }
        },
        SDL_WINDOWEVENT => {
            if (evt.window.event == SDL_WINDOWEVENT_MOVED and !self.main_state.fullscreen) {
                const display_index = SDL_GetWindowDisplayIndex(self.window);
                if (self.display_index != display_index) {
                    // window moved to another display
                    self.display_index = display_index;
                    // update max_canvas_scale based on the new display's dimensions.
                    // (the current canvas scale won't change, but the user won't be
                    // able to increase it beyond the new maximum.)
                    var bounds: SDL_Rect = undefined;
                    if (SDL_GetDisplayUsableBounds(display_index, &bounds) >= 0) {
                        const w = @intCast(u31, std.math.max(1, bounds.w));
                        const h = @intCast(u31, std.math.max(1, bounds.h));
                        self.main_state.max_canvas_scale = getMaxCanvasScale(w, h);
                    }
                }
            }
        },
        SDL_QUIT => self.quit = true,
        else => {},
    }
}
