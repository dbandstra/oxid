const std = @import("std");
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
    for (gs.players.objects) |*object| {
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
    if (gs.in_shoot) {
      if (self.player.trigger_released) {
        // the player can only have a certain amount of bullets in play at a
        // time.
        // look for a bullet slot that is either null (never been used) or a
        // non-existent entity (old bullet is gone)
        if (for (self.player.bullets) |*slot| {
          if (slot.*) |bullet_id| {
            if (gs.bullets.find(bullet_id) == null) {
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

pub const PlayerReactionSystem = struct{
  pub fn run(gs: *GameSession) void {
    for (gs.players.objects) |*object| {
      if (!object.is_active) {
        continue;
      }
      player_react(gs, object.entity_id, &object.data);
    }
  }

  fn player_react(gs: *GameSession, self_id: EntityId, self_player: *C.Player) void {
    const self_creature = gs.creatures.find(self_id).?;
    const self_phys = gs.phys_objects.find(self_id).?;
    const self_transform = gs.transforms.find(self_id).?;

    for (gs.event_confer_bonuses.objects) |*object| {
      if (!object.is_active) {
        continue;
      }
      const event_confer_bonus = &object.data;
      if (event_confer_bonus.recipient_id.id == self_id.id) {
        switch (event_confer_bonus.pickup_type) {
          C.Pickup.Type.PowerUp => {
            self_player.attack_level = switch (self_player.attack_level) {
              C.Player.AttackLevel.One => C.Player.AttackLevel.Two,
              else => C.Player.AttackLevel.Three,
            };
          },
          C.Pickup.Type.SpeedUp => {
            self_player.speed_level = switch (self_player.speed_level) {
              C.Player.SpeedLevel.One => C.Player.SpeedLevel.Two,
              else => C.Player.SpeedLevel.Three,
            };
            self_creature.walk_speed = switch (self_player.speed_level) {
              C.Player.SpeedLevel.One => Constants.PlayerWalkSpeed1,
              C.Player.SpeedLevel.Two => Constants.PlayerWalkSpeed2,
              C.Player.SpeedLevel.Three => Constants.PlayerWalkSpeed3,
            };
          },
        }
      }
    }
  }
};
