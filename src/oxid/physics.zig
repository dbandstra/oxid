const builtin = @import("builtin");
const std = @import("std");
const gbe = @import("gbe");
const math = @import("../common/math.zig");
const levels = @import("levels.zig");
const game = @import("game.zig");
const c = @import("components.zig");
const p = @import("prototypes.zig");

// convenience function
pub fn inWall(phys: *c.PhysObject, pos: math.Vec2) bool {
    return levels.boxInWall(levels.level1, pos, phys.world_bbox);
}

const Entity = struct {
    id: gbe.EntityId,
    transform: *c.Transform,
    phys: *c.PhysObject,
};

const MoveGroupMember = struct {
    entity: Entity,
    progress: u31,
    step: u31,
    next: ?*MoveGroupMember,
};

const MoveGroup = struct {
    head: ?*MoveGroupMember,
};

const max_phys_objects = game.ECS.getCapacity(c.PhysObject);

var g_move_group_members: [max_phys_objects]MoveGroupMember = undefined;
var g_move_groups: [max_phys_objects]MoveGroup = undefined;

pub fn frame(gs: *game.Session) void {
    // create a "move group" for each cluster of potentially interacting entities
    const move_groups = createMoveGroups(gs);

    // set each entity's `group_index` field (used for debug drawing)
    for (move_groups) |*move_group, j| {
        var member = move_group.head;
        while (member) |m| : (member = m.next) {
            m.entity.phys.internal.group_index = j;
        }
    }

    // resolve each move group independently
    for (move_groups) |*move_group| {
        resolveMoveGroup(gs, move_group);
    }

    if (builtin.mode == .Debug) {
        assertNoOverlaps(gs);
    }
}

// return a bounding box encapsulating the entity's potential movement space for this frame
fn getMoveBBox(self: Entity) math.Box {
    var mins = math.vec2Add(self.transform.pos, self.phys.entity_bbox.mins);
    var maxs = math.vec2Add(self.transform.pos, self.phys.entity_bbox.maxs);

    if (self.phys.speed > 0) {
        const speed: i32 = self.phys.speed;

        switch (self.phys.facing) {
            .w => mins.x -= speed,
            .e => maxs.x += speed,
            .n => mins.y -= speed,
            .s => maxs.y += speed,
        }

        // push_dir represents the possibility of changing direction in mid-move,
        // so factor that into the move box as well
        if (self.phys.push_dir) |push_dir| {
            if (push_dir != self.phys.facing) {
                switch (push_dir) {
                    .w => mins.x -= speed,
                    .e => maxs.x += speed,
                    .n => mins.y -= speed,
                    .s => maxs.y += speed,
                }
            }
        }
    }

    return .{
        .mins = mins,
        .maxs = maxs,
    };
}

fn createMoveGroups(gs: *game.Session) []const MoveGroup {
    var num_move_groups: usize = 0;
    var i: usize = 0;
    var it = gs.ecs.iter(Entity);
    while (it.next()) |self| : (i += 1) {
        self.phys.internal.move_bbox = getMoveBBox(self);

        const member = &g_move_group_members[i];
        member.* = .{
            .entity = self,
            .progress = 0,
            .step = undefined,
            .next = null,
        };

        var first_inactive_group: ?*MoveGroup = null;
        var my_move_group: ?*MoveGroup = null;

        // try to add to an existing move_group
        for (g_move_groups[0..num_move_groups]) |*move_group| {
            if (move_group.head == null) {
                // keep track of the first empty move group so we can reuse it if we need to make
                // a new one
                if (first_inactive_group == null) {
                    first_inactive_group = move_group;
                }
                continue;
            }
            if (physOverlapsMoveGroup(self.phys, move_group)) {
                if (my_move_group) |mmg| {
                    // this entity already overlapped a move group, now it's overlapping another
                    // one, forming a bridge between the two groups. so merge the second one into
                    // the first one (which this entity is already a member of)
                    mergeMoveGroups(mmg, move_group);
                } else {
                    // this is the first move group that this entity has been found to overlap
                    member.next = move_group.head;
                    move_group.head = member;
                    my_move_group = move_group;
                }
            }
        }
        if (my_move_group == null) {
            // entity didn't intersect any existing move group, so create a new one
            const move_group = first_inactive_group orelse blk: {
                const mg = &g_move_groups[num_move_groups];
                num_move_groups += 1;
                break :blk mg;
            };
            move_group.* = .{ .head = member };
        }
    }

    return g_move_groups[0..num_move_groups];
}

// check if the given entity intersects the move group, by checking it against each of the move
// group's members
fn physOverlapsMoveGroup(phys: *c.PhysObject, move_group: *MoveGroup) bool {
    var member = move_group.head;
    while (member) |m| : (member = m.next) {
        if (math.absBoxesOverlap(phys.internal.move_bbox, m.entity.phys.internal.move_bbox))
            return true;
    }
    return false;
}

// merge `src` into `dest`, leaving `src` as empty
fn mergeMoveGroups(dest: *MoveGroup, src: *MoveGroup) void {
    if (dest.head) |dest_head| {
        var last_member = dest_head;
        while (last_member.next) |next| {
            last_member = next;
        }
        last_member.next = src.head;
    } else {
        dest.head = src.head;
    }
    src.head = null;
}

// move all the entities in the move group according to their velocities and spawn collision
// events where they hit walls or each other
fn resolveMoveGroup(gs: *game.Session, move_group: *const MoveGroup) void {
    // calculate the product of all the non-zero speeds of move group members
    // TODO - could i find the least common multiple?
    const speed_product = blk: {
        var product: u31 = 0;
        var member = move_group.head;
        while (member) |m| : (member = m.next) {
            if (m.entity.phys.speed > 0) {
                if (product != 0) {
                    product *= m.entity.phys.speed;
                } else {
                    product = m.entity.phys.speed;
                }
            }
        }
        break :blk product;
    };

    if (speed_product == 0) {
        // either the move group was empty, or it consisted only of non-moving entities
        return;
    }

    // calculate step amount for each group member
    {
        var member = move_group.head;
        while (member) |m| : (member = m.next) {
            if (m.entity.phys.speed > 0) {
                m.step = speed_product / m.entity.phys.speed;
            } else {
                m.step = 0;
            }
        }
    }

    // members take turns moving forward one subpixel
    var sanity: usize = 0;
    while (sanity < 10000) : (sanity += 1) {
        // which member has the lowest progress?
        // TODO - if there is a tie, the one with highest speed should go first
        // (this could be implemented by sorting the members of the move group)
        // bah... nevermind. there are bigger problems than this
        const maybe_lowest = blk: {
            var lowest: ?*MoveGroupMember = null;
            var member = move_group.head;
            while (member) |m| : (member = m.next) {
                if (m.entity.phys.speed != 0 and m.progress < speed_product) {
                    if (lowest) |l| {
                        if (m.progress < l.progress) {
                            lowest = m;
                        }
                    } else {
                        lowest = m;
                    }
                }
            }
            break :blk lowest;
        };
        const m = maybe_lowest orelse break;

        // try to move this guy one subpixel
        var new_pos = math.vec2Add(m.entity.transform.pos, math.getNormal(m.entity.phys.facing));

        // if push_dir differs from velocity direction, and we can move in that direction,
        // redirect velocity to go in that direction
        if (m.entity.phys.push_dir) |push_dir| {
            if (push_dir != m.entity.phys.facing) {
                const new_pos2 = math.vec2Add(m.entity.transform.pos, math.getNormal(push_dir));
                if (!inWall(m.entity.phys, new_pos2)) {
                    m.entity.phys.facing = push_dir;
                    new_pos = new_pos2;
                }
            }
        }

        var hit_something = false;

        if (inWall(m.entity.phys, new_pos)) {
            p.spawnEventCollide(gs, .{
                .self_id = m.entity.id,
                .other_id = .{ .id = 0 },
                .propelled = true,
            });
            hit_something = true;
        }

        var other = move_group.head;
        while (other) |o| : (other = o.next) {
            if (couldObjectsCollide(m.entity.id, m.entity.phys, o.entity.id, o.entity.phys)) {
                if (math.boxesOverlap(
                    new_pos,
                    m.entity.phys.entity_bbox,
                    o.entity.transform.pos,
                    o.entity.phys.entity_bbox,
                )) {
                    spawnCollisionEvents(gs, m.entity.id, o.entity.id);
                    if (!m.entity.phys.illusory and !o.entity.phys.illusory) {
                        hit_something = true;
                    }
                }
            }
        }

        if (!hit_something) {
            m.entity.transform.pos = new_pos;
            m.progress += m.step;
        } else {
            m.progress = speed_product;
        }
    }
}

fn spawnCollisionEvents(gs: *game.Session, self_id: gbe.EntityId, other_id: gbe.EntityId) void {
    if (findCollisionEvent(gs, self_id, other_id)) |event_collide| {
        event_collide.propelled = true;
    } else {
        p.spawnEventCollide(gs, .{
            .self_id = self_id,
            .other_id = other_id,
            .propelled = true,
        });
    }

    if (findCollisionEvent(gs, other_id, self_id) == null) {
        p.spawnEventCollide(gs, .{
            .self_id = other_id,
            .other_id = self_id,
            .propelled = false,
        });
    }
}

fn findCollisionEvent(
    gs: *game.Session,
    self_id: gbe.EntityId,
    other_id: gbe.EntityId,
) ?*c.EventCollide {
    var it = gs.ecs.componentIter(c.EventCollide);
    while (it.next()) |event| {
        if (!gbe.EntityId.eql(event.self_id, self_id)) continue;
        if (!gbe.EntityId.eql(event.other_id, other_id)) continue;
        return event;
    }
    return null;
}

// a and b params in this function should be commutative
fn couldObjectsCollide(
    a_id: gbe.EntityId,
    a_phys: *const c.PhysObject,
    b_id: gbe.EntityId,
    b_phys: *const c.PhysObject,
) bool {
    if (gbe.EntityId.eql(a_id, b_id)) return false;
    if (gbe.EntityId.eql(a_id, b_phys.owner_id)) return false;
    if (gbe.EntityId.eql(a_phys.owner_id, b_id)) return false;
    if ((a_phys.flags & b_phys.ignore_flags) != 0) return false;
    if ((a_phys.ignore_flags & b_phys.flags) != 0) return false;
    return true;
}

// log a message if any entities are found to overlap. this either means there's a logic error in
// the physics code above, or a solid entity was spawned in a position intersecting another solid
// entity (which would be considered a logic error in the game code).
fn assertNoOverlaps(gs: *game.Session) void {
    var it = gs.ecs.iter(Entity);
    while (it.next()) |self| {
        if (self.phys.illusory)
            continue;
        var it2 = gs.ecs.iter(Entity);
        while (it2.next()) |other| {
            if (other.phys.illusory)
                continue;
            if (!couldObjectsCollide(self.id, self.phys, other.id, other.phys))
                continue;
            if (math.boxesOverlap(
                self.transform.pos,
                self.phys.entity_bbox,
                other.transform.pos,
                other.phys.entity_bbox,
            )) {
                std.log.debug("who is this joker", .{});
            }
        }
    }
}
