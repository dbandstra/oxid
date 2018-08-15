const std = @import("std");
const assert = std.debug.assert;
const c = @import("../platform/c.zig");
const all_shaders = @import("../platform/all_shaders.zig");
const static_geometry = @import("../platform/static_geometry.zig");

const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const image = @import("../../zigutils/src/image/image.zig");

const Platform = @import("../platform/platform.zig");
const Draw = @import("../draw.zig");
const loadTileset = @import("graphics.zig").loadTileset;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const LEVEL = @import("level.zig").LEVEL;
const GameInput = @import("game.zig").GameInput;
const GameSession = @import("game.zig").GameSession;
const InputEvent = @import("input.zig").InputEvent;
const killAllMonsters = @import("functions/kill_all_monsters.zig").killAllMonsters;
const gameInit = @import("frame.zig").gameInit;
const gamePreFrame = @import("frame.zig").gamePreFrame;
const gamePostFrame = @import("frame.zig").gamePostFrame;
const gameInput = @import("input.zig").gameInput;
const drawGame = @import("draw.zig").drawGame;
const Audio = @import("audio.zig");

// this many pixels is added to the top of the window for font stuff
pub const HUD_HEIGHT = 16;

// size of the virtual screen
pub const VWIN_W: u32 = LEVEL.w * GRIDSIZE_PIXELS; // 320
pub const VWIN_H: u32 = LEVEL.h * GRIDSIZE_PIXELS + HUD_HEIGHT; // 240

// size of the system window (virtual screen will be scaled to this)
const WINDOW_W = 1280;
const WINDOW_H = 960;

var dsaf_buffer: [200*1024]u8 = undefined;
var dsaf_ = DoubleStackAllocatorFlat.init(dsaf_buffer[0..]);
const dsaf = &dsaf_;

pub const GameState = struct {
  platform_state: Platform.State,
  samples: Audio.LoadedSamples,
  tileset: Draw.Tileset,
  session: GameSession,
  render_move_boxes: bool,
  paused: bool,
  fast_forward: bool,
};
pub var game_state: GameState = undefined;

pub fn main() !void {
  const g = &game_state;
  try Platform.init(&g.platform_state, Platform.InitParams{
    .window_width = WINDOW_W,
    .window_height = WINDOW_H,
    .virtual_window_width = VWIN_W,
    .virtual_window_height = VWIN_H,
    .dsaf = dsaf,
  });
  defer Platform.destroy(&g.platform_state);

  const rand_seed = blk: {
    var seed_bytes: [4]u8 = undefined;
    std.os.getRandomBytes(seed_bytes[0..]) catch {
      break :blk 0;
    };
    break :blk std.mem.readIntLE(u32, seed_bytes);
  };

  Audio.loadSamples(dsaf, &g.platform_state, &g.samples);

  g.render_move_boxes = false;
  g.paused = false;
  g.fast_forward = false;

  g.session.init(rand_seed);
  gameInit(&g.session);

  try loadTileset(dsaf, &g.tileset);

  var quit = false;
  while (!quit) {
    var event: c.SDL_Event = undefined;
    while (Platform.pollEvent(&g.platform_state, &event)) {
      switch (event.type) {
        c.SDL_KEYDOWN => {
          if (event.key.repeat != 0) {
            break;
          }
          switch (event.key.keysym.sym) {
            c.SDLK_ESCAPE => return,
            c.SDLK_BACKSPACE => {
              g.session.init(rand_seed);
              gameInit(&g.session);
            },
            c.SDLK_RETURN => {
              killAllMonsters(&g.session);
            },
            c.SDLK_F2 => {
              g.render_move_boxes = !g.render_move_boxes;
            },
            c.SDLK_F3 => {
              g.session.god_mode = !g.session.god_mode;
            },
            c.SDLK_UP => gameInput(&g.session, InputEvent.Up, true),
            c.SDLK_DOWN => gameInput(&g.session, InputEvent.Down, true),
            c.SDLK_LEFT => gameInput(&g.session, InputEvent.Left, true),
            c.SDLK_RIGHT => gameInput(&g.session, InputEvent.Right, true),
            c.SDLK_SPACE => gameInput(&g.session, InputEvent.Shoot, true),
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
            c.SDLK_UP => gameInput(&g.session, InputEvent.Up, false),
            c.SDLK_DOWN => gameInput(&g.session, InputEvent.Down, false),
            c.SDLK_LEFT => gameInput(&g.session, InputEvent.Left, false),
            c.SDLK_RIGHT => gameInput(&g.session, InputEvent.Right, false),
            c.SDLK_SPACE => gameInput(&g.session, InputEvent.Shoot, false),
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
        gamePreFrame(&g.session);
        playSounds(g);
        gamePostFrame(&g.session);
      }
    }

    Platform.preDraw(&g.platform_state);
    drawGame(g);
    Platform.postDraw(&g.platform_state);
  }
}

// "middleware"

const C = @import("components.zig");

fn playSounds(g: *GameState) void {
  var it = g.session.gbe.iter(C.EventSound); while (it.next()) |object| {
    Audio.playSample(&g.platform_state, &g.samples, object.data.sample);
  }
}
