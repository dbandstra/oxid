const std = @import("std");
const c = @import("../c.zig");
const math3d = @import("math3d.zig");
const debug_gl = @import("debug_gl.zig");
const shaders = @import("shaders.zig");
const shader_primitive = @import("shader_primitive.zig");
const shader_textured = @import("shader_textured.zig");
const static_geometry = @import("static_geometry.zig");
const BUFFER_VERTICES = static_geometry.BUFFER_VERTICES;
const updateVbo = static_geometry.updateVbo;
const State = @import("../platform.zig").State;
const InitParams = @import("../platform.zig").InitParams;
const Draw = @import("../../draw.zig");

pub const GlitchMode = enum{
  Normal,
  QuadStrips,
  WholeTilesets,
};

pub fn cycleGlitchMode(ps: *State) void {
  const i = @enumToInt(ps.glitch_mode);
  const count = @memberCount(GlitchMode);
  ps.glitch_mode =
    if (i + 1 < count)
      @intToEnum(GlitchMode, i + 1)
    else
      @intToEnum(GlitchMode, 0);
}

const DrawBuffer = struct{
  active: bool,
  vertex2f: [2 * BUFFER_VERTICES]c.GLfloat,
  texcoord2f: [2 * BUFFER_VERTICES]c.GLfloat,
  num_vertices: usize,
};

pub const DrawState = struct{
  // dimensions of the system window
  window_width: u32,
  window_height: u32,
  // dimensions of the game viewport, which will be scaled up to fit the system
  // window
  virtual_window_width: u32,
  virtual_window_height: u32,
  // frame buffer object
  fb: c.GLuint,
  // render texture
  rt: c.GLuint,
  shader_primitive: shader_primitive.Shader,
  shader_textured: shader_textured.Shader,
  static_geometry: static_geometry.StaticGeometry,
  draw_buffer: DrawBuffer,
  projection: math3d.Mat4x4,
};

pub fn init(ds: *DrawState, params: InitParams, window_width: u32, window_height: u32) !void {
  const gl_version = c.glGetString(c.GL_VERSION);

  const glsl_version = blk: {
    if (gl_version) |v| {
      if (v[1] == '.') {
        if (v[0] == '2' and v[2] != '0') {
          break :blk shaders.GLSLVersion.V120;
        } else if (v[0] >= '3' and v[0] <= '9') {
          break :blk shaders.GLSLVersion.V130;
        }
      }
    }
    std.debug.warn("Unsupported OpenGL version: {s}\n", gl_version);
    return error.OpenGLVersionError;
  };

  ds.shader_primitive = try shader_primitive.create(&params.dsa.low_stack, glsl_version);
  errdefer shaders.destroy(ds.shader_primitive.program);
  ds.shader_textured = try shader_textured.create(&params.dsa.low_stack, glsl_version);
  errdefer shaders.destroy(ds.shader_textured.program);

  ds.static_geometry = static_geometry.createStaticGeometry();
  errdefer ds.static_geometry.destroy();

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
    std.debug.warn("initDraw: failed to create framebuffer\n");
    return error.InitDrawFailed;
  }

  c.glDisable(c.GL_DEPTH_TEST);
  c.glEnable(c.GL_CULL_FACE);
  c.glFrontFace(c.GL_CCW);
  c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
  c.glEnable(c.GL_BLEND);

  debug_gl.assertNoError();

  ds.window_width = window_width;
  ds.window_height = window_height;
  ds.virtual_window_width = params.virtual_window_width;
  ds.virtual_window_height = params.virtual_window_height;
  ds.fb = fb;
  ds.rt = rt;
  ds.draw_buffer.num_vertices = 0;
}

pub fn deinit(ds: *DrawState) void {
  ds.static_geometry.destroy();
  shaders.destroy(ds.shader_primitive.program);
  shaders.destroy(ds.shader_textured.program);
}

pub fn preDraw(ds: *DrawState, clear_screen: bool) void {
  const w = ds.virtual_window_width;
  const h = ds.virtual_window_height;
  const fw = @intToFloat(f32, w);
  const fh = @intToFloat(f32, h);
  ds.projection = math3d.mat4x4_ortho(0, fw, fh, 0);
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, ds.fb);
  c.glViewport(0, 0, @intCast(c_int, w), @intCast(c_int, h));
  if (clear_screen) {
    c.glClearColor(0, 0, 0, 0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
  }
}

pub fn postDraw(ds: *DrawState, blit_alpha: f32) void {
  ds.projection = math3d.mat4x4_ortho(0, 1, 1, 0);
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
  c.glViewport(0, 0, @intCast(c_int, ds.window_width), @intCast(c_int, ds.window_height));
  blit(ds, ds.rt, blit_alpha);
}

// this function must be called outside begin/end
pub fn blit(ds: *DrawState, tex_id: c.GLuint, alpha: f32) void {
  std.debug.assert(!ds.draw_buffer.active);

  ds.shader_textured.bind(shader_textured.BindParams{
    .tex = 0,
    .mvp = &ds.projection,
    .alpha = alpha,
    .vertex_buffer = ds.static_geometry.rect_2d_vertex_buffer,
    .texcoord_buffer = ds.static_geometry.rect_2d_blit_texcoord_buffer,
  });

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

// the following functions take PlatformState instead of DrawState, because
// they are exposed outside the platform/ folder (DrawState is internal).

// this function must be called outside begin/end
pub fn untexturedRect(ps: *State, x: f32, y: f32, w: f32, h: f32, color: Draw.Color, outline: bool) void {
  const ds = &ps.draw_state;

  std.debug.assert(!ds.draw_buffer.active);

  const model = math3d.mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = ds.projection.mult(&model);

  ds.shader_primitive.bind(shader_primitive.BindParams{
    .color = [4]f32{
      @intToFloat(f32, color.r) / 255.0,
      @intToFloat(f32, color.g) / 255.0,
      @intToFloat(f32, color.b) / 255.0,
      @intToFloat(f32, color.a) / 255.0,
    },
    .mvp = &mvp,
    .vertex_buffer = ds.static_geometry.rect_2d_vertex_buffer,
  });

  if (outline) {
    c.glPolygonMode(c.GL_FRONT, c.GL_LINE);
    c.glDrawArrays(c.GL_QUAD_STRIP, 0, 4);
    c.glPolygonMode(c.GL_FRONT, c.GL_FILL);
  } else {
    c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
  }
}

pub fn begin(ps: *State, tex_id: c.GLuint) void {
  const ds = &ps.draw_state;

  std.debug.assert(!ds.draw_buffer.active);
  std.debug.assert(ds.draw_buffer.num_vertices == 0);

  ds.shader_textured.bind(shader_textured.BindParams{
    .tex = 0,
    .alpha = 1.0,
    .mvp = &ds.projection,
    .vertex_buffer = null,
    .texcoord_buffer = null,
  });

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

  ds.draw_buffer.active = true;
}

pub fn end(ps: *State) void {
  const ds = &ps.draw_state;

  std.debug.assert(ds.draw_buffer.active);

  flush(ps);

  ds.draw_buffer.active = false;
}

pub fn tile(
  ps: *State,
  tileset: *const Draw.Tileset,
  dtile: Draw.Tile,
  x0: f32, y0: f32, w: f32, h: f32,
  transform: Draw.Transform,
) void {
  const ds = &ps.draw_state;

  std.debug.assert(ds.draw_buffer.active);
  const x1 = x0 + w;
  const y1 = y0 + h;
  if (dtile.tx >= tileset.xtiles or dtile.ty >= tileset.ytiles) {
    return;
  }
  var s0 = @intToFloat(f32, dtile.tx) / @intToFloat(f32, tileset.xtiles);
  var t0 = @intToFloat(f32, dtile.ty) / @intToFloat(f32, tileset.ytiles);
  var s1 = s0 + 1 / @intToFloat(f32, tileset.xtiles);
  var t1 = t0 + 1 / @intToFloat(f32, tileset.ytiles);

  if (ps.glitch_mode == GlitchMode.WholeTilesets) {
    // draw the whole tileset scaled down. with transparency this leads to
    // smearing. it's interesting how the level itself is "hidden" to begin
    // with
    s0 = 0;
    t0 = 0;
    s1 = 1;
    t1 = 1;
  }

  if (ds.draw_buffer.num_vertices + 4 > BUFFER_VERTICES) {
    flush(ps);
  }
  const num_vertices = ds.draw_buffer.num_vertices;
  std.debug.assert(num_vertices + 4 <= BUFFER_VERTICES);

  const vertex2f = ds.draw_buffer.vertex2f[num_vertices * 2..(num_vertices + 4) * 2];
  const texcoord2f = ds.draw_buffer.texcoord2f[num_vertices * 2..(num_vertices + 4) * 2];

  // top left, bottom left, bottom right, top right
  std.mem.copy(
    c.GLfloat,
    vertex2f,
    [8]c.GLfloat{x0, y0, x0, y1, x1, y1, x1, y0},
  );
  std.mem.copy(
    c.GLfloat,
    texcoord2f,
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

  if (ps.glitch_mode == GlitchMode.QuadStrips) {
    // swap last two vertices so that the order becomes top left, bottom left,
    // top right, bottom right (suitable for quad strips rather than individual
    // quads)
    std.mem.swap(c.GLfloat, &vertex2f[4], &vertex2f[6]);
    std.mem.swap(c.GLfloat, &vertex2f[5], &vertex2f[7]);
    std.mem.swap(c.GLfloat, &texcoord2f[4], &texcoord2f[6]);
    std.mem.swap(c.GLfloat, &texcoord2f[5], &texcoord2f[7]);
  }

  ds.draw_buffer.num_vertices = num_vertices + 4;
}

fn flush(ps: *State) void {
  const ds = &ps.draw_state;

  if (ds.draw_buffer.num_vertices == 0) {
    return;
  }

  ds.shader_textured.update(shader_textured.UpdateParams{
    .vertex_buffer = ds.static_geometry.dyn_vertex_buffer,
    .vertex2f = ds.draw_buffer.vertex2f[0..],
    .texcoord_buffer = ds.static_geometry.dyn_texcoord_buffer,
    .texcoord2f = ds.draw_buffer.texcoord2f[0..],
  });

  c.glDrawArrays(
    if (ps.glitch_mode == GlitchMode.QuadStrips)
      c.GLenum(c.GL_QUAD_STRIP)
    else
      c.GLenum(c.GL_QUADS),
    0,
    @intCast(c_int, ds.draw_buffer.num_vertices),
  );

  ds.draw_buffer.num_vertices = 0;
}
