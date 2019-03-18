const c = @import("../c.zig");
const Image = @import("../../load_pcx.zig").Image;

pub const Texture = struct{
  handle: c.GLuint,
};

pub fn uploadTexture(img: Image) Texture {
  var texid: c.GLuint = undefined;
  c.glGenTextures(1, &texid);
  c.glBindTexture(c.GL_TEXTURE_2D, texid);
  c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
  c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
  c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
  c.glTexParameterf(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
  c.glPixelStorei(c.GL_PACK_ALIGNMENT, 4);
  c.glTexImage2D(
    c.GL_TEXTURE_2D, // target
    0, // level
    c.GL_RGBA, // internalFormat
    @intCast(c.GLsizei, img.width), // width
    @intCast(c.GLsizei, img.height), // height
    0, // border
    c.GL_RGBA, // format
    c.GL_UNSIGNED_BYTE, // type
    &img.pixels[0], // data
  );
  return Texture{
    .handle = texid,
  };
}
