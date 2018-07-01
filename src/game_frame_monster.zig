const std = @import("std");
const Math = @import("math.zig");
const LEVEL = @import("game_level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const C = @import("game_components.zig");

pub fn monster_frame(gs: *GameSession, self_id: EntityId, self_monster: *C.Monster) bool {
  const self_creature = gs.creatures.find(self_id).?;
  const self_phys = gs.phys_objects.find(self_id).?;
  const self_transform = gs.transforms.find(self_id).?;

  var speed: i32 = undefined;
  const gcobj = gs.game_controllers.objects[0];
  std.debug.assert(gcobj.is_active == true);
  const gc = gcobj.data;
  speed = self_creature.walk_speed;
  speed += @intCast(i32, self_creature.walk_speed * gc.enemy_speed_level / 2);

  // TODO - take corners
  // TODO - sometimes randomly stop/change direction

  self_phys.speed = speed;

  return true;
}

pub fn monster_react(gs: *GameSession, self_id: EntityId, self_monster: *C.Monster) bool {
  const self_creature = gs.creatures.find(self_id).?;
  const self_phys = gs.phys_objects.find(self_id).?;

  var hit_wall = false;

  for (gs.event_collides.objects[0..gs.event_collides.count]) |*object| {
    if (object.is_active and object.data.self_id.id == self_id.id) {
      if (object.data.other_id.id == 0) {
        hit_wall = true;
      }
    }
  }

  if (hit_wall) {
    // change direction
    const r = gs.getRand().scalar(bool);
    self_phys.facing = switch(self_phys.facing) {
      Math.Direction.Up => if (r) Math.Direction.Right else Math.Direction.Left,
      Math.Direction.Right => if (r) Math.Direction.Down else Math.Direction.Up,
      Math.Direction.Down => if (r) Math.Direction.Left else Math.Direction.Right,
      Math.Direction.Left => if (r) Math.Direction.Up else Math.Direction.Down,
    };
  }

  return true;
}
