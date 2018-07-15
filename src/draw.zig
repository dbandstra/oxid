const c = @import("c.zig");
use @import("math3d.zig");
const GameState = @import("main.zig").GameState;

pub const Transform = enum {
  Identity,
  FlipHorizontal,
  FlipVertical,
  RotateClockwise,
  RotateCounterClockwise,
};

pub const SolidParams = struct {
  color: Vec4,
};

pub const OutlineParams = struct {
  color: Vec4,
};

pub const TexturedParams = struct {
  tex_id: c.GLuint,
  transform: Transform,
};

pub const RectStyle = union(enum) {
  Solid: SolidParams,
  Outline: OutlineParams,
  Textured: TexturedParams,
};

pub fn rect(g: *GameState, x: f32, y: f32, w: f32, h: f32, style: RectStyle) void {
  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = g.projection.mult(model);

  switch (style) {
    RectStyle.Solid => |params| {
      draw_untextured_rect_mvp(g, mvp, params.color, false);
    },
    RectStyle.Outline => |params| {
      draw_untextured_rect_mvp(g, mvp, params.color, true);
    },
    RectStyle.Textured => |params| {
      draw_textured_rect_mvp(g, mvp, params.tex_id, params.transform);
    },
  }
}

fn draw_untextured_rect_mvp(g: *GameState, mvp: *const Mat4x4, color: Vec4, outline: bool) void {
  g.shaders.primitive.bind();
  g.shaders.primitive.set_uniform_vec4(g.shaders.primitive_uniform_color, &color);
  g.shaders.primitive.set_uniform_mat4x4(g.shaders.primitive_uniform_mvp, mvp);

  if (g.shaders.primitive_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, g.shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, g.shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  if (outline) {
    c.glPolygonMode(c.GL_FRONT, c.GL_LINE);
    c.glDrawArrays(c.GL_QUAD_STRIP, 0, 4);
    c.glPolygonMode(c.GL_FRONT, c.GL_FILL);
  } else {
    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
  }
}

fn draw_textured_rect_mvp(g: *GameState, mvp: *const Mat4x4, tex_id: c.GLuint, transform: Transform) void {
  g.shaders.texture.bind();
  g.shaders.texture.set_uniform_int(g.shaders.texture_uniform_tex, 0);
  g.shaders.texture.set_uniform_mat4x4(g.shaders.texture_uniform_mvp, mvp);
  g.shaders.texture.set_uniform_vec2(g.shaders.texture_uniform_region_pos, 0, 0);
  g.shaders.texture.set_uniform_vec2(g.shaders.texture_uniform_region_dims, 1, 1);

  if (g.shaders.texture_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, g.shaders.texture_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, g.shaders.texture_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  if (g.shaders.texture_attrib_tex_coord >= 0) { // ?
    switch (transform) {
      Transform.Identity => c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_tex_coord_buffer_normal),
      Transform.FlipHorizontal => c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_tex_coord_buffer_flip_horizontal),
      Transform.FlipVertical => c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_tex_coord_buffer_flip_vertical),
      Transform.RotateClockwise => c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_tex_coord_buffer_rotate_clockwise),
      Transform.RotateCounterClockwise => c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_tex_coord_buffer_rotate_counter_clockwise),
    }
    c.glEnableVertexAttribArray(@intCast(c.GLuint, g.shaders.texture_attrib_tex_coord));
    c.glVertexAttribPointer(@intCast(c.GLuint, g.shaders.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}
