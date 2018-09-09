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
    drawHud(g);

    if (grs.exit_dialog_open) {
      drawExitDialog(g);
    }
  } else {
    Platform.drawBegin(&g.platform_state, g.tileset.texture.handle);
    drawMap(g);
    Platform.drawEnd(&g.platform_state);

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

fn drawUnderHud(g: *GameState) void {
  Platform.drawUntexturedRect(
    &g.platform_state,
    0, 0, @intToFloat(f32, VWIN_W), @intToFloat(f32, HUD_HEIGHT),
    Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    false,
  );
}

fn drawHud(g: *GameState) void {
  perf.begin(&perf.timers.DrawHud);
  defer perf.end(&perf.timers.DrawHud, g.perf_spam);

  const gc = g.session.findFirst(C.GameController).?;
  const pc_maybe = g.session.findFirst(C.PlayerController);

  drawUnderHud(g);

  Platform.drawBegin(&g.platform_state, g.font.tileset.texture.handle);

  if (pc_maybe) |pc| {
    const maybe_player_creature =
      if (pc.player_id) |player_id|
        g.session.find(player_id, C.Creature)
      else
        null;

    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);
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
      fontDrawString(&g.platform_state, &g.font, 18*8, 15*8, "GAME");
      fontDrawString(&g.platform_state, &g.font, 18*8, 16*8, "OVER");
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

  Platform.drawEnd(&g.platform_state);
}

fn drawExitDialog(g: *GameState) void {
  const str = "Quit game? [Y/N]";
  const len = @intCast(u31, str.len);

  const w = 8*(len+2);
  const h = 8*3;
  const x = VWIN_W / 2 - w / 2;
  const y = VWIN_H / 2 - h / 2;

  Platform.drawUntexturedRect(
    &g.platform_state,
    @intToFloat(f32, x), @intToFloat(f32, y),
    @intToFloat(f32, w), @intToFloat(f32, h),
    Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    false,
  );

  Platform.drawBegin(&g.platform_state, g.font.tileset.texture.handle);

  fontDrawString(&g.platform_state, &g.font, x + 8, y + 8, str);

  Platform.drawEnd(&g.platform_state);
}

fn drawMainMenu(g: *GameState) void {
  drawUnderHud(g);

  const str1 = "       OXID       ";
  const str2 = "Press SPACE to play";
  const len = @intCast(u31, str2.len);

  const w = 8*(len+2);
  const h = 8*5;
  const x = VWIN_W / 2 - w / 2;
  const y = VWIN_H / 2 - h / 2;

  Platform.drawUntexturedRect(
    &g.platform_state,
    @intToFloat(f32, x), @intToFloat(f32, y),
    @intToFloat(f32, w), @intToFloat(f32, h),
    Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    false,
  );

  Platform.drawBegin(&g.platform_state, g.font.tileset.texture.handle);

  fontDrawString(&g.platform_state, &g.font, x + 8, y + 8, str1);
  fontDrawString(&g.platform_state, &g.font, x + 8, y + 3*8, str2);

  Platform.drawEnd(&g.platform_state);
}
