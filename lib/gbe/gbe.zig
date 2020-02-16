// (g)ame (b)ack (e)nd
// an entity component system for zig

const std = @import("std");

pub const max_removals_per_frame: usize = 1000;

pub const EntityId = struct {
    id: u64,

    pub fn eql(a: EntityId, b: EntityId) bool {
        return a.id == b.id;
    }

    pub fn isZero(a: EntityId) bool {
        return a.id == 0;
    }
};

pub fn ComponentList(comptime T: type, comptime capacity_: usize) type {
    return struct {
        pub const ComponentType = T;
        const capacity = capacity_;

        id: [capacity]u64, // if 0, the slot is not in use
        data: [capacity]T,

        // `count` is incremented as slots are allocated, and never decremented.
        // slots (`id` and `data` elements) past `count` are uninitialized.
        count: usize,
    };
}

pub fn Session(comptime ComponentLists: type) type {
    std.debug.assert(@typeId(ComponentLists) == .Struct);
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

        removals: [max_removals_per_frame]EntityId,
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

        pub fn iter(self: *@This(), comptime T: type) ComponentIterator(T, getCapacity(T)) {
            const list = &@field(&self.components, @typeName(T));
            return ComponentIterator(T, comptime getCapacity(T)).init(list);
        }

        pub fn entityIter(self: *@This(), comptime T: type) EntityIterator(@This(), T) {
            return EntityIterator(@This(), T).init(self);
        }

        pub fn eventIter(self: *@This(), comptime T: type, comptime field: []const u8, entity_id: EntityId) EventIterator(T, getCapacity(T), field) {
            const list = &@field(&self.components, @typeName(T));
            return EventIterator(T, comptime getCapacity(T), field).init(list, entity_id);
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
        }

        // `data` must be a struct object, and it must be one of the structs in ComponentLists.
        // FIXME - is there any way to make this fail (at compile time!) if you try to add the same
        // component to an entity twice?
        // TODO - optional LRU reuse (whether this is used would be up to the
        // ComponentStorage config, per component type. obviously, kicking out old
        // entities to make room for new ones is not always the right choice)
        pub fn addComponent(self: *@This(), entity_id: EntityId, data: var) !void {
            var list = &@field(self.components, @typeName(@TypeOf(data)));
            const slot_index = blk: {
                var i: usize = 0;
                while (i < list.count) : (i += 1) {
                    if (list.id[i] != 0) {
                        continue;
                    }
                    break :blk i;
                }
                if (list.count < list.id.len) {
                    i = list.count;
                    list.count += 1;
                    break :blk i;
                }
                return error.NoComponentSlotsAvailable;
            };
            list.id[slot_index] = entity_id.id;
            list.data[slot_index] = data;
        }

        pub fn markEntityForRemoval(self: *@This(), entity_id: EntityId) void {
            if (self.num_removals >= max_removals_per_frame) {
                @panic("markEntityForRemoval: no removal slots available");
            }
            self.removals[self.num_removals] = entity_id;
            self.num_removals += 1;
        }

        pub fn applyRemovals(self: *@This()) void {
            for (self.removals[0..self.num_removals]) |entity_id| {
                self.freeEntity(entity_id);
            }
            self.num_removals = 0;
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
                for (list.id[0..list.count]) |*id| {
                    if (id.* == entity_id.id) {
                        id.* = 0;
                    }
                }
            }
        }
    };
}

pub fn ComponentIterator(comptime T: type, comptime capacity: usize) type {
    return struct {
        list: *ComponentList(T, capacity),
        index: usize,

        pub fn init(list: *ComponentList(T, capacity)) @This() {
            return .{
                .list = list,
                .index = 0,
            };
        }

        pub inline fn next(self: *@This()) ?*T {
            return self.nextWithId(null);
        }

        pub fn nextWithId(self: *@This(), maybe_out_id: ?*EntityId) ?*T {
            for (self.list.id[self.index..self.list.count]) |id, i| {
                if (id == 0) {
                    continue;
                }
                if (maybe_out_id) |out_id| {
                    out_id.* = .{ .id = id };
                }
                const data = &self.list.data[self.index + i];
                self.index += i + 1;
                return data;
            }
            self.index = self.list.count;
            return null;
        }
    };
}

// EventIterator takes a field name (compile-time) and an entity id (run-time),
// and only yields events where event.field_name == entity_id
pub fn EventIterator(comptime T: type, comptime capacity: usize, comptime field_name: []const u8) type {
    return struct {
        list: *ComponentList(T, capacity),
        entity_id: EntityId,
        index: usize,

        pub fn init(list: *ComponentList(T, capacity), entity_id: EntityId) @This() {
            return .{
                .list = list,
                .entity_id = entity_id,
                .index = 0,
            };
        }

        pub fn next(self: *@This()) ?*T {
            if (EntityId.isZero(self.entity_id)) {
                return null;
            }
            for (self.list.id[self.index..self.list.count]) |id, i| {
                if (id == 0) {
                    continue;
                }
                const data = &self.list.data[self.index + i];
                if (!EntityId.eql(@field(data, field_name), self.entity_id)) {
                    continue;
                }
                self.index += i + 1;
                return data;
            }
            self.index = self.list.count;
            return null;
        }
    };
}

// `T` is a struct containing pointers to components
pub fn EntityIterator(comptime SessionType: type, comptime T: type) type {
    return struct {
        gs: *SessionType,
        best_field_index: ?usize, // which component type we are iterating through
        index: usize, // current position within the "best" component type's slot array

        pub fn init(gs: *SessionType) @This() {
            // choose the best field
            // only if all fields are optional will we consider optional fields when
            // determining the best component type
            comptime var all_fields_optional = true;

            inline for (@typeInfo(T).Struct.fields) |field| {
                if (field.field_type == EntityId) continue;
                if (@typeId(field.field_type) != .Optional) {
                    all_fields_optional = false;
                }
            }

            if (all_fields_optional) {
                @compileError("all fields cannot be optional");
            }

            // go through the fields in the SystemType struct (where each field
            // is either an EntityId or a pointer to a component). decide which
            // component type to do the outermost iteration over. choose the
            // component type with the lowest amount of active entities.
            var best: usize = std.math.maxInt(usize);
            var maybe_which: ?usize = null;

            inline for (@typeInfo(T).Struct.fields) |field, i| {
                if (field.field_type == EntityId) continue;
                // skip optional fields, unless all fields are optional
                if (@typeId(field.field_type) == .Optional and !all_fields_optional) {
                    continue;
                }
                comptime const field_type = UnpackComponentType(field.field_type);
                if (@field(&gs.components, @typeName(field_type)).count < best) {
                    best = @field(&gs.components, @typeName(field_type)).count;
                    maybe_which = i;
                }
            }

            return .{
                .gs = gs,
                .best_field_index = maybe_which,
                .index = 0,
            };
        }

        pub inline fn next(self: *@This()) ?T {
            return self.nextWithId(null);
        }

        pub fn nextWithId(self: *@This(), maybe_out_id: ?*EntityId) ?T {
            var result: T = undefined;

            while (self.nextMainComponent(&result)) |entity_id| {
                if (self.fillOtherComponents(&result, entity_id)) {
                    if (maybe_out_id) |out_id| {
                        out_id.* = .{ .id = entity_id };
                    }
                    return result;
                }
            }

            return null;
        }

        // get the next instance of the "best" component type. if found,
        // set the field in `result` and return the entity id.
        fn nextMainComponent(self: *@This(), result: *T) ?u64 {
            const best_field_index = self.best_field_index orelse return null;

            // go through the components of the "best" type. find the next one that exists
            inline for (@typeInfo(T).Struct.fields) |field, field_index| {
                if (field.field_type == EntityId) continue;
                if (field_index == best_field_index) {
                    const ComponentType = UnpackComponentType(field.field_type);

                    comptime var found_component_type = false;

                    // find the component list in the GBE session
                    inline for (@typeInfo(SessionType.ComponentListsType).Struct.fields) |c_field, c_field_index| {
                        if (c_field.field_type.ComponentType == ComponentType) {
                            found_component_type = true;

                            const list = &@field(self.gs.components, c_field.name);

                            // for the best component type, we are iterating through the
                            // component array using self.index...
                            for (list.id[self.index..list.count]) |id, i| {
                                // i can't do `if (id == 0) continue;` here. the compiler thinks
                                // i'm mixing up runtime and compile-time control flow, which is not true.
                                if (id != 0) {
                                    @field(result, field.name) = &list.data[self.index + i];
                                    self.index += i + 1;
                                    return id;
                                }
                            } else {
                                // hit the end of the component list - nothing left
                                self.index = list.count;
                                return null;
                            }
                        }
                    }

                    if (!found_component_type) {
                        @compileError("iterator struct has field (" ++ field.name ++ ") " ++
                            "that isn't a recognized component type (" ++ @typeName(ComponentType) ++ ")");
                    }
                }
            }

            unreachable;
        }

        fn fillOtherComponents(self: *@This(), result: *T, entity_id: u64) bool {
            const best_field_index = self.best_field_index.?;

            // go through other component types in the struct. look for components with the same
            // entity_id as we found from the best entry above.
            // if the field is not optional, and a component is not found, clear the result and we'll try again.
            inline for (@typeInfo(T).Struct.fields) |field, field_index| {
                if (field.field_type == EntityId) {
                    @field(result, field.name) = .{ .id = entity_id };
                    continue;
                }

                if (field_index != best_field_index) {
                    const ComponentType = UnpackComponentType(field.field_type);

                    comptime var found_component_type = false;

                    inline for (@typeInfo(SessionType.ComponentListsType).Struct.fields) |c_field, c_field_index| {
                        if (c_field.field_type.ComponentType == ComponentType) {
                            // this component array corresponds to the field in the iterator struct...
                            found_component_type = true;

                            const list = &@field(self.gs.components, c_field.name);

                            // look for a component with an entity_id matching the entity we're currently looking at.
                            for (list.id[0..list.count]) |id, i| {
                                if (id == entity_id) {
                                    @field(result, field.name) = &list.data[i];
                                    break;
                                }
                            } else {
                                // requested component not present in this entity.
                                if (@typeId(field.field_type) == .Optional) {
                                    @field(result, field.name) = null;
                                } else {
                                    // it was required. so much for this entity. we'll try again with a
                                    // new first component
                                    return false;
                                }
                            }
                        }
                    }

                    if (!found_component_type) {
                        @compileError("iterator struct has field (" ++ field.name ++ ") " ++
                            "that isn't a recognized component type (" ++ @typeName(ComponentType) ++ ")");
                    }
                }
            }

            return true;
        }
    };
}

fn UnpackComponentType(comptime field_type: type) type {
    comptime var ft = field_type;
    if (@typeId(ft) == .Optional) {
        ft = @typeInfo(ft).Optional.child;
    }
    if (@typeId(ft) != .Pointer) {
        @compileError("field must be a pointer");
        unreachable;
    }
    ft = @typeInfo(ft).Pointer.child;
    return ft;
}
