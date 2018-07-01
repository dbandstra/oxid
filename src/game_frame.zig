const std = @import("std");
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

fn phys_object_frame(gs: *GameSession, self_id: EntityId, self_phys: *PhysObject) bool {
  const self_transform = gs.transforms.find(self_id).?;

  const dir = get_dir_vec(self_phys.facing);

  // hit walls
  var i: i32 = 0;
  while (i < self_phys.speed) : (i += 1) {
    const newpos = Vec2.add(self_transform.pos, dir);

    if (LEVEL.box_in_wall(newpos, self_phys.dims, true)) {
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
        PhysObject.Type.NonSolid => false,
        PhysObject.Type.Player => false,
        PhysObject.Type.Enemy => other_phys.physType == PhysObject.Type.Player,
        PhysObject.Type.Bullet => other_phys.physType == PhysObject.Type.Enemy,
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

fn player_frame(gs: *GameSession, entity_id: EntityId, player: *Player) bool {
  const creature = gs.creatures.find(entity_id).?;
  const phys = gs.phys_objects.find(entity_id).?;
  const transform = gs.transforms.find(entity_id).?;

  var xmove: i32 = 0;
  var ymove: i32 = 0;

  if (gs.in_right) {
    xmove += 1;
  }
  if (gs.in_left) {
    xmove -= 1;
  }
  if (gs.in_down) {
    ymove += 1;
  }
  if (gs.in_up) {
    ymove -= 1;
  }

  var i: @IntType(false, 31) = 0;
  while (i < creature.walk_speed) : (i += 1) {
    const x = transform.pos.x;
    const y = transform.pos.y;

    // if you are holding both horizontal and vertical keys, prefer to move on
    // the axis you are not facing along.
    // for example, if you are facing right, holding right and up, prefer to go
    // up.
    if (xmove != 0 and (ymove == 0 or phys.facing == Direction.Up or phys.facing == Direction.Down)) {
      if (!LEVEL.box_in_wall(Vec2{ .x = x + xmove, .y = y }, phys.dims, false)) {
        transform.pos.x += xmove;
        phys.facing = if (xmove > 0) Direction.Right else Direction.Left;
      } else if (ymove != 0 and !LEVEL.box_in_wall(Vec2{ .x = x, .y = y + ymove }, phys.dims, false)) {
        transform.pos.y += ymove;
        phys.facing = if (ymove > 0) Direction.Down else Direction.Up;
      } else {
        break;
      }
    } else if (ymove != 0) {
      if (!LEVEL.box_in_wall(Vec2{ .x = x, .y = y + ymove }, phys.dims, false)) {
        transform.pos.y += ymove;
        phys.facing = if (ymove > 0) Direction.Down else Direction.Up;
      } else if (xmove != 0 and !LEVEL.box_in_wall(Vec2{ .x = x + xmove, .y = y}, phys.dims, false)) {
        transform.pos.x += xmove;
        phys.facing = if (xmove > 0) Direction.Right else Direction.Left;
      } else {
        break;
      }
    } else {
      break;
    }
  }

  if (gs.shoot) {
    // player is 16x16, bullet is 4x4
    const bullet_ofs = Vec2{
      .x = 6 * SUBPIXELS,
      .y = 6 * SUBPIXELS,
    };
    _ = Prototypes.spawnBullet(gs, entity_id, Vec2.add(transform.pos, bullet_ofs), phys.facing);
    gs.shoot = false;
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
              _ = Prototypes.spawnAnimation(gs, self_transform.pos, Vec2{ .x = 0, .y = 0 }, SimpleAnim.Explosion);
              return false;
            }
          }
        }
      }
    }
  }
  return true;
}
