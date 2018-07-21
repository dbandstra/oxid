const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const C = @import("game_components.zig");

// TODO - component lists in GameSession should just have the exact
// name as the type, then i don't need this stupid switch

pub fn BuildSystem(
  comptime SelfType: type,
  comptime MainComponentType: type,
  comptime think: fn(*GameSession, EntityId, SelfType)bool,
) fn(*GameSession)void {
  assert(@typeId(SelfType) == builtin.TypeId.Struct);

  const Impl = struct{
    pub fn runOne(gs: *GameSession, self_id: EntityId, main_component: *MainComponentType) bool {
      // fill in the fields of the `self` structure
      var self: SelfType = undefined;
      inline for (@typeInfo(SelfType).Struct.fields) |field| {
        assert(@typeId(field.field_type) == builtin.TypeId.Pointer);
        comptime const ComponentType = @typeInfo(field.field_type).Pointer.child;
        if (ComponentType == MainComponentType) {
          @field(self, field.name) = main_component;
        } else {
          @field(self, field.name) = gs.find(self_id, ComponentType) orelse return true;
        }
      }
      // call the think function
      return think(gs, self_id, self);
    }

    pub fn run(gs: *GameSession) void {
      var it = gs.iter(MainComponentType); while (it.next()) |object| {
        if (!runOne(gs, object.entity_id, &object.data)) {
          gs.remove(object.entity_id);
        }
      }
    }
  };

  return Impl.run;
}

// for think functions that only need a single component in self
pub fn BuildSimple(
  comptime MainComponentType: type,
  comptime think: fn(*GameSession, EntityId, *MainComponentType)bool,
) fn(*GameSession)void {
  return (struct{
    pub fn impl(gs: *GameSession) void {
      var it = gs.iter(MainComponentType); while (it.next()) |object| {
        if (!think(gs, object.entity_id, &object.data)) {
          gs.remove(object.entity_id);
        }
      }
    }
  }).impl;
}
