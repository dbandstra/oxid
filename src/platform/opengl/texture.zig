const c = @import("../c.zig");
const image = @import("../../../zigutils/src/image/image.zig");

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
