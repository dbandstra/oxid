const std = @import("std");
const u31 = @import("types.zig").u31;
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
const SpawningMonster = components.SpawningMonster;
const EventCollide = components.EventCollide;
const EventPlayerDied = components.EventPlayerDied;
const Prototypes = @import("game_prototypes.zig");
const monster_frame = @import("game_frame_monster.zig").monster_frame;
const monster_react = @import("game_frame_monster.zig").monster_react;
const phys_object_frame = @import("game_frame_phys.zig").phys_object_frame;
const player_frame = @import("game_frame_player.zig").player_frame;
const player_react = @import("game_frame_player.zig").player_react;

fn RunFrame(
  comptime T: type,
  gs: *GameSession,
  list: *ComponentList(T),
  func: ?fn(*GameSession, EntityId, *T)bool,
) void {
  for (list.objects[0..list.count]) |*object| {
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
  RunFrame(SpawningMonster, gs, &gs.spawning_monsters, spawning_monster_frame);
  RunFrame(Animation, gs, &gs.animations, animation_frame);
  RunFrame(Player, gs, &gs.players, player_frame);
  RunFrame(Monster, gs, &gs.monsters, monster_frame);
  RunFrame(Creature, gs, &gs.creatures, creature_frame);
  RunFrame(PhysObject, gs, &gs.phys_objects, phys_object_frame);
  RunFrame(Bullet, gs, &gs.bullets, bullet_react);
  RunFrame(Creature, gs, &gs.creatures, creature_react);
  RunFrame(Player, gs, &gs.players, player_react);
  RunFrame(Monster, gs, &gs.monsters, monster_react);
  RunFrame(GameController, gs, &gs.game_controllers, game_controller_react);

  RunFrame(EventCollide, gs, &gs.event_collides, null);
  RunFrame(EventPlayerDied, gs, &gs.event_player_dieds, null);

  gs.purge_removed();
  gs.frameindex +%= 1;
}

fn game_controller_frame(gs: *GameSession, self_id: EntityId, self: *GameController) bool {
  if (self.next_wave_timer == 0) {
    // are all monsters dead
    var num_monsters: u32 = 0;
    for (gs.spawning_monsters.objects[0..gs.spawning_monsters.count]) |object| {
      if (object.is_active) {
        num_monsters += 1;
      }
    }
    for (gs.monsters.objects[0..gs.monsters.count]) |object| {
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
      std.debug.warn("wave {}\n", self.wave_index);
      self.enemy_speed_level = 0;
      self.enemy_speed_ticks = 0;
      switch (self.wave_index) {
        1 => {
          game_spawn_monsters(gs, 8, SpawningMonster.Type.Spider);
        },
        2 => {
          game_spawn_monsters(gs, 8, SpawningMonster.Type.Squid);
        },
        3 => {
          game_spawn_monsters(gs, 12, SpawningMonster.Type.Spider);
        },
        4 => {
          game_spawn_monsters(gs, 4, SpawningMonster.Type.Squid);
          game_spawn_monsters(gs, 10, SpawningMonster.Type.Spider);
        },
        5 => {
          game_spawn_monsters(gs, 20, SpawningMonster.Type.Spider);
        },
        6 => {
          game_spawn_monsters(gs, 14, SpawningMonster.Type.Squid);
        },
        7 => {
          game_spawn_monsters(gs, 8, SpawningMonster.Type.Spider);
          game_spawn_monsters(gs, 8, SpawningMonster.Type.Squid);
          self.enemy_speed_level = 1;
        },
        8 => {
          game_spawn_monsters(gs, 10, SpawningMonster.Type.Spider);
          game_spawn_monsters(gs, 10, SpawningMonster.Type.Squid);
          self.enemy_speed_level = 1;
        },
        else => {
          // done
          game_spawn_monsters(gs, 1, SpawningMonster.Type.Spider);
        },
      }
    }
  }

  if (self.respawn_timer > 0) {
    self.respawn_timer -= 1;
    if (self.respawn_timer == 0) {
      game_spawn_player(gs);
    }
  }
  self.enemy_speed_ticks += 1;
  if (self.enemy_speed_ticks == 800) {
    if (self.enemy_speed_level < 4) {
      self.enemy_speed_level += 1;
      std.debug.warn("speed level {}\n", self.enemy_speed_level);
    }
    self.enemy_speed_ticks = 0;
  }
  return true;
}

fn game_controller_react(gs: *GameSession, self_id: EntityId, self: *GameController) bool {
  for (gs.event_player_dieds.objects[0..gs.event_player_dieds.count]) |object| {
    if (object.is_active) {
      self.respawn_timer = Constants.PlayerRespawnTime;
    }
  }
  return true;
}

fn spawning_monster_frame(gs: *GameSession, self_id: EntityId, self: *SpawningMonster) bool {
  self.timer += 1;
  if (self.timer >= 60) {
    const self_transform = gs.transforms.find(self_id).?;
    switch (self.monsterType) {
      SpawningMonster.Type.Spider => {
        _ = Prototypes.spawnSpider(gs, self_transform.pos);
      },
      SpawningMonster.Type.Squid => {
        _ = Prototypes.spawnSquid(gs, self_transform.pos);
      },
    }    
    return false;
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
    if (self_creature.invulnerability_timer == 0) {
      const self_phys = gs.phys_objects.find(self_id).?;

      self_phys.physType = self_creature.defaultPhysType;
    }
  }
  return true;
}

pub fn bullet_react(gs: *GameSession, self_id: EntityId, self_bullet: *Bullet) bool {
  for (gs.event_collides.objects[0..gs.event_collides.count]) |*object| {
    if (object.is_active and object.data.self_id.id == self_id.id) {
      const self_drawable = gs.drawables.find(self_id).?;
      const self_transform = gs.transforms.find(self_id).?;
      const pos = self_transform.pos;
      _ = Prototypes.spawnAnimation(gs, pos, self_drawable.offset, SimpleAnim.PlaSparks);
      return false;
    }
  }
  return true;
}

pub fn creature_react(gs: *GameSession, self_id: EntityId, self_creature: *Creature) bool {
  for (gs.event_collides.objects[0..gs.event_collides.count]) |*object| {
    if (object.is_active and object.data.self_id.id == self_id.id) {
      if (object.data.other_id.id != 0) {
        const other = gs.phys_objects.find(object.data.other_id).?;
        if (other.damages) {
          if (self_creature.hit_points > 1) {
            self_creature.hit_points -= 1;
          } else if (self_creature.hit_points == 1) {
            self_creature.hit_points = 0;
            const self_transform = gs.transforms.find(self_id).?;
            if (gs.players.find(self_id)) |_| {
              _ = Prototypes.spawnEventPlayerDied(gs);
              _ = Prototypes.spawnCorpse(gs, self_transform.pos);
              return false;
            } else {
              _ = Prototypes.spawnAnimation(gs, self_transform.pos, Vec2.init(0, 0), SimpleAnim.Explosion);
              return false;
            }
          }
        }
      }
    }
  }
  return true;
}
