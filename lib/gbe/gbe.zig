const std = @import("std");

pub const max_removals_per_frame: usize = 1000;

/// Boxed entity ID. This is wrapped in a struct for two reason:
/// 1. Can't accidentally mix up entity ID with other int values in function
///    calls,
/// 2. Identifies a field in `T` structs (in various ECS
///    functions / iterators) to be filled in with the entity ID.
pub const EntityId = struct {
    id: u64,

    pub const zero = EntityId {
        .id = 0,
    };

    pub inline fn isZero(a: EntityId) bool {
        return a.id == 0;
    }

    pub inline fn eql(a: EntityId, b: EntityId) bool {
        return a.id == b.id;
    }
};

pub const ComponentDef = struct {
    Type: type,
    capacity: usize,
};

/// Data store for a single ECS component type. This is internal to the ECS.
pub const Slots = struct {
    name: []const u8, // @typeName of the component type

    capacity: usize, // max number of components allowed. never changes

    size: usize, // size of one element

    /// The value of the component in each slot. If the slot is unoccupied,
    /// the value is undefined/uninitialized. This is a byte array to reduce
    /// code size from all the comptime code.
    slice: []u8, // length is capacity * size

    /// The ID of the entity that each component belongs to. 0 means that
    /// the component slot is unoccupied.
    entity_ids: []u64, // length is capacity
};

pub const ECSBase = struct {
    // Static storage for all component types
    runtime_array: []Slots,

    // The ID of the next spawned entity. This simplify autoincrements
    next_entity_id: u64,

    // Queue of entity IDs to be removed. (Removal will take effect, and
    // this list will be cleared, when `settle` is called.)
    entities_to_remove: []u64,
    num_entities_to_remove: usize,

    // ID of the most recent settled, spawned entity. When spawns are
    // realized (in `settle`), this is set to the value of
    // `next_entity_id`. New, unsettled entities are identified by having
    // an id which is greater than or equal to this value.
    first_new_entity_id: u64,

    pub fn spawn(self: *ECSBase) EntityId {
        if (self.next_entity_id == std.math.maxInt(u64)) {
            @panic("spawn: exhausted all 2^64 entity ids"); // impressive
        }
        const id = self.next_entity_id;
        self.next_entity_id += 1;
        return .{ .id = id };
    }

    pub fn undoSpawn(self: *ECSBase, entity_id: EntityId) void {
        for (self.runtime_array) |ra| {
            for (ra.entity_ids) |slot_entity_id, i| {
                if (slot_entity_id == entity_id.id) {
                    ra.entity_ids[i] = 0;
                }
            }
        }
    }

    pub fn addComponent(
        self: *ECSBase,
        entity_id: EntityId,
        component_type_index: usize,
        size: usize,
        memory: []const u8,
    ) !void {
        if (entity_id.id == 0) {
            return error.CantAddComponentsToEntityIdZero;
        }
        if (entity_id.id < self.first_new_entity_id) {
            return error.CantAddComponentsToExistingEntity;
        }

        const ra = &self.runtime_array[component_type_index];
        for (ra.entity_ids) |slot_entity_id, i| {
            if (slot_entity_id != 0) {
                continue;
            }
            ra.entity_ids[i] = entity_id.id;
            if (size > 0) {
                std.mem.copy(u8, ra.slice[i * size .. i * size + memory.len],
                                 memory);
            }
            return;
        }

        return error.NoComponentSlotsAvailable;
    }

    pub fn markForRemoval(self: *ECSBase, entity_id: EntityId) void {
        if (self.num_entities_to_remove >= self.entities_to_remove.len) {
            // FIXME - what can i do?
            return;
        }
        self.entities_to_remove[self.num_entities_to_remove] = entity_id.id;
        self.num_entities_to_remove += 1;
    }

    // remove all components of a certain type.
    // currently, this doesn't affect unsettled spawns. i'm not sure if it should.
    // for now you can just call settle before calling this function.
    pub fn markAllForRemoval(self: *@This(), component_type_index: usize) void {
        const ra = &self.runtime_array[component_type_index];
        for (ra.entity_ids) |id| {
            if (id == 0) {
                continue;
            }
            self.markForRemoval(.{ .id = id });
        }
    }

    pub fn settle(self: *ECSBase) void {
        // apply removals
        for (self.entities_to_remove[0..self.num_entities_to_remove]) |entity_id| {
            for (self.runtime_array) |ra| {
                for (ra.entity_ids) |slot_entity_id, i| {
                    if (slot_entity_id == entity_id) {
                        ra.entity_ids[i] = 0;
                    }
                }
            }
        }
        self.num_entities_to_remove = 0;

        // realize spawns
        self.first_new_entity_id = self.next_entity_id;
    }
};

pub fn ECS(comptime wrappers_: []const ComponentDef) type {
    return struct {
        const wrappers = wrappers_;

        base: ECSBase,

        fn getComponentTypeIndex(comptime Type: type) usize {
            inline for (wrappers) |wrapper, i| {
                if (Type == wrapper.Type) return i;
            }
            @compileError("invalid component type: " ++ @typeName(Type));
        }

        /// Initialize the ECS.
        pub fn init(self: *@This(), allocator: *std.mem.Allocator) !void {
            self.base = .{
                .runtime_array = try allocator.alloc(Slots, wrappers.len),
                .entities_to_remove =
                    try allocator.alloc(u64, max_removals_per_frame),
                .next_entity_id = 1,
                .num_entities_to_remove = 0,
                .first_new_entity_id = 1,
            };
            inline for (wrappers) |wrapper, i| {
                self.base.runtime_array[i] = Slots {
                    .name = @typeName(wrapper.Type),
                    .capacity = wrapper.capacity,
                    .size = @sizeOf(wrapper.Type),
                    .slice =
                        if (@alignOf(wrapper.Type) >= 1)
                            try allocator.alignedAlloc(u8, @alignOf(wrapper.Type),
                                wrapper.capacity * @sizeOf(wrapper.Type))
                        else // empty struct
                            try allocator.alloc(u8, 0),
                    .entity_ids = try allocator.alloc(u64, wrapper.capacity),
                };
                std.mem.set(u64, self.base.runtime_array[i].entity_ids, 0);
            }
        }

        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            for (self.base.runtime_array) |ra| {
                allocator.free(ra.slice);
                allocator.free(ra.entity_ids);
            }
            allocator.free(self.base.entities_to_remove);
            allocator.free(self.base.runtime_array);
        }

        pub fn getCapacity(comptime T: type) usize {
            inline for (wrappers) |wrapper| {
                if (wrapper.Type == T) {
                    return wrapper.capacity;
                }
            }
            @compileError("getCapacity: bad type " ++ @typeName(T));
        }

        /// Return an entity iterator which yields all entities that contain
        /// all of the components in `T`.
        pub fn iter(
            self: *@This(),
            comptime T: type,
        ) EntityIterator(@This(), T) {
            return EntityIterator(@This(), T).init(&self.base);
        }

        pub fn componentIter(
            self: *@This(),
            comptime T: type,
        ) ComponentIterator(@This(), T) {
            return ComponentIterator(@This(), T).init(&self.base);
        }

        /// Find an entity by id. Returns null if the entity doesn't exist or
        /// if it doesn't contain all the components requested by `T`.
        pub fn findById(
            self: *@This(),
            entity_id: EntityId,
            comptime T: type,
        ) ?T {
            var id: EntityId = undefined;
            var it = self.iter(T);
            while (it.nextWithId(&id)) |entry| {
                if (id.id == entity_id.id) {
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
            while (it.nextWithId(&id)) |item| {
                if (id.id == entity_id.id) {
                    return item;
                }
            }
            return null;
        }

        /// Return the first entity of the given type. This should only be used
        /// with entity types that are considered singletons (only one should
        /// ever exist).
        pub fn findFirst(self: *@This(), comptime T: type) ?T {
            var it = self.iter(T);
            if (it.next()) |entry| {
                return entry;
            }
            return null;
        }

        pub fn findFirstComponent(
            self: *@This(),
            comptime ComponentType: type,
        ) ?*ComponentType {
            var it = self.componentIter(ComponentType);
            if (it.next()) |component| {
                return component;
            }
            return null;
        }

        /// Return the number of active entities that match `T`.
        pub fn count(self: *@This(), comptime T: type) usize {
            var n: usize = 0;
            var it = self.iter(T);
            while (it.next() != null) {
                n += 1;
            }
            return n;
        }

        /// Spawn a new entity with no components. (Add components to it using
        /// `addComponent`.) The entity will not be considered active until
        /// `settle` has been called.
        pub fn spawn(self: *@This()) EntityId {
            return self.base.spawn();
        }

        /// Undo a spawn. Call this if an error occurred while trying to spawn
        /// an entity (e.g. ran out of component slots). Don't call this
        /// function if `settle` has been called since the entity was spawned.
        pub fn undoSpawn(self: *@This(), entity_id: EntityId) void {
            self.base.undoSpawn(entity_id);
        }

        /// Add a component to an entity. This should be done immediately after
        /// `spawn` and before `settle`.
        pub fn addComponent(
            self: *@This(),
            entity_id: EntityId,
            component: var,
        ) !void {
            try self.base.addComponent(
                entity_id,
                getComponentTypeIndex(@TypeOf(component)),
                @sizeOf(@TypeOf(component)),
                std.mem.asBytes(&component),
            );
        }

        /// Mark an entity for removal. It will not actually be removed until
        /// `settle` is called.
        pub fn markForRemoval(self: *@This(), entity_id: EntityId) void {
            self.base.markForRemoval(entity_id);
        }

        pub fn markAllForRemoval(self: *@This(), comptime T: type) void {
            const component_type_index = getComponentTypeIndex(T);
            self.base.markAllForRemoval(component_type_index);
        }

        /// Apply removals (`markForRemoval`) and spawns (`spawn`). This should
        /// not be called during an entity iteration.
        pub fn settle(self: *@This()) void {
            self.base.settle();
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
        pub inline fn all(self: *const @This()) []*const ComponentType {
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

pub const IterField = struct {
    component_type_index: usize,
    is_optional: bool,
    offset: ?usize, // null for 0-size fields (non-optional ptr to empty struct)
};

pub const IterInbox = struct {
    capacity: usize,
    event_component_type_index: usize,
    event_id_field_offset: ?usize,
    offset_array: ?usize, // offset of inbox's `array` field inside `T`
    offset_count: usize, // offset of inbox's `count` field inside `T`
};

pub const IterStaticTable = struct {
    entity_id_T_offsets: []const usize,
    component_fields: []const IterField,
    inboxes: []const IterInbox,
};

pub const EntityIteratorBase = struct {
    ecs_base: *ECSBase,

    static: *const IterStaticTable,

    // index of "best" component in self.static.component_fields
    best_iterfield_index: usize,

    // current position within the "best" component type's slot array
    index: usize,

    pub fn init(
        ecs_base: *ECSBase,
        static: *const IterStaticTable,
    ) EntityIteratorBase {
        // go through the fields in the `T` struct (where each field
        // is either an EntityId or a (possibly optional) pointer to
        // a component). decide which component type to do the
        // outermost iteration over. choose the component type with
        // the lowest capacity (= least amount of iterations).
        var best: ?struct { iterfield_index: usize, count: usize } = null;

        for (static.component_fields) |iterfield, iterfield_index| {
            if (iterfield.is_optional) {
                continue;
            }
            const ra = &ecs_base.runtime_array[iterfield.component_type_index];
            if (best == null or ra.capacity < best.?.count) {
                best = .{
                    .iterfield_index = iterfield_index,
                    .count = ra.capacity,
                };
            }
        }

        return .{
            .ecs_base = ecs_base,
            .static = static,
            .best_iterfield_index = best.?.iterfield_index,
            .index = 0,
        };
    }

    pub fn nextWithId(
        self: *EntityIteratorBase,
        result_address: usize,
        maybe_out_id: ?*EntityId,
    ) bool {
        while (self.nextMainComponent(result_address)) |entity_id| {
            if (!self.fillComponentPointers(result_address, entity_id)) {
                continue;
            }
            if (!self.fillInboxes(result_address, entity_id)) {
                continue;
            }
            self.fillEntityId(result_address, entity_id);

            if (maybe_out_id) |out_id| {
                out_id.* = .{ .id = entity_id };
            }
            return true;
        }
        return false;
    }

    // get the next instance of the "best" component type. if found,
    // set the field in `result` and return the entity id.
    pub fn nextMainComponent(
        self: *EntityIteratorBase,
        result_address: usize,
    ) ?u64 {
        const best_component_index = self.static.component_fields
            [self.best_iterfield_index].component_type_index;
        const best_field_T_offset = self.static.component_fields
            [self.best_iterfield_index].offset;

        // for the "best" component type, we are iterating through the
        // component array using self.index...
        const ra = &self.ecs_base.runtime_array[best_component_index];
        for (ra.entity_ids[self.index..]) |id, i| {
            // make sure the entity has been "settled". freshly spawned
            // but unsettled entities are not returned by iterators.
            if (id == 0 or id >= self.ecs_base.first_new_entity_id) {
                continue;
            }
            if (best_field_T_offset) |offset| {
                // note: it's guaranteed that ra.size > 0 here, since we already
                // checked that the main component is not optional. thus, if
                // size was 0, offset would also have been null.
                @intToPtr(**u8, result_address + offset).* =
                    &ra.slice[(self.index + i) * ra.size];
            }
            self.index += i + 1;
            return id;
        }
        // hit the end of the component list - nothing left
        self.index = ra.capacity;
        return null;
    }

    pub fn fillEntityId(
        self: *@This(),
        result_address: usize,
        entity_id: u64,
    ) void {
        for (self.static.entity_id_T_offsets) |offset| {
            @intToPtr(*EntityId, result_address + offset).id = entity_id;
        }
    }

    pub fn fillComponentPointers(
        self: *@This(),
        result_address: usize,
        entity_id: u64,
    ) bool {
        for (self.static.component_fields) |iterfield, iterfield_index| {
            if (iterfield_index == self.best_iterfield_index) {
                // the "best" one was filled already by nextMainComponent
                continue;
            }
            // go through all components of this type, looking for one that
            // matches our entity_id
            const ra = &self.ecs_base.runtime_array
                [iterfield.component_type_index];
            for (ra.entity_ids) |slot_entity_id, i| {
                if (slot_entity_id != entity_id) {
                    continue;
                }
                if (iterfield.offset) |offset| {
                    if (ra.size > 0) {
                        @intToPtr(*?*u8, result_address + offset).* =
                            &ra.slice[i * ra.size];
                    } else {
                        // optional pointers to empty structs are modelled
                        // differently in zig. they're basically booleans.
                        // this marks the pointer value as "not null".
                        @intToPtr(*?*u0, result_address + offset).* =
                            &@as(u0, 0);
                    }
                } else {
                    // if offset is null, it's a non-optional pointer to an
                    // empty struct, i.e. the pointer itself has no size or
                    // meaning
                }
                break;
            } else {
                // didn't find any component with our entity_id
                if (!iterfield.is_optional) {
                    // it was required. so much for this entity.
                    // we'll try again with a new "main" component
                    return false;
                }
                // it was optional. set to null and carry on
                const offset = iterfield.offset.?;
                if (ra.size > 0) {
                    @intToPtr(*?*u8, result_address + offset).* = null;
                } else {
                    @intToPtr(*?*u0, result_address + offset).* = null;
                }
            }
        }
        return true;
    }

    pub fn fillInboxes(
        self: *@This(),
        result_address: usize,
        entity_id: u64,
    ) bool {
        for (self.static.inboxes) |inbox| {
            var array_ptr =
                if (inbox.offset_array) |o|
                    @intToPtr([*]*const u8, result_address + o)
                else undefined;
            var count: usize = 0;

            // look for an event pointing to this entity
            const ra = &self.ecs_base.runtime_array
                [inbox.event_component_type_index];
            for (ra.entity_ids) |id, i| {
                if (id == 0 or id >= self.ecs_base.first_new_entity_id) {
                    continue;
                }
                if (inbox.offset_array) |o| {
                    const event_address = @ptrToInt(&ra.slice[i * ra.size]);
                    if (inbox.event_id_field_offset) |id_field_offset| {
                        const id_address = event_address + id_field_offset;
                        const id_ptr = @intToPtr(*EntityId, id_address);
                        if (id_ptr.id != entity_id) {
                            continue;
                        }
                    }
                    array_ptr[count] = @intToPtr(*const u8, event_address);
                }
                count += 1;
                // if the inbox is full, silently drop events
                if (count == inbox.capacity) {
                    break;
                }
            }
            if (count == 0) {
                return false;
            }
            @intToPtr(*usize, result_address + inbox.offset_count).* = count;
        }
        return true;
    }
};

/// Type of the value returned by `iter`.
/// Yields all entities matching the given type.
pub fn EntityIterator(comptime ECSType: type, comptime T: type) type {
    // validate `T` and count things for the static table we'll make later
    comptime var all_component_fields_optional = true;
    comptime var num_entity_id_T_offsets: usize = 0;
    comptime var num_component_fields: usize = 0;
    comptime var num_inboxes: usize = 0;
    inline for (@typeInfo(T).Struct.fields) |field| {
        var ft = field.field_type;
        switch (@typeInfo(field.field_type)) {
            .Pointer => all_component_fields_optional = false,
            .Optional => |o| ft = o.child,
            else => {},
        }
        switch (@typeInfo(ft)) {
            .Pointer => |p| {
                const ComponentType = p.child;
                inline for (ECSType.wrappers) |wrapper| {
                    if (wrapper.Type == ComponentType) {
                        break;
                    }
                } else {
                    @compileError("iterator struct has field (" ++ field.name
                        ++ ") " ++ "that isn't a registered component type ("
                        ++ @typeName(ComponentType) ++ ")");
                }
                num_component_fields += 1;
            },
            .Struct => {
                if (ft == EntityId) {
                    num_entity_id_T_offsets += 1;
                } else if (ft.is_inbox) {
                    num_inboxes += 1;
                } else {
                    @compileError("invalid field (" ++ field.name ++ ")");
                }
            },
            else => @compileError("invalid field (" ++ field.name ++ ")"),
        }
    }
    if (all_component_fields_optional) {
        @compileError("all component fields cannot be optional");
    }

    // validation complete. make static arrays
    var entity_id_T_offsets: [num_entity_id_T_offsets]usize = undefined;
    {
        var i: usize = 0;
        inline for (@typeInfo(T).Struct.fields) |field| {
            if (field.field_type != EntityId) continue;
            entity_id_T_offsets[i] = field.offset.?;
            i += 1;
        }
        std.debug.assert(i == num_entity_id_T_offsets);
    }
    var component_fields: [num_component_fields]IterField = undefined;
    {
        var i: usize = 0;
        inline for (@typeInfo(T).Struct.fields) |field| {
            comptime var ft = field.field_type;
            comptime var is_optional = false;
            switch (@typeInfo(ft)) {
                .Optional => |o| {
                    ft = o.child;
                    is_optional = true;
                },
                else => {},
            }
            switch (@typeInfo(ft)) {
                .Pointer => |p| {
                    component_fields[i] = .{
                        .component_type_index =
                            ECSType.getComponentTypeIndex(p.child),
                        .is_optional = is_optional,
                        .offset =
                            // https://github.com/ziglang/zig/issues/4529
                            if (field.offset) |offset| offset else null,
                    };
                    i += 1;
                },
                else => {},
            }
        }
        std.debug.assert(i == num_component_fields);
    }
    var inboxes: [num_inboxes]IterInbox = undefined;
    {
        @setEvalBranchQuota(20000);
        var i: usize = 0;
        inline for (@typeInfo(T).Struct.fields) |field| {
            if (field.field_type == EntityId) continue;
            if (@typeInfo(field.field_type) != .Struct) continue;
            if (!field.field_type.is_inbox) continue;

            const EventComponentType = field.field_type.ComponentType;

            // offset of inbox object inside `T`
            const offset = field.offset.?;

            var capacity: ?usize = null;
            // offset of inbox's `array` field inside the inbox
            var offset_array: ?usize = null;
            var offset_count: ?usize = null;
            inline for (@typeInfo(field.field_type).Struct.fields) |inbox_field| {
                if (std.mem.eql(u8, inbox_field.name, "array")) {
                    capacity = @typeInfo(inbox_field.field_type).Array.len;
                    // offset will be null if the event component type has no
                    // size (and thus the array itself has no size)
                    if (inbox_field.offset) |o| {
                        offset_array = o;
                    }
                }
                if (std.mem.eql(u8, inbox_field.name, "count")) {
                    offset_count = inbox_field.offset.?;
                }
            }

            // offset if "id" field within event component type
            var event_id_field_offset: ?usize = null;
            if (field.field_type.id_field) |id_field| {
                inline for (@typeInfo(EventComponentType).Struct.fields)
                            |event_field| {
                    if (!std.mem.eql(u8, event_field.name, id_field)) {
                        continue;
                    }
                    if (event_field.field_type != EntityId) {
                        @compileError("inbox id field must be of type EntityId");
                    }
                    event_id_field_offset = event_field.offset.?;
                    break;
                } else {
                    @compileError("no field \"" ++ id_field ++ "\" in " ++
                        "struct " ++ @typeName(EventComponentType));
                }
            }

            inboxes[i] = .{
                .capacity = capacity.?,
                .event_component_type_index =
                    ECSType.getComponentTypeIndex(EventComponentType),
                .offset_array =
                    if (offset_array) |o| offset + o else null,
                .offset_count = offset + offset_count.?,
                .event_id_field_offset = event_id_field_offset,
            };
            i += 1;
        }
        std.debug.assert(i == num_inboxes);
    }

    const static_table: IterStaticTable = .{
        .entity_id_T_offsets = &entity_id_T_offsets,
        .component_fields = &component_fields,
        .inboxes = &inboxes,
    };

    // TODO - as an optimization, if one of the fields is an Inbox, we should
    // iterate over the events instead of over the "self" entity components.

    return struct {
        base: EntityIteratorBase,

        pub fn init(ecs_base: *ECSBase) @This() {
            return .{
                .base = EntityIteratorBase.init(ecs_base, &static_table),
            };
        }

        pub inline fn next(self: *@This()) ?T {
            return self.nextWithId(null);
        }

        pub fn nextWithId(self: *@This(), maybe_out_id: ?*EntityId) ?T {
            var result: T = undefined;
            const result_address = @ptrToInt(&result);

            if (!self.base.nextWithId(result_address, maybe_out_id)) {
                return null;
            }

            return result;
        }
    };
}

pub const ComponentIteratorBase = struct {
    ecs_base: *ECSBase,
    component_type_index: usize,
    index: usize,

    pub fn init(
        ecs_base: *ECSBase,
        component_type_index: usize,
    ) ComponentIteratorBase {
        return .{
            .ecs_base = ecs_base,
            .component_type_index = component_type_index,
            .index = 0,
        };
    }

    pub fn nextWithIdNonEmpty(
        self: *ComponentIteratorBase,
        maybe_out_id: ?*EntityId,
    ) ?*u8 {
        const ra = &self.ecs_base.runtime_array[self.component_type_index];
        for (ra.entity_ids[self.index..]) |id, i| {
            if (id == 0 or id >= self.ecs_base.first_new_entity_id) {
                continue;
            }
            const item = &ra.slice[(self.index + i) * ra.size];
            self.index += i + 1;
            if (maybe_out_id) |out_id| {
                out_id.id = id;
            }
            return item;
        }
        self.index = ra.capacity;
        return null;
    }

    // same as the above but for 0-byte components (for which the ?*u8 type does
    // not work)
    pub fn nextWithIdEmpty(
        self: *ComponentIteratorBase,
        maybe_out_id: ?*EntityId,
    ) bool {
        const ra = &self.ecs_base.runtime_array[self.component_type_index];
        for (ra.entity_ids[self.index..]) |id, i| {
            if (id == 0 or id >= self.ecs_base.first_new_entity_id) {
                continue;
            }
            self.index += i + 1;
            if (maybe_out_id) |out_id| {
                out_id.id = id;
            }
            return true;
        }
        self.index = ra.capacity;
        return false;
    }
};

pub fn ComponentIterator(comptime ECSType: type, comptime T: type) type {
    return struct {
        base: ComponentIteratorBase,

        pub fn init(ecs_base: *ECSBase) @This() {
            return .{
                .base = ComponentIteratorBase.init(
                    ecs_base,
                    ECSType.getComponentTypeIndex(T),
                ),
            };
        }

        pub inline fn next(self: *@This()) ?*T {
            return self.nextWithId(null);
        }

        pub fn nextWithId(self: *@This(), maybe_out_id: ?*EntityId) ?*T {
            if (@sizeOf(T) >= 1) {
                if (self.base.nextWithIdNonEmpty(maybe_out_id)) |ptr| {
                    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
                }
            } else {
                if (self.base.nextWithIdEmpty(maybe_out_id)) {
                    // issue for a better way to come up with a not-null sentinel
                    // value for optional pointers to zero-bit types:
                    // https://github.com/ziglang/zig/issues/4537
                    var not_null: T = undefined;
                    return &not_null;
                }
            }
            return null;
        }
    };
}
