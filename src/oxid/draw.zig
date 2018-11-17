const std = @import("std");
const lessThanField = @import("../util.zig").lessThanField;
const Math = @import("../math.zig");
const Draw = @import("../draw.zig");
const fontDrawString = @import("../font.zig").fontDrawString;
const Platform = @import("../platform/index.zig");
const VWIN_W = @import("main.zig").VWIN_W;
const VWIN_H = @import("main.zig").VWIN_H;
const HUD_HEIGHT = @import("main.zig").HUD_HEIGHT;
const GameState = @import("main.zig").GameState;
const Constants = @import("constants.zig");
const GameSession = @import("game.zig").GameSession;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("level.zig").LEVEL;
const C = @import("components.zig");
const perf = @import("perf.zig");

pub fn drawGame(g: *GameState) void {
  const mc = g.session.findFirst(C.MainController) orelse return;

  if (mc.game_running_state) |grs| {
    const max_drawables = comptime GameSession.getCapacity(C.EventDraw);
    var sort_buffer: [max_drawables]*const C.EventDraw = undefined;
    const sorted_drawables = getSortedDrawables(g, sort_buffer[0..]);

    Platform.drawBegin(&g.platform_state, g.tileset.texture.handle);
    drawMap(g);
    drawEntities(g, sorted_drawables);
    Platform.drawEnd(&g.platform_state);

    drawBoxes(g);
    drawHud(g, true);

    if (grs.exit_dialog_open) {
      drawExitDialog(g);
    }
  } else {
    Platform.drawBegin(&g.platform_state, g.tileset.texture.handle);
    drawMap(g);
    Platform.drawEnd(&g.platform_state);

    drawHud(g, false);
    drawMainMenu(g);
  }
}

///////////////////////////////////////

fn getSortedDrawables(g: *GameState, sort_buffer: []*const C.EventDraw) []*const C.EventDraw {
  perf.begin(&perf.timers.DrawSort);
  defer perf.end(&perf.timers.DrawSort, g.perf_spam);

  var num_drawables: usize = 0;
  var it = g.session.iter(C.EventDraw); while (it.next()) |object| {
    if (object.is_active) {
      sort_buffer[num_drawables] = &object.data;
      num_drawables += 1;
    }
  }
  var sorted_drawables = sort_buffer[0..num_drawables];
  std.sort.sort(*const C.EventDraw, sorted_drawables, lessThanField(*const C.EventDraw, "z_index"));
  return sorted_drawables;
}

fn drawMap(g: *GameState) void {
  perf.begin(&perf.timers.DrawMap);
  defer perf.end(&perf.timers.DrawMap, g.perf_spam);

  var y: u31 = 0;
  while (y < LEVEL.h) : (y += 1) {
    var x: u31 = 0;
    while (x < LEVEL.w) : (x += 1) {
      const gridpos = Math.Vec2.init(x, y);
      if (switch (LEVEL.getGridValue(gridpos).?) {
        0x00 => Graphic.Floor,
        0x80 => Graphic.Wall,
        0x81 => Graphic.Wall2,
        0x82 => Graphic.Pit,
        0x83 => Graphic.EvilWallTL,
        0x84 => Graphic.EvilWallTR,
        0x85 => Graphic.EvilWallBL,
        0x86 => Graphic.EvilWallBR,
        else => null,
      }) |graphic| {
        const pos = Math.Vec2.scale(gridpos, GRIDSIZE_SUBPIXELS);
        const dx = @intToFloat(f32, @divFloor(pos.x, Math.SUBPIXELS));
        const dy = @intToFloat(f32, @divFloor(pos.y, Math.SUBPIXELS)) + HUD_HEIGHT;
        const dw = GRIDSIZE_PIXELS;
        const dh = GRIDSIZE_PIXELS;
        Platform.drawTile(
          &g.platform_state,
          &g.tileset,
          getGraphicTile(graphic),
          dx, dy, dw, dh,
          Draw.Transform.Identity,
        );
      }
    }
  }
}

fn drawEntities(g: *GameState, sorted_drawables: []*const C.EventDraw) void {
  perf.begin(&perf.timers.DrawEntities);
  defer perf.end(&perf.timers.DrawEntities, g.perf_spam);

  for (sorted_drawables) |drawable| {
    const x = @intToFloat(f32, @divFloor(drawable.pos.x, Math.SUBPIXELS));
    const y = @intToFloat(f32, @divFloor(drawable.pos.y, Math.SUBPIXELS)) + HUD_HEIGHT;
    const w = GRIDSIZE_PIXELS;
    const h = GRIDSIZE_PIXELS;
    Platform.drawTile(
      &g.platform_state,
      &g.tileset,
      getGraphicTile(drawable.graphic),
      x, y, w, h,
      drawable.transform,
    );
  }
}

fn drawBoxes(g: *GameState) void {
  var it = g.session.iter(C.EventDrawBox); while (it.next()) |object| {
    if (object.is_active) {
      const abs_bbox = object.data.box;
      const x0 = @intToFloat(f32, @divFloor(abs_bbox.mins.x, Math.SUBPIXELS));
      const y0 = @intToFloat(f32, @divFloor(abs_bbox.mins.y, Math.SUBPIXELS)) + HUD_HEIGHT;
      const x1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.x + 1, Math.SUBPIXELS));
      const y1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.y + 1, Math.SUBPIXELS)) + HUD_HEIGHT;
      const w = x1 - x0;
      const h = y1 - y0;
      Platform.drawUntexturedRect(
        &g.platform_state,
        x0, y0, w, h,
        object.data.color,
        true,
      );
    }
  }
}

fn drawHud(g: *GameState, game_active: bool) void {
  perf.begin(&perf.timers.DrawHud);
  defer perf.end(&perf.timers.DrawHud, g.perf_spam);

  var buffer: [40]u8 = undefined;
  var dest = std.io.SliceOutStream.init(buffer[0..]);

  const mc = g.session.findFirst(C.MainController).?;
  const gc_maybe = g.session.findFirst(C.GameController);
  const pc_maybe = g.session.findFirst(C.PlayerController);

  Platform.drawUntexturedRect(
    &g.platform_state,
    0, 0, @intToFloat(f32, VWIN_W), @intToFloat(f32, HUD_HEIGHT),
    Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    false,
  );

  Platform.drawBegin(&g.platform_state, g.font.tileset.texture.handle);

  if (gc_maybe) |gc| {
    if (pc_maybe) |pc| {
      const maybe_player_creature =
        if (pc.player_id) |player_id|
          g.session.find(player_id, C.Creature)
        else
          null;

      _ = dest.stream.print("Wave: {}", gc.wave_number);
      fontDrawString(&g.platform_state, &g.font, 0, 0, dest.getWritten());
      dest.reset();
      _ = dest.stream.print("Speed: {}", gc.enemy_speed_level);
      fontDrawString(&g.platform_state, &g.font, 9*8, 0, dest.getWritten());
      dest.reset();
      fontDrawString(&g.platform_state, &g.font, 19*8, 0, "Lives:");
      var i: u31 = 0; while (i < pc.lives) : (i += 1) {
        fontDrawString(&g.platform_state, &g.font, (25+i)*8, 0, "\x1E"); // heart
      }
      if (pc.lives == 0) {
        fontDrawString(&g.platform_state, &g.font, 25*8, 0, "\x1F"); // skull
      }
      if (maybe_player_creature) |player_creature| {
        if (player_creature.god_mode) {
          fontDrawString(&g.platform_state, &g.font, 19*8, 8, "god mode");
        }
      }
      _ = dest.stream.print("Score: {}", pc.score);
      fontDrawString(&g.platform_state, &g.font, 29*8, 0, dest.getWritten());
      dest.reset();
    }

    if (gc.wave_message_timer > 0 and gc.wave_number > 0 and gc.wave_number <= Constants.Waves.len) {
      if (Constants.Waves[gc.wave_number - 1].message) |message| {
        const x = 320 / 2 - message.len * 8 / 2;
        fontDrawString(&g.platform_state, &g.font, @intCast(i32, x), 28*8, message);
      }
    }
  }

  if (!game_active) {
    _ = dest.stream.print("High score: {}", mc.high_score);
    fontDrawString(&g.platform_state, &g.font, 24*8, 0, dest.getWritten());
    dest.reset();
  }

  Platform.drawEnd(&g.platform_state);

  if (if (gc_maybe) |gc| gc.game_over else false) {
    const y = 8*4;

    if (mc.new_high_score) {
      drawTextBox(g, DrawCoord.Centered, DrawCoord{ .Exact = y }, "GAME OVER\n\nNew high score!");
    } else {
      drawTextBox(g, DrawCoord.Centered, DrawCoord{ .Exact = y }, "GAME OVER");
    }
  }
}

fn drawExitDialog(g: *GameState) void {
  drawTextBox(g, DrawCoord.Centered, DrawCoord.Centered, "Leave game? [Y/N]");
}

fn drawMainMenu(g: *GameState) void {
  drawTextBox(g, DrawCoord.Centered, DrawCoord.Centered, "OXID\n\n[Space] to play\n\n[Esc] to quit");
}

const DrawCoord = union(enum){
  Centered,
  Exact: i32,
};

fn drawTextBox(g: *GameState, dx: DrawCoord, dy: DrawCoord, text: []const u8) void {
  var tw: u31 = 0;
  var th: u31 = 1;

  {
    var tx: u31 = 0;
    for (text) |c| {
      if (c == '\n') {
        tx = 0;
        th += 1;
      } else {
        tx += 1;
        if (tx > tw) {
          tw = tx;
        }
      }
    }
  }

  const w = 8 * (tw + 2);
  const h = 8 * (th + 2);

  const x = switch (dx) {
    DrawCoord.Centered => i32(VWIN_W / 2 - w / 2),
    DrawCoord.Exact => |x| x,
  };
  const y = switch (dy) {
    DrawCoord.Centered => i32(VWIN_H / 2 - h / 2),
    DrawCoord.Exact => |y| y,
  };

  Platform.drawUntexturedRect(
    &g.platform_state,
    @intToFloat(f32, x), @intToFloat(f32, y),
    @intToFloat(f32, w), @intToFloat(f32, h),
    Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    false,
  );

  Platform.drawBegin(&g.platform_state, g.font.tileset.texture.handle);
  {
    var start: usize = 0;
    var sy = y + 8;
    var i: usize = 0; while (i <= text.len) : (i += 1) {
      if (i == text.len or text[i] == '\n') {
        const slice = text[start..i];
        const sw = 8 * @intCast(u31, slice.len);
        const sx = x + i32(w / 2 - sw / 2);
        fontDrawString(&g.platform_state, &g.font, sx, sy, slice);
        sy += 8;
        start = i + 1;
      }
    }
  }
  Platform.drawEnd(&g.platform_state);
}
