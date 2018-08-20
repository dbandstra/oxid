const std = @import("std");
const c = @import("c.zig");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const debug_gl = @import("opengl/debug_gl.zig");
const RWops = @import("rwops.zig").RWops;
const all_shaders = @import("opengl/shaders.zig");
const static_geometry = @import("opengl/static_geometry.zig");
const PlatformDraw = @import("opengl/draw.zig");
const PlatformAudio = @import("audio.zig");
const Draw = @import("../draw.zig");
const Event = @import("../event.zig").Event;
const translateEvent = @import("translate_event.zig").translateEvent;

pub const State = struct {
  initialized: bool,
  glitch_mode: PlatformDraw.GlitchMode,
  clear_screen: bool,
  window: *c.SDL_Window,
  glcontext: c.SDL_GLContext,
  window_width: u32,
  window_height: u32,
  draw_state: PlatformDraw.DrawState,
  audio_state: PlatformAudio.AudioState,
};

// See https://github.com/zig-lang/zig/issues/565
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_MASK    0x1FFF0000u
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

extern fn SDL_PollEvent(event: *c.SDL_Event) c_int;

pub const InitParams = struct{
  window_title: []const u8,
  // dimensions of the system window
  window_width: u32,
  window_height: u32,
  // dimensions of the game viewport, which will be scaled up to fit the system
  // window
  virtual_window_width: u32,
  virtual_window_height: u32,
  // audio settings
  audio_frequency: u32,
  audio_buffer_size: u32,
  // allocator (only used for temporary allocations during init)
  dsaf: *DoubleStackAllocatorFlat,
};

fn makeCString(allocator: *std.mem.Allocator, source: []const u8) ![*]const u8 {
  const bytes = try allocator.alloc(u8, source.len + 1);
  std.mem.copy(u8, bytes, source);
  bytes[source.len] = 0;
  return bytes.ptr;
}

pub fn init(ps: *State, params: *const InitParams) !void {
  ps.initialized = false;

  if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
    c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  }
  errdefer c.SDL_Quit();

  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_DOUBLEBUFFER), 1);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_BUFFER_SIZE), 32);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_RED_SIZE), 8);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_GREEN_SIZE), 8);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_BLUE_SIZE), 8);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_ALPHA_SIZE), 8);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_DEPTH_SIZE), 24);
  _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_STENCIL_SIZE), 8);

  const low_mark = params.dsaf.get_low_mark();
  const c_window_title = try makeCString(&params.dsaf.low_allocator, params.window_title);

  const window = c.SDL_CreateWindow(
    c_window_title,
    SDL_WINDOWPOS_UNDEFINED,
    SDL_WINDOWPOS_UNDEFINED,
    @intCast(c_int, params.window_width),
    @intCast(c_int, params.window_height),
    c.SDL_WINDOW_OPENGL,
  ) orelse {
    c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
    params.dsaf.free_to_low_mark(low_mark);
    return error.SDLInitializationFailed;
  };
  errdefer c.SDL_DestroyWindow(window);
  params.dsaf.free_to_low_mark(low_mark);

  if (c.Mix_OpenAudio(
    @intCast(c_int, params.audio_frequency),
    c.MIX_DEFAULT_FORMAT, // default format is 16-bit signed
    1, // num channels (1 for mono, 2 for stereo)
    @intCast(c_int, params.audio_buffer_size),
  ) == -1) {
    c.SDL_Log(c"Mix_OpenAudio failed: %s", c.Mix_GetError());
    return error.SDLInitializationFailed;
  }
  errdefer c.Mix_CloseAudio();

  const glcontext = c.SDL_GL_CreateContext(window) orelse {
    c.SDL_Log(c"SDL_GL_CreateContext failed: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  };
  errdefer c.SDL_GL_DeleteContext(glcontext);

  _ = c.SDL_GL_MakeCurrent(window, glcontext);

  try PlatformDraw.init(&ps.draw_state, params);
  errdefer PlatformDraw.deinit(&ps.draw_state);

  try PlatformAudio.init(&ps.audio_state, params);
  errdefer PlatformAudio.deinit(&ps.audio_state);

  ps.initialized = true;
  ps.glitch_mode = PlatformDraw.GlitchMode.Normal;
  ps.clear_screen = true;
  ps.window_width = params.window_width;
  ps.window_height = params.window_height;
  ps.window = window;
  ps.glcontext = glcontext;
}

pub fn deinit(ps: *State) void {
  if (!ps.initialized) {
    return;
  }
  PlatformAudio.deinit(&ps.audio_state);
  PlatformDraw.deinit(&ps.draw_state);
  c.SDL_GL_DeleteContext(ps.glcontext);
  c.Mix_CloseAudio();
  c.SDL_DestroyWindow(ps.window);
  c.SDL_Quit();
  ps.initialized = false;
}

pub fn pollEvent(ps: *State) ?Event {
  var sdl_event: c.SDL_Event = undefined;

  if (SDL_PollEvent(&sdl_event) == 0) {
    return null;
  }

  return translateEvent(sdl_event);
}

pub fn preDraw(ps: *State) void {
  PlatformDraw.preDraw(&ps.draw_state, ps.clear_screen);
  ps.clear_screen = false;
}

pub fn postDraw(ps: *State) void {
  PlatformDraw.postDraw(&ps.draw_state);

  c.SDL_GL_SwapWindow(ps.window);

  // FIXME - try to detect if vsync is enabled...
  // c.SDL_Delay(17);
}
