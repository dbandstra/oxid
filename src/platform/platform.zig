const c = @import("c.zig");
const image = @import("../../zigutils/src/image/image.zig");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const debug_gl = @import("debug_gl.zig");
use @import("math3d.zig");
const all_shaders = @import("all_shaders.zig");
const static_geometry = @import("static_geometry.zig");
const Font = @import("font.zig").Font;
const loadFont = @import("font.zig").loadFont;
const PlatformDraw = @import("draw.zig");
const Draw = @import("../draw.zig");

// this platform file is for OpenGL + SDL2
// TODO - split into two (as much as possible)

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
  projection: Mat4x4,
  font: Font,
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

pub fn init(ps: *State, params: *const InitParams) !void {
  ps.initialized = false;

  if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
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
  const w = ps.window_width;
  const h = ps.window_height;
  const fw = @intToFloat(f32, w);
  const fh = @intToFloat(f32, h);
  ps.projection = mat4x4_ortho(0, fw, fh, 0);
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
  c.glViewport(0, 0, @intCast(c_int, w), @intCast(c_int, h));
  PlatformDraw.drawTextured(ps, ps.rt, 0, 0, fw, fh, Draw.Transform.FlipVertical);

  c.SDL_GL_SwapWindow(ps.window);

  // FIXME - try to detect if vsync is enabled...
  // c.SDL_Delay(17);
}
