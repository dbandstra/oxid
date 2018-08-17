const std = @import("std");
use @import("math3d.zig");
const c = @import("c.zig");
const BUFFER_VERTICES = @import("static_geometry.zig").BUFFER_VERTICES;
const updateVbo = @import("static_geometry.zig").updateVbo;
const Platform = @import("platform.zig");
const Draw = @import("../draw.zig");

pub const DrawBuffer = struct {
  active: bool,
  vertex2f: [2 * BUFFER_VERTICES]c.GLfloat,
  texcoord2f: [2 * BUFFER_VERTICES]c.GLfloat,
  num_vertices: usize,
};

// this function must be called outside begin/end
pub fn untexturedRect(ps: *Platform.State, x: f32, y: f32, w: f32, h: f32, color: Draw.Color, outline: bool) void {
  std.debug.assert(!ps.draw_buffer.active);

  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = ps.projection.mult(model);

  const colorvec = vec4(
    @intToFloat(f32, color.r) / 255.0,
    @intToFloat(f32, color.g) / 255.0,
    @intToFloat(f32, color.b) / 255.0,
    @intToFloat(f32, color.a) / 255.0,
  );

  ps.shaders.primitive.bind();
  ps.shaders.primitive.setUniformVec4(ps.shaders.primitive_uniform_color, &colorvec);
  ps.shaders.primitive.setUniformMat4x4(ps.shaders.primitive_uniform_mvp, mvp);

  if (ps.shaders.primitive_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  if (outline) {
    c.glPolygonMode(c.GL_FRONT, c.GL_LINE);
    c.glDrawArrays(c.GL_QUAD_STRIP, 0, 4);
    c.glPolygonMode(c.GL_FRONT, c.GL_FILL);
  } else {
    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
  }
}

// this function must be called outside begin/end
pub fn blit(ps: *Platform.State, tex_id: c.GLuint) void {
  std.debug.assert(!ps.draw_buffer.active);

  ps.shaders.texture.bind();
  ps.shaders.texture.setUniformInt(ps.shaders.texture_uniform_tex, 0);
  ps.shaders.texture.setUniformMat4x4(ps.shaders.texture_uniform_mvp, ps.projection);

  c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_vertex_buffer);
  c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_position));
  c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_position), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

  c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_blit_texcoord_buffer);
  c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord));
  c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn begin(ps: *Platform.State, tex_id: c.GLuint) void {
  std.debug.assert(!ps.draw_buffer.active);
  std.debug.assert(ps.draw_buffer.num_vertices == 0);

  ps.shaders.texture.bind();
  ps.shaders.texture.setUniformInt(ps.shaders.texture_uniform_tex, 0);
  ps.shaders.texture.setUniformMat4x4(ps.shaders.texture_uniform_mvp, ps.projection);

  c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_position));
  c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord));

  c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ps.static_geometry.quad_index_buffer);

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

  ps.draw_buffer.active = true;
}

pub fn end(ps: *Platform.State) void {
  std.debug.assert(ps.draw_buffer.active);

  flush(ps);

  ps.draw_buffer.active = false;
}

pub fn tile(
  ps: *Platform.State,
  tileset: *const Draw.Tileset,
  dtile: Draw.Tile,
  x0: f32, y0: f32, w: f32, h: f32,
  transform: Draw.Transform,
) void {
  std.debug.assert(ps.draw_buffer.active);
  const x1 = x0 + w;
  const y1 = y0 + h;
  if (dtile.tx >= tileset.xtiles or dtile.ty >= tileset.ytiles) {
    return;
  }
  const s0 = @intToFloat(f32, dtile.tx) / @intToFloat(f32, tileset.xtiles);
  const t0 = @intToFloat(f32, dtile.ty) / @intToFloat(f32, tileset.ytiles);
  const s1 = s0 + 1 / @intToFloat(f32, tileset.xtiles);
  const t1 = t0 + 1 / @intToFloat(f32, tileset.ytiles);

  if (ps.draw_buffer.num_vertices + 4 > BUFFER_VERTICES) {
    flush(ps);
  }
  const num_vertices = ps.draw_buffer.num_vertices;
  std.debug.assert(num_vertices + 4 <= BUFFER_VERTICES);

  // top left, bottom left, bottom right, top right
  std.mem.copy(
    c.GLfloat,
    ps.draw_buffer.vertex2f[num_vertices * 2..(num_vertices + 4) * 2],
    [8]c.GLfloat{x0, y0, x0, y1, x1, y1, x1, y0},
  );
  std.mem.copy(
    c.GLfloat,
    ps.draw_buffer.texcoord2f[num_vertices * 2..(num_vertices + 4) * 2],
    switch (transform) {
      Draw.Transform.Identity =>
        [8]f32{s0, t0, s0, t1, s1, t1, s1, t0},
      Draw.Transform.FlipVertical =>
        [8]f32{s0, t1, s0, t0, s1, t0, s1, t1},
      Draw.Transform.FlipHorizontal =>
        [8]f32{s1, t0, s1, t1, s0, t1, s0, t0},
      Draw.Transform.RotateClockwise =>
        [8]f32{s0, t1, s1, t1, s1, t0, s0, t0},
      Draw.Transform.RotateCounterClockwise =>
        [8]f32{s1, t0, s0, t0, s0, t1, s1, t1},
    },
  );
  ps.draw_buffer.num_vertices = num_vertices + 4;
}

fn flush(ps: *Platform.State) void {
  if (ps.draw_buffer.num_vertices == 0) {
    return;
  }

  updateVbo(ps.static_geometry.dyn_vertex_buffer, ps.draw_buffer.vertex2f[0..]);
  c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_position), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
  updateVbo(ps.static_geometry.dyn_texcoord_buffer, ps.draw_buffer.texcoord2f[0..]);
  c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

  // each quad is 4 vertices but 6 elements (because they're drawn as triangles)
  const num_elements = ps.draw_buffer.num_vertices / 4 * 6;

  c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, num_elements), c.GL_UNSIGNED_INT, null);

  ps.draw_buffer.num_vertices = 0;
}
