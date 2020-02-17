const std = @import("std");
const gbe = @import("gbe.zig");

const Creature = struct { hit_points: u32 };
const Monster = struct { chasing: bool };
const Player = struct { attack_level: u32 };
const Transform = struct { x: i32, y: i32 };
const EventDie = struct { self_id: gbe.EntityId, num: usize };

const MockGameSession = gbe.Session(struct {
    Creature: gbe.ComponentList(Creature, 50),
    Monster: gbe.ComponentList(Monster, 50),
    Player: gbe.ComponentList(Player, 50),
    Transform: gbe.ComponentList(Transform, 50),
    EventDie: gbe.ComponentList(EventDie, 50),
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
    var player_ids: [8]gbe.EntityId = undefined;
    i = 0; while (i < 8) : (i += 1) {
        const entity_id = gs.spawn();
        try gs.addComponent(entity_id, Transform { .x = 0, .y = 0 });
        try gs.addComponent(entity_id, Creature { .hit_points = 16 });
        try gs.addComponent(entity_id, Player { .attack_level = 0 });
        player_ids[i] = entity_id;
    }
    i = 0; while (i < 2) : (i += 1) {
        const entity_id = gs.spawn();
        try gs.addComponent(entity_id, EventDie {
            .self_id = player_ids[i],
            .num = i,
        });
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

test "EntityIterator test with optionals and id field" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);

    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        monster: ?*Monster,
        player: ?*Player,
        creature: *Creature,
        transform: *Transform,
    });
    var i: usize = 0; while (i < 16) : (i += 1) {
        const entry = it.next().?;
        std.testing.expect(entry.id.id == i + 1);
        if (i < 8) {
            std.testing.expect(entry.monster != null);
            std.testing.expect(entry.player == null);
        } else {
            std.testing.expect(entry.monster == null);
            std.testing.expect(entry.player != null);
        }
    }
    std.testing.expect(it.next() == null);
}

test "EntityIterator test with Events" {
    var gs: MockGameSession = undefined;
    try prepareGs(&gs);

    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        player: *Player,
        events: gbe.Inbox(EventDie, "self_id"),
    });
    var i: usize = 0; while (i < 8) : (i += 1) {
        const entry = it.next().?;
        if (i < 2) {
            std.testing.expect(entry.events.head != null);
            std.testing.expect(entry.events.head.?.num == i);
        } else {
            std.testing.expect(entry.events.head == null);
        }
    }
    std.testing.expect(it.next() == null);
}
