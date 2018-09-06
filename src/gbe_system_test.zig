const std = @import("std");
const Gbe = @import("gbe.zig");
const GbeSystem = @import("gbe_system.zig");

const Creature = struct{ hit_points: u32 };
const Monster = struct{ chasing: bool };
const Player = struct{ attack_level: u32 };
const Transform = struct{ x: i32, y: i32 };

const GameComponentLists = struct {
  Creature: Gbe.ComponentList(Creature, 50),
  Monster: Gbe.ComponentList(Monster, 50),
  Player: Gbe.ComponentList(Player, 50),
  Transform: Gbe.ComponentList(Transform, 50),
};

const MockGameSession = struct {
  gbe: Gbe.Session(GameComponentLists),
};

fn prepareGs(gs: *MockGameSession) !void {
  gs.gbe.init(0);

  var i: usize = undefined;

  i = 0; while (i < 8) : (i += 1) {
    const entity_id = gs.gbe.spawn();
    try gs.gbe.addComponent(entity_id, Transform{ .x = 0, .y = 0 });
    try gs.gbe.addComponent(entity_id, Creature{ .hit_points = 8 });
    try gs.gbe.addComponent(entity_id, Monster{ .chasing = true });
  }
  i = 0; while (i < 8) : (i += 1) {
    const entity_id = gs.gbe.spawn();
    try gs.gbe.addComponent(entity_id, Transform{ .x = 0, .y = 0 });
    try gs.gbe.addComponent(entity_id, Creature{ .hit_points = 16 });
    try gs.gbe.addComponent(entity_id, Player{ .attack_level = 0 });
  }
}

var g_count: u32 = undefined;

const SystemData = struct{
  creature: *Creature,
  transform: *Transform,
};

fn think(gs: *MockGameSession, self: SystemData) bool {
  std.debug.assert(self.transform.x == 0);
  std.debug.assert(self.transform.y == 0);
  std.debug.assert(self.creature.hit_points == 8 or self.creature.hit_points == 16);
  g_count += 1;
  return true;
}

test "GbeSystem basic test" {
  var the_gs: MockGameSession = undefined;
  try prepareGs(&the_gs);
  g_count = 0;
  GbeSystem.build(MockGameSession, SystemData, think)(&the_gs);
  std.debug.assert(g_count == 16);
}

const SystemData2 = struct{
  transform: *Transform,
  creature: ?*Creature,
};

fn think2(gs: *MockGameSession, self: SystemData2) bool {
  std.debug.assert(self.transform.x == 0);
  std.debug.assert(self.transform.y == 0);
  std.debug.assert(if (self.creature) |creature| creature.hit_points == 8 or creature.hit_points == 16 else false);
  g_count += 1;
  return true;
}

test "GbeSystem works with one optional and one required component" {
  var the_gs: MockGameSession = undefined;
  try prepareGs(&the_gs);
  g_count = 0;
  GbeSystem.build(MockGameSession, SystemData2, think2)(&the_gs);
  std.debug.assert(g_count == 16);
}

const SystemData3 = struct{
  transform: ?*Transform,
  creature: ?*Creature,
};

fn think3(gs: *MockGameSession, self: SystemData3) bool {
  std.debug.assert(if (self.transform) |transform| transform.x == 0 else false);
  std.debug.assert(if (self.transform) |transform| transform.y == 0 else false);
  std.debug.assert(if (self.creature) |creature| creature.hit_points == 8 or creature.hit_points == 16 else false);
  g_count += 1;
  return true;
}

test "GbeSystem works if all components are optional" {
  var the_gs: MockGameSession = undefined;
  try prepareGs(&the_gs);
  g_count = 0;
  GbeSystem.build(MockGameSession, SystemData3, think3)(&the_gs);
  std.debug.assert(g_count == 16);
}

// any way to test something that would result in a compile error...?
// e.g. a SystemData which doesn't contain any component pointers
