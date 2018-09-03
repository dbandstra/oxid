const std = @import("std");

const Gbe = @import("../gbe.zig");
const Constants = @import("constants.zig");
const C = @import("components.zig");

pub fn ComponentStorage(comptime T: type, comptime capacity: usize) type {
  return struct{
    objects: [capacity]Gbe.ComponentObject(T),
  };
}

pub const MaxDrawables = 100;
pub const MaxPhysObjects = 100;

pub const GameComponentStorage = struct {
  Animation: ComponentStorage(C.Animation, 10),
  Bullet: ComponentStorage(C.Bullet, 10),
  Creature: ComponentStorage(C.Creature, 50),
  GameController: ComponentStorage(C.GameController, 1),
  Monster: ComponentStorage(C.Monster, 50),
  PhysObject: ComponentStorage(C.PhysObject, MaxPhysObjects),
  Pickup: ComponentStorage(C.Pickup, 10),
  Player: ComponentStorage(C.Player, 50),
  PlayerController: ComponentStorage(C.PlayerController, 4),
  SimpleGraphic: ComponentStorage(C.SimpleGraphic, 50),
  Transform: ComponentStorage(C.Transform, 100),
  Web: ComponentStorage(C.Web, 100),
  EventAwardLife: ComponentStorage(C.EventAwardLife, 20),
  EventAwardPoints: ComponentStorage(C.EventAwardPoints, 20),
  EventCollide: ComponentStorage(C.EventCollide, 50),
  EventConferBonus: ComponentStorage(C.EventConferBonus, 5),
  EventDraw: ComponentStorage(C.EventDraw, MaxDrawables),
  EventDrawBox: ComponentStorage(C.EventDrawBox, 100),
  EventMonsterDied: ComponentStorage(C.EventMonsterDied, 20),
  EventPlayerDied: ComponentStorage(C.EventPlayerDied, 20),
  EventSound: ComponentStorage(C.EventSound, 20),
  EventTakeDamage: ComponentStorage(C.EventTakeDamage, 50),
};

pub const GameComponentLists = struct {
  Animation: Gbe.ComponentList(C.Animation),
  Bullet: Gbe.ComponentList(C.Bullet),
  Creature: Gbe.ComponentList(C.Creature),
  GameController: Gbe.ComponentList(C.GameController),
  Monster: Gbe.ComponentList(C.Monster),
  PhysObject: Gbe.ComponentList(C.PhysObject),
  Pickup: Gbe.ComponentList(C.Pickup),
  Player: Gbe.ComponentList(C.Player),
  PlayerController: Gbe.ComponentList(C.PlayerController),
  SimpleGraphic: Gbe.ComponentList(C.SimpleGraphic),
  Transform: Gbe.ComponentList(C.Transform),
  Web: Gbe.ComponentList(C.Web),
  EventAwardLife: Gbe.ComponentList(C.EventAwardLife),
  EventAwardPoints: Gbe.ComponentList(C.EventAwardPoints),
  EventCollide: Gbe.ComponentList(C.EventCollide),
  EventConferBonus: Gbe.ComponentList(C.EventConferBonus),
  EventDraw: Gbe.ComponentList(C.EventDraw),
  EventDrawBox: Gbe.ComponentList(C.EventDrawBox),
  EventMonsterDied: Gbe.ComponentList(C.EventMonsterDied),
  EventPlayerDied: Gbe.ComponentList(C.EventPlayerDied),
  EventSound: Gbe.ComponentList(C.EventSound),
  EventTakeDamage: Gbe.ComponentList(C.EventTakeDamage),
};

pub const GameSession = struct {
  component_storage: GameComponentStorage,
  gbe: Gbe.Session(GameComponentLists),

  god_mode: bool,
  paused: bool,
  fast_forward: bool,
  render_move_boxes: bool,
  in_left: bool,
  in_right: bool,
  in_up: bool,
  in_down: bool,
  in_shoot: bool,

  pub fn init(self: *GameSession, rand_seed: u32) void {
    self.gbe.init(&self.component_storage, rand_seed);

    self.god_mode = false;
    self.paused = false;
    self.fast_forward = false;
    self.render_move_boxes = false;
    self.in_up = false;
    self.in_down = false;
    self.in_left = false;
    self.in_right = false;
    self.in_shoot = false;
  }

  pub fn markAllEventsForRemoval(self: *GameSession) void {
    inline for (@typeInfo(GameComponentLists).Struct.fields) |field| {
      const ComponentType = field.field_type.ComponentType;
      if (std.mem.startsWith(u8, @typeName(ComponentType), "Event")) {
        var it = self.gbe.iter(ComponentType); while (it.next()) |object| {
          self.gbe.markEntityForRemoval(object.entity_id);
        }
      }
    }
  }

  pub fn getGameController(self: *GameSession) *C.GameController {
    return &self.gbe.iter(C.GameController).next().?.data;
  }
};
