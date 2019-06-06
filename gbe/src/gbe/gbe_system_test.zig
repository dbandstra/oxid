const std = @import("std");
const Gbe = @import("gbe_main.zig");
const buildSystem = @import("gbe_system.zig").buildSystem;

const Creature = struct{ hit_points: u32 };
const Monster = struct{ chasing: bool };
const Player = struct{ attack_level: u32 };
const Transform = struct{ x: i32, y: i32 };

const MockGameSession = Gbe.Session(struct{
    Creature: Gbe.ComponentList(Creature, 50),
    Monster: Gbe.ComponentList(Monster, 50),
    Player: Gbe.ComponentList(Player, 50),
    Transform: Gbe.ComponentList(Transform, 50),
});

fn prepareGs(gs: *MockGameSession) !void {
    gs.init(0);

    var i: usize = undefined;

    i = 0; while (i < 8) : (i += 1) {
        const entity_id = gs.spawn();
        try gs.addComponent(entity_id, Transform{ .x = 0, .y = 0 });
        try gs.addComponent(entity_id, Creature{ .hit_points = 8 });
        try gs.addComponent(entity_id, Monster{ .chasing = true });
    }
    i = 0; while (i < 8) : (i += 1) {
        const entity_id = gs.spawn();
        try gs.addComponent(entity_id, Transform{ .x = 0, .y = 0 });
        try gs.addComponent(entity_id, Creature{ .hit_points = 16 });
        try gs.addComponent(entity_id, Player{ .attack_level = 0 });
    }
}

var g_count: u32 = undefined;

///////////////////////////////////////

const SystemData1 = struct{
    creature: *Creature,
    transform: *Transform,
};

fn think1(gs: *MockGameSession, self: SystemData1) bool {
    std.testing.expect(self.transform.x == 0);
    std.testing.expect(self.transform.y == 0);
    std.testing.expect(self.creature.hit_points == 8 or self.creature.hit_points == 16);
    g_count += 1;
    return true;
}

const run1 = buildSystem(MockGameSession, SystemData1, think1);

test "GbeSystem basic test" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);
    g_count = 0;
    run1(&gs);
    std.testing.expect(g_count == 16);
}

///////////////////////////////////////

const SystemData2 = struct{
    transform: *Transform,
    creature: ?*Creature,
};

fn think2(gs: *MockGameSession, self: SystemData2) bool {
    std.testing.expect(self.transform.x == 0);
    std.testing.expect(self.transform.y == 0);
    std.testing.expect(if (self.creature) |creature| creature.hit_points == 8 or creature.hit_points == 16 else false);
    g_count += 1;
    return true;
}

const run2 = buildSystem(MockGameSession, SystemData2, think2);

test "GbeSystem works with one optional and one required component" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);
    g_count = 0;
    run2(&gs);
    std.testing.expect(g_count == 16);
}

///////////////////////////////////////

const SystemData3 = struct{
    transform: ?*Transform,
    creature: ?*Creature,
};

fn think3(gs: *MockGameSession, self: SystemData3) bool {
    std.testing.expect(if (self.transform) |transform| transform.x == 0 else false);
    std.testing.expect(if (self.transform) |transform| transform.y == 0 else false);
    std.testing.expect(if (self.creature) |creature| creature.hit_points == 8 or creature.hit_points == 16 else false);
    g_count += 1;
    return true;
}

const run3 = buildSystem(MockGameSession, SystemData3, think3);

test "GbeSystem works if all components are optional" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);
    g_count = 0;
    run3(&gs);
    std.testing.expect(g_count == 16);
}

// any way to test something that would result in a compile error...?
// e.g. a SystemData which doesn't contain any component pointers
