const std = @import("std");
const c = @import("c.zig");
const u31 = @import("types.zig").u31;
const lessThanField = @import("util.zig").lessThanField;
const GameState = @import("main.zig").GameState;
const Transform = @import("main.zig").Transform;
const drawBox = @import("main.zig").drawBox;
const fillRect = @import("main.zig").fillRect;
const Math = @import("math.zig");
const Graphic = @import("graphics.zig").Graphic;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const EntityId = @import("game.zig").EntityId;
const Constants = @import("game_constants.zig");
const GRIDSIZE_PIXELS = @import("game_level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("game_level.zig").LEVEL;
const components = @import("game_components.zig");
const Bullet = components.Bullet;
const Drawable = components.Drawable;
const Player = components.Player;

const SortItem = struct {
  component_index: usize,
  z_index: u32,
};

pub fn game_draw(g: *GameState) void {
  // sort drawables
  var sortarray: [Constants.MaxComponentsPerType]SortItem = undefined;
  var num_drawables: usize = 0;
  for (g.session.drawables.objects) |*object, i| {
    if (object.is_active) {
      sortarray[num_drawables] = SortItem{
        .component_index = i,
        .z_index = object.data.z_index,
      };
      num_drawables += 1;
    }
  }
  var sortslice = sortarray[0..num_drawables];
  std.sort.sort(SortItem, sortslice, lessThanField(SortItem, "z_index"));

  // actually draw
  draw_map(g);

  for (sortslice) |sort_item| {
    const object = &g.session.drawables.objects[sort_item.component_index];
    switch (object.data.drawType) {
      Drawable.Type.Soldier => soldier_draw(g, object.entity_id),
      Drawable.Type.SoldierCorpse => soldier_corpse_draw(g, object.entity_id),
      Drawable.Type.Spider => spider_draw(g, object.entity_id),
      Drawable.Type.MonsterSpawn => monster_spawn_draw(g, object.entity_id),
      Drawable.Type.Squid => squid_draw(g, object.entity_id),
      Drawable.Type.PlayerBullet => bullet_draw(g, object.entity_id, Graphic.PlaBullet),
      Drawable.Type.MonsterBullet => bullet_draw(g, object.entity_id, Graphic.MonBullet),
      Drawable.Type.Animation => animation_draw(g, object.entity_id),
    }
  }

  if (g.render_move_boxes) {
    for (g.session.phys_objects.objects) |*object| {
      if (!object.is_active) {
        continue;
      }
      const int = object.data.internal;
      const R = @intCast(u8, 64 + ((int.group_index * 41) % 192));
      const G = @intCast(u8, 64 + ((int.group_index * 901) % 192));
      const B = @intCast(u8, 64 + ((int.group_index * 10031) % 192));
      draw_box(g, int.move_bbox, R, G, B);
    }
  }
}

// helper
fn alternation(comptime T: type, variable: T, half_period: T) bool {
  return @mod(@divFloor(variable, half_period * 2), half_period) == 0;
}

// helper
const DrawCreature = struct{
  const Params = struct{
    entity_id: EntityId,
    graphic1: Graphic,
    graphic2: Graphic,
  };

  fn run(g: *GameState, params: Params) void {
    const entity_id = params.entity_id;

    if (g.session.creatures.find(entity_id)) |creature| {
    if (g.session.phys_objects.find(entity_id)) |phys| {
    if (g.session.transforms.find(entity_id)) |transform| {
      if (creature.invulnerability_timer > 0) {
        if (alternation(u8, g.session.frameindex, 2)) {
          return;
        }
      }

      const xpos = switch (phys.facing) {
        Math.Direction.W, Math.Direction.E => transform.pos.x,
        Math.Direction.N, Math.Direction.S => transform.pos.y,
      };
      const sxpos = @divFloor(xpos, Math.SUBPIXELS);

      // animate legs every 4 screen pixels
      const graphic = if (alternation(i32, sxpos, 2)) params.graphic1 else params.graphic2;

      draw_block(g, transform.pos, graphic, get_dir_transform(phys.facing));
    }
  }}}
};

fn bullet_draw(g: *GameState, entity_id: EntityId, graphic: Graphic) void {
  if (g.session.phys_objects.find(entity_id)) |phys| {
  if (g.session.transforms.find(entity_id)) |transform| {
    draw_block(g, transform.pos, graphic, get_dir_transform(phys.facing));
  }}
}

fn soldier_draw(g: *GameState, entity_id: EntityId) void {
  DrawCreature.run(g, DrawCreature.Params{
    .entity_id = entity_id,
    .graphic1 = Graphic.Man1,
    .graphic2 = Graphic.Man2,
  });
}

fn soldier_corpse_draw(g: *GameState, entity_id: EntityId) void {
  if (g.session.transforms.find(entity_id)) |transform| {
    draw_block(g, transform.pos, Graphic.Skeleton, Transform.Identity);
  }
}

fn spider_draw(g: *GameState, entity_id: EntityId) void {
  DrawCreature.run(g, DrawCreature.Params{
    .entity_id = entity_id,
    .graphic1 = Graphic.Spider1,
    .graphic2 = Graphic.Spider2,
  });
}

fn squid_draw(g: *GameState, entity_id: EntityId) void {
  DrawCreature.run(g, DrawCreature.Params{
    .entity_id = entity_id,
    .graphic1 = Graphic.Squid1,
    .graphic2 = Graphic.Squid2,
  });
}

fn monster_spawn_draw(g: *GameState, entity_id: EntityId) void {
  if (g.session.transforms.find(entity_id)) |transform| {
    const graphic = if (alternation(u8, g.session.frameindex, 2)) Graphic.Spawn1 else Graphic.Spawn2;
    draw_block(g, transform.pos, graphic, Transform.Identity);
  }
}

pub fn animation_draw(g: *GameState, entity_id: EntityId) void {
  if (g.session.animations.find(entity_id)) |animation| {
  if (g.session.transforms.find(entity_id)) |transform| {
    const animcfg = getSimpleAnim(animation.simple_anim);

    std.debug.assert(animation.frame_index < animcfg.frames.len);

    const graphic = animcfg.frames[animation.frame_index];
    draw_block(g, transform.pos, graphic, Transform.Identity);
  }}
}

pub fn draw_map(g: *GameState) void {
  var y: u31 = 0;
  while (y < LEVEL.h) : (y += 1) {
    var x: u31 = 0;
    while (x < LEVEL.w) : (x += 1) {
      const gridpos = Math.Vec2.init(x, y);
      if (switch (LEVEL.get_gridvalue(gridpos).?) {
        0x00 => Graphic.Floor,
        0x80 => Graphic.Wall,
        0x81 => Graphic.Wall2,
        0x82 => Graphic.Pit,
        else => null,
      }) |graphic| {
        const size = GRIDSIZE_SUBPIXELS;
        draw_block(g, Math.Vec2.scale(gridpos, size), graphic, Transform.Identity);
      }
    }
  }
}

///////////////////////////////////////////////////////////

pub fn get_dir_transform(direction: Math.Direction) Transform {
  return switch (direction) {
    Math.Direction.N => Transform.RotateCounterClockwise,
    Math.Direction.E => Transform.Identity,
    Math.Direction.S => Transform.RotateClockwise,
    Math.Direction.W => Transform.FlipHorizontal,
  };
}

pub fn draw_block(g: *GameState, pos: Math.Vec2, graphic: Graphic, transform: Transform) void {
  const tex = g.graphics.texture(graphic).handle;
  const x = @intToFloat(f32, @divFloor(pos.x, Math.SUBPIXELS));
  const y = @intToFloat(f32, @divFloor(pos.y, Math.SUBPIXELS));
  const w = GRIDSIZE_PIXELS;
  const h = GRIDSIZE_PIXELS;
  fillRect(g, tex, x, y, w, h, transform);
}

pub fn draw_box(g: *GameState, abs_bbox: Math.BoundingBox, R: u8, G: u8, B: u8) void {
  const x0 = @intToFloat(f32, @divFloor(abs_bbox.mins.x, Math.SUBPIXELS));
  const y0 = @intToFloat(f32, @divFloor(abs_bbox.mins.y, Math.SUBPIXELS));
  const x1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.x + 1, Math.SUBPIXELS));
  const y1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.y + 1, Math.SUBPIXELS));
  const w = x1 - x0;
  const h = y1 - y0;
  drawBox(
    g, x0, y0, w, h,
    @intToFloat(f32, R) / 255.0,
    @intToFloat(f32, G) / 255.0,
    @intToFloat(f32, B) / 255.0,
  );
}
