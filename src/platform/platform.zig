const std = @import("std");
const c = @import("c.zig");
const image = @import("../../zigutils/src/image/image.zig");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const Seekable = @import("../../zigutils/src/traits/Seekable.zig").Seekable;
const debug_gl = @import("debug_gl.zig");
use @import("math3d.zig");
const RWops = @import("rwops.zig").RWops;
const all_shaders = @import("all_shaders.zig");
const static_geometry = @import("static_geometry.zig");
const Font = @import("font.zig").Font;
const loadFont = @import("font.zig").loadFont;
const PlatformDraw = @import("draw.zig");
const Draw = @import("../draw.zig");

// this platform file is for OpenGL + SDL2
// TODO - split into two (as much as possible)

const MAX_CHUNKS = 20;

pub const State = struct {
  initialized: bool,
  window: *c.SDL_Window,
  glcontext: c.SDL_GLContext,
  fb: c.GLuint,
  rt: c.GLuint,
  window_width: u32,
  window_height: u32,
  virtual_window_width: u32,
  virtual_window_height: u32,
  shaders: all_shaders.AllShaders,
  static_geometry: static_geometry.StaticGeometry,
  draw_buffer: PlatformDraw.DrawBuffer,
  projection: Mat4x4,
  font: Font,
  chunks: [MAX_CHUNKS][*]c.Mix_Chunk,
  num_chunks: u32,
};

pub const Texture = struct{
  handle: c.GLuint,
};

pub fn uploadTexture(img: *const image.Image) Texture {
  if (img.info.format == image.Format.INDEXED) {
    @panic("uploadTexture does not work on indexed-color images");
  }
  var texid: c.GLuint = undefined;
  c.glGenTextures(1, c.ptr(&texid));
  c.glBindTexture(c.GL_TEXTURE_2D, texid);
  c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
  c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
  c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
  c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
  c.glPixelStorei(c.GL_PACK_ALIGNMENT, 4);
  c.glTexImage2D(
    c.GL_TEXTURE_2D, // target
    0, // level
    // internalFormat
    switch (img.info.format) {
      image.Format.RGB => @intCast(c.GLint, c.GL_RGB),
      image.Format.RGBA => @intCast(c.GLint, c.GL_RGBA),
      image.Format.INDEXED => unreachable, // FIXME
    },
    @intCast(c.GLsizei, img.info.width), // width
    @intCast(c.GLsizei, img.info.height), // height
    0, // border
    // format
    switch (img.info.format) {
      image.Format.RGB => @intCast(c.GLenum, c.GL_RGB),
      image.Format.RGBA => @intCast(c.GLenum, c.GL_RGBA),
      image.Format.INDEXED => unreachable, // FIXME
    },
    c.GL_UNSIGNED_BYTE, // type
    @ptrCast(*const c_void, &img.pixels[0]), // data
  );
  return Texture{
    .handle = texid,
  };
}

// See https://github.com/zig-lang/zig/issues/565
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_MASK    0x1FFF0000u
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

extern fn SDL_PollEvent(event: *c.SDL_Event) c_int;

pub const InitParams = struct{
  // window_title: []const u8,
  // dimensions of the system window
  window_width: u32,
  window_height: u32,
  // dimensions of the game viewport, which will be scaled up to fit the system
  // window
  virtual_window_width: u32,
  virtual_window_height: u32,
  // allocator (only used for temporary allocations during init)
  dsaf: *DoubleStackAllocatorFlat,
};

// note: handle 0 is null/empty.
// handle 1 refers to chunks[0], etc.
pub fn loadSound(
  ps: *State,
  comptime ReadError: type,
  stream: *std.io.InStream(ReadError),
  seekable: *Seekable,
) u32 {
  if (ps.num_chunks == MAX_CHUNKS) {
    c.SDL_Log(c"no slots free to load sound");
    return 0;
  }
  var rwops = RWops(ReadError).create(stream, seekable);
  var rwops_ptr = @ptrCast([*]c.SDL_RWops, &rwops);
  const chunk = c.Mix_LoadWAV_RW(rwops_ptr, 0) orelse {
    c.SDL_Log(c"Mix_LoadWAV failed: %s", c.Mix_GetError());
    return 0;
  };
  ps.chunks[ps.num_chunks] = chunk;
  ps.num_chunks += 1;
  return ps.num_chunks;
}

pub fn playSound(ps: *State, handle: u32) void {
  const channel = -1;
  const loops = 0;
  const ticks = -1;
  if (handle > 0 and handle <= ps.num_chunks) {
    const chunk = ps.chunks[handle - 1];
    _ = c.Mix_PlayChannelTimed(channel, chunk, loops, ticks);
  }
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

  const window = c.SDL_CreateWindow(c"My Game Window",
    SDL_WINDOWPOS_UNDEFINED,
    SDL_WINDOWPOS_UNDEFINED,
    @intCast(c_int, params.window_width),
    @intCast(c_int, params.window_height),
    c.SDL_WINDOW_OPENGL,
  ) orelse {
    c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  };
  errdefer c.SDL_DestroyWindow(window);

  // 4096
  if (c.Mix_OpenAudio(22050, c.MIX_DEFAULT_FORMAT, 1, 1024) == -1) {
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

  ps.shaders = try all_shaders.createAllShaders();
  errdefer ps.shaders.destroy();

  ps.static_geometry = static_geometry.createStaticGeometry();
  errdefer ps.static_geometry.destroy();

  try loadFont(params.dsaf, &ps.font);

  var fb: c.GLuint = 0;
  c.glGenFramebuffers(1, c.ptr(&fb));
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, fb);

  var rt: c.GLuint = 0;
  c.glGenTextures(1, c.ptr(&rt));
  c.glBindTexture(c.GL_TEXTURE_2D, rt);
  c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @intCast(c_int, params.virtual_window_width), @intCast(c_int, params.virtual_window_height), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, @intToPtr(*const c_void, 0));
  c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
  c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
  c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
  c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

  c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, rt, 0);

  var draw_buffers = []c.GLenum{ c.GL_COLOR_ATTACHMENT0 };
  c.glDrawBuffers(1, c.ptr(&draw_buffers[0]));

  if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE) {
    c.SDL_Log(c"failed to create framebuffer");
    return error.SDLInitializationFailed; // not really
  }

  c.glDisable(c.GL_DEPTH_TEST);
  c.glEnable(c.GL_CULL_FACE);
  c.glFrontFace(c.GL_CCW);
  c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
  c.glEnable(c.GL_BLEND);

  debug_gl.assertNoError();

  ps.initialized = true;
  ps.window_width = params.window_width;
  ps.window_height = params.window_height;
  ps.virtual_window_width = params.virtual_window_width;
  ps.virtual_window_height = params.virtual_window_height;
  ps.window = window;
  ps.glcontext = glcontext;
  ps.draw_buffer.num_vertices = 0;
  ps.fb = fb;
  ps.rt = rt;
}

pub fn destroy(ps: *State) void {
  if (!ps.initialized) {
    return;
  }
  ps.static_geometry.destroy();
  ps.shaders.destroy();
  c.SDL_GL_DeleteContext(ps.glcontext);
  for (ps.chunks[0..ps.num_chunks]) |chunk| {
    c.Mix_FreeChunk(chunk);
  }
  c.Mix_CloseAudio();
  c.SDL_DestroyWindow(ps.window);
  c.SDL_Quit();
  ps.initialized = false;
}

pub fn pollEvent(ps: *State, out_event: *c.SDL_Event) bool {
  return SDL_PollEvent(out_event) != 0;
}

pub fn preDraw(ps: *State) void {
  const w = ps.virtual_window_width;
  const h = ps.virtual_window_height;
  const fw = @intToFloat(f32, w);
  const fh = @intToFloat(f32, h);
  ps.projection = mat4x4_ortho(0, fw, fh, 0);
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, ps.fb);
  c.glViewport(0, 0, @intCast(c_int, w), @intCast(c_int, h));
}

pub fn postDraw(ps: *State) void {
  ps.projection = mat4x4_ortho(0, 1, 1, 0);
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
  c.glViewport(0, 0, @intCast(c_int, ps.window_width), @intCast(c_int, ps.window_height));
  PlatformDraw.blit(ps, ps.rt);

  c.SDL_GL_SwapWindow(ps.window);

  // FIXME - try to detect if vsync is enabled...
  // c.SDL_Delay(17);
}
