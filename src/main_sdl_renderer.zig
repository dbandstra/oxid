const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const zang = @import("zang");
const inputs = @import("common/inputs.zig");
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const oxid = @import("oxid/oxid.zig");

const sdl = @import("platform/sdl.zig");
const translateKey = @import("platform/sdl_keys.zig").translateKey;

// drivers that other source files can access via @import("root")
pub const passets = @import("platform/assets_native.zig");
pub const pdate = @import("platform/date_libc.zig");
pub const pdraw = @import("platform/draw_sdl.zig");
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
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
    display_index: c_int, // used to detect when the window has been moved to another display
    toggle_fullscreen: bool,
    set_canvas_scale: ?u31,
    audio_sample_rate: u31,
    audio_device: sdl.SDL_AudioDeviceID,
    saved_window_pos: ?SavedWindowPos, // only set when in fullscreen mode
    quit: bool,
};

pub fn main() u8 {
    const temp_space = 100000; // room for temporary allocations
    const audio_assets_size = 220000; // room for audio assets
    const total_memory_size = @sizeOf(Main) + temp_space + audio_assets_size;
    var main_memory = std.heap.page_allocator.alloc(u8, total_memory_size) catch |err| {
        std.log.emerg("Failed to allocate {} bytes: {}", .{ total_memory_size, err });
        return 1;
    };
    defer std.heap.page_allocator.free(main_memory);

    std.log.notice("Allocated {} bytes", .{total_memory_size});

    var hunk = Hunk.init(main_memory);

    const self = init(&hunk) catch return 1; // init prints its own error

    while (!self.quit)
        tick(self);

    deinit(self);
    return 0;
}

fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) callconv(.C) void {
    const audio_state = @ptrCast(*audio.State, @alignCast(@alignOf(*audio.State), userdata_.?));
    const out_bytes = stream_.?[0..@intCast(usize, len_)];

    const buf = audio_state.paint();
    const vol = std.math.min(1.0, @intToFloat(f32, audio_state.volume) / 100.0);
    zang.mixDown(out_bytes, buf, .signed16_lsb, 1, 0, vol);
}

fn init(hunk: *Hunk) !*Main {
    const self = hunk.low().allocator.create(Main) catch unreachable;

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO) != 0) {
        std.log.emerg("Unable to initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    }
    errdefer sdl.SDL_Quit();

    // determine initial and max canvas scale (note: max canvas scale will be
    // updated on the fly when the window is moved between displays)
    const max_canvas_scale: u31 = blk: {
        // get the usable screen region (for the first display)
        var bounds: sdl.SDL_Rect = undefined;
        if (sdl.SDL_GetDisplayUsableBounds(0, &bounds) < 0) {
            std.log.err("Failed to query desktop display mode.", .{});
            break :blk 1; // stick with a small 1x scale window
        }
        const w = @intCast(u31, std.math.max(1, bounds.w));
        const h = @intCast(u31, std.math.max(1, bounds.h));
        break :blk getMaxCanvasScale(w, h);
    };

    const initial_canvas_scale = std.math.min(max_canvas_scale, 4);
    const window_dims = getWindowDimsForScale(initial_canvas_scale);
    const window = sdl.SDL_CreateWindow(
        "Oxid",
        // note: these macros will place the window on the first display
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        window_dims.w,
        window_dims.h,
        0,
    ) orelse {
        std.log.emerg("Unable to create window: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    };
    errdefer sdl.SDL_DestroyWindow(window);

    // print available render drivers (just out of curiosity; there's no way
    // for the user to pick one currently)
    {
        const num_drivers = sdl.SDL_GetNumRenderDrivers();
        if (num_drivers < 0) {
            std.log.warn("Failed to get number of SDL render drivers: {s}", .{sdl.SDL_GetError()});
        } else if (num_drivers == 0) {
            std.log.notice("No available SDL render drivers.", .{});
        } else blk: {
            std.log.notice("Available SDL render drivers:", .{});
            var driver_index: c_int = 0;
            while (driver_index < num_drivers) : (driver_index += 1) {
                var info: sdl.SDL_RendererInfo = undefined;
                if (sdl.SDL_GetRenderDriverInfo(driver_index, &info) != 0) {
                    std.log.notice("Failed to get SDL render driver info: {s}", .{sdl.SDL_GetError()});
                    break :blk;
                } else {
                    std.log.notice("  - {s}", .{std.mem.spanZ(info.name)});
                }
            }
        }
    }

    // ask for vsync support (and hope it's 60hz), because framerate control is
    // not implemented in this build
    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_PRESENTVSYNC) orelse {
        std.log.emerg("Unable to create SDL renderer: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    };
    errdefer sdl.SDL_DestroyRenderer(renderer);

    // print the name of the render driver that SDL picked
    {
        var info: sdl.SDL_RendererInfo = undefined;
        if (sdl.SDL_GetRendererInfo(renderer, &info) == 0) {
            std.log.notice("Chosen SDL render driver: {s}", .{std.mem.spanZ(info.name)});
        } else {
            std.log.warn("Failed to get SDL renderer info: {s}", .{sdl.SDL_GetError()});
        }
    }

    _ = sdl.SDL_RenderSetLogicalSize(renderer, oxid.vwin_w, oxid.vwin_h);
    // _ = sdl.SDL_RenderSetIntegerScale(renderer, @intToEnum(sdl.SDL_bool, sdl.SDL_TRUE));

    self.window = window;
    self.renderer = renderer;

    if (sdl.SDL_GetCurrentAudioDriver()) |name| {
        std.log.notice("Audio driver: {s}", .{std.mem.spanZ(name)});
    } else {
        std.log.warn("Failed to get audio driver name.", .{});
    }

    var want = std.mem.zeroes(sdl.SDL_AudioSpec);
    want.freq = 44100;
    want.format = sdl.AUDIO_S16LSB;
    want.channels = 1;
    want.samples = 1024;
    want.callback = audioCallback;
    want.userdata = &self.main_state.audio_state;

    var have: sdl.SDL_AudioSpec = undefined;

    const device = sdl.SDL_OpenAudioDevice(
        0, // device name (NULL to let SDL choose)
        0, // non-zero to open for recording instead of playback
        &want,
        &have,
        // tell SDL that we can handle any frequency. however for other
        // properties, like format, we will let SDL do the resampling if the
        // system doesn't support it
        sdl.SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
    );
    if (device == 0) {
        std.log.emerg("Failed to open audio: {s}", .{sdl.SDL_GetError()});
        return error.Failed;
    }
    errdefer sdl.SDL_CloseAudioDevice(device);

    std.log.notice("Audio sample rate: {}hz", .{have.freq});

    pdraw.init(&self.draw_state, renderer);
    // note: platform/draw_sdl has no deinit function

    try oxid.init(&self.main_state, &self.draw_state, .{
        .hunk = hunk,
        .random_seed = @truncate(u32, @bitCast(u64, std.time.milliTimestamp())),
        .audio_buffer_size = have.samples,
        .audio_sample_rate = @intToFloat(f32, have.freq),
        .fullscreen = false,
        .canvas_scale = initial_canvas_scale,
        .max_canvas_scale = max_canvas_scale,
        .sound_enabled = true,
        .disable_recording = false,
    }); // oxid.init prints its own error and returns error.Failed
    errdefer oxid.deinit(&self.main_state);

    self.display_index = 0;
    self.toggle_fullscreen = false;
    self.set_canvas_scale = null;
    self.audio_sample_rate = @intCast(u31, have.freq);
    self.audio_device = device;
    self.quit = false;
    self.saved_window_pos = null;

    sdl.SDL_PauseAudioDevice(device, 0); // unpause
    errdefer sdl.SDL_PauseAudioDevice(device, 1);

    std.log.notice("Initialization complete.", .{});

    return self;
}

fn deinit(self: *Main) void {
    std.log.notice("Shutting down.", .{});

    config.write(
        &self.main_state.hunk.low(),
        storagekey_config,
        self.main_state.cfg,
    ) catch |err| {
        std.log.err("Failed to save config: {}", .{err});
    };

    sdl.SDL_PauseAudioDevice(self.audio_device, 1);
    oxid.deinit(&self.main_state);
    sdl.SDL_CloseAudioDevice(self.audio_device);
    sdl.SDL_DestroyRenderer(self.renderer);
    sdl.SDL_DestroyWindow(self.window);
    sdl.SDL_Quit();
}

fn tick(self: *Main) void {
    var evt: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&evt) != 0) {
        handleSDLEvent(self, evt);
        if (self.quit) {
            return;
        }
    }

    // when fast forwarding, we'll simulate multiple frames and only draw the
    // last one
    const num_frames = if (self.main_state.fast_forward)
        if (self.main_state.lshift or self.main_state.rshift) @as(u32, 16) else @as(u32, 4)
    else
        1;

    var frame_index: u32 = 0;
    while (frame_index < num_frames) : (frame_index += 1) {
        // if we're simulating multiple frames for one draw cycle, we only
        // need to actually draw for the last one of them
        const should_draw = frame_index == num_frames - 1;

        // run simulation and create events for drawing, playing sounds, etc.
        oxid.frame(&self.main_state, should_draw);

        // draw to framebuffer (from events)
        if (should_draw) {
            perf.begin(.whole_draw);
            perf.begin(.draw);
            oxid.draw(&self.main_state, &self.draw_state);
            perf.end(.draw);
            perf.end(.whole_draw);
        }

        // delete events
        oxid.frameCleanup(&self.main_state);
    }

    sdl.SDL_RenderPresent(self.renderer);

    sdl.SDL_LockAudioDevice(self.audio_device);
    if (self.main_state.fast_forward and (self.main_state.lshift or self.main_state.rshift)) {
        // 16x super fast forward
        oxid.audioSync(&self.main_state, @intToFloat(f32, self.audio_sample_rate) / 16.0);
    } else if (self.main_state.fast_forward) {
        // 4x fast forward
        oxid.audioSync(&self.main_state, @intToFloat(f32, self.audio_sample_rate) / 4.0);
    } else {
        oxid.audioSync(&self.main_state, @intToFloat(f32, self.audio_sample_rate));
    }
    sdl.SDL_UnlockAudioDevice(self.audio_device);

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
    sdl.SDL_SetWindowSize(self.window, w, h);

    // if resizing the window puts part of it off-screen, push it back on-screen
    const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
    if (display_index < 0)
        return;
    var bounds: sdl.SDL_Rect = undefined;
    if (sdl.SDL_GetDisplayUsableBounds(display_index, &bounds) < 0)
        return;

    var x: i32 = undefined;
    var y: i32 = undefined;
    sdl.SDL_GetWindowPosition(self.window, &x, &y);

    const new_x = if (x + w > bounds.x + bounds.w)
        std.math.max(bounds.x, bounds.x + bounds.w - w)
    else
        x;

    const new_y = if (y + h > bounds.y + bounds.h)
        std.math.max(bounds.y, bounds.y + bounds.h - h)
    else
        y;

    if (new_x != x or new_y != y)
        sdl.SDL_SetWindowPosition(self.window, new_x, new_y);
}

fn toggleFullscreen(self: *Main) void {
    if (self.main_state.fullscreen) {
        // disable fullscreen mode
        if (sdl.SDL_SetWindowFullscreen(self.window, 0) < 0) {
            std.log.err("Failed to disable fullscreen mode", .{});
            return;
        }
        // give the window back its original dimensions
        const swp = self.saved_window_pos.?; // this field is always set when fullscreen is true
        sdl.SDL_SetWindowSize(self.window, swp.w, swp.h);
        sdl.SDL_SetWindowPosition(self.window, swp.x, swp.y);
        self.main_state.fullscreen = false;
        self.saved_window_pos = null;
        return;
    }
    // enabling fullscreen mode. we use SDL's "fake" fullscreen mode to avoid a video mode change.
    // first get the full window dimensions to use
    const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
    if (display_index < 0)
        return;
    var mode: sdl.SDL_DisplayMode = undefined;
    if (sdl.SDL_GetDesktopDisplayMode(display_index, &mode) < 0)
        return;
    const full_w = @intCast(u31, std.math.max(1, mode.w));
    const full_h = @intCast(u31, std.math.max(1, mode.h));
    // save the current window pos and size
    const swp: SavedWindowPos = blk: {
        var x: i32 = undefined;
        var y: i32 = undefined;
        var w: i32 = undefined;
        var h: i32 = undefined;
        sdl.SDL_GetWindowPosition(self.window, &x, &y);
        sdl.SDL_GetWindowSize(self.window, &w, &h);
        break :blk .{
            .x = x,
            .y = y,
            .w = @intCast(u31, std.math.max(1, w)),
            .h = @intCast(u31, std.math.max(1, h)),
        };
    };
    // set new window size and go fullscreen
    sdl.SDL_SetWindowSize(self.window, full_w, full_h);
    if (sdl.SDL_SetWindowFullscreen(self.window, sdl.SDL_WINDOW_FULLSCREEN_DESKTOP) < 0) {
        std.log.err("Failed to enable fullscreen mode", .{});
        sdl.SDL_SetWindowSize(self.window, swp.w, swp.h); // put it back
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

fn handleSDLEvent(self: *Main, evt: sdl.SDL_Event) void {
    switch (evt.type) {
        sdl.SDL_QUIT => {
            self.quit = true;
        },
        sdl.SDL_KEYDOWN => if (evt.key.repeat == 0) {
            if (translateKey(evt.key.keysym.sym)) |key|
                inputEvent(self, .{ .key = key }, true);
        },
        sdl.SDL_KEYUP => {
            if (translateKey(evt.key.keysym.sym)) |key|
                inputEvent(self, .{ .key = key }, false);
        },
        sdl.SDL_WINDOWEVENT => {
            if (evt.window.event == sdl.SDL_WINDOWEVENT_MOVED and !self.main_state.fullscreen) {
                const display_index = sdl.SDL_GetWindowDisplayIndex(self.window);
                if (self.display_index != display_index) {
                    // window moved to another display
                    self.display_index = display_index;
                    // update max_canvas_scale based on the new display's dimensions.
                    // (the current canvas scale won't change, but the user won't be
                    // able to increase it beyond the new maximum.)
                    var bounds: sdl.SDL_Rect = undefined;
                    if (sdl.SDL_GetDisplayUsableBounds(display_index, &bounds) >= 0) {
                        const w = @intCast(u31, std.math.max(1, bounds.w));
                        const h = @intCast(u31, std.math.max(1, bounds.h));
                        self.main_state.max_canvas_scale = getMaxCanvasScale(w, h);
                    }
                }
            }
        },
        else => {},
    }
}
