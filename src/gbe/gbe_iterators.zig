const Gbe = @import("gbe_main.zig");

pub fn ComponentObjectIterator(comptime T: type, comptime capacity: usize) type {
    return struct{
        const Self = @This();

        list: *Gbe.ComponentList(T, capacity),
        index: usize,

        pub fn next(self: *Self) ?*Gbe.ComponentObject(T) {
            for (self.list.objects[self.index..self.list.count]) |*object, i| {
                if (object.is_active) {
                    self.index += i + 1;
                    return object;
                }
            }
            self.index = self.list.count + 1;
            return null;
        }

        pub fn init(list: *Gbe.ComponentList(T, capacity)) Self {
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
pub fn EventIterator(comptime T: type, comptime capacity: usize, comptime field: []const u8) type {
    return struct{
        const Self = @This();

        list: *Gbe.ComponentList(T, capacity),
        entity_id: Gbe.EntityId,
        index: usize,

        pub fn next(self: *Self) ?*T {
            for (self.list.objects[self.index..self.list.count]) |*object, i| {
                if (object.is_active and Gbe.EntityId.eql(@field(&object.data, field), self.entity_id)) {
                    self.index += i + 1;
                    return &object.data;
                }
            }
            self.index = self.list.count + 1;
            return null;
        }

        pub fn init(list: *Gbe.ComponentList(T, capacity), entity_id: Gbe.EntityId) Self {
            return Self{
                .list = list,
                .entity_id = entity_id,
                .index = 0,
            };
        }
    };
}
