const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;

const Gbe = @import("../gbe.zig");
const Constants = @import("constants.zig");
const C = @import("components.zig");

const COMPONENT_TYPES = []const type{
  C.Animation,
  C.Bullet,
  C.Creature,
  C.Drawable,
  C.GameController,
  C.Monster,
  C.PhysObject,
  C.Pickup,
  C.Player,
  C.PlayerController,
  C.Transform,
  C.EventAwardLife,
  C.EventAwardPoints,
  C.EventCollide,
  C.EventConferBonus,
  C.EventMonsterDied,
  C.EventPlayerDied,
  C.EventTakeDamage,
};

// FIXME - is there any way to generate this from COMPONENT_TYPES
pub const GameComponentLists = struct {
  Animation: Gbe.ComponentList(C.Animation),
  Bullet: Gbe.ComponentList(C.Bullet),
  Creature: Gbe.ComponentList(C.Creature),
  Drawable: Gbe.ComponentList(C.Drawable),
  GameController: Gbe.ComponentList(C.GameController),
  Monster: Gbe.ComponentList(C.Monster),
  PhysObject: Gbe.ComponentList(C.PhysObject),
  Pickup: Gbe.ComponentList(C.Pickup),
  Player: Gbe.ComponentList(C.Player),
  PlayerController: Gbe.ComponentList(C.PlayerController),
  Transform: Gbe.ComponentList(C.Transform),
  EventAwardLife: Gbe.ComponentList(C.EventAwardLife),
  EventAwardPoints: Gbe.ComponentList(C.EventAwardPoints),
  EventCollide: Gbe.ComponentList(C.EventCollide),
  EventConferBonus: Gbe.ComponentList(C.EventConferBonus),
  EventMonsterDied: Gbe.ComponentList(C.EventMonsterDied),
  EventPlayerDied: Gbe.ComponentList(C.EventPlayerDied),
  EventTakeDamage: Gbe.ComponentList(C.EventTakeDamage),
};

pub const GameSession = struct {
  gbe: Gbe.Session(COMPONENT_TYPES[0..], GameComponentLists),

  god_mode: bool,
  in_left: bool,
  in_right: bool,
  in_up: bool,
  in_down: bool,
  in_shoot: bool,

  pub fn init(self: *GameSession, rand_seed: u32) void {
    self.gbe.init(rand_seed);

    self.god_mode = false;
    self.in_up = false;
    self.in_down = false;
    self.in_left = false;
    self.in_right = false;
    self.in_shoot = false;
  }

  pub fn getGameController(self: *GameSession) *C.GameController {
    return &self.gbe.iter(C.GameController).next().?.data;
  }
};
