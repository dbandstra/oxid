// (g)ame (b)ack (e)nd

const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;

const GbeConstants = @import("gbe_constants.zig");
const GbeIterators = @import("gbe_iterators.zig");

pub const EntityId = struct {
    id: usize,

    pub fn eql(a: EntityId, b: EntityId) bool {
        return a.id == b.id;
    }

    pub fn isZero(a: EntityId) bool {
        return a.id == 0;
    }
};

pub fn ComponentObject(comptime T: type) type {
    return struct {
        is_active: bool,
        entity_id: EntityId,
        data: T,
    };
}

pub fn ComponentList(comptime T: type, comptime capacity_: usize) type {
    return struct {
        const Self = @This();

        pub const ComponentType = T;
        const capacity = capacity_;

        objects: [capacity]ComponentObject(T),
        count: usize,
    };
}

pub fn Session(comptime ComponentLists: type) type {
    assert(@typeId(ComponentLists) == builtin.TypeId.Struct);
    inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
        // ?! is it possible to assert that a type == ComponentList(X)?

        // without doing some kind of duck typing check on every field
        // so that it "looks like" ComponentList?

        // @compileError(@typeName(field.field_type));
    }

    return struct {
        const Self = @This();
        pub const ComponentListsType = ComponentLists;

        prng: std.rand.DefaultPrng,

        next_entity_id: usize,

        removals: [GbeConstants.max_removals_per_frame]EntityId,
        num_removals: usize,

        components: ComponentLists,

        pub fn init(self: *Self, rand_seed: u32) void {
            self.prng = std.rand.DefaultPrng.init(rand_seed);
            self.next_entity_id = 1;
            self.num_removals = 0;
            inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
                @field(&self.components, field.name).count = 0;
            }
        }

        pub fn getCapacity(comptime T: type) usize {
            @setEvalBranchQuota(10000);
            comptime var capacity: usize = 0;
            inline for (@typeInfo(ComponentLists).Struct.fields) |sfield| {
                if (comptime std.mem.eql(u8, sfield.name, @typeName(T))) {
                    capacity = sfield.field_type.capacity;
                }
            }
            return capacity;
        }

        pub fn iter(self: *Self, comptime T: type) GbeIterators.ComponentObjectIterator(T, getCapacity(T)) {
            const list = &@field(&self.components, @typeName(T));
            return GbeIterators.ComponentObjectIterator(T, comptime getCapacity(T)).init(list);
        }

        pub fn eventIter(self: *Self, comptime T: type, comptime field: []const u8, entity_id: EntityId) GbeIterators.EventIterator(T, getCapacity(T), field) {
            const list = &@field(&self.components, @typeName(T));
            return GbeIterators.EventIterator(T, comptime getCapacity(T), field).init(list, entity_id);
        }

        pub fn findObject(self: *Self, entity_id: EntityId, comptime T: type) ?*ComponentObject(T) {
            var it = self.iter(T); while (it.next()) |object| {
                if (EntityId.eql(object.entity_id, entity_id)) {
                    return object;
                }
            }
            return null;
        }

        pub fn find(self: *Self, entity_id: EntityId, comptime T: type) ?*T {
            return if (self.findObject(entity_id, T)) |object| &object.data else null;
        }

        // use this for ad-hoc singleton component types
        pub fn findFirstObject(self: *Self, comptime T: type) ?*ComponentObject(T) {
            return self.iter(T).next();
        }

        pub fn findFirst(self: *Self, comptime T: type) ?*T {
            return if (self.findFirstObject(T)) |object| &object.data else null;
        }

        pub fn getRand(self: *Self) *std.rand.Random {
            return &self.prng.random;
        }

        pub fn spawn(self: *Self) EntityId {
            const id = EntityId{ .id = self.next_entity_id };
            self.next_entity_id += 1; // TODO - reuse these?
            return id;
        }

        // this is only called in spawn functions, to clean up components of a
        // partially constructed entity, when something goes wrong
        pub fn undoSpawn(self: *Self, entity_id: EntityId) void {
            inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
                self.destroyComponent(entity_id, field.field_type.ComponentType);
            }
        }

        pub fn markEntityForRemoval(self: *Self, entity_id: EntityId) void {
            if (self.num_removals >= GbeConstants.max_removals_per_frame) {
                @panic("markEntityForRemoval: no removal slots available");
            }
            self.removals[self.num_removals] = entity_id;
            self.num_removals += 1;
        }

        // `data` must be a struct object, and it must be one of the structs in ComponentLists.
        // FIXME - before i used duck typing for this, `data` had type `*const T`.
        // then you could pass struct using as-value syntax, and it was implicitly sent as a reference
        // (like c++ references). but with `var`, i don't think this is possible?
        // FIXME - is there any way to make this fail (at compile time!) if you try to add the same
        // component to an entity twice?
        // TODO - optional LRU reuse (whether this is used would be up to the
        // ComponentStorage config, per component type. obviously, kicking out old
        // entities to make room for new ones is not always the right choice)
        pub fn addComponent(self: *Self, entity_id: EntityId, data: var) !void {
            const T: type = @typeOf(data);
            // assert(@typeId(T) == .Struct);
            var list = &@field(&self.components, @typeName(T));
            const slot = blk: {
                var i: usize = 0;
                while (i < list.count) : (i += 1) {
                    const object = &list.objects[i];
                    if (!object.is_active) {
                        break :blk object;
                    }
                }
                if (list.count < list.objects.len) {
                    i = list.count;
                    list.count += 1;
                    break :blk &list.objects[i];
                }
                break :blk null;
            };
            if (slot) |object| {
                object.is_active = true;
                object.data = data;
                object.entity_id = entity_id;
            } else {
                //std.debug.warn("warning: no slots available for new `" ++ @typeName(T) ++ "` component\n");
                return error.NoComponentSlotsAvailable;
            }
        }

        pub fn destroyComponent(self: *Self, entity_id: EntityId, comptime T: type) void {
            if (self.findObject(entity_id, T)) |object| {
                object.is_active = false;
            }
        }

        pub fn applyRemovals(self: *Self) void {
            for (self.removals[0..self.num_removals]) |entity_id| {
                inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
                    self.destroyComponent(entity_id, field.field_type.ComponentType);
                }
            }
            self.num_removals = 0;
        }
    };
}
