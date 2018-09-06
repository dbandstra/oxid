const std = @import("std");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const image = @import("../../zigutils/src/image/image.zig");

const Platform = @import("../platform/index.zig");
const Event = @import("../event.zig").Event;
const Key = @import("../event.zig").Key;
const Draw = @import("../draw.zig");
const Font = @import("../font.zig").Font;
const loadFont = @import("../font.zig").loadFont;
const loadTileset = @import("graphics.zig").loadTileset;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const LEVEL = @import("level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const gameInit = @import("frame.zig").gameInit;
const gameFrame = @import("frame.zig").gameFrame;
const gameFrameCleanup = @import("frame.zig").gameFrameCleanup;
const input = @import("input.zig");
const Prototypes = @import("prototypes.zig");
const drawGame = @import("draw.zig").drawGame;
const Audio = @import("audio.zig");
const perf = @import("perf.zig");

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
  font: Font,
  session: GameSession,
  perf_spam: bool,
  mute: bool,
};
pub var game_state: GameState = undefined;

pub fn main() !void {
  const g = &game_state;
  try Platform.init(&g.platform_state, Platform.InitParams{
    .window_title = "Oxid",
    .window_width = WINDOW_W,
    .window_height = WINDOW_H,
    .virtual_window_width = VWIN_W,
    .virtual_window_height = VWIN_H,
    .audio_frequency = 22050,
    .audio_buffer_size = 1024, // 4096,
    .dsaf = dsaf,
  });
  defer Platform.deinit(&g.platform_state);

  const rand_seed = blk: {
    var seed_bytes: [4]u8 = undefined;
    std.os.getRandomBytes(seed_bytes[0..]) catch {
      break :blk 0;
    };
    break :blk std.mem.readIntLE(u32, seed_bytes);
  };

  Audio.loadSamples(&g.platform_state, &g.samples);

  g.perf_spam = false;
  g.mute = false;

  g.session.init(rand_seed);
  gameInit(&g.session);

  try loadFont(dsaf, &g.font);
  try loadTileset(dsaf, &g.tileset);

  perf.init();

  var quit = false;
  while (!quit) {
    while (Platform.pollEvent(&g.platform_state)) |event| {
      switch (event) {
        Event.KeyDown => |key| {
          if (input.getCommandForKey(key)) |command| {
            _ = Prototypes.EventInput.spawn(&g.session, C.EventInput{
              .command = command,
              .down = true,
            });
          }
          switch (key) {
            Key.Escape => return,
            Key.Backspace => {
              g.session.init(rand_seed);
              gameInit(&g.session);
            },
            Key.F4 => {
              g.perf_spam = !g.perf_spam;
            },
            Key.F5 => {
              Platform.cycleGlitchMode(&g.platform_state);
              g.platform_state.clear_screen = true;
            },
            Key.M => {
              g.mute = !g.mute;
              Platform.setMute(&g.platform_state, g.mute);
            },
            else => {},
          }
        },
        Event.KeyUp => |key| {
          if (input.getCommandForKey(key)) |command| {
            _ = Prototypes.EventInput.spawn(&g.session, C.EventInput{
              .command = command,
              .down = false,
            });
          }
        },
        Event.Quit => {
          quit = true;
        },
        else => {},
      }
    }

    perf.begin(&perf.timers.Frame);
    gameFrame(&g.session);
    perf.end(&perf.timers.Frame, g.perf_spam);

    playSounds(g);
    draw(g);

    gameFrameCleanup(&g.session);
  }
}

// "middleware"

const C = @import("components.zig");

fn playSounds(g: *GameState) void {
  var it = g.session.gbe.iter(C.EventSound); while (it.next()) |object| {
    Audio.playSample(&g.platform_state, &g.samples, object.data.sample);
  }
}

fn draw(g: *GameState) void {
  perf.begin(&perf.timers.WholeDraw);
  Platform.preDraw(&g.platform_state);
  perf.begin(&perf.timers.Draw);
  drawGame(g);
  perf.end(&perf.timers.Draw, g.perf_spam);
  Platform.postDraw(&g.platform_state);
  perf.end(&perf.timers.WholeDraw, g.perf_spam);
}
