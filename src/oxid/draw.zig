const std = @import("std");
const lessThanField = @import("../util.zig").lessThanField;
const Math = @import("../math.zig");
const Draw = @import("../draw.zig");
const fontDrawString = @import("../platform/font.zig").fontDrawString;
const PlatformDraw = @import("../platform/draw.zig");
const Gbe = @import("../gbe.zig");
const VWIN_W = @import("main.zig").VWIN_W;
const HUD_HEIGHT = @import("main.zig").HUD_HEIGHT;
const GameState = @import("main.zig").GameState;
const MaxDrawables = @import("game.zig").MaxDrawables;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("level.zig").LEVEL;
const C = @import("components.zig");

const SortItem = struct {
  object: *Gbe.ComponentObject(C.Drawable),
  z_index: u32,
};

pub fn drawGame(g: *GameState) void {
  const gs = &g.session;
  // sort drawables
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

  // actually draw
  drawMap(g);

  for (sortslice) |sort_item| {
    const object = sort_item.object;
    switch (object.data.draw_type) {
      C.Drawable.Type.Soldier => drawSoldier(g, object.entity_id),
      C.Drawable.Type.SoldierCorpse => drawSoldierCorpse(g, object.entity_id),
      C.Drawable.Type.Spider => drawMonster(g, object.entity_id, Graphic.Spider1, Graphic.Spider2),
      C.Drawable.Type.FastBug => drawMonster(g, object.entity_id, Graphic.FastBug1, Graphic.FastBug2),
      C.Drawable.Type.Squid => drawMonster(g, object.entity_id, Graphic.Squid1, Graphic.Squid2),
      C.Drawable.Type.PlayerBullet => drawBullet(g, object.entity_id, Graphic.PlaBullet),
      C.Drawable.Type.PlayerBullet2 => drawBullet(g, object.entity_id, Graphic.PlaBullet2),
      C.Drawable.Type.PlayerBullet3 => drawBullet(g, object.entity_id, Graphic.PlaBullet3),
      C.Drawable.Type.MonsterBullet => drawBullet(g, object.entity_id, Graphic.MonBullet),
      C.Drawable.Type.Animation => drawAnimation(g, object.entity_id),
      C.Drawable.Type.Pickup => drawPickup(g, object.entity_id),
    }
  }

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

  drawHud(g);
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
  };

  fn run(g: *GameState, params: Params) void {
    const entity_id = params.entity_id;
    const creature = g.session.gbe.find(entity_id, C.Creature) orelse return;
    const phys = g.session.gbe.find(entity_id, C.PhysObject) orelse return;
    const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;

    if (params.spawning_timer > 0) {
      const graphic = if (alternation(u32, params.spawning_timer, 4)) Graphic.Spawn1 else Graphic.Spawn2;
      drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
      return;
    }
    if (creature.invulnerability_timer > 0) {
      if (alternation(u32, creature.invulnerability_timer, 1)) {
        return;
      }
    }

    const xpos = switch (phys.facing) {
      Math.Direction.W, Math.Direction.E => transform.pos.x,
      Math.Direction.N, Math.Direction.S => transform.pos.y,
    };
    const sxpos = @divFloor(xpos, Math.SUBPIXELS);

    // animate legs every 4 screen pixels
    const graphic = if (alternation(i32, sxpos, 4)) params.graphic1 else params.graphic2;

    drawBlock(g, transform.pos, graphic, getDirTransform(phys.facing));
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
    if (player.dying_timer > 15) {
      const graphic = if (alternation(u32, player.dying_timer, 2)) Graphic.ManDying1 else Graphic.ManDying2;
      drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
    } else if (player.dying_timer > 10) {
      drawBlock(g, transform.pos, Graphic.ManDying3, Draw.Transform.Identity);
    } else if (player.dying_timer > 5) {
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
  });
}

fn drawSoldierCorpse(g: *GameState, entity_id: Gbe.EntityId) void {
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  drawBlock(g, transform.pos, Graphic.ManDying6, Draw.Transform.Identity);
}

fn drawMonster(g: *GameState, entity_id: Gbe.EntityId, graphic1: Graphic, graphic2: Graphic) void {
  const monster = g.session.gbe.find(entity_id, C.Monster) orelse return;
  DrawCreature.run(g, DrawCreature.Params{
    .entity_id = entity_id,
    .spawning_timer = monster.spawning_timer,
    .graphic1 = graphic1,
    .graphic2 = graphic2,
  });
}

pub fn drawAnimation(g: *GameState, entity_id: Gbe.EntityId) void {
  const animation = g.session.gbe.find(entity_id, C.Animation) orelse return;
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  const animcfg = getSimpleAnim(animation.simple_anim);
  std.debug.assert(animation.frame_index < animcfg.frames.len);
  const graphic = animcfg.frames[animation.frame_index];
  drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
}

pub fn drawPickup(g: *GameState, entity_id: Gbe.EntityId) void {
  const pickup = g.session.gbe.find(entity_id, C.Pickup) orelse return;
  const transform = g.session.gbe.find(entity_id, C.Transform) orelse return;
  const graphic = switch (pickup.pickup_type) {
    C.Pickup.Type.PowerUp => Graphic.PowerUp,
    C.Pickup.Type.SpeedUp => Graphic.SpeedUp,
    C.Pickup.Type.LifeUp => Graphic.LifeUp,
    C.Pickup.Type.Coin => Graphic.Coin,
  };
  drawBlock(g, transform.pos, graphic, Draw.Transform.Identity);
}

pub fn drawMap(g: *GameState) void {
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
        const size = GRIDSIZE_SUBPIXELS;
        drawBlock(g, Math.Vec2.scale(gridpos, size), graphic, Draw.Transform.Identity);
      }
    }
  }
}

pub fn drawHud(g: *GameState) void {
  const gc = g.session.getGameController();
  const pc_maybe = if (g.session.gbe.iter(C.PlayerController).next()) |object| &object.data else null;

  PlatformDraw.rect(&g.platform_state, 0, 0, @intToFloat(f32, VWIN_W), @intToFloat(f32, HUD_HEIGHT), Draw.RectStyle{
    .Solid = Draw.SolidParams{
      .color = Draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    },
  });

  if (pc_maybe) |pc| {
    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);
    _ = dest.stream.print("Wave: {}", gc.wave_index);
    fontDrawString(&g.platform_state, Math.Vec2.init(0, 0), dest.getWritten());
    dest.reset();
    _ = dest.stream.print("Speed: {}", gc.enemy_speed_level);
    fontDrawString(&g.platform_state, Math.Vec2.init(9*8, 0), dest.getWritten());
    dest.reset();
    if (pc.lives > 0) {
      // show one less so that 0 is a life
      _ = dest.stream.print("Lives: {}", pc.lives - 1);
      fontDrawString(&g.platform_state, Math.Vec2.init(19*8, 0), dest.getWritten());
      dest.reset();
    } else {
      fontDrawString(&g.platform_state, Math.Vec2.init(19*8, 0), "Lives: \x1F"); // skull
      fontDrawString(&g.platform_state, Math.Vec2.init(18*8, 15*8), "GAME");
      fontDrawString(&g.platform_state, Math.Vec2.init(18*8, 16*8), "OVER");
    }
    if (g.session.god_mode) {
      fontDrawString(&g.platform_state, Math.Vec2.init(19*8, 8), "god mode");
    }
    _ = dest.stream.print("Score: {}", pc.score);
    fontDrawString(&g.platform_state, Math.Vec2.init(29*8, 0), dest.getWritten());
    dest.reset();
  }
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
  PlatformDraw.drawTile(
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
  PlatformDraw.rect(&g.platform_state, x0, y0, w, h, Draw.RectStyle{
    .Outline = Draw.OutlineParams{
      .color = color,
    },
  });
}
