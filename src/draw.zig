use @import("math3d.zig");
const c = @import("platform/c.zig");
const Platform = @import("platform/platform.zig");
const PlatformDraw = @import("platform/draw.zig");

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
  tex_id: c.GLuint, // FIXME
  transform: Transform,
};

pub const RectStyle = union(enum) {
  Solid: SolidParams,
  Outline: OutlineParams,
  Textured: TexturedParams,
};

pub fn rect(ps: *Platform.State, x: f32, y: f32, w: f32, h: f32, style: RectStyle) void {
  // TODO - move this projection matrix stuff to platform
  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = ps.projection.mult(model);

  switch (style) {
    RectStyle.Solid => |params| {
      PlatformDraw.draw_untextured_rect_mvp(ps, mvp, params.color, false);
    },
    RectStyle.Outline => |params| {
      PlatformDraw.draw_untextured_rect_mvp(ps, mvp, params.color, true);
    },
    RectStyle.Textured => |params| {
      PlatformDraw.draw_textured_rect_mvp(ps, mvp, params.tex_id, params.transform);
    },
  }
}
