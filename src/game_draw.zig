const std = @import("std");
const sort = std.sort.sort;
const c = @import("c.zig");
const u31 = @import("types.zig").u31;
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

  if (g.render_move_boxes) {
    for (g.session.phys_objects.objects[0..g.session.phys_objects.count]) |*object| {
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

fn bullet_draw(g: *GameState, entity_id: EntityId) void {
  const phys = g.session.phys_objects.find(entity_id).?;
  const transform = g.session.transforms.find(entity_id).?;

  const t = get_dir_transform(phys.facing);
  draw_block(g, transform.pos, g.graphics.texture(Graphic.PlaBullet).handle, t);
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
    Math.Direction.W, Math.Direction.E => transform.pos.x,
    Math.Direction.N, Math.Direction.S => transform.pos.y,
  };
  const sxpos = @divFloor(xpos, Math.SUBPIXELS);

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
    Math.Direction.W, Math.Direction.E => transform.pos.x,
    Math.Direction.N, Math.Direction.S => transform.pos.y,
  };
  const sxpos = @divFloor(xpos, Math.SUBPIXELS);

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
    Math.Direction.W, Math.Direction.E => transform.pos.x,
    Math.Direction.N, Math.Direction.S => transform.pos.y,
  };
  const sxpos = @divFloor(xpos, Math.SUBPIXELS);

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
  const transform = g.session.transforms.find(entity_id).?;

  const animcfg = getSimpleAnim(animation.simple_anim);

  std.debug.assert(animation.frame_index < animcfg.frames.len);

  const graphic = animcfg.frames[animation.frame_index];
  const tex = g.graphics.texture(graphic).handle;
  draw_block(g, transform.pos, tex, Transform.Identity);
}

pub fn draw_map(g: *GameState) void {
  var y: u31 = 0;
  while (y < LEVEL.h) : (y += 1) {
    var x: u31 = 0;
    while (x < LEVEL.w) : (x += 1) {
      const gridpos = Math.Vec2.init(x, y);
      if (switch (LEVEL.get_gridvalue(gridpos).?) {
        0x00 => g.graphics.texture(Graphic.Floor).handle,
        0x80 => g.graphics.texture(Graphic.Wall).handle,
        0x81 => g.graphics.texture(Graphic.Wall2).handle,
        0x82 => g.graphics.texture(Graphic.Pit).handle,
        else => null,
      }) |tex| {
        const size = GRIDSIZE_SUBPIXELS;
        draw_block(g, Math.Vec2.scale(gridpos, size), tex, Transform.Identity);
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

pub fn draw_block(g: *GameState, pos: Math.Vec2, tex: c.GLuint, transform: Transform) void {
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
