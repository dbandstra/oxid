const SUBPIXELS = @import("math.zig").SUBPIXELS;
const Direction = @import("math.zig").Direction;
const Vec2 = @import("math.zig").Vec2;
const get_dir_vec = @import("math.zig").get_dir_vec;
const boxes_overlap = @import("boxes_overlap.zig").boxes_overlap;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("game_level.zig").LEVEL;
const ComponentList = @import("game.zig").ComponentList;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const Constants = @import("game_constants.zig");
const MonsterType = @import("game_init.zig").MonsterType;
const game_spawn_monsters = @import("game_init.zig").game_spawn_monsters;
const game_spawn_player = @import("game_init.zig").game_spawn_player;
const components = @import("game_components.zig");
const Animation = components.Animation;
const Bullet = components.Bullet;
const Creature = components.Creature;
const GameController = components.GameController;
const Monster = components.Monster;
const PhysObject = components.PhysObject;
const Player = components.Player;
const PlayerController = components.PlayerController;
const EventCollide = components.EventCollide;
const EventMonsterKilled = components.EventMonsterKilled;
const EventPlayerDied = components.EventPlayerDied;
const EventTakeDamage = components.EventTakeDamage;
const Prototypes = @import("game_prototypes.zig");
const physics_frame = @import("game_physics.zig").physics_frame;
const MonsterMovementSystem = @import("game_frame_monster.zig").MonsterMovementSystem;
const MonsterTouchResponseSystem = @import("game_frame_monster.zig").MonsterTouchResponseSystem;
const PlayerMovementSystem = @import("game_frame_player.zig").PlayerMovementSystem;

fn RunFrame(
  comptime T: type,
  gs: *GameSession,
  list: *ComponentList(T),
  func: ?fn(*GameSession, EntityId, *T)bool,
) void {
  for (list.objects) |*object| {
    if (object.is_active) {
      if (func) |f| {
        if (!f(gs, object.entity_id, &object.data)) {
          gs.remove(object.entity_id);
        }
      } else {
        gs.remove(object.entity_id);
      }
    }
  }
}

pub fn game_frame(gs: *GameSession) void {
  RunFrame(GameController, gs, &gs.game_controllers, game_controller_frame);
  RunFrame(PlayerController, gs, &gs.player_controllers, player_controller_frame);
  RunFrame(Animation, gs, &gs.animations, animation_frame);
  PlayerMovementSystem.run(gs);
  MonsterMovementSystem.run(gs);
  RunFrame(Creature, gs, &gs.creatures, creature_frame);

  physics_frame(gs);

  // bullets react to event_collide, spawn event_take_damage
  RunFrame(Bullet, gs, &gs.bullets, bullet_collide);
  // monsters react to event_collide, damage others
  MonsterTouchResponseSystem.run(gs);

  // creatures react to event_take_damage, die
  RunFrame(Creature, gs, &gs.creatures, creature_take_damage);

  // player controller reacts to 'player died' event
  RunFrame(PlayerController, gs, &gs.player_controllers, player_controller_react);

  RunFrame(EventCollide, gs, &gs.event_collides, null);
  RunFrame(EventMonsterKilled, gs, &gs.event_monster_killeds, null);
  RunFrame(EventPlayerDied, gs, &gs.event_player_dieds, null);
  RunFrame(EventTakeDamage, gs, &gs.event_take_damages, null);

  gs.purge_removed();
  gs.frameindex +%= 1;
}

fn game_controller_frame(gs: *GameSession, self_id: EntityId, self: *GameController) bool {
  if (self.next_wave_timer == 0) {
    // are all monsters dead
    var num_monsters: u32 = 0;
    for (gs.monsters.objects) |object| {
      if (object.is_active) {
        num_monsters += 1;
      }
    }
    if (num_monsters == 0) {
      // prepare next wave
      self.next_wave_timer = 90;
    }
  } else {
    self.next_wave_timer -= 1;
    if (self.next_wave_timer == 0) {
      self.wave_index += 1;
      self.enemy_speed_level = 0;
      self.enemy_speed_ticks = 0;
      switch (self.wave_index) {
        1 => {
          game_spawn_monsters(gs, 8, MonsterType.Spider);
        },
        2 => {
          game_spawn_monsters(gs, 8, MonsterType.Squid);
        },
        3 => {
          game_spawn_monsters(gs, 12, MonsterType.Spider);
        },
        4 => {
          game_spawn_monsters(gs, 4, MonsterType.Squid);
          game_spawn_monsters(gs, 10, MonsterType.Spider);
        },
        5 => {
          game_spawn_monsters(gs, 20, MonsterType.Spider);
        },
        6 => {
          game_spawn_monsters(gs, 14, MonsterType.Squid);
        },
        7 => {
          game_spawn_monsters(gs, 8, MonsterType.Spider);
          game_spawn_monsters(gs, 8, MonsterType.Squid);
          self.enemy_speed_level = 1;
        },
        8 => {
          game_spawn_monsters(gs, 10, MonsterType.Spider);
          game_spawn_monsters(gs, 10, MonsterType.Squid);
          self.enemy_speed_level = 1;
        },
        else => {
          // done
          game_spawn_monsters(gs, 1, MonsterType.Spider);
        },
      }
    }
  }

  self.enemy_speed_ticks += 1;
  if (self.enemy_speed_ticks == 800) {
    if (self.enemy_speed_level < 4) {
      self.enemy_speed_level += 1;
    }
    self.enemy_speed_ticks = 0;
  }
  return true;
}

fn player_controller_frame(gs: *GameSession, self_id: EntityId, self: *PlayerController) bool {
  if (self.respawn_timer > 0) {
    self.respawn_timer -= 1;
    if (self.respawn_timer == 0) {
      game_spawn_player(gs, self_id);
    }
  }
  return true;
}

fn player_controller_react(gs: *GameSession, self_id: EntityId, self: *PlayerController) bool {
  for (gs.event_player_dieds.objects) |object| {
    if (object.is_active) {
      if (self.lives > 0) {
        self.lives -= 1;
        if (self.lives > 0) {
          self.respawn_timer = Constants.PlayerRespawnTime;
        }
      }
    }
  }
  for (gs.event_monster_killeds.objects) |object| {
    if (object.is_active) {
      if (object.data.player_controller_id.id == self_id.id) {
        self.score += object.data.points;
      }
    }
  }
  return true;
}

fn animation_frame(gs: *GameSession, self_id: EntityId, self: *Animation) bool {
  const animcfg = getSimpleAnim(self.simple_anim);

  self.ticks += 1;
  if (self.ticks >= animcfg.ticks_per_frame) {
    self.ticks = 0;
    self.frame_index += 1;
    if (self.frame_index >= animcfg.frames.len) {
      return false;
    }
  }

  return true;
}

fn creature_frame(gs: *GameSession, self_id: EntityId, self_creature: *Creature) bool {
  if (self_creature.invulnerability_timer > 0) {
    self_creature.invulnerability_timer -= 1;
  }
  return true;
}

pub fn bullet_collide(gs: *GameSession, self_id: EntityId, self_bullet: *Bullet) bool {
  for (gs.event_collides.objects) |*object| {
    if (object.is_active and object.data.self_id.id == self_id.id) {
      const self_transform = gs.transforms.find(self_id).?;
      _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
        .pos = self_transform.pos,
        .simple_anim = SimpleAnim.PlaSparks,
        .z_index = Constants.ZIndexSparks,
      });
      if (object.data.other_id.id != 0) {
        _ = Prototypes.EventTakeDamage.spawn(gs, Prototypes.EventTakeDamage.Params{
          .inflictor_player_controller_id = self_bullet.inflictor_player_controller_id,
          .self_id = object.data.other_id,
          .amount = 1,
        });
      }
      return false;
    }
  }
  return true;
}

pub fn creature_take_damage(gs: *GameSession, self_id: EntityId, self_creature: *Creature) bool {
  if (self_creature.invulnerability_timer > 0) {
    return true;
  }
  for (gs.event_take_damages.objects) |*object| {
    if (object.is_active and object.data.self_id.id == self_id.id) {
      if (gs.players.find(self_id)) |_| {
        if (gs.god_mode) {
          continue;
        }
      }
      const amount = object.data.amount;
      if (self_creature.hit_points > amount) {
        self_creature.hit_points -= amount;
      } else if (self_creature.hit_points > 0) {
        self_creature.hit_points = 0;
        const self_transform = gs.transforms.find(self_id).?;
        if (gs.players.find(self_id)) |_| {
          // player died
          _ = Prototypes.EventPlayerDied.spawn(gs);
          _ = Prototypes.Corpse.spawn(gs, Prototypes.Corpse.Params{
            .pos = self_transform.pos,
          });
          return false;
        } else {
          if (gs.monsters.find(self_id)) |self_monster| {
            if (object.data.inflictor_player_controller_id) |player_controller_id| {
              _ = Prototypes.EventMonsterKilled.spawn(gs, Prototypes.EventMonsterKilled.Params{
                .player_controller_id = player_controller_id,
                .points = self_monster.kill_points,
              });
            }
          }
          // something other than a player died
          _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
            .pos = self_transform.pos,
            .simple_anim = SimpleAnim.Explosion,
            .z_index = Constants.ZIndexExplosion,
          });
          return false;
        }
      }
    }
  }
  return true;
}
