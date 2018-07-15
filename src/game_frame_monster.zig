const std = @import("std");
const u31 = @import("types.zig").u31;
const lessThanField = @import("util.zig").lessThanField;
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

    // look ahead for corners
    const pos = self.transform.pos;
    const fwd = Math.Direction.normal(self.phys.facing);
    const left = Math.Direction.rotate_ccw(self.phys.facing);
    const right = Math.Direction.rotate_cw(self.phys.facing);
    const left_normal = Math.Direction.normal(left);
    const right_normal = Math.Direction.normal(right);

    var wall_in_front = false;
    var left_corner = false;
    var right_corner = false;

    if (phys_in_wall(self.phys, pos)) {
      // stuck in a wall
      return;
    }

    var i: u31 = 0;
    while (i < speed) : (i += 1) {
      const new_pos = Math.Vec2.add(pos, Math.Vec2.scale(fwd, i));
      const left_pos = Math.Vec2.add(new_pos, left_normal);
      const right_pos = Math.Vec2.add(new_pos, right_normal);

      if (i > 0 and phys_in_wall(self.phys, new_pos)) {
        wall_in_front = true;
      }
      if (!phys_in_wall(self.phys, left_pos)) {
        left_corner = true;
      }
      if (!phys_in_wall(self.phys, right_pos)) {
        right_corner = true;
      }
    }

    if (choose_turn(gs, self.monster.personality, pos, self.phys.facing, !wall_in_front, left_corner, right_corner)) |dir| {
      self.phys.push_dir = dir;
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
      self.monster.next_shoot_timer = gs.getRand().range(u32, 75, 400);
    }
  }

  fn choose_turn(
    gs: *GameSession,
    personality: C.Monster.Personality,
    pos: Math.Vec2,
    facing: Math.Direction,
    can_go_forward: bool,
    can_go_left: bool,
    can_go_right: bool,
  ) ?Math.Direction {
    const left = Math.Direction.rotate_ccw(facing);
    const right = Math.Direction.rotate_cw(facing);

    var choices = Choices.init();

    if (personality == C.Monster.Personality.Chase) {
      if (for (gs.players.objects) |*player| {
        if (player.is_active) {
          break gs.transforms.find(player.entity_id).?.pos;
        }
      } else null) |player_pos| {
        const fwd = Math.Direction.normal(facing);
        const left_normal = Math.Direction.normal(left);
        const right_normal = Math.Direction.normal(right);

        const forward_point = Math.Vec2.add(pos, Math.Vec2.scale(fwd, GRIDSIZE_SUBPIXELS));
        const left_point = Math.Vec2.add(pos, Math.Vec2.scale(left_normal, GRIDSIZE_SUBPIXELS));
        const right_point = Math.Vec2.add(pos, Math.Vec2.scale(right_normal, GRIDSIZE_SUBPIXELS));

        const forward_point_dist = Math.Vec2.manhattan_distance(forward_point, player_pos);
        const left_point_dist = Math.Vec2.manhattan_distance(left_point, player_pos);
        const right_point_dist = Math.Vec2.manhattan_distance(right_point, player_pos);

        if (can_go_forward) {
          choices.add(facing, forward_point_dist);
        }
        if (can_go_left) {
          choices.add(left, left_point_dist);
        }
        if (can_go_right) {
          choices.add(right, right_point_dist);
        }

        if (choices.choose()) |best_direction| {
          if (best_direction != facing) {
            return best_direction;
          }
        }

        return null;
      }
    }

    // wandering
    if (can_go_forward) {
      choices.add(facing, 2);
    }
    if (can_go_left) {
      choices.add(left, 1);
    }
    if (can_go_right) {
      choices.add(right, 1);
    }
    const total_score = blk: {
      var total: u32 = 0;
      for (choices.choices[0..choices.num_choices]) |choice| {
        total += choice.score;
      }
      break :blk total;
    };
    var r = gs.getRand().range(u32, 0, total_score);
    for (choices.choices[0..choices.num_choices]) |choice| {
      if (r < choice.score) {
        return choice.direction;
      } else {
        r -= choice.score;
      }
    }

    return null;
  }
};

const Choice = struct{
  direction: Math.Direction,
  score: u32, // lower is better
};

const Choices = struct{
  choices: [4]Choice,
  num_choices: usize,

  pub fn init() Choices {
    return Choices{
      .choices = undefined,
      .num_choices = 0,
    };
  }

  pub fn add(self: *Choices, direction: Math.Direction, score: u32) void {
    self.choices[self.num_choices] = Choice{
      .direction = direction,
      .score = score,
    };
    self.num_choices += 1;
  }

  pub fn choose(self: *Choices) ?Math.Direction {
    if (self.num_choices > 0) {
      // TODO - use random if there is a tie.
      std.sort.sort(Choice, self.choices[0..self.num_choices], lessThanField(Choice, "score"));
      return self.choices[0].direction;
    } else {
      return null;
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
    }
  }
};
