const std = @import("std");
const lessThanField = @import("../util.zig").lessThanField;
const Math = @import("../math.zig");
const Draw = @import("../draw.zig");
const fontDrawString = @import("../font.zig").fontDrawString;
const Platform = @import("../platform/index.zig");
const Gbe = @import("../gbe.zig");
const VWIN_W = @import("main.zig").VWIN_W;
const HUD_HEIGHT = @import("main.zig").HUD_HEIGHT;
const GameState = @import("main.zig").GameState;
const ConstantTypes = @import("constant_types.zig");
const Constants = @import("constants.zig");
const MaxDrawables = @import("game.zig").MaxDrawables;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("level.zig").LEVEL;
const C = @import("components.zig");
const perf = @import("perf.zig");

const SortItem = struct {
  object: *Gbe.ComponentObject(C.Drawable),
  z_index: u32,
};

pub fn drawGame(g: *GameState) void {
  const gs = &g.session;

  // sort drawables
  perf.begin(&perf.timers.DrawSort);
  var sortarray: [MaxDrawables]SortItem = undefined;
  var num_drawables: usize = 0;
  var it = gs.gbe.iter(C.Drawable); while (it.next()) |object| {
    if (object.is_active) {
      sortarray[num_drawables] = SortItem{
        .object = object,
        .z_index = object.data.z_index,
      };
      num_drawables += 1;
    }
  }
  var sortslice = sortarray[0..num_drawables];
  std.sort.sort(SortItem, sortslice, lessThanField(SortItem, "z_index"));
  perf.end(&perf.timers.DrawSort, g.perf_spam);

  // actually draw
  Platform.drawBegin(&g.platform_state, g.tileset.texture.handle);

  perf.begin(&perf.timers.DrawMap);
  drawMap(g);
  perf.end(&perf.timers.DrawMap, g.perf_spam);

  perf.begin(&perf.timers.DrawEntities);
  for (sortslice) |sort_item| {
    const object = sort_item.object;
    switch (object.data.draw_type) {
      C.Drawable.Type.Soldier => drawSoldier(g, object.entity_id),
      C.Drawable.Type.SoldierCorpse => drawSoldierCorpse(g, object.entity_id),
      C.Drawable.Type.Spider => drawMonster(g, object.entity_id, Graphic.Spider1, Graphic.Spider2, true),
      C.Drawable.Type.Knight => drawMonster(g, object.entity_id, Graphic.Knight1, Graphic.Knight2, true),
      C.Drawable.Type.FastBug => drawMonster(g, object.entity_id, Graphic.FastBug1, Graphic.FastBug2, true),
      C.Drawable.Type.Squid => drawMonster(g, object.entity_id, Graphic.Squid1, Graphic.Squid2, true),
      C.Drawable.Type.Juggernaut => drawMonster(g, object.entity_id, Graphic.Juggernaut, Graphic.Juggernaut, false),
      C.Drawable.Type.PlayerBullet => drawBullet(g, object.entity_id, Graphic.PlaBullet),
      C.Drawable.Type.PlayerBullet2 => drawBullet(g, object.entity_id, Graphic.PlaBullet2),
      C.Drawable.Type.PlayerBullet3 => drawBullet(g, object.entity_id, Graphic.PlaBullet3),
      C.Drawable.Type.MonsterBullet => drawBullet(g, object.entity_id, Graphic.MonBullet),
      C.Drawable.Type.Web => drawWeb(g, object.entity_id),
      C.Drawable.Type.Animation => drawAnimation(g, object.entity_id),
      C.Drawable.Type.Pickup => drawPickup(g, object.entity_id),
    }
  }
  perf.end(&perf.timers.DrawEntities, g.perf_spam);

  Platform.drawEnd(&g.platform_state);

  if (g.render_move_boxes) {
    var it2 = gs.gbe.iter(C.PhysObject); while (it2.next()) |object| {
      const int = object.data.internal;
      drawBox(g, int.move_bbox, Draw.Color{
        .r = @intCast(u8, 64 + ((int.group_index * 41) % 192)),
        .g = @intCast(u8, 64 + ((int.group_index * 901) % 192)),
        .b = @intCast(u8, 64 + ((int.group_index * 10031) % 192)),
        .a = 255,
      });
    }
  }

  perf.begin(&perf.timers.DrawHud);
  drawHud(g);
  perf.end(&perf.timers.DrawHud, g.perf_spam);
}

// helper
fn alternation(comptime T: type, variable: T, half_period: T) bool {
  return @mod(@divFloor(variable, half_period), 2) == 0;
}

// helper
const DrawCreature = struct{
  const Params = struct{
    entity_id: Gbe.EntityId,
    spawning_timer: u32,
    graphic1: Graphic,
    graphic2: Graphic,
    rotates: bool,
  };

  fn run(g: *GameState, params: Params) void {
    const entity_id = params.entity_id;
    const creature = g.session.gbe.find(entity_id, C.Creature) orelse return;
    const phys = g.session.gbe.find(entity_id, C.PhysObject) orelse return;
    const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;

    if (params.spawning_timer > 0) {
      const graphic = if (alternation(u32, params.spawning_timer, 8)) Graphic.Spawn1 else Graphic.Spawn2;
      drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
      return;
    }
    if (creature.invulnerability_timer > 0) {
      if (alternation(u32, creature.invulnerability_timer, 2)) {
        return;
      }
    }

    const xpos = switch (phys.facing) {
      Math.Direction.W, Math.Direction.E => transform.pos.x,
      Math.Direction.N, Math.Direction.S => transform.pos.y,
    };
    const sxpos = @divFloor(xpos, Math.SUBPIXELS);

    drawBlock(g,
      transform.pos,
      // animate legs every 6 screen pixels
      if (alternation(i32, sxpos, 6)) params.graphic1 else params.graphic2,
      if (params.rotates) getDirTransform(phys.facing) else Draw.Transform.Identity,
    );
  }
};

fn drawBullet(g: *GameState, entity_id: Gbe.EntityId, graphic: Graphic) void {
  const phys = g.session.gbe.find(entity_id, C.PhysObject) orelse return;
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  drawBlock(g, transform.pos, graphic, getDirTransform(phys.facing));
}

fn drawSoldier(g: *GameState, entity_id: Gbe.EntityId) void {
  const player = g.session.gbe.find(entity_id, C.Player) orelse return;
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  if (player.dying_timer > 0) {
    if (player.dying_timer > 30) {
      const graphic = if (alternation(u32, player.dying_timer, 2)) Graphic.ManDying1 else Graphic.ManDying2;
      drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
    } else if (player.dying_timer > 20) {
      drawBlock(g, transform.pos, Graphic.ManDying3, Draw.Transform.Identity);
    } else if (player.dying_timer > 10) {
      drawBlock(g, transform.pos, Graphic.ManDying4, Draw.Transform.Identity);
    } else {
      drawBlock(g, transform.pos, Graphic.ManDying5, Draw.Transform.Identity);
    }
    return;
  }
  DrawCreature.run(g, DrawCreature.Params{
    .entity_id = entity_id,
    .spawning_timer = 0,
    .graphic1 = Graphic.Man1,
    .graphic2 = Graphic.Man2,
    .rotates = true,
  });
}

fn drawSoldierCorpse(g: *GameState, entity_id: Gbe.EntityId) void {
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  drawBlock(g, transform.pos, Graphic.ManDying6, Draw.Transform.Identity);
}

fn drawMonster(g: *GameState, entity_id: Gbe.EntityId, graphic1: Graphic, graphic2: Graphic, rotates: bool) void {
  const monster = g.session.gbe.find(entity_id, C.Monster) orelse return;
  DrawCreature.run(g, DrawCreature.Params{
    .entity_id = entity_id,
    .spawning_timer = monster.spawning_timer,
    .graphic1 = graphic1,
    .graphic2 = graphic2,
    .rotates = rotates,
  });
}

fn drawWeb(g: *GameState, entity_id: Gbe.EntityId) void {
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  const creature = g.session.gbe.find(entity_id, C.Creature) orelse return;
  const graphic =
    if (creature.flinch_timer > 0)
      Graphic.Web2
    else
      Graphic.Web1;
  drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
}

fn drawAnimation(g: *GameState, entity_id: Gbe.EntityId) void {
  const animation = g.session.gbe.find(entity_id, C.Animation) orelse return;
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  const animcfg = getSimpleAnim(animation.simple_anim);
  std.debug.assert(animation.frame_index < animcfg.frames.len);
  const graphic = animcfg.frames[animation.frame_index];
  drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
}

fn drawPickup(g: *GameState, entity_id: Gbe.EntityId) void {
  const pickup = g.session.gbe.find(entity_id, C.Pickup) orelse return;
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  const graphic = switch (pickup.pickup_type) {
    ConstantTypes.PickupType.PowerUp => Graphic.PowerUp,
    ConstantTypes.PickupType.SpeedUp => Graphic.SpeedUp,
    ConstantTypes.PickupType.LifeUp => Graphic.LifeUp,
    ConstantTypes.PickupType.Coin => Graphic.Coin,
  };
  drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
}

fn drawMap(g: *GameState) void {
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
        mapTile(g, Math.Vec2.scale(gridpos, GRIDSIZE_SUBPIXELS), graphic);
      }
    }
  }
}

fn drawHud(g: *GameState) void {
  const gc = g.session.getGameController();
  const pc_maybe = if (g.session.gbe.iter(C.PlayerController).next()) |object| &object.data else null;

  Platform.drawUntexturedRect(
    &g.platform_state,
    0, 0, @intToFloat(f32, VWIN_W), @intToFloat(f32, HUD_HEIGHT),
    Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    false,
  );

  Platform.drawBegin(&g.platform_state, g.font.tileset.texture.handle);

  if (pc_maybe) |pc| {
    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);
    _ = dest.stream.print("Wave: {}", gc.wave_number);
    fontDrawString(&g.platform_state, &g.font, 0, 0, dest.getWritten());
    dest.reset();
    _ = dest.stream.print("Speed: {}", gc.enemy_speed_level);
    fontDrawString(&g.platform_state, &g.font, 9*8, 0, dest.getWritten());
    dest.reset();
    if (pc.lives > 0) {
      // show one less so that 0 is a life
      _ = dest.stream.print("Lives: {}", pc.lives - 1);
      fontDrawString(&g.platform_state, &g.font, 19*8, 0, dest.getWritten());
      dest.reset();
    } else {
      fontDrawString(&g.platform_state, &g.font, 19*8, 0, "Lives: \x1F"); // skull
      fontDrawString(&g.platform_state, &g.font, 18*8, 15*8, "GAME");
      fontDrawString(&g.platform_state, &g.font, 18*8, 16*8, "OVER");
    }
    if (g.session.god_mode) {
      fontDrawString(&g.platform_state, &g.font, 19*8, 8, "god mode");
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

///////////////////////////////////////////////////////////

fn getDirTransform(direction: Math.Direction) Draw.Transform {
  return switch (direction) {
    Math.Direction.N => Draw.Transform.RotateCounterClockwise,
    Math.Direction.E => Draw.Transform.Identity,
    Math.Direction.S => Draw.Transform.RotateClockwise,
    Math.Direction.W => Draw.Transform.FlipHorizontal,
  };
}

fn drawBlock(g: *GameState, pos: Math.Vec2, graphic: Graphic, transform: Draw.Transform) void {
  const x = @intToFloat(f32, @divFloor(pos.x, Math.SUBPIXELS));
  const y = @intToFloat(f32, @divFloor(pos.y, Math.SUBPIXELS)) + HUD_HEIGHT;
  const w = GRIDSIZE_PIXELS;
  const h = GRIDSIZE_PIXELS;
  Platform.drawTile(
    &g.platform_state,
    &g.tileset,
    getGraphicTile(graphic),
    x, y, w, h, transform,
  );
}

fn drawBox(g: *GameState, abs_bbox: Math.BoundingBox, color: Draw.Color) void {
  const x0 = @intToFloat(f32, @divFloor(abs_bbox.mins.x, Math.SUBPIXELS));
  const y0 = @intToFloat(f32, @divFloor(abs_bbox.mins.y, Math.SUBPIXELS)) + HUD_HEIGHT;
  const x1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.x + 1, Math.SUBPIXELS));
  const y1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.y + 1, Math.SUBPIXELS)) + HUD_HEIGHT;
  const w = x1 - x0;
  const h = y1 - y0;
  Platform.drawUntexturedRect(
    &g.platform_state,
    x0, y0, w, h,
    color,
    true,
  );
}

fn mapTile(g: *GameState, pos: Math.Vec2, graphic: Graphic) void {
  const x = @intToFloat(f32, @divFloor(pos.x, Math.SUBPIXELS));
  const y = @intToFloat(f32, @divFloor(pos.y, Math.SUBPIXELS)) + HUD_HEIGHT;
  const w = GRIDSIZE_PIXELS;
  const h = GRIDSIZE_PIXELS;
  Platform.drawTile(
    &g.platform_state,
    &g.tileset,
    getGraphicTile(graphic),
    x, y, w, h, Draw.Transform.Identity,
  );
}
