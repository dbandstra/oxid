const std = @import("std");
const u31 = @import("types.zig").u31;
const Math = @import("math.zig");
const abs_boxes_overlap = @import("boxes_overlap.zig").abs_boxes_overlap;
const boxes_overlap = @import("boxes_overlap.zig").boxes_overlap;
const Constants = @import("game_constants.zig");
const LEVEL = @import("game_level.zig").LEVEL;
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const C = @import("game_components.zig");
const Prototypes = @import("game_prototypes.zig");

// convenience function
pub fn phys_in_wall(phys: *C.PhysObject, pos: Math.Vec2) bool {
  return LEVEL.box_in_wall(pos, phys.mins, phys.maxs, phys.ignore_pits);
}

const MoveGroupMember = struct{
  phys: *C.PhysObject,
  next: ?*MoveGroupMember,
  entity_id: EntityId,
  progress: u31,
  step: u31,
};

const MoveGroup = struct{
  head: *MoveGroupMember,
  is_active: bool,
};

var move_group_members: [Constants.MaxComponentsPerType]MoveGroupMember = undefined;
var move_groups: [Constants.MaxComponentsPerType]MoveGroup = undefined;

pub fn physics_frame(gs: *GameSession) void {
  // calculate move bboxes
  for (gs.phys_objects.objects[0..gs.phys_objects.count]) |*object| {
    if (!object.is_active) {
      continue;
    }
    const phys = &object.data;
    const transform = gs.transforms.find(object.entity_id).?;
    phys.internal.move_mins = Math.Vec2.add(transform.pos, phys.mins);
    phys.internal.move_maxs = Math.Vec2.add(transform.pos, phys.maxs);
    if (phys.speed != 0) {
      switch (phys.facing) {
        Math.Direction.Left => phys.internal.move_mins.x -= phys.speed,
        Math.Direction.Right => phys.internal.move_maxs.x += phys.speed,
        Math.Direction.Up => phys.internal.move_mins.y -= phys.speed,
        Math.Direction.Down => phys.internal.move_maxs.y += phys.speed,
      }
      // push_dir represents the possibility of changing direction in mid-move,
      // so factor that into the move box as well
      if (phys.push_dir) |push_dir| {
        if (push_dir != phys.facing) {
          switch (push_dir) {
            Math.Direction.Left => phys.internal.move_mins.x -= phys.speed,
            Math.Direction.Right => phys.internal.move_maxs.x += phys.speed,
            Math.Direction.Up => phys.internal.move_mins.y -= phys.speed,
            Math.Direction.Down => phys.internal.move_maxs.y += phys.speed,
          }
        }
      }
    }

        // phys.internal.move_mins.x -= 32;
        // phys.internal.move_maxs.x += 32;
        // phys.internal.move_mins.y -= 32;
        // phys.internal.move_maxs.y += 32;
  }

  // TODO - some broadphase thing to avoid all global O(n2) checks?

  // group intersecting moves
  var num_move_groups: usize = 0;
  for (gs.phys_objects.objects[0..gs.phys_objects.count]) |*object, i| {
    if (!object.is_active) {
      continue;
    }
    const phys = &object.data;
    var my_move_group: ?*MoveGroup = null;
    // try to add to an existing move_group
    for (move_groups[0..num_move_groups]) |*move_group| {
      if (!move_group.is_active) {
        continue;
      }
      if (phys_overlaps_move_group(phys, move_group)) {
        if (my_move_group) |mmg| {
          // this is a subsequent move_group that phys overlaps.
          // merge move_group into my_move_group
          merge_move_groups(mmg, move_group);
        } else {
          // this is the first move_group that phys overlaps
          my_move_group = move_group;
          // add self to the move group
          const member = &move_group_members[i];
          member.* = MoveGroupMember{
            .phys = phys,
            .entity_id = object.entity_id,
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
      member.* = MoveGroupMember{
        .phys = phys,
        .entity_id = object.entity_id,
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
      move_group.* = MoveGroup{
        .is_active = true,
        .head = member,
      };
    }
  }

  // set `group_index` (used for debug drawing)
  for (move_groups[0..num_move_groups]) |*move_group, i| {
    if (!move_group.is_active) {
      continue;
    }
    var member: ?*MoveGroupMember = move_group.head;
    while (member) |m| {
      m.phys.internal.group_index = i;
      member = m.next;
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
    while (member) |m| {
      if (m.phys.speed > 0) {
        if (speed_product != 0) {
          speed_product *= @intCast(u31, m.phys.speed);
        } else {
          speed_product = @intCast(u31, m.phys.speed);
        }
      }
      member = m.next;
    }

    // calculate step amount for each group member
    member = move_group.head;
    while (member) |m| {
      if (m.phys.speed > 0) {
        m.step = speed_product / @intCast(u31, m.phys.speed);
      } else {
        m.step = 0;
      }
      member = m.next;
    }

    // members take turns moving forward one subpixel
    var sanity: usize = 0;
    while (true) {
      sanity += 1; std.debug.assert(sanity < 10000);

      // which member has the lowest progress?
      // TODO - if there is a tie, the one with highest speed should go first
      // (this could be implemented by sorting the members of the move group)
      // bah... nevermind. there are bigger problems than this
      var lowest: ?*MoveGroupMember = null;
      member = move_group.head;
      while (member) |m| {
        if (m.phys.speed != 0 and m.progress < speed_product) {
          if (lowest) |l| {
            if (m.progress < l.progress) {
              lowest = m;
            }
          } else {
            lowest = m;
          }
        }
        member = m.next;
      }

      if (lowest) |m| {
        // try to move this guy one subpixel
        const transform = gs.transforms.find(m.entity_id).?;
        var new_pos = Math.Vec2.add(transform.pos, Math.get_dir_vec(m.phys.facing));

        // if push_dir differs from velocity direction, and we can move in that
        // direction, redirect velocity to go in that direction
        if (m.phys.push_dir) |push_dir| {
          if (push_dir != m.phys.facing) {
            const new_pos2 = Math.Vec2.add(transform.pos, Math.get_dir_vec(push_dir));
            if (!phys_in_wall(m.phys, new_pos2)) {
              m.phys.facing = push_dir;
              new_pos = new_pos2;
            }
          }
        }

        var hit_something = false;

        if (phys_in_wall(m.phys, new_pos)) {
          _ = Prototypes.spawnEventCollide(gs, m.entity_id, EntityId{ .id = 0 });
          hit_something = true;
        }

        var other: ?*MoveGroupMember = move_group.head;
        while (other) |o| {
          if (o != m and
              o.entity_id.id != m.phys.owner_id.id and
              o.phys.owner_id.id != m.entity_id.id and
              could_objects_collide(m.phys, o.phys)) {
            const other_transform = gs.transforms.find(o.entity_id).?;
            if (boxes_overlap(
              new_pos, m.phys.mins, m.phys.maxs,
              other_transform.pos, o.phys.mins, o.phys.maxs,
            )) {
              _ = Prototypes.spawnEventCollide(gs, m.entity_id, o.entity_id);
              hit_something = true;
            }
          }
          other = o.next;
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

  assert_no_overlaps(gs);
}

fn merge_move_groups(dest: *MoveGroup, src: *MoveGroup) void {
  var old_dest_count: usize = 0;
  var old_src_count: usize = 0;
  var member: ?*MoveGroupMember = undefined;
  member = dest.head; while (member) |m| { old_dest_count += 1; member = m.next; }
  member = src.head; while (member) |m| { old_src_count += 1; member = m.next; }
  
  var last_member = dest.head;
  while (last_member.next) |next| {
    last_member = next;
  }
  std.debug.assert(last_member.next == null);
  last_member.next = src.head;
  src.is_active = false;

  var new_dest_count: usize = 0;
  member = dest.head; while (member) |m| { new_dest_count += 1; member = m.next; }
  std.debug.assert(new_dest_count == old_dest_count + old_src_count);
}

fn phys_overlaps_move_group(phys: *C.PhysObject, move_group: *MoveGroup) bool {
  var member: ?*MoveGroupMember = move_group.head;
  while (member) |m| {
    if (abs_boxes_overlap(phys.internal.move_mins, phys.internal.move_maxs, m.phys.internal.move_mins, m.phys.internal.move_maxs)) {
      return true;
    }
    member = m.next;
  }
  return false;
}

fn could_objects_collide(a: *C.PhysObject, b: *C.PhysObject) bool {
  return switch (a.physType) {
    C.PhysObject.Type.NonSolid =>
      false,
    C.PhysObject.Type.Creature =>
      b.physType == C.PhysObject.Type.Creature or
      b.physType == C.PhysObject.Type.Bullet,
    C.PhysObject.Type.Bullet =>
      b.physType == C.PhysObject.Type.Creature,
  };
}

fn assert_no_overlaps(gs: *GameSession) void {
  for (gs.phys_objects.objects[0..gs.phys_objects.count]) |*self| {
    if (!self.is_active) {
      continue;
    }
    const self_transform = gs.transforms.find(self.entity_id).?;
    for (gs.phys_objects.objects[0..gs.phys_objects.count]) |*other| {
      if (!other.is_active) {
        continue;
      }
      if (self != other and
          other.entity_id.id != self.data.owner_id.id and
          other.data.owner_id.id != self.entity_id.id) {
        const other_transform = gs.transforms.find(other.entity_id).?;
        if (boxes_overlap(
          self_transform.pos, self.data.mins, self.data.maxs,
          other_transform.pos, other.data.mins, other.data.maxs,
        )) {
          std.debug.warn("who is this joker\n");
        }
      }
    }
  }
}
