use @import("math3d.zig");
const c = @import("c.zig");
const Platform = @import("platform.zig");
const Draw = @import("../draw.zig");

fn drawUntexturedRectMvp(ps: *Platform.State, mvp: *const Mat4x4, color: Vec4, outline: bool) void {
  ps.shaders.primitive.bind();
  ps.shaders.primitive.setUniformVec4(ps.shaders.primitive_uniform_color, &color);
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

fn drawTexturedRectMvp(ps: *Platform.State, mvp: *const Mat4x4, tex_id: c.GLuint, transform: Draw.Transform) void {
  ps.shaders.texture.bind();
  ps.shaders.texture.setUniformInt(ps.shaders.texture_uniform_tex, 0);
  ps.shaders.texture.setUniformMat4x4(ps.shaders.texture_uniform_mvp, mvp);
  ps.shaders.texture.setUniformVec2(ps.shaders.texture_uniform_region_pos, 0, 0);
  ps.shaders.texture.setUniformVec2(ps.shaders.texture_uniform_region_dims, 1, 1);

  if (ps.shaders.texture_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  if (ps.shaders.texture_attrib_tex_coord >= 0) { // ?
    switch (transform) {
      Draw.Transform.Identity => c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_tex_coord_buffer_normal),
      Draw.Transform.FlipHorizontal => c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_tex_coord_buffer_flip_horizontal),
      Draw.Transform.FlipVertical => c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_tex_coord_buffer_flip_vertical),
      Draw.Transform.RotateClockwise => c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_tex_coord_buffer_rotate_clockwise),
      Draw.Transform.RotateCounterClockwise => c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_tex_coord_buffer_rotate_counter_clockwise),
    }
    c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord));
    c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn rect(ps: *Platform.State, x: f32, y: f32, w: f32, h: f32, style: Draw.RectStyle) void {
  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = ps.projection.mult(model);

  switch (style) {
    Draw.RectStyle.Solid => |params| {
      drawUntexturedRectMvp(ps, mvp, params.color, false);
    },
    Draw.RectStyle.Outline => |params| {
      drawUntexturedRectMvp(ps, mvp, params.color, true);
    },
    Draw.RectStyle.Textured => |params| {
      drawTexturedRectMvp(ps, mvp, params.tex_id, params.transform);
    },
  }
}
