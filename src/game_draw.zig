const std = @import("std");
const sort = std.sort.sort;
const c = @import("c.zig");
const u31 = @import("types.zig").u31;
const GameState = @import("main.zig").GameState;
const Transform = @import("main.zig").Transform;
const fillRect = @import("main.zig").fillRect;
const Direction = @import("math.zig").Direction;
const SUBPIXELS = @import("math.zig").SUBPIXELS;
const Vec2 = @import("math.zig").Vec2;
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

  fn lessThan(lhs: *const SortItem, rhs: *const SortItem) bool {
    return lhs.z_index < rhs.z_index;
  }
};

pub fn game_draw(g: *GameState) void {
  // sort drawables
  var sortarray: [Constants.MaxComponentsPerType]SortItem = undefined;
  var num_drawables: usize = 0;
  for (g.session.drawables.objects[0..g.session.drawables.count]) |*object, i| {
    if (object.is_active) {
      sortarray[num_drawables] = SortItem{
        .component_index = i,
        .z_index = object.data.z_index,
      };
      num_drawables += 1;
    }
  }
  var sortslice = sortarray[0..num_drawables];
  sort(SortItem, sortslice, SortItem.lessThan);

  // actually draw
  draw_map(g);

  for (sortslice) |sort_item| {
    const object = &g.session.drawables.objects[sort_item.component_index];
    switch (object.data.drawType) {
      Drawable.Type.Soldier => soldier_draw(g, object.entity_id),
      Drawable.Type.SoldierCorpse => soldier_corpse_draw(g, object.entity_id),
      Drawable.Type.Monster => monster_draw(g, object.entity_id),
      Drawable.Type.MonsterSpawn => monster_spawn_draw(g, object.entity_id),
      Drawable.Type.Squid => squid_draw(g, object.entity_id),
      Drawable.Type.Bullet => bullet_draw(g, object.entity_id),
      Drawable.Type.Animation => animation_draw(g, object.entity_id),
    }
  }
}

fn bullet_draw(g: *GameState, entity_id: EntityId) void {
  const drawable = g.session.drawables.find(entity_id).?;
  const phys = g.session.phys_objects.find(entity_id).?;
  const transform = g.session.transforms.find(entity_id).?;

  // graphic is 16x16, actual bullet is 4x4
  const pos = Vec2{
    .x = transform.pos.x - drawable.offset.x * SUBPIXELS,
    .y = transform.pos.y - drawable.offset.y * SUBPIXELS,
  };
  const t = get_dir_transform(phys.facing);
  draw_block(g, pos, g.graphics.texture(Graphic.PlaBullet).handle, t);
}

fn soldier_draw(g: *GameState, entity_id: EntityId) void {
  const creature = g.session.creatures.find(entity_id).?;
  const phys = g.session.phys_objects.find(entity_id).?;
  const transform = g.session.transforms.find(entity_id).?;

  if (creature.invulnerability_timer > 0) {
    if (((g.session.frameindex >> 2) & 1) == 0) {
      return;
    }
  }

  const xpos = switch (phys.facing) {
    Direction.Left, Direction.Right => transform.pos.x,
    Direction.Up, Direction.Down => transform.pos.y,
  };
  const sxpos = @divFloor(xpos, SUBPIXELS);

  var player_tex: c.GLuint = undefined;
  // animate legs every 4 screen pixels
  if (@mod(@divFloor(sxpos, 4), 2) == 0) {
    player_tex = g.graphics.texture(Graphic.Man1).handle;
  } else {
    player_tex = g.graphics.texture(Graphic.Man2).handle;
  }
  const t = get_dir_transform(phys.facing);
  draw_block(g, transform.pos, player_tex, t);
}

fn soldier_corpse_draw(g: *GameState, entity_id: EntityId) void {
  const transform = g.session.transforms.find(entity_id).?;

  draw_block(g, transform.pos, g.graphics.texture(Graphic.Skeleton).handle, Transform.Identity);
}

fn monster_draw(g: *GameState, entity_id: EntityId) void {
  const creature = g.session.creatures.find(entity_id).?;
  const phys = g.session.phys_objects.find(entity_id).?;
  const transform = g.session.transforms.find(entity_id).?;

  if (creature.invulnerability_timer > 0) {
    if (((g.session.frameindex >> 2) & 1) == 0) {
      return;
    }
  }

  const xpos = switch (phys.facing) {
    Direction.Left, Direction.Right => transform.pos.x,
    Direction.Up, Direction.Down => transform.pos.y,
  };
  const sxpos = @divFloor(xpos, SUBPIXELS);

  var player_tex: c.GLuint = undefined;
  // animate legs every 4 screen pixels
  if (@mod(@divFloor(sxpos, 4), 2) == 0) {
    player_tex = g.graphics.texture(Graphic.Monster1).handle;
  } else {
    player_tex = g.graphics.texture(Graphic.Monster2).handle;
  }
  const t = get_dir_transform(phys.facing);
  draw_block(g, transform.pos, player_tex, t);
}

fn squid_draw(g: *GameState, entity_id: EntityId) void {
  const creature = g.session.creatures.find(entity_id).?;
  const phys = g.session.phys_objects.find(entity_id).?;
  const transform = g.session.transforms.find(entity_id).?;

  if (creature.invulnerability_timer > 0) {
    if (((g.session.frameindex >> 2) & 1) == 0) {
      return;
    }
  }

  const xpos = switch (phys.facing) {
    Direction.Left, Direction.Right => transform.pos.x,
    Direction.Up, Direction.Down => transform.pos.y,
  };
  const sxpos = @divFloor(xpos, SUBPIXELS);

  var player_tex: c.GLuint = undefined;
  // animate legs every 4 screen pixels
  if (@mod(@divFloor(sxpos, 4), 2) == 0) {
    player_tex = g.graphics.texture(Graphic.Squid1).handle;
  } else {
    player_tex = g.graphics.texture(Graphic.Squid2).handle;
  }
  const t = get_dir_transform(phys.facing);
  draw_block(g, transform.pos, player_tex, t);
}

fn monster_spawn_draw(g: *GameState, entity_id: EntityId) void {
  const transform = g.session.transforms.find(entity_id).?;

  var player_tex: c.GLuint = undefined;
  // animate legs every 4 screen pixels
  if (((g.session.frameindex >> 2) & 1) == 0) {
    player_tex = g.graphics.texture(Graphic.Spawn1).handle;
  } else {
    player_tex = g.graphics.texture(Graphic.Spawn2).handle;
  }
  draw_block(g, transform.pos, player_tex, Transform.Identity);
}

pub fn animation_draw(g: *GameState, entity_id: EntityId) void {
  const animation = g.session.animations.find(entity_id).?;
  const drawable = g.session.drawables.find(entity_id).?;
  const transform = g.session.transforms.find(entity_id).?;

  const animcfg = getSimpleAnim(animation.simple_anim);

  std.debug.assert(animation.frame_index < animcfg.frames.len);

  const pos = Vec2{
    .x = transform.pos.x - drawable.offset.x * SUBPIXELS,
    .y = transform.pos.y - drawable.offset.y * SUBPIXELS,
  };
  const graphic = animcfg.frames[animation.frame_index];
  const tex = g.graphics.texture(graphic).handle;
  draw_block(g, pos, tex, Transform.Identity);
}

pub fn draw_map(g: *GameState) void {
  var y: u31 = 0;
  while (y < LEVEL.h) : (y += 1) {
    var x: u31 = 0;
    while (x < LEVEL.w) : (x += 1) {
      const gridpos = Vec2{ .x = x, .y = y };
      if (switch (LEVEL.get_gridvalue(gridpos).?) {
        0x00 => g.graphics.texture(Graphic.Floor).handle,
        0x80 => g.graphics.texture(Graphic.Wall).handle,
        0x81 => g.graphics.texture(Graphic.Wall2).handle,
        0x82 => g.graphics.texture(Graphic.Pit).handle,
        else => null,
      }) |tex| {
        const size = GRIDSIZE_SUBPIXELS;
        draw_block(g, Vec2.scale(gridpos, size), tex, Transform.Identity);
      }
    }
  }
}

///////////////////////////////////////////////////////////

pub fn get_dir_transform(direction: Direction) Transform {
  return switch (direction) {
    Direction.Left => Transform.FlipHorizontal,
    Direction.Right => Transform.Identity,
    Direction.Up => Transform.RotateCounterClockwise,
    Direction.Down => Transform.RotateClockwise,
  };
}

pub fn draw_block(g: *GameState, pos: *const Vec2, tex: c.GLuint, transform: Transform) void {
  const x = @intToFloat(f32, @divFloor(pos.x, SUBPIXELS)); // TODO - round
  const y = @intToFloat(f32, @divFloor(pos.y, SUBPIXELS)); // TODO - round
  const w = GRIDSIZE_PIXELS;
  const h = GRIDSIZE_PIXELS;
  fillRect(g, tex, x, y, w, h, transform);
}
