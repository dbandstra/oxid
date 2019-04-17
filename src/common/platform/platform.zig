const builtin = @import("builtin");
const std = @import("std");
const c = @import("c.zig");
const Hunk = @import("zig-hunk").Hunk;
const debug_gl = @import("opengl/debug_gl.zig");
const all_shaders = @import("opengl/shaders.zig");
const static_geometry = @import("opengl/static_geometry.zig");
const PlatformDraw = @import("opengl/draw.zig");
const Draw = @import("../draw.zig");
const Event = @import("../event.zig").Event;
const translateEvent = @import("translate_event.zig").translateEvent;

pub const AudioCallback = fn (userdata: *c_void, out_bytes: []u8, sample_rate: u32) void;
pub const AudioUserData = struct {
  userdata: *c_void,
  sample_rate: u32,
  callback: AudioCallback,
};

pub const State = struct {
  initialized: bool,
  hunk: *Hunk,
  glitch_mode: PlatformDraw.GlitchMode,
  clear_screen: bool,
  window: *c.SDL_Window,
  glcontext: c.SDL_GLContext,
  draw_state: PlatformDraw.DrawState,
  audio_device: c.SDL_AudioDeviceID,
  audio_sample_rate: u32,
  audio_user_data: AudioUserData,
};

// See https://github.com/zig-lang/zig/issues/565
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_MASK    0x1FFF0000u
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

pub const InitParams = struct {
  window_title: []const u8,
  // dimensions of the game viewport, which will be scaled up to fit the system
  // window
  virtual_window_width: u32,
  virtual_window_height: u32,
  // the actual window size will be a multiple of the virtual window size. this
  // value puts a limit on high big it will be scaled (it will also be limited
  // by the user's screen resolution)
  max_scale: u3,
  // audio settings
  audio_sample_rate: u32,
  audio_buffer_size: u16,
  // allocators (low = temporary, high = persistent)
  hunk: *Hunk,
};

fn makeCString(allocator: *std.mem.Allocator, source: []const u8) ![*]const u8 {
  const bytes = try allocator.alloc(u8, source.len + 1);
  std.mem.copy(u8, bytes, source);
  bytes[source.len] = 0;
  return bytes.ptr;
}

extern fn platformAudioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) void {
  const ud = @ptrCast(*AudioUserData, @alignCast(@alignOf(*AudioUserData), userdata_.?));
  const stream = stream_.?[0..@intCast(usize, len_)];

  ud.callback(ud.userdata, stream, ud.sample_rate);
}

pub fn init(ps: *State, audio_userdata: var, audio_callback: var, params: InitParams) !void {
  // type check the `audio_userdata` and `audio_callback` args
  {
    const UserDataType = @typeOf(audio_userdata);
    if (@typeId(UserDataType) != builtin.TypeId.Pointer) {
      @compileError("Platform.init: `audio_userdata` must be a pointer");
    }
    const CallbackType = @typeOf(audio_callback);
    if (@typeId(CallbackType) != builtin.TypeId.Fn) {
      @compileError("Platform.init: `audio_callback` must be a function`");
    }
    const args = @typeInfo(CallbackType).Fn.args;
    if (args.len != 3) {
      @compileError("Platform.init: `audio_callback` must take 3 args");
    }
    if (if (args[0].arg_type) |at| at != UserDataType else false) {
      @compileError("Platform.init: `audio_callback` first arg must have same type as `audio_userdata`");
    }
    if (if (args[1].arg_type) |at| at != []u8 else false) {
      @compileError("Platform.init: `audio_callback` second arg must have type `[]u8`");
    }
    if (if (args[2].arg_type) |at| at != u32 else false) {
      @compileError("Platform.init: `audio_callback` third arg must have type `u32`");
    }
    if (if (@typeInfo(CallbackType).Fn.return_type) |ret| ret != void else false) {
      @compileError("Platform.init: `audio_callback` must return `void`");
    }
  }

  ps.initialized = false;

  if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
    c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  }
  errdefer c.SDL_Quit();

  var window_width = params.virtual_window_width;
  var window_height = params.virtual_window_height;

  // get the desktop resolution (for the first display)
  var dm: c.SDL_DisplayMode = undefined;

  if (c.SDL_GetDesktopDisplayMode(0, &dm) != 0) {
    std.debug.warn("Failed to query desktop display mode.\n");
  } else {
    // pick a window size that isn't bigger than the desktop resolution
    const max_w = @intCast(u32, dm.w);
    const max_h = @intCast(u32, dm.h) - 40; // bias for menubars/taskbars

    var scale: u32 = 1; while (scale <= params.max_scale) : (scale += 1) {
      const w = scale * params.virtual_window_width;
      const h = scale * params.virtual_window_height;

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

  const low_mark = params.hunk.getLowMark();
  const c_window_title = try makeCString(&params.hunk.low().allocator, params.window_title);

  const window = c.SDL_CreateWindow(
    c_window_title,
    SDL_WINDOWPOS_UNDEFINED,
    SDL_WINDOWPOS_UNDEFINED,
    @intCast(c_int, window_width),
    @intCast(c_int, window_height),
    c.SDL_WINDOW_OPENGL,
  ) orelse {
    c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
    params.hunk.freeToLowMark(low_mark);
    return error.SDLInitializationFailed;
  };
  errdefer c.SDL_DestroyWindow(window);
  params.hunk.freeToLowMark(low_mark);

  ps.audio_user_data = AudioUserData {
    .userdata = audio_userdata,
    .sample_rate = params.audio_sample_rate,
    .callback = @ptrCast(AudioCallback, audio_callback),
  };

  var want: c.SDL_AudioSpec = undefined;
  want.freq = @intCast(c_int, params.audio_sample_rate);
  want.format = c.AUDIO_S16LSB;
  want.channels = 1;
  want.samples = params.audio_buffer_size;
  want.callback = platformAudioCallback;
  want.userdata = &ps.audio_user_data;

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
    return error.SDLInitializationFailed;
  }
  errdefer c.SDL_CloseAudio();

  const glcontext = c.SDL_GL_CreateContext(window) orelse {
    c.SDL_Log(c"SDL_GL_CreateContext failed: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  };
  errdefer c.SDL_GL_DeleteContext(glcontext);

  _ = c.SDL_GL_MakeCurrent(window, glcontext);

  try PlatformDraw.init(&ps.draw_state, params, window_width, window_height);
  errdefer PlatformDraw.deinit(&ps.draw_state);

  ps.initialized = true;
  ps.hunk = params.hunk;
  ps.glitch_mode = PlatformDraw.GlitchMode.Normal;
  ps.clear_screen = true;
  ps.window = window;
  ps.glcontext = glcontext;
  ps.audio_device = device;
  ps.audio_sample_rate = params.audio_sample_rate;

  c.SDL_PauseAudioDevice(device, 0); // unpause
}

pub fn deinit(ps: *State) void {
  if (!ps.initialized) {
    return;
  }

  c.SDL_PauseAudioDevice(ps.audio_device, 1);
  c.SDL_CloseAudioDevice(ps.audio_device);

  PlatformDraw.deinit(&ps.draw_state);
  c.SDL_GL_DeleteContext(ps.glcontext);
  c.SDL_DestroyWindow(ps.window);
  c.SDL_Quit();
  ps.initialized = false;
}

pub fn pollEvent(ps: *State) ?Event {
  var sdl_event: c.SDL_Event = undefined;

  if (c.SDL_PollEvent(&sdl_event) == 0) {
    return null;
  }

  return translateEvent(sdl_event);
}

pub fn preDraw(ps: *State) void {
  PlatformDraw.preDraw(&ps.draw_state, ps.clear_screen);
  ps.clear_screen = false;
}

pub fn postDraw(ps: *State, blit_alpha: f32) void {
  PlatformDraw.postDraw(&ps.draw_state, blit_alpha);
}

pub fn swapWindow(ps: *State) void {
  c.SDL_GL_SwapWindow(ps.window);

  // FIXME - try to detect if vsync is enabled...
  // c.SDL_Delay(17);
}

pub fn lockAudio(ps: *State) void {
  c.SDL_LockAudioDevice(ps.audio_device);
}

pub fn unlockAudio(ps: *State) void {
  c.SDL_UnlockAudioDevice(ps.audio_device);
}
