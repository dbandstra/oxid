const randomEnumValue = @import("../util.zig").randomEnumValue;
const Math = @import("../math.zig");
const boxes_overlap = @import("../boxes_overlap.zig").boxes_overlap;
const Gbe = @import("../gbe.zig");
const GbeSystem = @import("../gbe_system.zig");
const SimpleAnim = @import("graphics_config.zig").SimpleAnim;
const getSimpleAnim = @import("graphics_config.zig").getSimpleAnim;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("level.zig").LEVEL;
const ComponentList = @import("game.zig").ComponentList;
const GameSession = @import("game.zig").GameSession;
const Constants = @import("constants.zig");
const MonsterType = @import("init.zig").MonsterType;
const spawnMonsters = @import("init.zig").spawnMonsters;
const spawnPlayer = @import("init.zig").spawnPlayer;
const spawnPickup = @import("init.zig").spawnPickup;
const C = @import("components.zig");
const Prototypes = @import("prototypes.zig");
const physicsFrame = @import("physics.zig").physicsFrame;
const MonsterMovementSystem = @import("frame_monster.zig").MonsterMovementSystem;
const MonsterTouchResponseSystem = @import("frame_monster.zig").MonsterTouchResponseSystem;
const PlayerMovementSystem = @import("frame_player.zig").PlayerMovementSystem;
const PlayerReactionSystem = @import("frame_player.zig").PlayerReactionSystem;

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

fn removeAll(gs: *GameSession, comptime T: type) void {
  var it = gs.gbe.iter(T); while (it.next()) |object| {
    gs.gbe.markEntityForRemoval(object.entity_id);
  }
}

pub fn gameFrame(gs: *GameSession) void {
  GameControllerSystem.run(gs);
  PlayerControllerSystem.run(gs);
  AnimationSystem.run(gs);
  PlayerMovementSystem.run(gs);
  MonsterMovementSystem.run(gs);
  CreatureSystem.run(gs);
  PickupSystem.run(gs);

  physicsFrame(gs);

  // pickups react to event_collide, spawn event_confer_bonus
  PickupCollideSystem.run(gs);
  // bullets react to event_collide, spawn event_take_damage
  BulletCollideSystem.run(gs);
  // monsters react to event_collide, damage others
  MonsterTouchResponseSystem.run(gs);
  // player reacts to event_confer_bonus, gets bonus effect
  PlayerReactionSystem.run(gs);

  // creatures react to event_take_damage, die
  CreatureTakeDamageSystem.run(gs);

  // game controller reacts to 'player died' event
  GameControllerReactSystem.run(gs);
  // player controller reacts to 'player died' event
  PlayerControllerReactSystem.run(gs);

  removeAll(gs, C.EventAwardLife);
  removeAll(gs, C.EventAwardPoints);
  removeAll(gs, C.EventCollide);
  removeAll(gs, C.EventConferBonus);
  removeAll(gs, C.EventMonsterDied);
  removeAll(gs, C.EventPlayerDied);
  removeAll(gs, C.EventTakeDamage);

  gs.gbe.applyRemovals();
}

const GameControllerSystem = struct{
  const SystemData = struct{ gc: *C.GameController };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    // if all monsters are dead, prepare next wave
    if (self.gc.next_wave_timer == 0 and countMonsters(gs) == 0) {
      self.gc.next_wave_timer = Constants.NextWaveTime;
    }
    if (decrementTimer(&self.gc.next_wave_timer)) {
      self.gc.wave_index += 1;
      self.gc.enemy_speed_level = 0;
      self.gc.enemy_speed_timer = Constants.EnemySpeedTicks;
      if (self.gc.wave_index - 1 < Constants.Waves.len) {
        const wave = &Constants.Waves[self.gc.wave_index - 1];
        spawnMonsters(gs, wave.spiders, MonsterType.Spider);
        spawnMonsters(gs, wave.squids, MonsterType.Squid);
        self.gc.enemy_speed_level = wave.speed;
        self.gc.monster_count = wave.spiders + wave.squids;
      } else {
        spawnMonsters(gs, 1, MonsterType.Spider);
      }
    }
    if (decrementTimer(&self.gc.enemy_speed_timer)) {
      if (self.gc.enemy_speed_level < Constants.MaxEnemySpeedLevel) {
        self.gc.enemy_speed_level += 1;
      }
      self.gc.enemy_speed_timer = Constants.EnemySpeedTicks;
    }
    if (decrementTimer(&self.gc.next_pickup_timer)) {
      const pickup_type = randomEnumValue(C.Pickup.Type, gs.gbe.getRand());
      spawnPickup(gs, pickup_type);
      self.gc.next_pickup_timer = Constants.PickupSpawnTime;
    }
    _ = decrementTimer(&self.gc.freeze_monsters_timer);
    return true;
  }

  fn countMonsters(gs: *GameSession) u32 {
    var count: u32 = 0;
    var it = gs.gbe.iter(C.Monster); while (it.next()) |_| {
      count += 1;
    }
    return count;
  }
};

const GameControllerReactSystem = struct{
  const SystemData = struct{ gc: *C.GameController };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    if (gs.gbe.iter(C.EventPlayerDied).next() != null) {
      self.gc.freeze_monsters_timer = Constants.MonsterFreezeTimer;
    }
    var it = gs.gbe.iter(C.EventMonsterDied); while (it.next()) |object| {
      if (self.gc.monster_count > 0) {
        self.gc.monster_count -= 1;
        if (self.gc.monster_count == 4 and self.gc.enemy_speed_level < 1) {
          self.gc.enemy_speed_level = 1;
        }
        if (self.gc.monster_count == 3 and self.gc.enemy_speed_level < 2) {
          self.gc.enemy_speed_level = 2;
        }
        if (self.gc.monster_count == 2 and self.gc.enemy_speed_level < 3) {
          self.gc.enemy_speed_level = 3;
        }
        if (self.gc.monster_count == 1 and self.gc.enemy_speed_level < 4) {
          self.gc.enemy_speed_level = 4;
        }
      }
    }
    return true;
  }
};

const PlayerControllerSystem = struct{
  const SystemData = struct{ id: Gbe.EntityId, pc: *C.PlayerController };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    if (decrementTimer(&self.pc.respawn_timer)) {
      spawnPlayer(gs, self.id);
    }
    return true;
  }
};

const PlayerControllerReactSystem = struct{
  const SystemData = struct{ id: Gbe.EntityId, pc: *C.PlayerController };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.gbe.eventIter(C.EventPlayerDied, "player_controller_id", self.id); while (it.next()) |_| {
      if (self.pc.lives > 0) {
        self.pc.lives -= 1;
        if (self.pc.lives > 0) {
          self.pc.respawn_timer = Constants.PlayerRespawnTime;
        }
      }
    }
    var it2 = gs.gbe.eventIter(C.EventAwardPoints, "player_controller_id", self.id); while (it2.next()) |event| {
      self.pc.score += event.points;
    }
    var it3 = gs.gbe.eventIter(C.EventAwardLife, "player_controller_id", self.id); while (it3.next()) |event| {
      self.pc.lives += 1;
    }
    return true;
  }
};

const AnimationSystem = struct {
  const SystemData = struct{ animation: *C.Animation };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    const animcfg = getSimpleAnim(self.animation.simple_anim);
    if (decrementTimer(&self.animation.frame_timer)) {
      self.animation.frame_index += 1;
      if (self.animation.frame_index >= animcfg.frames.len) {
        return false;
      }
      self.animation.frame_timer = animcfg.ticks_per_frame;
    }
    return true;
  }
};

const CreatureSystem = struct {
  const SystemData = struct{ creature: *C.Creature };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    _ = decrementTimer(&self.creature.invulnerability_timer);
    return true;
  }
};

const PickupSystem = struct {
  const SystemData = struct{ pickup: *C.Pickup };
  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    if (decrementTimer(&self.pickup.timer)) {
      return false;
    }
    return true;
  }
};

const PickupCollideSystem = struct{
  const SystemData = struct{ id: Gbe.EntityId, pickup: *C.Pickup };
  const run = GbeSystem.build(GameSession, SystemData, collide);

  fn collide(gs: *GameSession, self: SystemData) bool {
    var it = gs.gbe.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
      const other_player = gs.gbe.find(event.other_id, C.Player) orelse continue;
      Prototypes.EventConferBonus.spawn(gs, C.EventConferBonus{
        .recipient_id = event.other_id,
        .pickup_type = self.pickup.pickup_type,
      });
      Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints{
        .player_controller_id = other_player.player_controller_id,
        .points = Constants.PickupGetPoints,
      });
      return false;
    }
    return true;
  }
};

const BulletCollideSystem = struct {
  const SystemData = struct {
    id: Gbe.EntityId,
    bullet: *C.Bullet,
    transform: *C.Transform,
  };

  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.gbe.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
      _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
        .pos = self.transform.pos,
        .simple_anim = SimpleAnim.PlaSparks,
        .z_index = Constants.ZIndexSparks,
      });
      if (!Gbe.EntityId.isZero(event.other_id)) {
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

const CreatureTakeDamageSystem = struct{
  const SystemData = struct{
    id: Gbe.EntityId,
    creature: *C.Creature,
    transform: *C.Transform,
    monster: ?*C.Monster,
    player: ?*C.Player,
  };

  const run = GbeSystem.build(GameSession, SystemData, think);

  fn think(gs: *GameSession, self: SystemData) bool {
    if (self.creature.invulnerability_timer > 0) {
      return true;
    }
    if (gs.god_mode and self.player != null) {
      return true;
    }
    var it = gs.gbe.eventIter(C.EventTakeDamage, "self_id", self.id); while (it.next()) |event| {
      const amount = event.amount;
      if (self.creature.hit_points > amount) {
        self.creature.hit_points -= amount;
      } else if (self.creature.hit_points > 0) {
        self.creature.hit_points = 0;
        if (self.player) |self_player| {
          // player died
          self_player.dying_timer = 45;
          Prototypes.EventPlayerDied.spawn(gs, C.EventPlayerDied{
            .player_controller_id = self_player.player_controller_id,
          });
          return true;
        } else {
          if (self.monster) |self_monster| {
            Prototypes.EventMonsterDied.spawn(gs, C.EventMonsterDied{
              .unused = 0,
            });
            if (event.inflictor_player_controller_id) |player_controller_id| {
              Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints{
                .player_controller_id = player_controller_id,
                .points = self_monster.kill_points,
              });
            }
          }
          // something other than a player died
          _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
            .pos = self.transform.pos,
            .simple_anim = SimpleAnim.Explosion,
            .z_index = Constants.ZIndexExplosion,
          });
          return false;
        }
      }
    }
    return true;
  }
};
