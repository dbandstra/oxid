const Math = @import("math.zig");
const Constants = @import("game_constants.zig");
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const decrementTimer = @import("game_frame.zig").decrementTimer;
const phys_in_wall = @import("game_physics.zig").phys_in_wall;
const BuildSystem = @import("game_system.zig").BuildSystem;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

// TODO - system should be able to read all of these, but only write to them
// one (player)...
// right now, other than player fields, it's writing:
// - self.phys.speed
// - self.phys.push_dir
// - self.phys.facing
// that's it. the react system is also writing self.creature.walk_speed.
// need an Event to set phys fields.

pub const PlayerMovementSystem = struct{
  const SystemData = struct{
    creature: *C.Creature,
    phys: *C.PhysObject,
    player: *C.Player,
    transform: *C.Transform,
  };

  pub const run = BuildSystem(SystemData, C.Player, think);

  fn think(gs: *GameSession, self_id: EntityId, self: SystemData) bool {
    if (decrementTimer(&self.player.dying_timer)) {
      _ = Prototypes.Corpse.spawn(gs, Prototypes.Corpse.Params{
        .pos = self.transform.pos,
      });
      return false;
    } else if (self.player.dying_timer > 0) {
      self.phys.speed = 0;
      self.phys.push_dir = null;
    } else {
      playerMove(gs, self_id, self);
      playerShoot(gs, self_id, self);
    }
    return true;
  }

  fn playerShoot(gs: *GameSession, self_id: EntityId, self: SystemData) void {
    if (gs.in_shoot) {
      if (self.player.trigger_released) {
        // the player can only have a certain amount of bullets in play at a
        // time.
        // look for a bullet slot that is either null (never been used) or a
        // non-existent entity (old bullet is gone)
        if (for (self.player.bullets) |*slot| {
          if (slot.*) |bullet_id| {
            if (gs.find(bullet_id, C.Bullet) == null) {
              break slot;
            }
          } else {
            break slot;
          }
        } else null) |slot| {
          // spawn the bullet one quarter of a grid cell in front of the player
          const pos = self.transform.pos;
          const dir_vec = Math.Direction.normal(self.phys.facing);
          const ofs = Math.Vec2.scale(dir_vec, GRIDSIZE_SUBPIXELS / 4);
          const bullet_pos = Math.Vec2.add(pos, ofs);
          slot.* = Prototypes.Bullet.spawn(gs, Prototypes.Bullet.Params{
            .inflictor_player_controller_id = self.player.player_controller_id,
            .owner_id = self_id,
            .pos = bullet_pos,
            .facing = self.phys.facing,
            .bullet_type = Prototypes.Bullet.BulletType.PlayerBullet,
            .cluster_size = switch (self.player.attack_level) {
              C.Player.AttackLevel.One => u32(1),
              C.Player.AttackLevel.Two => u32(2),
              C.Player.AttackLevel.Three => u32(3),
            },
          });
          self.player.trigger_released = false;
        }
      }
    } else {
      self.player.trigger_released = true;
    }
  }

  fn playerMove(gs: *GameSession, self_id: EntityId, self: SystemData) void {
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

pub const PlayerReactionSystem = struct{
  pub const SystemData = struct{
    creature: *C.Creature,
    phys: *C.PhysObject,
    player: *C.Player,
    transform: *C.Transform,
  };

  pub const run = BuildSystem(SystemData, C.Player, playerReact);

  fn playerReact(gs: *GameSession, self_id: EntityId, self: SystemData) bool {
    var it = gs.eventIter(C.EventConferBonus, "recipient_id", self_id); while (it.next()) |event| {
      switch (event.pickup_type) {
        C.Pickup.Type.PowerUp => {
          self.player.attack_level = switch (self.player.attack_level) {
            C.Player.AttackLevel.One => C.Player.AttackLevel.Two,
            else => C.Player.AttackLevel.Three,
          };
        },
        C.Pickup.Type.SpeedUp => {
          self.player.speed_level = switch (self.player.speed_level) {
            C.Player.SpeedLevel.One => C.Player.SpeedLevel.Two,
            else => C.Player.SpeedLevel.Three,
          };
          self.creature.walk_speed = switch (self.player.speed_level) {
            C.Player.SpeedLevel.One => Constants.PlayerWalkSpeed1,
            C.Player.SpeedLevel.Two => Constants.PlayerWalkSpeed2,
            C.Player.SpeedLevel.Three => Constants.PlayerWalkSpeed3,
          };
        },
      }
    }
    return true;
  }
};
