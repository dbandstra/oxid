const std = @import("std");

const Gbe = @import("../gbe.zig");
const Constants = @import("constants.zig");
const C = @import("components.zig");

pub const GameComponentLists = struct {
  Animation: Gbe.ComponentList(C.Animation, 10),
  Bullet: Gbe.ComponentList(C.Bullet, 10),
  Creature: Gbe.ComponentList(C.Creature, 50),
  GameController: Gbe.ComponentList(C.GameController, 1),
  Monster: Gbe.ComponentList(C.Monster, 50),
  PhysObject: Gbe.ComponentList(C.PhysObject, 100),
  Pickup: Gbe.ComponentList(C.Pickup, 10),
  Player: Gbe.ComponentList(C.Player, 50),
  PlayerController: Gbe.ComponentList(C.PlayerController, 4),
  SimpleGraphic: Gbe.ComponentList(C.SimpleGraphic, 50),
  Transform: Gbe.ComponentList(C.Transform, 100),
  Web: Gbe.ComponentList(C.Web, 100),
  EventAwardLife: Gbe.ComponentList(C.EventAwardLife, 20),
  EventAwardPoints: Gbe.ComponentList(C.EventAwardPoints, 20),
  EventCollide: Gbe.ComponentList(C.EventCollide, 50),
  EventConferBonus: Gbe.ComponentList(C.EventConferBonus, 5),
  EventDraw: Gbe.ComponentList(C.EventDraw, 100),
  EventDrawBox: Gbe.ComponentList(C.EventDrawBox, 100),
  EventInput: Gbe.ComponentList(C.EventInput, 20),
  EventMonsterDied: Gbe.ComponentList(C.EventMonsterDied, 20),
  EventPlayerDied: Gbe.ComponentList(C.EventPlayerDied, 20),
  EventSound: Gbe.ComponentList(C.EventSound, 20),
  EventTakeDamage: Gbe.ComponentList(C.EventTakeDamage, 20),
};

// TODO - try to get rid of this struct completely and just move the fields
// into C.GameController
pub const GameSession = struct {
  const GbeSessionType = Gbe.Session(GameComponentLists);

  gbe: GbeSessionType,

  pub fn init(self: *GameSession, rand_seed: u32) void {
    self.gbe.init(rand_seed);
  }
};
