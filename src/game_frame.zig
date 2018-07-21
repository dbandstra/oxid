const randomEnumValue = @import("util.zig").randomEnumValue;
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
const game_spawn_pickup = @import("game_init.zig").game_spawn_pickup;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");
const physics_frame = @import("game_physics.zig").physics_frame;
const BuildSystem = @import("game_system.zig").BuildSystem;
const BuildSimple = @import("game_system.zig").BuildSimple;
const MonsterMovementSystem = @import("game_frame_monster.zig").MonsterMovementSystem;
const MonsterTouchResponseSystem = @import("game_frame_monster.zig").MonsterTouchResponseSystem;
const PlayerMovementSystem = @import("game_frame_player.zig").PlayerMovementSystem;
const PlayerReactionSystem = @import("game_frame_player.zig").PlayerReactionSystem;

fn RunFrame(
  gs: *GameSession,
  comptime T: type,
  func: ?fn(*GameSession, EntityId, *T)bool,
) void {
  var it = gs.iter(T); while (it.next()) |object| {
    if (func) |f| {
      if (!f(gs, object.entity_id, &object.data)) {
        gs.remove(object.entity_id);
      }
    } else {
      gs.remove(object.entity_id);
    }
  }
}

// decrements the timer. return true if it just hit zero (but not if it was
// already at zero
pub fn decrementTimer(timer: *u32) bool {
  if (timer.* > 0) {
    timer.* -= 1;
    if (timer.* == 0) {
      return true;
    }
  }
  return false;
}

pub fn game_frame(gs: *GameSession) void {
  RunFrame(gs, C.GameController, game_controller_frame);
  RunFrame(gs, C.PlayerController, player_controller_frame);
  animationSystem(gs);
  PlayerMovementSystem.run(gs);
  MonsterMovementSystem.run(gs);
  creatureSystem(gs);
  RunFrame(gs, C.Pickup, pickup_frame);

  physics_frame(gs);

  // pickups react to event_collide, spawn event_confer_bonus
  RunFrame(gs, C.Pickup, pickup_collide);
  // bullets react to event_collide, spawn event_take_damage
  BulletCollideSystem.run(gs);
  // monsters react to event_collide, damage others
  MonsterTouchResponseSystem.run(gs);
  // player reacts to event_confer_bonus, gets bonus effect
  PlayerReactionSystem.run(gs);

  // creatures react to event_take_damage, die
  RunFrame(gs, C.Creature, creature_take_damage);

  // game controller reacts to 'player died' event
  RunFrame(gs, C.GameController, game_controller_react);
  // player controller reacts to 'player died' event
  RunFrame(gs, C.PlayerController, player_controller_react);

  RunFrame(gs, C.EventCollide, null);
  RunFrame(gs, C.EventConferBonus, null);
  RunFrame(gs, C.EventAwardPoints, null);
  RunFrame(gs, C.EventPlayerDied, null);
  RunFrame(gs, C.EventTakeDamage, null);

  gs.applyRemovals();
}

fn countMonsters(gs: *GameSession) u32 {
  var count: u32 = 0;
  var it = gs.iter(C.Monster); while (it.next()) |_| {
    count += 1;
  }
  return count;
}

fn game_controller_frame(gs: *GameSession, self_id: EntityId, self: *C.GameController) bool {
  // if all monsters are dead, prepare next wave
  if (self.next_wave_timer == 0 and countMonsters(gs) == 0) {
    self.next_wave_timer = Constants.NextWaveTime;
  }
  if (decrementTimer(&self.next_wave_timer)) {
    self.wave_index += 1;
    self.enemy_speed_level = 0;
    self.enemy_speed_timer = Constants.EnemySpeedTicks;
    if (self.wave_index - 1 < Constants.Waves.len) {
      const wave = &Constants.Waves[self.wave_index - 1];
      game_spawn_monsters(gs, wave.spiders, MonsterType.Spider);
      game_spawn_monsters(gs, wave.squids, MonsterType.Squid);
      self.enemy_speed_level = wave.speed;
    } else {
      game_spawn_monsters(gs, 1, MonsterType.Spider);
    }
  }
  if (decrementTimer(&self.enemy_speed_timer)) {
    if (self.enemy_speed_level < Constants.MaxEnemySpeedLevel) {
      self.enemy_speed_level += 1;
    }
    self.enemy_speed_timer = Constants.EnemySpeedTicks;
  }
  if (decrementTimer(&self.next_pickup_timer)) {
    const pickup_type = randomEnumValue(C.Pickup.Type, gs.getRand());
    game_spawn_pickup(gs, pickup_type);
    self.next_pickup_timer = Constants.PickupSpawnTime;
  }
  _ = decrementTimer(&self.freeze_monsters_timer);
  return true;
}

fn game_controller_react(gs: *GameSession, self_id: EntityId, self: *C.GameController) bool {
  if (gs.iter(C.EventPlayerDied).next() != null) {
    self.freeze_monsters_timer = Constants.MonsterFreezeTimer;
  }
  return true;
}

fn player_controller_frame(gs: *GameSession, self_id: EntityId, self: *C.PlayerController) bool {
  if (decrementTimer(&self.respawn_timer)) {
    game_spawn_player(gs, self_id);
  }
  return true;
}

fn player_controller_react(gs: *GameSession, self_id: EntityId, self: *C.PlayerController) bool {
  var it = gs.eventIter(C.EventPlayerDied, "player_controller_id", self_id); while (it.next()) |_| {
    if (self.lives > 0) {
      self.lives -= 1;
      if (self.lives > 0) {
        self.respawn_timer = Constants.PlayerRespawnTime;
      }
    }
  }
  var it2 = gs.eventIter(C.EventAwardPoints, "player_controller_id", self_id); while (it2.next()) |event| {
    self.score += event.points;
  }
  return true;
}

const animationSystem = BuildSimple(C.Animation, (struct {
  fn think(gs: *GameSession, self_id: EntityId, self: *C.Animation) bool {
    const animcfg = getSimpleAnim(self.simple_anim);
    if (decrementTimer(&self.frame_timer)) {
      self.frame_index += 1;
      if (self.frame_index >= animcfg.frames.len) {
        return false;
      }
      self.frame_timer = animcfg.ticks_per_frame;
    }
    return true;
  }
}).think);

const creatureSystem = BuildSimple(C.Creature, (struct {
  fn think(gs: *GameSession, self_id: EntityId, self: *C.Creature) bool {
    _ = decrementTimer(&self.invulnerability_timer);
    return true;
  }
}).think);

pub fn pickup_frame(gs: *GameSession, self_id: EntityId, self_pickup: *C.Pickup) bool {
  if (decrementTimer(&self_pickup.timer)) {
    return false;
  }
  return true;
}

pub fn pickup_collide(gs: *GameSession, self_id: EntityId, self_pickup: *C.Pickup) bool {
  var it = gs.eventIter(C.EventCollide, "self_id", self_id); while (it.next()) |event| {
    const other_player = gs.find(event.other_id, C.Player) orelse continue;
    Prototypes.EventConferBonus.spawn(gs, C.EventConferBonus{
      .recipient_id = event.other_id,
      .pickup_type = self_pickup.pickup_type,
    });
    Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints{
      .player_controller_id = other_player.player_controller_id,
      .points = Constants.PickupGetPoints,
    });
    return false;
  }
  return true;
}

const BulletCollideSystem = struct {
  const SystemData = struct {
    bullet: *C.Bullet,
    transform: *C.Transform,
  };

  const run = BuildSystem(SystemData, C.Bullet, think);

  fn think(gs: *GameSession, self_id: EntityId, self: SystemData) bool {
    var it = gs.eventIter(C.EventCollide, "self_id", self_id); while (it.next()) |event| {
      _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
        .pos = self.transform.pos,
        .simple_anim = SimpleAnim.PlaSparks,
        .z_index = Constants.ZIndexSparks,
      });
      if (!EntityId.isZero(event.other_id)) {
        Prototypes.EventTakeDamage.spawn(gs, C.EventTakeDamage{
          .inflictor_player_controller_id = self.bullet.inflictor_player_controller_id,
          .self_id = event.other_id,
          .amount = self.bullet.damage,
        });
      }
      return false;
    }
    return true;
  }
};

pub fn creature_take_damage(gs: *GameSession, self_id: EntityId, self_creature: *C.Creature) bool {
  if (self_creature.invulnerability_timer > 0) {
    return true;
  }
  const maybe_self_monster = gs.find(self_id, C.Monster);
  const maybe_self_player = gs.find(self_id, C.Player);
  if (gs.god_mode and maybe_self_player != null) {
    return true;
  }
  var it = gs.eventIter(C.EventTakeDamage, "self_id", self_id); while (it.next()) |event| {
    const amount = event.amount;
    if (self_creature.hit_points > amount) {
      self_creature.hit_points -= amount;
    } else if (self_creature.hit_points > 0) {
      self_creature.hit_points = 0;
      if (maybe_self_player) |self_player| {
        // player died
        self_player.dying_timer = 45;
        Prototypes.EventPlayerDied.spawn(gs, C.EventPlayerDied{
          .player_controller_id = self_player.player_controller_id,
        });
        return true;
      } else {
        if (maybe_self_monster) |self_monster| {
          if (event.inflictor_player_controller_id) |player_controller_id| {
            Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints{
              .player_controller_id = player_controller_id,
              .points = self_monster.kill_points,
            });
          }
        }
        // something other than a player died
        if (gs.find(self_id, C.Transform)) |self_transform| {
          _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
            .pos = self_transform.pos,
            .simple_anim = SimpleAnim.Explosion,
            .z_index = Constants.ZIndexExplosion,
          });
        }
        return false;
      }
    }
  }
  return true;
}
