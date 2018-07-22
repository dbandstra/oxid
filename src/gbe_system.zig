const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const Gbe = @import("gbe.zig");

// `SessionType` param to these functions must have have a field called `gbe`
// which is of type `Gbe.Session(...)`

pub fn build(
  comptime SessionType: type,
  comptime SelfType: type,
  comptime MainComponentType: type,
  comptime think: fn(*SessionType, SelfType)bool,
) fn(*SessionType)void {
  assert(@typeId(SelfType) == builtin.TypeId.Struct);

  const Impl = struct{
    fn runOne(gs: *SessionType, self_id: Gbe.EntityId, main_component: *MainComponentType) bool {
      // fill in the fields of the `self` structure
      var self: SelfType = undefined;
      inline for (@typeInfo(SelfType).Struct.fields) |field| {
        // if the field is of type EntityId, fill it in....
        if (field.field_type == Gbe.EntityId) {
          @field(self, field.name) = self_id;
          continue;
        }
        // otherwise, it must be a pointer to a component, or an optional
        // pointer to a component
        comptime var field_type = field.field_type;
        comptime var is_optional = false;
        if (@typeId(field_type) == builtin.TypeId.Optional) {
          field_type = @typeInfo(field_type).Optional.child;
          is_optional = true;
        }
        if (@typeId(field_type) != builtin.TypeId.Pointer) {
          @compileError("field must be a pointer");
          unreachable;
        }
        comptime const ComponentType = @typeInfo(field_type).Pointer.child;
        @field(self, field.name) =
          if (ComponentType == MainComponentType)
            main_component
          else if (is_optional)
            gs.gbe.find(self_id, ComponentType)
          else
            gs.gbe.find(self_id, ComponentType) orelse return true;
      }
      // call the think function
      return think(gs, self);
    }

    fn run(gs: *SessionType) void {
      var it = gs.gbe.iter(MainComponentType); while (it.next()) |object| {
        if (!runOne(gs, object.entity_id, &object.data)) {
          gs.gbe.markEntityForRemoval(object.entity_id);
        }
      }
    }
  };

  return Impl.run;
}
