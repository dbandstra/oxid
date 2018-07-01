const std = @import("std");
const Math = @import("math.zig");
const LEVEL = @import("game_level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const C = @import("game_components.zig");

pub fn monster_frame(gs: *GameSession, self_id: EntityId, self_enemy: *C.Monster) bool {
  const self_creature = gs.creatures.find(self_id).?;
  const self_phys = gs.phys_objects.find(self_id).?;
  const self_transform = gs.transforms.find(self_id).?;

  var speed: u32 = undefined;
  const gcobj = gs.game_controllers.objects[0];
  std.debug.assert(gcobj.is_active == true);
  const gc = gcobj.data;
  speed = self_creature.walk_speed;
  speed += self_creature.walk_speed * gc.enemy_speed_level / 2;

  // TODO - take corners
  // TODO - sometimes randomly stop/change direction

  var i: u32 = 0;
  while (i < speed) : (i += 1) {
    // move forward one pixel
    const dir = Math.get_dir_vec(self_phys.facing);

    const newpos = Math.Vec2.add(self_transform.pos, dir);

    if (LEVEL.box_in_wall(newpos, self_phys.dims, false)) {
      // hit wall. don't move. change direction
      const r = gs.getRand().scalar(bool);
      self_phys.facing = switch(self_phys.facing) {
        Math.Direction.Up => if (r) Math.Direction.Right else Math.Direction.Left,
        Math.Direction.Right => if (r) Math.Direction.Down else Math.Direction.Up,
        Math.Direction.Down => if (r) Math.Direction.Left else Math.Direction.Right,
        Math.Direction.Left => if (r) Math.Direction.Up else Math.Direction.Down,
      };
      return true;
    } else {
      self_transform.pos = newpos;
    }
  }

  return true;
}
