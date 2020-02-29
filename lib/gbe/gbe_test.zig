const std = @import("std");
const gbe = @import("gbe.zig");

const Creature = struct { hit_points: u32 };
const Monster = struct { chasing: bool };
const Player = struct { attack_level: u32 };
const Transform = struct { x: i32, y: i32 };
const EventDie = struct { self_id: gbe.EntityId, num: usize };

const MockECS = gbe.ECS(&[_]gbe.ComponentDef {
    .{ .Type = Creature, .capacity = 50 },
    .{ .Type = Monster, .capacity = 50 },
    .{ .Type = Player, .capacity = 50 },
    .{ .Type = Transform, .capacity = 50 },
    .{ .Type = EventDie, .capacity = 50 },
});

fn initECS(ecs: *MockECS, allocator: *std.mem.Allocator) !void {
    try MockECS.init(ecs, allocator);

    var i: usize = undefined;

    i = 0; while (i < 8) : (i += 1) {
        const entity_id = ecs.spawn();
        try ecs.addComponent(entity_id, Transform { .x = 0, .y = 0 });
        try ecs.addComponent(entity_id, Creature { .hit_points = 8 });
        try ecs.addComponent(entity_id, Monster { .chasing = true });
    }
    var player_ids: [8]gbe.EntityId = undefined;
    i = 0; while (i < 8) : (i += 1) {
        const entity_id = ecs.spawn();
        try ecs.addComponent(entity_id, Transform { .x = 0, .y = 0 });
        try ecs.addComponent(entity_id, Creature { .hit_points = 16 });
        try ecs.addComponent(entity_id, Player { .attack_level = 0 });
        player_ids[i] = entity_id;
    }
    i = 0; while (i < 2) : (i += 1) {
        const entity_id = ecs.spawn();
        try ecs.addComponent(entity_id, EventDie {
            .self_id = player_ids[i],
            .num = i,
        });
    }

    ecs.settle();
}

test "EntityIterator basic test" {
    var ecs: MockECS = undefined;
    try initECS(&ecs, std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var it = ecs.iter(struct {
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
    var ecs: MockECS = undefined;
    try initECS(&ecs, std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var it = ecs.iter(struct {
        player: *Player,
    });
    var i: usize = 0; while (i < 8) : (i += 1) {
        const entry = it.next().?;
        std.testing.expect(entry.player.attack_level == 0);
    }
    std.testing.expect(it.next() == null);
}

test "EntityIterator test with optionals and id field" {
    var ecs: MockECS = undefined;
    try initECS(&ecs, std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var it = ecs.iter(struct {
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

test "EntityIterator test with inbox" {
    var ecs: MockECS = undefined;
    try initECS(&ecs, std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var it = ecs.iter(struct {
        id: gbe.EntityId,
        player: *Player,
        inbox: gbe.Inbox(10, EventDie, "self_id"),
    });
    var i: usize = 0; while (i < 2) : (i += 1) {
        var entry = it.next().?;
        std.testing.expect(entry.inbox.all().len == 1);
        std.testing.expect(entry.inbox.all()[0].num == i);
        std.testing.expect(entry.inbox.one().num == i);
    }
    std.testing.expect(it.next() == null);
}

test "EntityIterator test with inbox with null id_field" {
    var ecs: MockECS = undefined;
    try initECS(&ecs, std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var it = ecs.iter(struct {
        id: gbe.EntityId,
        player: *Player,
        inbox: gbe.Inbox(10, EventDie, null),
    });
    var i: usize = 0; while (i < 8) : (i += 1) {
        var entry = it.next().?;
        const all = entry.inbox.all();
        std.testing.expect(all.len == 2);
        var j: usize = 0; while (j < 2) : (j += 1) {
            std.testing.expect(all[j].num == j);
        }
    }
    std.testing.expect(it.next() == null);
}

// TODO blocked on https://github.com/ziglang/zig/issues/4539
//test "EntityIterator test with inbox referring to 0-bit component" {
//    const NotEmpty = struct { field: u32 };
//    const Empty = struct {};
//    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
//        .{ .Type = NotEmpty, .capacity = 5 },
//        .{ .Type = Empty, .capacity = 5 },
//    }) = undefined;
//    try ecs.init(std.heap.page_allocator);
//    defer ecs.deinit(std.heap.page_allocator);
//
//    try ecs.addComponent(ecs.spawn(), NotEmpty { .field = 0 });
//    try ecs.addComponent(ecs.spawn(), NotEmpty { .field = 1 });
//    try ecs.addComponent(ecs.spawn(), Empty {});
//    try ecs.addComponent(ecs.spawn(), Empty {});
//    try ecs.addComponent(ecs.spawn(), Empty {});
//    ecs.settle();
//
//    var it = ecs.iter(struct {
//        id: gbe.EntityId,
//        not_empty: *NotEmpty,
//        inbox: gbe.Inbox(10, Empty, null),
//    });
//    var entry = it.next().?;
//    std.testing.expect(entry.not_empty.field == 0);
//    std.testing.expect(entry.inbox.all().len == 3);
//    entry = it.next().?;
//    std.testing.expect(entry.not_empty.field == 1);
//    std.testing.expect(entry.inbox.all().len == 3);
//    std.testing.expect(it.next() == null);
//}

test "EntityIterator where \"main\" component type is zero-sized" {
    // make sure the "next main component" function supports zero sized
    // components
    const NotEmpty = struct { field: u32 };
    const Empty = struct {};

    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = NotEmpty, .capacity = 5 },
        .{ .Type = Empty, .capacity = 4 }, // less capacity = best
    }) = undefined;

    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var i: u32 = 0; while (i < 2) : (i += 1) {
        const entity_id = ecs.spawn();
        try ecs.addComponent(entity_id, NotEmpty { .field = i });
        try ecs.addComponent(entity_id, Empty {});
    }

    ecs.settle();

    var it = ecs.iter(struct {
        not_empty: *NotEmpty,
        empty: *Empty,
    });

    i = 0; while (i < 2) : (i += 1) {
        const entry = it.next().?;
        std.testing.expect(entry.not_empty.field == i);
    }

    std.testing.expect(it.next() == null);
}

test "EntityIterator with an optional zero-size component" {
    const NotEmpty = struct { field: u32 };
    const Empty = struct {};

    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = NotEmpty, .capacity = 5 },
        .{ .Type = Empty, .capacity = 5 },
    }) = undefined;

    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var entity_id = ecs.spawn();
    try ecs.addComponent(entity_id, NotEmpty { .field = 1 });
    try ecs.addComponent(entity_id, Empty {});

    entity_id = ecs.spawn();
    try ecs.addComponent(entity_id, NotEmpty { .field = 2 });

    ecs.settle();

    var it = ecs.iter(struct {
        not_empty: *NotEmpty,
        empty: ?*Empty,
    });

    var entry = it.next().?;
    std.testing.expect(entry.not_empty.field == 1);
    std.testing.expect(entry.empty != null);

    entry = it.next().?;
    std.testing.expect(entry.not_empty.field == 2);
    std.testing.expect(entry.empty == null);

    std.testing.expect(it.next() == null);
}

test "EntityIterator with a 0-size component" {
    const NotEmpty = struct { field: u32 };
    const Empty = struct {};

    const ECS = gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = NotEmpty, .capacity = 5 },
        .{ .Type = Empty, .capacity = 5 },
    });

    var ecs: ECS = undefined;
    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    var entity_id = ecs.spawn();
    try ecs.addComponent(entity_id, NotEmpty { .field = 1 });
    try ecs.addComponent(entity_id, Empty {});

    entity_id = ecs.spawn();
    try ecs.addComponent(entity_id, NotEmpty { .field = 2 });

    ecs.settle();

    var it = ecs.iter(struct {
        not_empty: *NotEmpty,
        empty: *Empty,
    });

    const entry = it.next().?;
    std.testing.expect(entry.not_empty.field == 1);

    std.testing.expect(it.next() == null);
}

test "ComponentIterator with a non-empty struct component" {
    const NonEmpty = struct { field: u32 };
    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = NonEmpty, .capacity = 5 },
    }) = undefined;
    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    try ecs.addComponent(ecs.spawn(), NonEmpty { .field = 1 });
    try ecs.addComponent(ecs.spawn(), NonEmpty { .field = 2 });
    ecs.settle();
    try ecs.addComponent(ecs.spawn(), NonEmpty { .field = 3 });

    var it = ecs.componentIter(NonEmpty);
    std.testing.expect(it.next().?.field == 1);
    std.testing.expect(it.next().?.field == 2);
    std.testing.expect(it.next() == null);
}

test "ComponentIterator with a non-struct component" {
    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = f32, .capacity = 5 },
    }) = undefined;
    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    try ecs.addComponent(ecs.spawn(), @as(f32, 1.0));
    try ecs.addComponent(ecs.spawn(), @as(f32, 2.0));
    ecs.settle();
    try ecs.addComponent(ecs.spawn(), @as(f32, 3.0));

    var it = ecs.componentIter(f32);
    std.testing.expect(it.next() != null);
    std.testing.expect(it.next() != null);
    std.testing.expect(it.next() == null);
}

test "ComponentIterator with an empty struct component" {
    const Empty = struct {};
    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = Empty, .capacity = 5 },
    }) = undefined;
    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    try ecs.addComponent(ecs.spawn(), Empty {});
    try ecs.addComponent(ecs.spawn(), Empty {});
    ecs.settle();
    try ecs.addComponent(ecs.spawn(), Empty {});

    var it = ecs.componentIter(Empty);
    std.testing.expect(it.next() != null);
    std.testing.expect(it.next() != null);
    std.testing.expect(it.next() == null);
}

test "ComponentIterator with a 0-size non-struct component" {
    var ecs: gbe.ECS(&[_]gbe.ComponentDef {
        .{ .Type = u0, .capacity = 5 },
    }) = undefined;
    try ecs.init(std.heap.page_allocator);
    defer ecs.deinit(std.heap.page_allocator);

    try ecs.addComponent(ecs.spawn(), @as(u0, 0));
    try ecs.addComponent(ecs.spawn(), @as(u0, 0));
    ecs.settle();
    try ecs.addComponent(ecs.spawn(), @as(u0, 0));

    var it = ecs.componentIter(u0);
    std.testing.expect(it.next() != null);
    std.testing.expect(it.next() != null);
    std.testing.expect(it.next() == null);
}
