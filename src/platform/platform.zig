const c = @import("c.zig");
const image = @import("../../zigutils/src/image/image.zig");
use @import("../math3d.zig");
const all_shaders = @import("all_shaders.zig");
const static_geometry = @import("static_geometry.zig");
const Font = @import("../font.zig").Font;

// this platform file is for OpenGL + SDL2
// TODO - split into two

pub const State = struct {
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

// pub fn platformInit() void {
//   if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
//     c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
//     return error.SDLInitializationFailed;
//   }
//   defer c.SDL_Quit();

//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_DOUBLEBUFFER), 1);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_BUFFER_SIZE), 32);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_RED_SIZE), 8);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_GREEN_SIZE), 8);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_BLUE_SIZE), 8);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_ALPHA_SIZE), 8);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_DEPTH_SIZE), 24);
//   _ = c.SDL_GL_SetAttribute(@intToEnum(c.SDL_GLattr, c.SDL_GL_STENCIL_SIZE), 8);

//   const window = c.SDL_CreateWindow(c"My Game Window",
//     SDL_WINDOWPOS_UNDEFINED,
//     SDL_WINDOWPOS_UNDEFINED,
//     WINDOW_W, WINDOW_H,
//     c.SDL_WINDOW_OPENGL,
//   ) orelse {
//     c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
//     return error.SDLInitializationFailed;
//   };
//   defer c.SDL_DestroyWindow(window);

//   const glcontext = c.SDL_GL_CreateContext(window) orelse {
//     c.SDL_Log(c"SDL_GL_CreateContext failed: %s", c.SDL_GetError());
//     return error.SDLInitializationFailed;
//   };
//   defer c.SDL_GL_DeleteContext(glcontext);

//   _ = c.SDL_GL_MakeCurrent(window, glcontext);
// }
