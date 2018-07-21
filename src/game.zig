const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;

const Constants = @import("game_constants.zig");
const C = @import("game_components.zig");
const GameIterators = @import("game_iterators.zig");

pub const EntityId = struct {
  id: usize,

  pub fn eql(a: EntityId, b: EntityId) bool {
    return a.id == b.id;
  }

  pub fn isZero(a: EntityId) bool {
    return a.id == 0;
  }
};

pub fn ComponentObject(comptime T: type) type {
  return struct {
    is_active: bool,
    entity_id: EntityId,
    data: T,
  };
}

pub fn ComponentList(comptime T: type) type {
  return struct {
    objects: [Constants.MaxComponentsPerType]ComponentObject(T),
    count: usize,
  };
}

const COMPONENT_TYPES = []type{
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
  C.EventCollide,
  C.EventConferBonus,
  C.EventAwardPoints,
  C.EventPlayerDied,
  C.EventTakeDamage,
};

// FIXME - is there any way to generate this from COMPONENT_TYPES
pub const GameComponentLists = struct {
  Animation: ComponentList(C.Animation),
  Bullet: ComponentList(C.Bullet),
  Creature: ComponentList(C.Creature),
  Drawable: ComponentList(C.Drawable),
  GameController: ComponentList(C.GameController),
  Monster: ComponentList(C.Monster),
  PhysObject: ComponentList(C.PhysObject),
  Pickup: ComponentList(C.Pickup),
  Player: ComponentList(C.Player),
  PlayerController: ComponentList(C.PlayerController),
  Transform: ComponentList(C.Transform),
  EventCollide: ComponentList(C.EventCollide),
  EventConferBonus: ComponentList(C.EventConferBonus),
  EventAwardPoints: ComponentList(C.EventAwardPoints),
  EventPlayerDied: ComponentList(C.EventPlayerDied),
  EventTakeDamage: ComponentList(C.EventTakeDamage),
};

pub const GameSession = struct {
  prng: std.rand.DefaultPrng,

  next_entity_id: usize,

  removals: [Constants.MaxRemovalsPerFrame]EntityId,
  num_removals: usize,

  god_mode: bool,

  components: GameComponentLists,

  in_left: bool,
  in_right: bool,
  in_up: bool,
  in_down: bool,
  in_shoot: bool,

  pub fn init(self: *GameSession, rand_seed: u32) void {

    self.prng = std.rand.DefaultPrng.init(rand_seed);
    self.next_entity_id = 1;
    self.removals = undefined;
    self.num_removals = 0;
    self.god_mode = false;
    inline for (@typeInfo(GameComponentLists).Struct.fields) |field| {
      @field(&self.components, field.name).count = 0;
    }
    self.in_up = false;
    self.in_down = false;
    self.in_left = false;
    self.in_right = false;
    self.in_shoot = false;
  }

  pub fn iter(self: *GameSession, comptime T: type) GameIterators.ComponentObjectIterator(T) {
    const list = &@field(&self.components, @typeName(T));
    return GameIterators.ComponentObjectIterator(T).init(list);
  }

  pub fn eventIter(self: *GameSession, comptime T: type, comptime field: []const u8, entity_id: EntityId) GameIterators.EventIterator(T, field) {
    const list = &@field(&self.components, @typeName(T));
    return GameIterators.EventIterator(T, field).init(list, entity_id);
  }

  pub fn findObject(self: *GameSession, entity_id: EntityId, comptime T: type) ?*ComponentObject(T) {
    var it = self.iter(T); while (it.next()) |object| {
      if (EntityId.eql(object.entity_id, entity_id)) {
        return object;
      }
    }
    return null;
  }

  pub fn find(self: *GameSession, entity_id: EntityId, comptime T: type) ?*T {
    if (self.findObject(entity_id, T)) |object| {
      return &object.data;
    } else {
      return null;
    }
  }

  pub fn getGameController(self: *GameSession) *C.GameController {
    return &self.iter(C.GameController).next().?.data;
  }

  pub fn getRand(self: *GameSession) *std.rand.Random {
    return &self.prng.random;
  }

  pub fn spawn(self: *GameSession) EntityId {
    const id = EntityId{ .id = self.next_entity_id };
    self.next_entity_id += 1; // TODO - reuse these?
    return id;
  }

  pub fn remove(self: *GameSession, entity_id: EntityId) void {
    if (self.num_removals >= Constants.MaxRemovalsPerFrame) {
      unreachable;
    }
    self.removals[self.num_removals] = entity_id;
    self.num_removals += 1;
  }

  // `data` must be a struct object, and it must be one of the structs in GameComponentLists.
  // FIXME - before i used duck typing for this, `data` had type `*const T`.
  // then you could pass struct using as-value syntax, and it was implicitly sent as a reference
  // (like c++ references). but with `var`, i don't think this is possible?
  // FIXME - is there any way to make this fail (at compile time!) if you try to add the same
  // component to an entity twice?
  // TODO - optional LRU reuse.
  // (ok for non crucial entities. crucial ones should still crash)
  pub fn addComponent(self: *GameSession, entity_id: EntityId, data: var) void {
    const T: type = @typeOf(data);
    assert(@typeId(T) == builtin.TypeId.Struct);
    var list = &@field(&self.components, @typeName(T));
    const slot = blk: {
      var i: usize = 0;
      while (i < list.count) : (i += 1) {
        const object = &list.objects[i];
        if (!object.is_active) {
          break :blk object;
        }
      }
      if (list.count < Constants.MaxComponentsPerType) {
        i = list.count;
        list.count += 1;
        break :blk &list.objects[i];
      }
      break :blk null;
    };
    if (slot) |object| {
      object.is_active = true;
      object.data = data;
      object.entity_id = entity_id;
    } else {
      @panic("no slots left to add component");
    }
  }

  pub fn destroyComponent(self: *GameSession, entity_id: EntityId, comptime T: type) void {
    if (self.findObject(entity_id, T)) |object| {
      object.is_active = false;
    }
  }

  pub fn applyRemovals(self: *GameSession) void {
    for (self.removals) |entity_id| {
      inline for (COMPONENT_TYPES) |component_type| {
        self.destroyComponent(entity_id, component_type);
      }
    }
    self.num_removals = 0;
  }
};
