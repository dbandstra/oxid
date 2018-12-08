const std = @import("std");
const DoubleStackAllocator = @import("zigutils").DoubleStackAllocator;
const image = @import("zigutils").image;

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
const datafile = @import("datafile.zig");

// this many pixels is added to the top of the window for font stuff
pub const HUD_HEIGHT = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const VWIN_W: u31 = LEVEL.w * GRIDSIZE_PIXELS; // 320
pub const VWIN_H: u31 = LEVEL.h * GRIDSIZE_PIXELS + HUD_HEIGHT; // 240

pub const GameState = struct{
  platform_state: Platform.State,
  samples: Audio.LoadedSamples,
  tileset: Draw.Tileset,
  font: Font,
  session: GameSession,
  perf_spam: bool,
  mute: bool,
};
pub var game_state: GameState = undefined;

pub fn main() void {
  var memory: [200*1024]u8 = undefined;
  var dsa = DoubleStackAllocator.init(memory[0..]);

  const g = &game_state;
  Platform.init(&g.platform_state, Platform.InitParams{
    .window_title = "Oxid",
    .virtual_window_width = VWIN_W,
    .virtual_window_height = VWIN_H,
    .max_scale = 4,
    .audio_frequency = 44100,
    .audio_buffer_size = 1024,
    .dsa = &dsa,
  }) catch |err| {
    // this causes runaway allocation in the compiler!
    // https://github.com/ziglang/zig/issues/1753
    // std.debug.warn("Platform.init failed: {}.\n", err);
    std.debug.warn("Platform init failed.\n");
    return;
  };
  defer Platform.deinit(&g.platform_state);

  const rand_seed = blk: {
    var seed_bytes: [4]u8 = undefined;
    std.os.getRandomBytes(seed_bytes[0..]) catch {
      break :blk 0;
    };
    break :blk std.mem.readIntLE(u32, seed_bytes);
  };

  // TODO - is it really a good idea to set high score to 0 if it failed to
  // load? i think we should disable high score functionality for this session
  // instead. otherwise the real high score could get overwritten by a lower
  // score.
  const initial_high_score = datafile.loadHighScore(&dsa.low_stack) catch |err| blk: {
    std.debug.warn("Failed to load high score from disk: {}.\n", err);
    break :blk 0;
  };

  loadFont(&dsa.low_stack, &g.font) catch |err| {
    std.debug.warn("Failed to load font.\n"); // TODO - print error (see above)
    return;
  };

  loadTileset(&dsa.low_stack, &g.tileset) catch |err| {
    std.debug.warn("Failed to load tileset.\n"); // TODO - print error (see above)
    return;
  };

  Audio.loadSamples(&g.platform_state, &g.samples);

  g.perf_spam = false;
  g.mute = false;

  g.session.init(rand_seed);
  gameInit(&g.session, initial_high_score);

  perf.init();

  var fast_forward = false;

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
            Key.Backquote => {
              fast_forward = true;
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
          switch (key) {
            Key.Backquote => {
              fast_forward = false;
            },
            else => {},
          }
        },
        Event.Quit => {
          quit = true;
        },
        else => {},
      }
    }

    const num_frames = if (fast_forward) usize(4) else usize(1);
    var i: usize = 0; while (i < num_frames) : (i += 1) {
      perf.begin(&perf.timers.Frame);
      gameFrame(&g.session);
      perf.end(&perf.timers.Frame, g.perf_spam);

      if (g.session.findFirst(C.EventQuit) != null) {
        quit = true;
        break;
      }

      saveHighScore(g);
      playSounds(g);
      draw(g, 1.0 / @intToFloat(f32, i + 1));

      gameFrameCleanup(&g.session);
    }

    Platform.swapWindow(&g.platform_state);
    Platform.incrementTickCount(&g.platform_state, num_frames);
  }
}

// "middleware"

const C = @import("components.zig");

fn saveHighScore(g: *GameState) void {
  var it = g.session.iter(C.EventSaveHighScore); while (it.next()) |object| {
    datafile.saveHighScore(&g.platform_state.dsa.low_stack, object.data.high_score) catch |err| {
      std.debug.warn("Failed to save high score to disk: {}\n", err);
    };
  }
}

fn playSounds(g: *GameState) void {
  var it = g.session.iter(C.EventSound); while (it.next()) |object| {
    Audio.playSample(&g.platform_state, &g.samples, object.data.sample);
  }
}

fn draw(g: *GameState, blit_alpha: f32) void {
  perf.begin(&perf.timers.WholeDraw);
  Platform.preDraw(&g.platform_state);
  perf.begin(&perf.timers.Draw);
  drawGame(g);
  perf.end(&perf.timers.Draw, g.perf_spam);
  Platform.postDraw(&g.platform_state, blit_alpha);
  perf.end(&perf.timers.WholeDraw, g.perf_spam);
}
