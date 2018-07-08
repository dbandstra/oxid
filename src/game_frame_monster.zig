const std = @import("std");
const u31 = @import("types.zig").u31;
const Math = @import("math.zig");
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("game_level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const phys_in_wall = @import("game_physics.zig").phys_in_wall;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

pub const MonsterMovementSystem = struct{
  pub const SystemData = struct{
    creature: *C.Creature,
    phys: *C.PhysObject,
    monster: *C.Monster,
    transform: *C.Transform,
  };

  pub fn run(gs: *GameSession) void {
    // can i make this outer loop not tied to a hard coded component?
    // it should use reflection and choose the best one?
    for (gs.monsters.objects) |*object| {
      if (!object.is_active) {
        continue;
      }

      if (gs.creatures.find(object.entity_id)) |creature| {
      if (gs.phys_objects.find(object.entity_id)) |phys| {
      if (gs.transforms.find(object.entity_id)) |transform| {
        const self = SystemData{
          .monster = &object.data,
          .creature = creature,
          .phys = phys,
          .transform = transform,
        };

        monster_move(gs, object.entity_id, self);
        monster_shoot(gs, object.entity_id, self);
      }}}
    }
  }

  fn monster_move(gs: *GameSession, self_id: EntityId, self: SystemData) void {
    const gc = gs.getGameController();

    const speed
      = self.creature.walk_speed
      + self.creature.walk_speed * gc.enemy_speed_level / 2;

    self.phys.push_dir = null;

    var left_corner = false;
    var right_corner = false;

    // look ahead for corners
    const pos = self.transform.pos;
    const fwd = Math.Direction.normal(self.phys.facing);
    const left = Math.Direction.rotate_ccw(self.phys.facing);
    const right = Math.Direction.rotate_cw(self.phys.facing);
    const left_normal = Math.Direction.normal(left);
    const right_normal = Math.Direction.normal(right);

    var i: u31 = 0;
    while (i < speed) : (i += 1) {
      const new_pos = Math.Vec2.add(pos, Math.Vec2.scale(fwd, i));
      const left_pos = Math.Vec2.add(new_pos, left_normal);
      const right_pos = Math.Vec2.add(new_pos, right_normal);

      if (!phys_in_wall(self.phys, left_pos)) {
        left_corner = true;
      }
      if (!phys_in_wall(self.phys, right_pos)) {
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
      self.phys.push_dir = left;
    } else if (r < left_weight + right_weight) {
      self.phys.push_dir = right;
    }

    // TODO - sometimes randomly stop/change direction

    self.phys.speed = @intCast(i32, speed);
  }

  fn monster_shoot(gs: *GameSession, self_id: EntityId, self: SystemData) void {
    if (self.monster.next_shoot_timer > 0) {
      self.monster.next_shoot_timer -= 1;
    } else {
      // spawn the bullet one quarter of a grid cell in front of the monster
      const pos = self.transform.pos;
      const dir_vec = Math.Direction.normal(self.phys.facing);
      const ofs = Math.Vec2.scale(dir_vec, GRIDSIZE_SUBPIXELS / 4);
      const bullet_pos = Math.Vec2.add(pos, ofs);
      _ = Prototypes.Bullet.spawn(gs, Prototypes.Bullet.Params{
        .owner_id = self_id,
        .pos = bullet_pos,
        .facing = self.phys.facing,
        .bullet_type = Prototypes.Bullet.BulletType.MonsterBullet,
      });
      self.monster.next_shoot_timer = 100;
    }
  }
};

pub const MonsterTouchResponseSystem = struct{
  pub fn run(gs: *GameSession) void {
    for (gs.monsters.objects) |*object| {
      if (!object.is_active) {
        continue;
      }
      monster_collide(gs, object.entity_id, &object.data);
    }
  }

  fn monster_collide(gs: *GameSession, self_id: EntityId, self_monster: *C.Monster) void {
    const self_creature = gs.creatures.find(self_id).?;
    const self_phys = gs.phys_objects.find(self_id).?;
    const self_transform = gs.transforms.find(self_id).?;

    var hit_wall = false;
    var hit_creature = false;

    for (gs.event_collides.objects) |*object| {
      if (!object.is_active) {
        continue;
      }
      const event_collide = &object.data;
      if (event_collide.self_id.id == self_id.id) {
        if (event_collide.other_id.id == 0) {
          hit_wall = true;
        } else {
          if (gs.creatures.find(event_collide.other_id)) |other_creature| {
            if (event_collide.propelled) {
              hit_creature = true;
            }
            if (gs.monsters.find(event_collide.other_id) == null) {
              // if it's a non-monster creature, inflict damage on it
              _ = Prototypes.EventTakeDamage.spawn(gs, Prototypes.EventTakeDamage.Params{
                .self_id = event_collide.other_id,
                .amount = 1,
              });
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
  }
};
