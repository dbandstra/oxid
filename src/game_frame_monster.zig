const std = @import("std");
const u31 = @import("types.zig").u31;
const Math = @import("math.zig");
const LEVEL = @import("game_level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const phys_in_wall = @import("game_physics.zig").phys_in_wall;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

pub fn monster_frame(gs: *GameSession, self_id: EntityId, self_monster: *C.Monster) bool {
  const self_creature = gs.creatures.find(self_id).?;
  const self_phys = gs.phys_objects.find(self_id).?;
  const self_transform = gs.transforms.find(self_id).?;

  const gc = gs.getGameController();

  const speed
    = self_creature.walk_speed
    + self_creature.walk_speed * gc.enemy_speed_level / 2;

  self_phys.push_dir = null;

  var left_corner = false;
  var right_corner = false;

  // look ahead for corners
  const pos = self_transform.pos;
  const fwd = Math.Direction.normal(self_phys.facing);
  const left = Math.Direction.rotate_ccw(self_phys.facing);
  const right = Math.Direction.rotate_cw(self_phys.facing);
  const left_normal = Math.Direction.normal(left);
  const right_normal = Math.Direction.normal(right);

  var i: u31 = 0;
  while (i < speed) : (i += 1) {
    const new_pos = Math.Vec2.add(pos, Math.Vec2.scale(fwd, i));
    const left_pos = Math.Vec2.add(new_pos, left_normal);
    const right_pos = Math.Vec2.add(new_pos, right_normal);

    if (!phys_in_wall(self_phys, left_pos)) {
      left_corner = true;
    }
    if (!phys_in_wall(self_phys, right_pos)) {
      right_corner = true;
    }
  }

  // decide whether to take a corner
  const left_weight = if (left_corner) u32(1) else u32(0);
  const right_weight = if (right_corner) u32(1) else u32(0);
  const forward_weight: u32 = 2;
  const total_weight = left_weight + right_weight + forward_weight;
  const r = gs.getRand().range(u32, 0, total_weight);
  if (r < left_weight) {
    self_phys.push_dir = left;
  } else if (r < left_weight + right_weight) {
    self_phys.push_dir = right;
  }

  // TODO - sometimes randomly stop/change direction

  self_phys.speed = @intCast(i32, speed);

  return true;
}

pub fn monster_collide(gs: *GameSession, self_id: EntityId, self_monster: *C.Monster) bool {
  const self_creature = gs.creatures.find(self_id).?;
  const self_phys = gs.phys_objects.find(self_id).?;
  const self_transform = gs.transforms.find(self_id).?;

  var hit_wall = false;
  var hit_creature = false;

  for (gs.event_collides.objects[0..gs.event_collides.count]) |*object| {
    if (object.is_active and object.data.self_id.id == self_id.id) {
      if (object.data.other_id.id == 0) {
        hit_wall = true;
      } else {
        if (gs.creatures.find(object.data.other_id)) |other_creature| {
          hit_creature = true;
          if (gs.monsters.find(object.data.other_id) == null) {
            // if it's a non-monster creature, inflict damage on it
            const amount: u32 = 1;
            _ = Prototypes.spawnEventTakeDamage(gs, object.data.other_id, amount);
          }
        }
      }
    }
  }

  if (hit_creature) {
    // reverse direction
    self_phys.facing = Math.Direction.invert(self_phys.facing);
  } else if (hit_wall) {
    // change direction
    const pos = self_transform.pos;

    const left = Math.Direction.rotate_ccw(self_phys.facing);
    const right = Math.Direction.rotate_cw(self_phys.facing);

    const left_normal = Math.Direction.normal(left);
    const right_normal = Math.Direction.normal(right);

    const can_go_left = !phys_in_wall(self_phys, Math.Vec2.add(pos, left_normal));
    const can_go_right = !phys_in_wall(self_phys, Math.Vec2.add(pos, right_normal));

    if (can_go_left and can_go_right) {
      if (gs.getRand().scalar(bool)) {
        self_phys.facing = left;
      } else {
        self_phys.facing = right;
      }
    } else if (can_go_left) {
      self_phys.facing = left;
    } else if (can_go_right) {
      self_phys.facing = right;
    } else {
      self_phys.facing = Math.Direction.invert(self_phys.facing);
    }
  }

  return true;
}
