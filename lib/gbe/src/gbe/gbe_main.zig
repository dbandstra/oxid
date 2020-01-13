// (g)ame (b)ack (e)nd

const builtin = @import("builtin");
const std = @import("std");

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
        entity_id: EntityId, // if 0, the slot is not in use
        data: T,
    };
}

pub fn ComponentList(comptime T: type, comptime capacity_: usize) type {
    return struct {
        pub const ComponentType = T;
        const capacity = capacity_;

        objects: [capacity]ComponentObject(T),
        count: usize,
    };
}

pub fn Session(comptime ComponentLists: type) type {
    std.debug.assert(@typeId(ComponentLists) == builtin.TypeId.Struct);
    //inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
    //    // ?! is it possible to assert that a type == ComponentList(X)?

    //    // without doing some kind of duck typing check on every field
    //    // so that it "looks like" ComponentList?

    //    // @compileError(@typeName(field.field_type));
    //}

    return struct {
        pub const ComponentListsType = ComponentLists;

        prng: std.rand.DefaultPrng,

        next_entity_id: usize,

        removals: [GbeConstants.max_removals_per_frame]EntityId,
        num_removals: usize,

        components: ComponentLists,

        pub fn init(self: *@This(), rand_seed: u32) void {
            self.prng = std.rand.DefaultPrng.init(rand_seed);
            self.next_entity_id = 1;
            self.num_removals = 0;
            inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
                @field(&self.components, field.name).count = 0;
            }
        }

        pub fn getRand(self: *@This()) *std.rand.Random {
            return &self.prng.random;
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

        pub fn iter(self: *@This(), comptime T: type) GbeIterators.ComponentIterator(T, getCapacity(T)) {
            const list = &@field(&self.components, @typeName(T));
            return GbeIterators.ComponentIterator(T, comptime getCapacity(T)).init(list);
        }

        pub fn entityIter(self: *@This(), comptime T: type) GbeIterators.EntityIterator(@This(), T) {
            return GbeIterators.EntityIterator(@This(), T).init(self);
        }

        pub fn eventIter(self: *@This(), comptime T: type, comptime field: []const u8, entity_id: EntityId) GbeIterators.EventIterator(T, getCapacity(T), field) {
            const list = &@field(&self.components, @typeName(T));
            return GbeIterators.EventIterator(T, comptime getCapacity(T), field).init(list, entity_id);
        }

        pub fn find(self: *@This(), entity_id: EntityId, comptime T: type) ?*T {
            var id: EntityId = undefined;
            var it = self.iter(T);
            while (it.nextWithId(&id)) |object| {
                if (EntityId.eql(id, entity_id)) {
                    return object;
                }
            }
            return null;
        }

        pub fn findEntity(self: *@This(), entity_id: EntityId, comptime T: type) ?T {
            var entry_id: EntityId = undefined;
            var it = self.entityIter(T);
            while (it.nextWithId(&entry_id)) |entry| {
                if (EntityId.eql(entry_id, entity_id)) {
                    return entry;
                }
            }
            return null;
        }

        pub fn findFirst(self: *@This(), comptime T: type) ?*T {
            return self.iter(T).next();
        }

        pub fn spawn(self: *@This()) EntityId {
            const id: EntityId = .{ .id = self.next_entity_id };
            self.next_entity_id += 1; // TODO - reuse these?
            return id;
        }

        // this is only called in spawn functions, to clean up components of a
        // partially constructed entity, when something goes wrong
        pub fn undoSpawn(self: *@This(), entity_id: EntityId) void {
            self.freeEntity(entity_id);
            //inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
            //    self.destroyComponent(entity_id, field.field_type.ComponentType);
            //}
        }

        // `data` must be a struct object, and it must be one of the structs in ComponentLists.
        // FIXME - is there any way to make this fail (at compile time!) if you try to add the same
        // component to an entity twice?
        // TODO - optional LRU reuse (whether this is used would be up to the
        // ComponentStorage config, per component type. obviously, kicking out old
        // entities to make room for new ones is not always the right choice)
        pub fn addComponent(self: *@This(), entity_id: EntityId, data: var) !void {
            const T: type = @TypeOf(data);
            // std.debug.assert(@typeId(T) == .Struct);
            var list = &@field(&self.components, @typeName(T));
            const slot = blk: {
                var i: usize = 0;
                while (i < list.count) : (i += 1) {
                    const object = &list.objects[i];
                    if (EntityId.isZero(object.entity_id)) {
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
                object.data = data;
                object.entity_id = entity_id;
            } else {
                //std.debug.warn("warning: no slots available for new `" ++ @typeName(T) ++ "` component\n");
                return error.NoComponentSlotsAvailable;
            }
        }

        pub fn markEntityForRemoval(self: *@This(), entity_id: EntityId) void {
            if (self.num_removals >= GbeConstants.max_removals_per_frame) {
                @panic("markEntityForRemoval: no removal slots available");
            }
            self.removals[self.num_removals] = entity_id;
            self.num_removals += 1;
        }

        // (internal) actually free all components using this entity id
        fn freeEntity(self: *@This(), entity_id: EntityId) void {
            if (EntityId.isZero(entity_id)) {
                return;
            }
            // FIXME - this implementation is not good. it's going through
            // every slot of every component type, for each removal.
            inline for (@typeInfo(ComponentLists).Struct.fields) |field, field_index| {
                const list = &@field(self.components, @typeName(field.field_type.ComponentType));
                for (list.objects[0..list.count]) |*object| {
                    if (EntityId.eql(object.entity_id, entity_id)) {
                        object.entity_id = .{ .id = 0 };
                    }
                }
            }
        }

        pub fn applyRemovals(self: *@This()) void {
            for (self.removals[0..self.num_removals]) |entity_id| {
                self.freeEntity(entity_id);
            }
            self.num_removals = 0;
        }
    };
}
