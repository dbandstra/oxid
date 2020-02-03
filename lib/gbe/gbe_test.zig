const std = @import("std");
const gbe = @import("gbe.zig");

const Creature = struct { hit_points: u32 };
const Monster = struct { chasing: bool };
const Player = struct { attack_level: u32 };
const Transform = struct { x: i32, y: i32 };

const MockGameSession = gbe.Session(struct {
    Creature: gbe.ComponentList(Creature, 50),
    Monster: gbe.ComponentList(Monster, 50),
    Player: gbe.ComponentList(Player, 50),
    Transform: gbe.ComponentList(Transform, 50),
});

fn prepareGs(gs: *MockGameSession) !void {
    gs.init(0);

    var i: usize = undefined;

    i = 0; while (i < 8) : (i += 1) {
        const entity_id = gs.spawn();
        try gs.addComponent(entity_id, Transform { .x = 0, .y = 0 });
        try gs.addComponent(entity_id, Creature { .hit_points = 8 });
        try gs.addComponent(entity_id, Monster { .chasing = true });
    }
    i = 0; while (i < 8) : (i += 1) {
        const entity_id = gs.spawn();
        try gs.addComponent(entity_id, Transform { .x = 0, .y = 0 });
        try gs.addComponent(entity_id, Creature { .hit_points = 16 });
        try gs.addComponent(entity_id, Player { .attack_level = 0 });
    }
}

test "EntityIterator basic test" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);

    var it = gs.entityIter(struct {
        creature: *Creature,
        transform: *Transform,
    });
    var i: usize = 0; while (i < 16) : (i += 1) {
        const entry = it.next().?;
        std.testing.expect(entry.transform.x == 0);
        std.testing.expect(entry.transform.y == 0);
        if (i < 8) {
            std.testing.expect(entry.creature.hit_points == 8);
        } else {
            std.testing.expect(entry.creature.hit_points == 16);
        }
    }
    std.testing.expect(it.next() == null);
}

test "EntityIterator only players" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);

    var it = gs.entityIter(struct {
        player: *Player,
    });
    var i: usize = 0; while (i < 8) : (i += 1) {
        const entry = it.next().?;
        std.testing.expect(entry.player.attack_level == 0);
    }
    std.testing.expect(it.next() == null);
}

// i don't think optionals is the only thing hitting it. the crash in game code didn't have any optionals.
// one of the components was being set to weird garbage
test "EntityIterator test with optionals and id field" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);

    gbe.spam = true;
    defer gbe.spam = false;

    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        monster: ?*Monster,
        player: ?*Player,
        creature: *Creature,
        transform: *Transform,
    });
    var i: usize = 0; while (i < 16) : (i += 1) {
        std.debug.warn("{}\n", .{i});
        const entry = it.next().?;
        std.testing.expect(entry.id.id == i + 1);
        if (i < 8) {
            std.testing.expect(entry.monster != null);
            std.testing.expect(entry.player == null); // this is failing at i=0
        } else {
            std.testing.expect(entry.monster == null);
            std.testing.expect(entry.player != null);
        }
    }
    std.testing.expect(it.next() == null);
}

///////////////////////////////////////

var g_count: usize = 0;

const SystemData1 = struct {
    creature: *Creature,
    transform: *Transform,
};

fn think1(gs: *MockGameSession, self: SystemData1) gbe.ThinkResult {
    std.testing.expect(self.transform.x == 0);
    std.testing.expect(self.transform.y == 0);
    std.testing.expect(self.creature.hit_points == 8 or self.creature.hit_points == 16);
    g_count += 1;
    return .Remain;
}

const run1 = gbe.buildSystem(MockGameSession, SystemData1, think1);

test "GbeSystem basic test" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);
    g_count = 0;
    run1(&gs);
    std.testing.expect(g_count == 16);
}

///////////////////////////////////////

const SystemData2 = struct {
    transform: *Transform,
    creature: ?*Creature,
};

fn think2(gs: *MockGameSession, self: SystemData2) gbe.ThinkResult {
    std.testing.expect(self.transform.x == 0);
    std.testing.expect(self.transform.y == 0);
    std.testing.expect(if (self.creature) |creature| creature.hit_points == 8 or creature.hit_points == 16 else false);
    g_count += 1;
    return .Remain;
}

const run2 = gbe.buildSystem(MockGameSession, SystemData2, think2);

test "GbeSystem works with one optional and one required component" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);
    g_count = 0;
    run2(&gs);
    std.testing.expect(g_count == 16);
}

///////////////////////////////////////

//const SystemData3 = struct {
//    transform: ?*Transform,
//    creature: ?*Creature,
//};
//
//fn think3(gs: *MockGameSession, self: SystemData3) gbe.ThinkResult {
//    std.testing.expect(if (self.transform) |transform| transform.x == 0 else false);
//    std.testing.expect(if (self.transform) |transform| transform.y == 0 else false);
//    std.testing.expect(if (self.creature) |creature| creature.hit_points == 8 or creature.hit_points == 16 else false);
//    g_count += 1;
//    return .Remain;
//}
//
//const run3 = gbe.buildSystem(MockGameSession, SystemData3, think3);
//
//test "GbeSystem works if all components are optional" {
//    var gs: MockGameSession = undefined;
//    try prepareGs(&gs);
//    g_count = 0;
//    run3(&gs);
//    std.testing.expect(g_count == 16);
//}

// any way to test something that would result in a compile error...?
// e.g. a SystemData which doesn't contain any component pointers
