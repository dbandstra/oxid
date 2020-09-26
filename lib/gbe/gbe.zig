const std = @import("std");

pub const max_removals_per_frame: usize = 1000;

/// Boxed entity ID. This is wrapped in a struct for two reason:
/// 1. Can't accidentally mix up entity ID with other int values in function
///    calls,
/// 2. Identifies a field in `T` structs (in various ECS
///    functions / iterators) to be filled in with the entity ID.
pub const EntityId = struct {
    id: u64,

    pub const zero = EntityId{
        .id = 0,
    };

    pub inline fn isZero(a: EntityId) bool {
        return a.id == 0;
    }

    pub inline fn eql(a: EntityId, b: EntityId) bool {
        return a.id == b.id;
    }
};

pub fn ComponentList(comptime T: type, comptime capacity_: usize) type {
    return struct {
        pub const ComponentType = T;
        pub const capacity = capacity_;

        id: [capacity]u64, // if 0, the slot is not in use
        data: [capacity]T,

        // `count` is incremented as slots are allocated, and never decremented.
        // slots (`id` and `data` elements) past `count` are uninitialized.
        count: usize,
    };
}

pub const AddComponentError = error{NoComponentSlotsAvailable};

pub fn ECS(comptime ComponentLists: type) type {
    std.debug.assert(@typeInfo(ComponentLists) == .Struct);
    //inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
    //    // ?! is it possible to assert that a type == ComponentList(X)?

    //    // without doing some kind of duck typing check on every field
    //    // so that it "looks like" ComponentList?

    //    // @compileError(@typeName(field.field_type));
    //}

    return struct {
        pub const ComponentListsType = ComponentLists;

        next_entity_id: usize,

        removals: [max_removals_per_frame]EntityId,
        num_removals: usize,

        components: ComponentLists,

        pub fn init(self: *@This()) void {
            self.next_entity_id = 1;
            self.num_removals = 0;
            inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
                @field(self.components, field.name).count = 0;
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

        pub fn iter(
            self: *@This(),
            comptime T: type,
        ) EntityIterator(@This(), T) {
            return EntityIterator(@This(), T).init(self);
        }

        pub fn componentIter(
            self: *@This(),
            comptime T: type,
        ) ComponentIterator(T, getCapacity(T)) {
            const list = &@field(self.components, @typeName(T));
            return ComponentIterator(T, comptime getCapacity(T)).init(list);
        }

        pub fn findById(
            self: *@This(),
            entity_id: EntityId,
            comptime T: type,
        ) ?T {
            var entry_id: EntityId = undefined;
            var it = self.iter(T);
            while (it.nextWithId(&entry_id)) |entry| {
                if (EntityId.eql(entry_id, entity_id)) {
                    return entry;
                }
            }
            return null;
        }

        pub fn findComponentById(
            self: *@This(),
            entity_id: EntityId,
            comptime T: type,
        ) ?*T {
            var id: EntityId = undefined;
            var it = self.componentIter(T);
            while (it.nextWithId(&id)) |object| {
                if (EntityId.eql(id, entity_id)) {
                    return object;
                }
            }
            return null;
        }

        pub fn findFirstComponent(self: *@This(), comptime T: type) ?*T {
            return self.componentIter(T).next();
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

        // `data` must be a struct object, and it must be one of the structs
        // in ComponentLists.
        // FIXME - is there any way to make this fail (at compile time!) if
        // you try to add the same component to an entity twice?
        // TODO - optional LRU reuse (whether this is used would be up to the
        // ComponentStorage config, per component type. obviously, kicking out
        // old entities to make room for new ones is not always the right
        // choice)
        pub fn addComponent(
            self: *@This(),
            entity_id: EntityId,
            data: var,
        ) AddComponentError!void {
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

        pub fn markForRemoval(self: *@This(), entity_id: EntityId) void {
            if (self.num_removals >= max_removals_per_frame) {
                @panic("markEntityForRemoval: no removal slots available");
            }
            self.removals[self.num_removals] = entity_id;
            self.num_removals += 1;
        }

        pub fn markAllForRemoval(self: *@This(), comptime T: type) void {
            var id: EntityId = undefined;
            var it = self.componentIter(T);
            while (it.nextWithId(&id) != null) {
                self.markForRemoval(id);
            }
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
                defer self.index += i + 1;
                return &self.list.data[self.index + i];
            }
            self.index = self.list.count;
            return null;
        }
    };
}

pub fn Inbox(
    comptime capacity: usize,
    comptime ComponentType_: type,
    comptime id_field_: ?[]const u8,
) type {
    std.debug.assert(capacity > 0);

    if (@sizeOf(ComponentType_) == 0) {
        // TODO blocked on https://github.com/ziglang/zig/issues/4539
        @compileError("Inbox does not support zero-sized structs");
    }

    return struct {
        pub const is_inbox = true;
        pub const ComponentType = ComponentType_;
        pub const id_field = id_field_;

        array: [capacity]*const ComponentType,
        count: usize,

        // return all of the matches (up to the inbox's capacity), in an
        // arbitrary order.
        pub inline fn all(self: *const @This()) []const *const ComponentType {
            return self.array[0..self.count];
        }

        // sometimes, you only want an event to take effect once. this will
        // return an arbitrary one of the matching events. it's guaranteed to
        // always return something because iteration with an inbox will not
        // have yielded a result at all if the inbox had no matches.
        pub inline fn one(self: *const @This()) *const ComponentType {
            return self.array[0];
        }
    };
}

// `T` is a struct where each field is one of the following:
// - EntityId
// - (possibly optional) pointer to a component
// - (possibly optional) Events
pub fn EntityIterator(comptime ECSType: type, comptime T: type) type {
    // validate `T`
    comptime var all_fields_optional = true;

    inline for (@typeInfo(T).Struct.fields) |field, i| {
        if (field.field_type == EntityId) {
            continue;
        }

        if (@typeInfo(field.field_type) == .Pointer) {
            all_fields_optional = false;
        }

        const ft = switch (@typeInfo(field.field_type)) {
            .Optional => |o| o.child,
            else => field.field_type,
        };

        switch (@typeInfo(ft)) {
            .Pointer => |p| {
                const ComponentType = p.child;

                comptime var found_component_type = false;

                const ti = @typeInfo(ECSType.ComponentListsType);
                inline for (ti.Struct.fields) |c_field, c_field_index| {
                    if (c_field.field_type.ComponentType == ComponentType) {
                        found_component_type = true;
                    }
                }

                if (!found_component_type) {
                    @compileError("iterator struct has field (" ++
                        field.name ++ ") " ++ "that isn't a recognized" ++
                        " component type (" ++ @typeName(ComponentType) ++
                        ")");
                }
            },
            .Struct => {
                if (!ft.is_inbox) {
                    @compileError("invalid field (" ++ field.name ++ ")");
                }
            },
            else => {
                @compileError("invalid field (" ++ field.name ++ ")");
            },
        }
    }

    if (all_fields_optional) {
        @compileError("all fields cannot be optional");
    }

    // TODO - as an optimization, if one of the fields is an Inbox, we should
    // iterate over the events instead of over the "self" entity components.

    return struct {
        ecs: *ECSType,

        // which component type we are iterating through
        best_field_index: usize,

        // current position within the "best" component type's slot array
        index: usize,

        pub fn init(ecs: *ECSType) @This() {
            // go through the fields in the `T` struct. decide which component
            // type to do the outermost iteration over. choose the component
            // type with the lowest amount of active entities.
            const Best = struct {
                field_index: usize,
                count: usize,
            };
            var best: ?Best = null;

            inline for (@typeInfo(T).Struct.fields) |field, i| {
                const ComponentType = switch (@typeInfo(field.field_type)) {
                    .Pointer => |p| p.child,
                    else => continue,
                };

                const ti = @typeInfo(ECSType.ComponentListsType);
                inline for (ti.Struct.fields) |c_field, c_field_index| {
                    if (c_field.field_type.ComponentType != ComponentType) {
                        continue;
                    }
                    const list = &@field(ecs.components, c_field.name);
                    if (best == null or list.count < best.?.count) {
                        best = .{
                            .field_index = i,
                            .count = list.count,
                        };
                    }
                }
            }

            return .{
                .ecs = ecs,
                .best_field_index = best.?.field_index,
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
            // go through the components of the "best" type. find the next one
            // that exists
            inline for (@typeInfo(T).Struct.fields) |field, field_index| {
                const ComponentType = switch (@typeInfo(field.field_type)) {
                    .Pointer => |p| p.child,
                    else => continue,
                };

                if (field_index == self.best_field_index) {
                    // find the component list in the ECS
                    const ti = @typeInfo(ECSType.ComponentListsType);
                    inline for (ti.Struct.fields) |c_field, c_field_index| {
                        if (c_field.field_type.ComponentType != ComponentType) {
                            continue;
                        }

                        const list = &@field(self.ecs.components, c_field.name);

                        // for the best component type, we are iterating
                        // through the component array using self.index...
                        for (list.id[self.index..list.count]) |id, i| {
                            // i can't do `if (id == 0) continue;` here. the
                            // compiler thinks i'm mixing up runtime and
                            // compile-time control flow, which is not true.
                            if (id != 0) {
                                @field(result, field.name) =
                                    &list.data[self.index + i];
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
            }

            unreachable;
        }

        fn fillOtherComponents(self: *@This(), result: *T, entity_id: u64) bool {
            // go through other component types in the struct. look for
            // components with the same entity_id as we found from the best
            // entry above. if the field is not optional, and a component is
            // not found, clear the result and we'll try again.
            inline for (@typeInfo(T).Struct.fields) |field, field_index| {
                if (field.field_type == EntityId) {
                    @field(result, field.name) = .{ .id = entity_id };
                    continue;
                }

                if (@typeInfo(field.field_type) == .Struct and
                    field.field_type.is_inbox)
                {
                    const EventComponentType = field.field_type.ComponentType;

                    var array = &@field(result, field.name).array;
                    var count: usize = 0;

                    // look for an event pointing to this entity. we'll only
                    // take the first match.
                    const ti = @typeInfo(ECSType.ComponentListsType);
                    inline for (ti.Struct.fields) |c_field, c_field_index| {
                        if (c_field.field_type.ComponentType != EventComponentType) {
                            continue;
                        }

                        const list = &@field(self.ecs.components, c_field.name);

                        for (list.id[0..list.count]) |id, i| {
                            if (id == 0) {
                                continue;
                            }
                            const event = &list.data[i];
                            if (field.field_type.id_field) |id_field| {
                                if (@field(event, id_field).id != entity_id) {
                                    continue;
                                }
                            }
                            array[count] = event;
                            count += 1;
                            // if the inbox is full, silently drop events
                            if (count == array.len) {
                                break;
                            }
                        }
                    }

                    if (count == 0) {
                        return false;
                    }

                    @field(result, field.name).count = count;
                    continue;
                }

                // it's a regular component field (may be optional)
                comptime var ft = field.field_type;
                comptime var is_optional = false;
                switch (@typeInfo(ft)) {
                    .Optional => |o| {
                        ft = o.child;
                        is_optional = true;
                    },
                    else => {},
                }
                const ComponentType = switch (@typeInfo(ft)) {
                    .Pointer => |p| p.child,
                    else => unreachable,
                };

                if (field_index != self.best_field_index) {
                    const ti = @typeInfo(ECSType.ComponentListsType);
                    inline for (ti.Struct.fields) |c_field, c_field_index| {
                        if (c_field.field_type.ComponentType != ComponentType) {
                            continue;
                        }

                        const list = &@field(self.ecs.components, c_field.name);

                        // look for a component with an entity_id matching the
                        // entity we're currently looking at.
                        for (list.id[0..list.count]) |id, i| {
                            if (id == entity_id) {
                                @field(result, field.name) = &list.data[i];
                                break;
                            }
                        } else {
                            // requested component not present in this entity.
                            if (is_optional) {
                                @field(result, field.name) = null;
                            } else {
                                // it was required. so much for this entity.
                                // we'll try again with a new first component
                                return false;
                            }
                        }
                    }
                }
            }

            return true;
        }
    };
}
