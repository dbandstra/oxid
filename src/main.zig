const std = @import("std");
const assert = std.debug.assert;
const c = @import("c.zig");
const debug_gl = @import("debug_gl.zig");
use @import("math3d.zig");
const all_shaders = @import("all_shaders.zig");
const static_geometry = @import("static_geometry.zig");

const DoubleStackAllocatorFlat = @import("../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const Image = @import("../zigutils/src/image/image.zig").Image;
const ImageFormat = @import("../zigutils/src/image/image.zig").ImageFormat;

const Graphics = @import("graphics.zig").Graphics;
const load_graphics = @import("graphics.zig").load_graphics;

const GRIDSIZE_PIXELS = @import("game_level.zig").GRIDSIZE_PIXELS;
const LEVEL = @import("game_level.zig").LEVEL;
const GameInput = @import("game.zig").GameInput;
const GameSession = @import("game.zig").GameSession;
const InputEvent = @import("game.zig").InputEvent;
const MonsterType = @import("game_init.zig").MonsterType;
const game_init = @import("game_init.zig").game_init;
const game_spawn_monsters = @import("game_init.zig").game_spawn_monsters;
const game_frame = @import("game_frame.zig").game_frame;
const game_input = @import("game.zig").game_input;
const game_draw = @import("game_draw.zig").game_draw;

// See https://github.com/zig-lang/zig/issues/565
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
// SDL_video.h:#define SDL_WINDOWPOS_UNDEFINED_MASK    0x1FFF0000u
const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

extern fn SDL_PollEvent(event: *c.SDL_Event) c_int;

// size of the virtual screen
pub const GAME_W = LEVEL.w * GRIDSIZE_PIXELS; // 320
pub const GAME_H = LEVEL.h * GRIDSIZE_PIXELS; // 224

// size of the system window (virtual screen will be scaled to this)
const WINDOW_W = 1280;
const WINDOW_H = 896;

var dsaf_buffer: [200*1024]u8 = undefined;
var dsaf_ = DoubleStackAllocatorFlat.init(dsaf_buffer[0..]);
const dsaf = &dsaf_;

pub const GameState = struct {
  shaders: all_shaders.AllShaders,
  static_geometry: static_geometry.StaticGeometry,
  projection: Mat4x4,
  graphics: Graphics,
  session: GameSession,
  render_move_boxes: bool,
  paused: bool,
  fast_forward: bool,
};
pub var game_state: GameState = undefined;

pub const Texture = struct{
  handle: c.GLuint,
};

pub fn upload_texture(image: *const Image) Texture {
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
    switch (image.info.format) {
      ImageFormat.RGB => @intCast(c.GLint, c.GL_RGB),
      ImageFormat.RGBA => @intCast(c.GLint, c.GL_RGBA),
      ImageFormat.INDEXED => unreachable, // FIXME
    },
    @intCast(c.GLsizei, image.info.width), // width
    @intCast(c.GLsizei, image.info.height), // height
    0, // border
    // format
    switch (image.info.format) {
      ImageFormat.RGB => @intCast(c.GLenum, c.GL_RGB),
      ImageFormat.RGBA => @intCast(c.GLenum, c.GL_RGBA),
      ImageFormat.INDEXED => unreachable, // FIXME
    },
    c.GL_UNSIGNED_BYTE, // type
    @ptrCast(*const c_void, &image.pixels[0]), // data
  );
  return Texture{
    .handle = texid,
  };
}

pub fn main() !void {
  if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
    c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  }
  defer c.SDL_Quit();

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
    WINDOW_W, WINDOW_H,
    c.SDL_WINDOW_OPENGL,
  ) orelse {
    c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  };
  defer c.SDL_DestroyWindow(window);

  const glcontext = c.SDL_GL_CreateContext(window) orelse {
    c.SDL_Log(c"SDL_GL_CreateContext failed: %s", c.SDL_GetError());
    return error.SDLInitializationFailed;
  };
  defer c.SDL_GL_DeleteContext(glcontext);

  _ = c.SDL_GL_MakeCurrent(window, glcontext);

  const g = &game_state;
  g.render_move_boxes = false;
  g.paused = false;
  g.fast_forward = false;
  g.session = GameSession.init();
  game_init(&g.session);

  g.shaders = try all_shaders.createAllShaders();
  defer g.shaders.destroy();

  g.static_geometry = static_geometry.createStaticGeometry();
  defer g.static_geometry.destroy();

  try load_graphics(dsaf, &g.graphics);

  var fb: c.GLuint = 0;
  c.glGenFramebuffers(1, c.ptr(&fb));
  c.glBindFramebuffer(c.GL_FRAMEBUFFER, fb);

  var rt: c.GLuint = 0;
  c.glGenTextures(1, c.ptr(&rt));
  c.glBindTexture(c.GL_TEXTURE_2D, rt);
  c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @intCast(c_int, GAME_W), @intCast(c_int, GAME_H), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, @intToPtr(*const c_void, 0));
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
  c.glClearColor(
    @intToFloat(f32, g.graphics.background_colour.r) / 255.0,
    @intToFloat(f32, g.graphics.background_colour.g) / 255.0,
    @intToFloat(f32, g.graphics.background_colour.b) / 255.0,
    0,
  );

  debug_gl.assertNoError();

  var quit = false;
  while (!quit) {
    var event: c.SDL_Event = undefined;
    while (SDL_PollEvent(&event) != 0) {
      switch (event.type) {
        c.SDL_KEYDOWN => {
          if (event.key.repeat != 0) {
            break;
          }
          switch (event.key.keysym.sym) {
            c.SDLK_ESCAPE => return,
            c.SDLK_BACKSPACE => {
              g.session = GameSession.init();
              game_init(&g.session);
            },
            c.SDLK_RETURN => {
              game_spawn_monsters(&g.session, 8, MonsterType.Spider);
            },
            c.SDLK_F2 => {
              g.render_move_boxes = !g.render_move_boxes;
            },
            c.SDLK_F3 => {
              g.session.god_mode = !g.session.god_mode;
              std.debug.warn("god mode {}\n", if (g.session.god_mode) "enabled" else "disabled");
            },
            c.SDLK_UP => game_input(&g.session, InputEvent.Up, true),
            c.SDLK_DOWN => game_input(&g.session, InputEvent.Down, true),
            c.SDLK_LEFT => game_input(&g.session, InputEvent.Left, true),
            c.SDLK_RIGHT => game_input(&g.session, InputEvent.Right, true),
            c.SDLK_SPACE => game_input(&g.session, InputEvent.Shoot, true),
            c.SDLK_TAB => {
              g.paused = !g.paused;
            },
            c.SDLK_BACKQUOTE => {
              g.fast_forward = true;
            },
            else => {},
          }
        },
        c.SDL_KEYUP => {
          switch (event.key.keysym.sym) {
            c.SDLK_UP => game_input(&g.session, InputEvent.Up, false),
            c.SDLK_DOWN => game_input(&g.session, InputEvent.Down, false),
            c.SDLK_LEFT => game_input(&g.session, InputEvent.Left, false),
            c.SDLK_RIGHT => game_input(&g.session, InputEvent.Right, false),
            c.SDLK_SPACE => game_input(&g.session, InputEvent.Shoot, false),
            c.SDLK_BACKQUOTE => {
              g.fast_forward = false;
            },
            else => {},
          }
        },
        c.SDL_QUIT => {
          quit = true;
        },
        else => {},
      }
    }

    if (!g.paused) {
      const n = if (g.fast_forward) u32(4) else u32(1);
      var i: u32 = 0;
      while (i < n) : (i += 1) {
        game_frame(&g.session);
      }
    }

    g.projection = mat4x4_ortho(0.0, @intToFloat(f32, GAME_W), @intToFloat(f32, GAME_H), 0.0);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, fb);
    c.glViewport(0, 0, @intCast(c_int, GAME_W), @intCast(c_int, GAME_H));
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    game_draw(g);

    g.projection = mat4x4_ortho(0.0, @intToFloat(f32, WINDOW_W), @intToFloat(f32, WINDOW_H), 0.0);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    c.glViewport(0, 0, WINDOW_W, WINDOW_H);
    fillRect(g, rt, 0, 0, WINDOW_W, WINDOW_H, Transform.FlipVertical);

    c.SDL_GL_SwapWindow(window);

    // FIXME - don't delay if vsync is enabled
    c.SDL_Delay(17);
  }
}

pub const Transform = enum {
  Identity,
  FlipHorizontal,
  FlipVertical,
  RotateClockwise,
  RotateCounterClockwise,
};

pub fn fillRectMvp(g: *GameState, texid: c.GLuint, mvp: *const Mat4x4, transform: Transform) void {
  g.shaders.texture.bind();
  g.shaders.texture.set_uniform_int(g.shaders.texture_uniform_tex, 0);
  g.shaders.texture.set_uniform_mat4x4(g.shaders.texture_uniform_mvp, mvp);

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
  c.glBindTexture(c.GL_TEXTURE_2D, texid);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn fillRect(g: *GameState, texid: c.GLuint, x: f32, y: f32, w: f32, h: f32, transform: Transform) void {
  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = g.projection.mult(model);
  fillRectMvp(g, texid, mvp, transform);
}

pub fn drawBox(g: *GameState, x: f32, y: f32, w: f32, h: f32, R: f32, G: f32, B: f32) void {
  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = g.projection.mult(model);

  const color = vec4(R, G, B, 1);

  g.shaders.primitive.bind();
  g.shaders.primitive.set_uniform_vec4(g.shaders.primitive_uniform_color, &color);
  g.shaders.primitive.set_uniform_mat4x4(g.shaders.primitive_uniform_mvp, mvp);

  if (g.shaders.primitive_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, g.shaders.primitive_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, g.shaders.primitive_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  c.glPolygonMode(c.GL_FRONT, c.GL_LINE);
  c.glDrawArrays(c.GL_QUAD_STRIP, 0, 4);
  c.glPolygonMode(c.GL_FRONT, c.GL_FILL);
}
