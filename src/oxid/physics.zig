const std = @import("std");
const gbe = @import("gbe");
const warn = @import("../warn.zig").warn;
const math = @import("../common/math.zig");
const constants = @import("constants.zig");
const levels = @import("levels.zig");
const game = @import("game.zig");
const c = @import("components.zig");
const p = @import("prototypes.zig");

// convenience function
pub fn physInWall(phys: *c.PhysObject, pos: math.Vec2) bool {
    return levels.level1.boxInWall(pos, phys.world_bbox);
}

const MoveGroupMember = struct {
    phys: *c.PhysObject,
    next: ?*MoveGroupMember,
    entity_id: gbe.EntityId,
    progress: u31,
    step: u31,
};

const MoveGroup = struct {
    head: *MoveGroupMember,
    is_active: bool,
};

const max_phys_objects = comptime game.ECS.getCapacity(c.PhysObject);

var move_group_members: [max_phys_objects]MoveGroupMember = undefined;
var move_groups: [max_phys_objects]MoveGroup = undefined;

pub fn physicsFrame(gs: *game.Session) void {
    // calculate move bboxes
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        phys: *c.PhysObject,
        transform: *const c.Transform,
    });
    while (it.next()) |self| {
        self.phys.internal.move_bbox.mins = math.vec2Add(self.transform.pos, self.phys.entity_bbox.mins);
        self.phys.internal.move_bbox.maxs = math.vec2Add(self.transform.pos, self.phys.entity_bbox.maxs);

        if (self.phys.speed == 0) {
            continue;
        }

        const speed: i32 = self.phys.speed;

        switch (self.phys.facing) {
            .w => self.phys.internal.move_bbox.mins.x -= speed,
            .e => self.phys.internal.move_bbox.maxs.x += speed,
            .n => self.phys.internal.move_bbox.mins.y -= speed,
            .s => self.phys.internal.move_bbox.maxs.y += speed,
        }

        // push_dir represents the possibility of changing direction in mid-move,
        // so factor that into the move box as well
        if (self.phys.push_dir) |push_dir| {
            if (push_dir != self.phys.facing) {
                switch (push_dir) {
                    .w => self.phys.internal.move_bbox.mins.x -= speed,
                    .e => self.phys.internal.move_bbox.maxs.x += speed,
                    .n => self.phys.internal.move_bbox.mins.y -= speed,
                    .s => self.phys.internal.move_bbox.maxs.y += speed,
                }
            }
        }
    }

    // TODO - some broadphase thing to avoid all global O(n2) checks?

    // group intersecting moves
    var num_move_groups: usize = 0;
    var i: usize = 0;
    var it2 = gs.ecs.iter(struct {
        id: gbe.EntityId,
        phys: *c.PhysObject,
    });
    while (it2.next()) |self| : (i += 1) {
        var my_move_group: ?*MoveGroup = null;
        // try to add to an existing move_group
        for (move_groups[0..num_move_groups]) |*move_group| {
            if (!move_group.is_active) {
                continue;
            }
            if (phys_overlaps_move_group(self.phys, move_group)) {
                if (my_move_group) |mmg| {
                    // this is a subsequent move_group that phys overlaps.
                    // merge move_group into my_move_group
                    mergeMoveGroups(mmg, move_group);
                } else {
                    // this is the first move_group that phys overlaps
                    my_move_group = move_group;
                    // add self to the move group
                    const member = &move_group_members[i];
                    member.* = .{
                        .phys = self.phys,
                        .entity_id = self.id,
                        .progress = 0,
                        .step = undefined,
                        .next = move_group.head,
                    };
                    move_group.head = member;
                }
            }
        }
        if (my_move_group == null) {
            // create a new move group
            const member = &move_group_members[i];
            member.* = .{
                .phys = self.phys,
                .entity_id = self.id,
                .progress = 0,
                .step = undefined,
                .next = null,
            };
            const move_group = for (move_groups[0..num_move_groups]) |*mg| {
                if (!mg.is_active) {
                    break mg;
                }
            } else blk: {
                const mg = &move_groups[num_move_groups];
                num_move_groups += 1;
                break :blk mg;
            };
            move_group.* = .{
                .is_active = true,
                .head = member,
            };
        }
    }

    // set `group_index` (used for debug drawing)
    for (move_groups[0..num_move_groups]) |*move_group, j| {
        if (!move_group.is_active) {
            continue;
        }
        var member: ?*MoveGroupMember = move_group.head;
        while (member) |m| : (member = m.next) {
            m.phys.internal.group_index = j;
        }
    }

    // resolve move groups independently
    for (move_groups[0..num_move_groups]) |*move_group| {
        if (!move_group.is_active) {
            continue;
        }
        // calculate the product of all the non-zero speeds of move group members
        // TODO - could i find the least common multiple?
        var speed_product: u31 = 0;
        var member: ?*MoveGroupMember = move_group.head;
        while (member) |m| : (member = m.next) {
            if (m.phys.speed > 0) {
                if (speed_product != 0) {
                    speed_product *= @intCast(u31, m.phys.speed);
                } else {
                    speed_product = @intCast(u31, m.phys.speed);
                }
            }
        }

        // calculate step amount for each group member
        member = move_group.head;
        while (member) |m| : (member = m.next) {
            if (m.phys.speed > 0) {
                m.step = speed_product / @intCast(u31, m.phys.speed);
            } else {
                m.step = 0;
            }
        }

        // members take turns moving forward one subpixel
        var sanity: usize = 0;
        while (true) {
            sanity += 1;
            std.debug.assert(sanity < 10000);

            // which member has the lowest progress?
            // TODO - if there is a tie, the one with highest speed should go first
            // (this could be implemented by sorting the members of the move group)
            // bah... nevermind. there are bigger problems than this
            var lowest: ?*MoveGroupMember = null;
            member = move_group.head;
            while (member) |m| : (member = m.next) {
                if (m.phys.speed != 0 and m.progress < speed_product) {
                    if (lowest) |l| {
                        if (m.progress < l.progress) {
                            lowest = m;
                        }
                    } else {
                        lowest = m;
                    }
                }
            }

            if (lowest) |m| {
                // try to move this guy one subpixel
                const transform = gs.ecs.findComponentById(m.entity_id, c.Transform).?;
                var new_pos = math.vec2Add(transform.pos, math.getNormal(m.phys.facing));

                // if push_dir differs from velocity direction, and we can
                // move in that direction, redirect velocity to go in that
                // direction
                if (m.phys.push_dir) |push_dir| {
                    if (push_dir != m.phys.facing) {
                        const new_pos2 = math.vec2Add(transform.pos, math.getNormal(push_dir));
                        if (!physInWall(m.phys, new_pos2)) {
                            m.phys.facing = push_dir;
                            new_pos = new_pos2;
                        }
                    }
                }

                var hit_something = false;

                if (physInWall(m.phys, new_pos)) {
                    _ = p.EventCollide.spawn(gs, .{
                        .self_id = m.entity_id,
                        .other_id = .{ .id = 0 },
                        .propelled = true,
                    }) catch undefined;
                    hit_something = true;
                }

                var other: ?*MoveGroupMember = move_group.head;
                while (other) |o| : (other = o.next) {
                    if (couldObjectsCollide(m.entity_id, m.phys, o.entity_id, o.phys)) {
                        const other_transform = gs.ecs.findComponentById(o.entity_id, c.Transform).?;

                        if (math.boxesOverlap(
                            new_pos,
                            m.phys.entity_bbox,
                            other_transform.pos,
                            o.phys.entity_bbox,
                        )) {
                            collide(gs, m.entity_id, o.entity_id);
                            if (!m.phys.illusory and !o.phys.illusory) {
                                hit_something = true;
                            }
                        }
                    }
                }

                if (!hit_something) {
                    transform.pos = new_pos;
                    m.progress += m.step;
                } else {
                    m.progress = speed_product;
                }
            } else {
                // we are done
                break;
            }
        }
    }

    assertNoOverlaps(gs);
}

fn collide(gs: *game.Session, self_id: gbe.EntityId, other_id: gbe.EntityId) void {
    if (findCollisionEvent(gs, self_id, other_id)) |event_collide| {
        event_collide.propelled = true;
    } else {
        _ = p.EventCollide.spawn(gs, .{
            .self_id = self_id,
            .other_id = other_id,
            .propelled = true,
        }) catch undefined;
    }

    if (findCollisionEvent(gs, other_id, self_id) == null) {
        _ = p.EventCollide.spawn(gs, .{
            .self_id = other_id,
            .other_id = self_id,
            .propelled = false,
        }) catch undefined;
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

fn mergeMoveGroups(dest: *MoveGroup, src: *MoveGroup) void {
    var old_dest_count: usize = 0;
    var old_src_count: usize = 0;
    var member: ?*MoveGroupMember = undefined;
    member = dest.head;
    while (member) |m| {
        old_dest_count += 1;
        member = m.next;
    }
    member = src.head;
    while (member) |m| {
        old_src_count += 1;
        member = m.next;
    }

    var last_member = dest.head;
    while (last_member.next) |next| {
        last_member = next;
    }
    std.debug.assert(last_member.next == null);
    last_member.next = src.head;
    src.is_active = false;

    var new_dest_count: usize = 0;
    member = dest.head;
    while (member) |m| {
        new_dest_count += 1;
        member = m.next;
    }
    std.debug.assert(new_dest_count == old_dest_count + old_src_count);
}

fn phys_overlaps_move_group(phys: *c.PhysObject, move_group: *MoveGroup) bool {
    var member: ?*MoveGroupMember = move_group.head;
    while (member) |m| : (member = m.next) {
        if (math.absBoxesOverlap(phys.internal.move_bbox, m.phys.internal.move_bbox)) {
            return true;
        }
    }
    return false;
}

// a and b params in this function should be commutative
fn couldObjectsCollide(
    a_id: gbe.EntityId,
    a_phys: *const c.PhysObject,
    b_id: gbe.EntityId,
    b_phys: *const c.PhysObject,
) bool {
    if (gbe.EntityId.eql(a_id, b_id)) {
        return false;
    }
    if (gbe.EntityId.eql(a_id, b_phys.owner_id)) {
        return false;
    }
    if (gbe.EntityId.eql(a_phys.owner_id, b_id)) {
        return false;
    }
    if ((a_phys.flags & b_phys.ignore_flags) != 0) {
        return false;
    }
    if ((a_phys.ignore_flags & b_phys.flags) != 0) {
        return false;
    }
    return true;
}

fn assertNoOverlaps(gs: *game.Session) void {
    const T = struct {
        id: gbe.EntityId,
        phys: *const c.PhysObject,
        transform: *const c.Transform,
    };
    var it = gs.ecs.iter(T);
    while (it.next()) |self| {
        if (self.phys.illusory) {
            continue;
        }
        var it2 = gs.ecs.iter(T);
        while (it2.next()) |other| {
            if (other.phys.illusory) {
                continue;
            }
            if (!couldObjectsCollide(self.id, self.phys, other.id, other.phys)) {
                continue;
            }
            if (math.boxesOverlap(
                self.transform.pos,
                self.phys.entity_bbox,
                other.transform.pos,
                other.phys.entity_bbox,
            )) {
                warn("who is this joker\n", .{});
            }
        }
    }
}
