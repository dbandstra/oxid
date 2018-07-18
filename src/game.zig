const std = @import("std");

const Direction = @import("math.zig").Direction;
const Vec2 = @import("math.zig").Vec2;

const Constants = @import("game_constants.zig");
const C = @import("game_components.zig");

pub const InputEvent = enum {
  Left,
  Right,
  Up,
  Down,
  Shoot,
};

pub const EntityId = struct {
  id: usize,
};

pub fn ComponentObject(comptime T: type) type {
  return struct {
    entity_id: EntityId,
    data: T,
    is_active: bool,
  };
}

pub fn ComponentList(comptime T: type) type {
  return struct {
    const Self = this;

    objects_array: [Constants.MaxComponentsPerType]ComponentObject(T),
    objects: []ComponentObject(T),
    count: usize,

    pub fn init() Self {
      return Self{
        .objects_array = undefined,
        .objects = ([*]ComponentObject(T))(undefined)[0..0],
        .count = 0,
      };
    }

    // TODO - optional LRU reuse.
    // (ok for non crucial entities. crucial ones should still crash)
    pub fn create(self: *Self, entity_id: EntityId, data: *const T) void {
      const i = choose_slot(self).?; // can crash
      var object = &self.objects_array[i];
      object.is_active = true;
      object.data = data.*;
      object.entity_id = entity_id;
    }

    fn choose_slot(self: *Self) ?usize {
      var i: usize = 0;
      while (i < self.count) : (i += 1) {
        if (!self.objects_array[i].is_active) {
          return i;
        }
      }
      if (self.count < Constants.MaxComponentsPerType) {
        i = self.count;
        self.count += 1;
        self.objects = self.objects_array[0..self.count];
        return i;
      }
      return null;
    }

    pub fn find_object(self: *Self, entity_id: EntityId) ?*ComponentObject(T) {
      for (self.objects) |*object| {
        if (object.is_active and object.entity_id.id == entity_id.id) {
          return object;
        }
      }
      return null;
    }

    pub fn find(self: *Self, entity_id: EntityId) ?*T {
      if (self.find_object(entity_id)) |object| {
        return &object.data;
      } else {
        return null;
      }
    }

    pub fn destroy(self: *Self, entity_id: EntityId) void {
      if (self.find_object(entity_id)) |object| {
        object.is_active = false;
      }
    }
  };
}

pub const GameSession = struct {
  frameindex: u8,

  prng: std.rand.DefaultPrng,

  next_entity_id: usize,

  removals: [Constants.MaxRemovalsPerFrame]EntityId,
  num_removals: usize,

  god_mode: bool,

  animations: ComponentList(C.Animation),
  bullets: ComponentList(C.Bullet),
  creatures: ComponentList(C.Creature),
  drawables: ComponentList(C.Drawable),
  game_controllers: ComponentList(C.GameController),
  monsters: ComponentList(C.Monster),
  phys_objects: ComponentList(C.PhysObject),
  pickups: ComponentList(C.Pickup),
  players: ComponentList(C.Player),
  player_controllers: ComponentList(C.PlayerController),
  transforms: ComponentList(C.Transform),
  event_collides: ComponentList(C.EventCollide),
  event_confer_bonuses: ComponentList(C.EventConferBonus),
  event_award_pointses: ComponentList(C.EventAwardPoints),
  event_player_dieds: ComponentList(C.EventPlayerDied),
  event_take_damages: ComponentList(C.EventTakeDamage),

  in_left: bool,
  in_right: bool,
  in_up: bool,
  in_down: bool,
  in_shoot: bool,

  pub fn init() GameSession {
    // fn getRandomSeed() !u32 {
    //   var seed: u32 = undefined;
    //   const seed_bytes = @ptrCast([*]u8, &seed)[0..4];
    //   try std.os.getRandomBytes(seed_bytes);
    //   return seed;
    // }

    // const rand_seed = getRandomSeed() catch {
    //   std.debug.warn("unable to get random seed\n");
    //   std.os.abort();
    // };
    const rand_seed = 0;

    return GameSession{
      .frameindex = 0,
      .prng = std.rand.DefaultPrng.init(rand_seed),
      .next_entity_id = 1,
      .removals = undefined,
      .num_removals = 0,
      .god_mode = false,
      .animations = ComponentList(C.Animation).init(),
      .bullets = ComponentList(C.Bullet).init(),
      .creatures = ComponentList(C.Creature).init(),
      .drawables = ComponentList(C.Drawable).init(),
      .game_controllers = ComponentList(C.GameController).init(),
      .monsters = ComponentList(C.Monster).init(),
      .phys_objects = ComponentList(C.PhysObject).init(),
      .pickups = ComponentList(C.Pickup).init(),
      .player_controllers = ComponentList(C.PlayerController).init(),
      .players = ComponentList(C.Player).init(),
      .transforms = ComponentList(C.Transform).init(),
      .event_collides = ComponentList(C.EventCollide).init(),
      .event_confer_bonuses = ComponentList(C.EventConferBonus).init(),
      .event_award_pointses = ComponentList(C.EventAwardPoints).init(),
      .event_player_dieds = ComponentList(C.EventPlayerDied).init(),
      .event_take_damages = ComponentList(C.EventTakeDamage).init(),
      .in_up = false,
      .in_down = false,
      .in_left = false,
      .in_right = false,
      .in_shoot = false,
    };
  }

  pub fn getGameController(self: *GameSession) *C.GameController {
    var object = &self.game_controllers.objects[0];
    std.debug.assert(object.is_active == true);
    return &object.data;
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

  pub fn purge_removed(self: *GameSession) void {
    for (self.removals) |entity_id| {
      self.animations.destroy(entity_id);
      self.bullets.destroy(entity_id);
      self.creatures.destroy(entity_id);
      self.drawables.destroy(entity_id);
      self.game_controllers.destroy(entity_id);
      self.monsters.destroy(entity_id);
      self.phys_objects.destroy(entity_id);
      self.pickups.destroy(entity_id);
      self.players.destroy(entity_id);
      self.player_controllers.destroy(entity_id);
      self.transforms.destroy(entity_id);
      self.event_collides.destroy(entity_id);
      self.event_confer_bonuses.destroy(entity_id);
      self.event_award_pointses.destroy(entity_id);
      self.event_player_dieds.destroy(entity_id);
      self.event_take_damages.destroy(entity_id);
    }
    self.num_removals = 0;
  }
};

pub fn game_input(gs: *GameSession, event: InputEvent, down: bool) void {
  switch (event) {
    InputEvent.Left => {
      gs.in_left = down;
    },
    InputEvent.Right => {
      gs.in_right = down;
    },
    InputEvent.Up => {
      gs.in_up = down;
    },
    InputEvent.Down => {
      gs.in_down = down;
    },
    InputEvent.Shoot => {
      gs.in_shoot = down;
    },
  }
}
