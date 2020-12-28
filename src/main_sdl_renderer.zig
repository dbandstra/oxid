usingnamespace @import("platform/sdl.zig");
const translateKey = @import("platform/sdl_keys.zig").translateKey;
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const zang = @import("zang");
const InputSource = @import("common/key.zig").InputSource;
const game = @import("oxid/game.zig");
const audio = @import("oxid/audio.zig");
const perf = @import("oxid/perf.zig");
const config = @import("oxid/config.zig");
const common = @import("oxid_common.zig");

// drivers that other source files can access via @import("root")
pub const passets = @import("platform/assets_native.zig");
pub const pdraw = @import("platform/draw_sdl.zig");
pub const plog = @import("platform/log_native.zig");
pub const pstorage_dirname = "Oxid";
pub const pstorage = @import("platform/storage_native.zig");

pub const storagekey_config = "config.json";
pub const storagekey_highscores = "highscore.dat";

const Main = struct {
    main_state: common.MainState,
    draw_state: pdraw.State,
    window: *SDL_Window,
    renderer: *SDL_Renderer,
    audio_sample_rate: usize,
    audio_device: SDL_AudioDeviceID,
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

    const window = SDL_CreateWindow(
        "Oxid",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        common.vwin_w,
        common.vwin_h,
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

    self.window = window;
    self.renderer = renderer;

    const audio_sample_rate = 44100;
    const audio_buffer_size = 1024;

    var want: SDL_AudioSpec = undefined;
    want.freq = audio_sample_rate;
    want.format = AUDIO_S16LSB;
    want.channels = 1;
    want.samples = audio_buffer_size;
    want.callback = audioCallback;
    want.userdata = &self.main_state.audio_module;

    // TODO - allow SDL to pick something different?
    const device: SDL_AudioDeviceID = SDL_OpenAudioDevice(
        0, // device name (NULL)
        0, // non-zero to open for recording instead of playback
        &want, // desired output format
        0, // obtained output format (NULL)
        0, // allowed changes: 0 means `obtained` will not differ from `want`, and SDL will do any necessary resampling behind the scenes
    );
    if (device == 0) {
        std.debug.warn("Failed to open audio: {s}\n", .{SDL_GetError()});
        return error.Failed;
    }
    errdefer SDL_CloseAudioDevice(device);

    pdraw.init(&self.draw_state, renderer);

    try common.init(&self.main_state, &self.draw_state, .{
        .hunk = hunk,
        .random_seed = @intCast(u32, std.time.milliTimestamp() & 0xFFFFFFFF),
        .audio_buffer_size = audio_buffer_size,
        .audio_sample_rate = audio_sample_rate,
        .fullscreen = false,
        .canvas_scale = 1,
        .max_canvas_scale = 1,
        .sound_enabled = true,
    }); // common.init prints its own error and returns error.Failed
    errdefer common.deinit(&self.main_state);

    self.audio_sample_rate = audio_sample_rate;
    self.audio_device = device;
    self.quit = false;

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
    common.deinit(&self.main_state);
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

    common.frame(&self.main_state, .{
        .spawn_draw_events = true,
        .friendly_fire = self.main_state.friendly_fire,
    });

    perf.begin(.whole_draw);
    perf.begin(.draw);
    common.drawMain(&self.main_state, &self.draw_state);
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

    perf.display();
}

fn inputEvent(self: *Main, source: InputSource, down: bool) void {
    switch (common.inputEvent(&self.main_state, source, down) orelse return) {
        .noop => {},
        .quit => self.quit = true,
        .toggle_sound => {}, // unused
        .toggle_fullscreen => {}, // unused
        .set_canvas_scale => {}, // unused
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
        SDL_QUIT => self.quit = true,
        else => {},
    }
}
