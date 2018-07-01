const std = @import("std");
const u31 = @import("types.zig").u31;
const Math = @import("math.zig");
const Constants = @import("game_constants.zig");
const LEVEL = @import("game_level.zig").LEVEL;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

pub fn player_frame(gs: *GameSession, entity_id: EntityId, self_player: *C.Player) bool {
  const self_phys = gs.phys_objects.find(entity_id).?;
  const self_transform = gs.transforms.find(entity_id).?;

  player_move(gs, entity_id, self_player);

  if (gs.shoot) {
    // player is 16x16, bullet is 4x4
    const bullet_ofs = Math.Vec2.init(6 * Math.SUBPIXELS, 6 * Math.SUBPIXELS);
    _ = Prototypes.spawnBullet(gs, entity_id, Math.Vec2.add(self_transform.pos, bullet_ofs), self_phys.facing);
    gs.shoot = false;
  }

  return true;
}

pub fn player_react(gs: *GameSession, entity_id: EntityId, self_player: *C.Player) bool {
  return true;
}

fn player_move(gs: *GameSession, entity_id: EntityId, self_player: *C.Player) void {
  const self_creature = gs.creatures.find(entity_id).?;
  const self_phys = gs.phys_objects.find(entity_id).?;
  const self_transform = gs.transforms.find(entity_id).?;

  var xmove: i32 = 0;
  var ymove: i32 = 0;
  if (gs.in_right) { xmove += 1; }
  if (gs.in_left) { xmove -= 1; }
  if (gs.in_down) { ymove += 1; }
  if (gs.in_up) { ymove -= 1; }

  self_phys.speed = 0;
  self_phys.push_dir = null;

  const pos = self_transform.pos;

  if (xmove != 0) {
    const dir = if (xmove < 0) Math.Direction.Left else Math.Direction.Right;

    if (ymove == 0) {
      // only moving left/right. try to slip around corners
      try_push(pos, dir, self_creature.walk_speed, self_phys);
    } else {
      // trying to move diagonally.
      const secondary_dir = if (ymove < 0) Math.Direction.Up else Math.Direction.Down;

      // prefer to move horizontally (arbitrary, but i had to pick something)
      if (!LEVEL.box_in_wall(Math.Vec2.add(pos, Math.get_dir_vec(dir)), self_phys.dims, self_phys.ignore_pits)) {
        self_phys.facing = dir;
        self_phys.speed = self_creature.walk_speed;
      } else if (!LEVEL.box_in_wall(Math.Vec2.add(pos, Math.get_dir_vec(secondary_dir)), self_phys.dims, self_phys.ignore_pits)) {
        self_phys.facing = secondary_dir;
        self_phys.speed = self_creature.walk_speed;
      }
    }
  } else if (ymove != 0) {
    // only moving up/right. try to slip around corners
    const dir = if (ymove < 0) Math.Direction.Up else Math.Direction.Down;

    try_push(pos, dir, self_creature.walk_speed, self_phys);
  }
}

fn try_push(pos: Math.Vec2, dir: Math.Direction, speed: i32, self_phys: *C.PhysObject) void {
  const pos1 = Math.Vec2.add(pos, Math.get_dir_vec(dir));

  if (!LEVEL.box_in_wall(pos1, self_phys.dims, self_phys.ignore_pits)) {
    // no need to push, this direction works
    self_phys.facing = dir;
    self_phys.speed = speed;
    return;
  }

  var slip_dir: ?Math.Direction = null;

  var i: i32 = 1;
  while (i < Constants.PlayerSlipThreshold) : (i += 1) {
    if (dir == Math.Direction.Left or dir == Math.Direction.Right) {
      if (!LEVEL.box_in_wall(Math.Vec2.init(pos1.x, pos1.y - i), self_phys.dims, self_phys.ignore_pits)) {
        slip_dir = Math.Direction.Up;
        break;
      }
      if (!LEVEL.box_in_wall(Math.Vec2.init(pos1.x, pos1.y + i), self_phys.dims, self_phys.ignore_pits)) {
        slip_dir = Math.Direction.Down;
        break;
      }
    }
    if (dir == Math.Direction.Up or dir == Math.Direction.Down) {
      if (!LEVEL.box_in_wall(Math.Vec2.init(pos1.x - i, pos1.y), self_phys.dims, self_phys.ignore_pits)) {
        slip_dir = Math.Direction.Left;
        break;
      }
      if (!LEVEL.box_in_wall(Math.Vec2.init(pos1.x + i, pos1.y), self_phys.dims, self_phys.ignore_pits)) {
        slip_dir = Math.Direction.Right;
        break;
      }
    }
  }

  if (slip_dir) |slipdir| {
    self_phys.facing = slipdir;
    self_phys.speed = speed;
    self_phys.push_dir = dir;
  }
}
