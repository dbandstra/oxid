const Math = @import("math.zig");
const boxes_overlap = @import("boxes_overlap.zig").boxes_overlap;
const LEVEL = @import("game_level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

pub fn phys_object_frame(gs: *GameSession, self_id: EntityId, self_phys: *C.PhysObject) bool {
  const self_transform = gs.transforms.find(self_id).?;

  var dir_vec = Math.get_dir_vec(self_phys.facing);

  // hit walls
  var i: i32 = 0;
  while (i < self_phys.speed) : (i += 1) {
    // if push_dir differs from velocity direction, and we can move in that
    // direction, redirect velocity to go in that direction
    if (self_phys.push_dir) |pushdir| {
      if (pushdir != self_phys.facing) {
        const new_dir_vec = Math.get_dir_vec(pushdir);
        const new_pos = Math.Vec2.add(self_transform.pos, new_dir_vec);
        if (!LEVEL.box_in_wall(new_pos, self_phys.dims, self_phys.ignore_pits)) {
          dir_vec = new_dir_vec;
          self_phys.facing = pushdir;
          self_transform.pos = new_pos;
          continue;
        }
      }
    }

    const newpos = Math.Vec2.add(self_transform.pos, dir_vec);

    if (LEVEL.box_in_wall(newpos, self_phys.dims, self_phys.ignore_pits)) {
      _ = Prototypes.spawnEventCollide(gs, self_id, EntityId{ .id = 0 });
      return true;
    } else {
      self_transform.pos = newpos;
    }
  }

  // hit other physics objects
  // FIXME - this prioritizes earlier entities in the list!
  for (gs.phys_objects.objects[0..gs.phys_objects.count]) |*other| {
    if (other.is_active and
        other.entity_id.id != self_id.id and
        other.entity_id.id != self_phys.owner_id.id and
        other.data.owner_id.id != self_id.id) {
      const other_phys = &other.data;

      if (switch (self_phys.physType) {
        C.PhysObject.Type.NonSolid => false,
        C.PhysObject.Type.Player => false,
        C.PhysObject.Type.Enemy => other_phys.physType == C.PhysObject.Type.Player,
        C.PhysObject.Type.Bullet => other_phys.physType == C.PhysObject.Type.Enemy,
      }) {
        const other_transform = gs.transforms.find(other.entity_id).?;

        if (boxes_overlap(
          self_transform.pos, self_phys.dims,
          other_transform.pos, other_phys.dims,
        )) {
          _ = Prototypes.spawnEventCollide(gs, self_id, other.entity_id);
          _ = Prototypes.spawnEventCollide(gs, other.entity_id, self_id);
          return true;
        }
      }
    }
  }

  return true;
}
