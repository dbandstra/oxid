// comptime {
//   _ = @import("src/boxes_overlap.zig");
//   _ = @import("src/game_level_test.zig");
// }

const builtin = @import("builtin");
const assert = @import("std").debug.assert;

const A = struct { unused: bool };
const B = struct { unused: bool };
const C = struct { unused: bool };

fn ComponentList(comptime T: type) type {
  return struct {
    const Self = this;

    pub fn find(self: *Self, id: u32) ?*T {
      return null;
    }
  };
}

const GameState = struct {
  a: ComponentList(A),
  b: ComponentList(B),
  c: ComponentList(C),

  fn getListName(comptime T: type) []const u8 {
    return switch (T) {
      A => "a",
      B => "b",
      C => "c",
      else => unreachable,
    };
  }
};

// why doesn't this function work at comptime?
// (when called in an inline loop. my BuildSystem code is working
// when calling it on the main-component-type)

// comptime {
  fn getListName2(comptime T: type) []const u8 {
    return "a";
    // return switch (T) {
    //   A => "a",
    //   B => "b",
    //   C => "c",
    //   else => unreachable,
    // };
  }
// };

const Entity = struct {
  a: *A,
  b: *B,
  c: *C,
};

fn system(comptime EntityType: type) fn(*GameState)void {
  assert(@typeId(EntityType) == builtin.TypeId.Struct);

  const Impl = struct{
    pub fn run(gs: *GameState) void {
      // fill in the fields of the `self` structure
      var self: EntityType = undefined;

      inline for (@typeInfo(EntityType).Struct.fields) |field| {
        assert(@typeId(field.field_type) == builtin.TypeId.Pointer);
        comptime const ComponentType = @typeInfo(field.field_type).Pointer.child;
        // @compileError(@typeName(ComponentType));
        // comptime const list_name = GameState.getListName(ComponentType);
        comptime const list_name = getListName2(ComponentType);
        // comptime const list_name = switch (ComponentType) {
        //   A => "a",
        //   B => "b",
        //   C => "c",
        //   else => unreachable,
        // };
        const list: ComponentList(ComponentType) = @field(gs, list_name);

        @field(self, field.name) = @field(gs, list_name).find(12345).?;
      }
      // would do some actual game stuff here...
    }
  };

  return Impl.run;
}

test "" {
  // var a = A{.unused=true};
  // var b = B{.unused=true};
  // var c = C{.unused=true};
  var gs = GameState{
    // .a = ([]A{ a })[0..],
    // .b = ([]B{ b })[0..],
    // .c = ([]C{ c })[0..],
    .a = undefined,
    .b = undefined,
    .c = undefined,
  };

  system(Entity)(&gs);
}
