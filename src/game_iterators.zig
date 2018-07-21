const ComponentList = @import("game.zig").ComponentList;
const ComponentObject = @import("game.zig").ComponentObject;
const EntityId = @import("game.zig").EntityId;

pub fn ComponentObjectIterator(comptime T: type) type {
  return struct {
    const Self = this;

    list: *ComponentList(T),
    index: usize,

    pub fn next(self: *Self) ?*ComponentObject(T) {
      for (self.list.objects[self.index..self.list.count]) |*object, i| {
        if (object.is_active) {
          self.index += i + 1;
          return object;
        }
      }
      self.index = self.list.count + 1;
      return null;
    }

    pub fn init(list: *ComponentList(T)) Self {
      return Self{
        .list = list,
        .index = 0,
      };
    }
  };
}

// EventIterator is like ComponentObjectIterator, with the following
// differences:
// - takes a field name (compile-time) and entity id (run-time), and only
//   yields events where event.field == entity_id
// - returns *T (component data) directly, instead of *ComponentObject(T)
pub fn EventIterator(comptime T: type, comptime field: []const u8) type {
  return struct {
    const Self = this;

    list: *ComponentList(T),
    entity_id: EntityId,
    index: usize,

    pub fn next(self: *Self) ?*T {
      for (self.list.objects[self.index..self.list.count]) |*object, i| {
        if (object.is_active and EntityId.eql(@field(&object.data, field), self.entity_id)) {
          self.index += i + 1;
          return &object.data;
        }
      }
      self.index = self.list.count + 1;
      return null;
    }

    pub fn init(list: *ComponentList(T), entity_id: EntityId) Self {
      return Self{
        .list = list,
        .entity_id = entity_id,
        .index = 0,
      };
    }
  };
}
