const Gbe = @import("../gbe.zig");
const GameSession = @import("game.zig").GameSession;
const physicsFrame = @import("physics.zig").physicsFrame;
const C = @import("components.zig");
const Prototypes = @import("prototypes.zig");

const AnimationSystem = @import("systems/animation.zig");
const BulletSystem = @import("systems/bullet.zig");
const BulletCollideSystem = @import("systems/bullet_collide.zig");
const CreatureSystem = @import("systems/creature.zig");
const CreatureTakeDamageSystem = @import("systems/creature_take_damage.zig");
const GameControllerReactSystem = @import("systems/game_controller_react.zig");
const GameControllerSystem = @import("systems/game_controller.zig");
const MonsterMovementSystem = @import("systems/monster_movement.zig");
const MonsterTouchResponseSystem = @import("systems/monster_touch_response.zig");
const PickupCollideSystem = @import("systems/pickup_collide.zig");
const PickupSystem = @import("systems/pickup.zig");
const PlayerControllerReactSystem = @import("systems/player_controller_react.zig");
const PlayerControllerSystem = @import("systems/player_controller.zig");
const PlayerMovementSystem = @import("systems/player_movement.zig");
const PlayerReactionSystem = @import("systems/player_reaction.zig");

pub fn gameInit(gs: *GameSession) void {
  _ = Prototypes.GameController.spawn(gs);
  _ = Prototypes.PlayerController.spawn(gs);
}

pub fn gamePreFrame(gs: *GameSession) void {
  GameControllerSystem.run(gs);
  PlayerControllerSystem.run(gs);
  AnimationSystem.run(gs);
  PlayerMovementSystem.run(gs);
  MonsterMovementSystem.run(gs);
  BulletSystem.run(gs);
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
}

pub fn gamePostFrame(gs: *GameSession) void {
  removeAll(gs, C.EventAwardLife);
  removeAll(gs, C.EventAwardPoints);
  removeAll(gs, C.EventCollide);
  removeAll(gs, C.EventConferBonus);
  removeAll(gs, C.EventMonsterDied);
  removeAll(gs, C.EventPlayerDied);
  removeAll(gs, C.EventSound);
  removeAll(gs, C.EventTakeDamage);

  gs.gbe.applyRemovals();
}

fn removeAll(gs: *GameSession, comptime T: type) void {
  var it = gs.gbe.iter(T); while (it.next()) |object| {
    gs.gbe.markEntityForRemoval(object.entity_id);
  }
}
