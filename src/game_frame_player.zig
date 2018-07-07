const std = @import("std");
const u31 = @import("types.zig").u31;
const Math = @import("math.zig");
const Constants = @import("game_constants.zig");
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const RunFrame = @import("game_frame.zig").RunFrame;
const phys_in_wall = @import("game_physics.zig").phys_in_wall;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

pub const PlayerMovementSystem = struct{
  pub const SystemData = struct{
    creature: *C.Creature,
    phys: *C.PhysObject,
    player: *C.Player,
    transform: *C.Transform,
  };

  pub fn run(gs: *GameSession) void {
    // can i make this outer loop not tied to a hard coded component?
    // it should use reflection and choose the best one?
    for (gs.players.objects[0..gs.players.count]) |*object| {
      if (!object.is_active) {
        continue;
      }

      if (gs.creatures.find(object.entity_id)) |creature| {
      if (gs.phys_objects.find(object.entity_id)) |phys| {
      if (gs.transforms.find(object.entity_id)) |transform| {
        const self = SystemData{
          .player = &object.data,
          .creature = creature,
          .phys = phys,
          .transform = transform,
        };

        player_move(gs, object.entity_id, self);
        player_shoot(gs, object.entity_id, self);
      }}}
    }
  }

  fn player_shoot(gs: *GameSession, self_id: EntityId, self: SystemData) void {
    if (gs.shoot) {
      // spawn the bullet one quarter of a grid cell in front of the player
      const pos = self.transform.pos;
      const dir_vec = Math.Direction.normal(self.phys.facing);
      const ofs = Math.Vec2.scale(dir_vec, GRIDSIZE_SUBPIXELS / 4);
      const bullet_pos = Math.Vec2.add(pos, ofs);
      _ = Prototypes.Bullet.spawn(gs, Prototypes.Bullet.Params{
        .owner_id = self_id,
        .pos = bullet_pos,
        .facing = self.phys.facing,
        .bullet_type = Prototypes.Bullet.BulletType.PlayerBullet,
      });
      gs.shoot = false; // FIXME
    }
  }

  fn player_move(gs: *GameSession, self_id: EntityId, self: SystemData) void {
    var xmove: i32 = 0;
    var ymove: i32 = 0;
    if (gs.in_right) { xmove += 1; }
    if (gs.in_left) { xmove -= 1; }
    if (gs.in_down) { ymove += 1; }
    if (gs.in_up) { ymove -= 1; }

    self.phys.speed = 0;
    self.phys.push_dir = null;

    const pos = self.transform.pos;

    if (xmove != 0) {
      const dir = if (xmove < 0) Math.Direction.W else Math.Direction.E;

      if (ymove == 0) {
        // only moving along x axis. try to slip around corners
        try_push(pos, dir, self.creature.walk_speed, self.phys);
      } else {
        // trying to move diagonally.
        const secondary_dir = if (ymove < 0) Math.Direction.N else Math.Direction.S;

        // prefer to move on the x axis (arbitrary, but i had to pick something)
        if (!phys_in_wall(self.phys, Math.Vec2.add(pos, Math.Direction.normal(dir)))) {
          self.phys.facing = dir;
          self.phys.speed = self.creature.walk_speed;
        } else if (!phys_in_wall(self.phys, Math.Vec2.add(pos, Math.Direction.normal(secondary_dir)))) {
          self.phys.facing = secondary_dir;
          self.phys.speed = self.creature.walk_speed;
        }
      }
    } else if (ymove != 0) {
      // only moving along y axis. try to slip around corners
      const dir = if (ymove < 0) Math.Direction.N else Math.Direction.S;

      try_push(pos, dir, self.creature.walk_speed, self.phys);
    }
  }

  fn try_push(pos: Math.Vec2, dir: Math.Direction, speed: i32, self_phys: *C.PhysObject) void {
    const pos1 = Math.Vec2.add(pos, Math.Direction.normal(dir));

    if (!phys_in_wall(self_phys, pos1)) {
      // no need to push, this direction works
      self_phys.facing = dir;
      self_phys.speed = speed;
      return;
    }

    var slip_dir: ?Math.Direction = null;

    var i: i32 = 1;
    while (i < Constants.PlayerSlipThreshold) : (i += 1) {
      if (dir == Math.Direction.W or dir == Math.Direction.E) {
        if (!phys_in_wall(self_phys, Math.Vec2.init(pos1.x, pos1.y - i))) {
          slip_dir = Math.Direction.N;
          break;
        }
        if (!phys_in_wall(self_phys, Math.Vec2.init(pos1.x, pos1.y + i))) {
          slip_dir = Math.Direction.S;
          break;
        }
      }
      if (dir == Math.Direction.N or dir == Math.Direction.S) {
        if (!phys_in_wall(self_phys, Math.Vec2.init(pos1.x - i, pos1.y))) {
          slip_dir = Math.Direction.W;
          break;
        }
        if (!phys_in_wall(self_phys, Math.Vec2.init(pos1.x + i, pos1.y))) {
          slip_dir = Math.Direction.E;
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
};

pub const PlayerTouchResponseSystem = struct{
  pub fn run(gs: *GameSession) void {
    for (gs.players.objects[0..gs.players.count]) |*object| {
      if (!object.is_active) {
        continue;
      }
      player_collide(gs, object.entity_id, &object.data);
    }
  }

  // if player touches a monster, damage self
  fn player_collide(gs: *GameSession, self_id: EntityId, self_player: *C.Player) void {
    for (gs.event_collides.objects[0..gs.event_collides.count]) |*object| {
      if (object.is_active and object.data.self_id.id == self_id.id) {
        if (object.data.other_id.id != 0) {
          if (gs.monsters.find(object.data.other_id)) |_| {
            const amount: u32 = 1;
            _ = Prototypes.EventTakeDamage.spawn(gs, Prototypes.EventTakeDamage.Params{
              .self_id = self_id,
              .amount = amount,
            });
          }
        }
      }
    }
  }
};
