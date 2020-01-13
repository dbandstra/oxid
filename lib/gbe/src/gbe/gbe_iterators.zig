const std = @import("std");
const Gbe = @import("gbe_main.zig");

pub fn ComponentIterator(comptime T: type, comptime capacity: usize) type {
    return struct {
        list: *Gbe.ComponentList(T, capacity),
        index: usize,

        pub fn init(list: *Gbe.ComponentList(T, capacity)) @This() {
            return .{
                .list = list,
                .index = 0,
            };
        }

        pub inline fn next(self: *@This()) ?*T {
            return self.nextWithId(null);
        }

        pub fn nextWithId(self: *@This(), maybe_out_id: ?*Gbe.EntityId) ?*T {
            for (self.list.objects[self.index..self.list.count]) |*object, i| {
                if (Gbe.EntityId.isZero(object.entity_id)) {
                    continue;
                }
                if (maybe_out_id) |out_id| {
                    out_id.* = object.entity_id;
                }
                self.index += i + 1;
                return &object.data;
            }
            self.index = self.list.count + 1;
            return null;
        }
    };
}

// EventIterator takes a field name (compile-time) and an entity id (run-time),
// and only yields events where event.field == entity_id
pub fn EventIterator(comptime T: type, comptime capacity: usize, comptime field: []const u8) type {
    return struct {
        list: *Gbe.ComponentList(T, capacity),
        entity_id: Gbe.EntityId,
        index: usize,

        pub fn init(list: *Gbe.ComponentList(T, capacity), entity_id: Gbe.EntityId) @This() {
            return .{
                .list = list,
                .entity_id = entity_id,
                .index = 0,
            };
        }

        pub fn next(self: *@This()) ?*T {
            if (Gbe.EntityId.isZero(self.entity_id)) {
                return null;
            }
            for (self.list.objects[self.index..self.list.count]) |*object, i| {
                if (Gbe.EntityId.isZero(object.entity_id)) {
                    continue;
                }
                if (!Gbe.EntityId.eql(@field(&object.data, field), self.entity_id)) {
                    continue;
                }
                self.index += i + 1;
                return &object.data;
            }
            self.index = self.list.count + 1;
            return null;
        }
    };
}

// `T` is a struct containing pointers to components
pub fn EntityIterator(comptime SessionType: type, comptime T: type) type {
    return struct {
        gs: *SessionType,
        index: usize, // component index within "best" component type's slot array

        pub fn init(gs: *SessionType) @This() {
            return .{
                .gs = gs,
                .index = 0,
            };
        }

        pub inline fn next(self: *@This()) ?T {
            return self.nextWithId(null);
        }

        pub fn nextWithId(self: *@This(), maybe_out_id: ?*Gbe.EntityId) ?T {
            // choose the best field
            // only if all fields are optional will we consider optional fields when
            // determining the best component type
            comptime var all_fields_optional = true;

            inline for (@typeInfo(T).Struct.fields) |field| {
                if (field.field_type == Gbe.EntityId) continue;
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
                if (field.field_type == Gbe.EntityId) continue;
                // skip optional fields, unless all fields are optional
                if (@typeId(field.field_type) == .Optional and !all_fields_optional) {
                    continue;
                }
                comptime const field_type = UnpackComponentType(field.field_type);
                if (@field(&self.gs.components, @typeName(field_type)).count < best) {
                    best = @field(&self.gs.components, @typeName(field_type)).count;
                    maybe_which = i;
                }
            }

            const best_field_index = maybe_which orelse {
                // no valid component?
                return null;
            };

            while (true) {
                var nope = false;

                // fields of the result will be filled out one at a time
                var result: T = undefined;
                var entity_id: Gbe.EntityId = undefined;

                // go through the components of the "best" type. find the next one that exists
                inline for (@typeInfo(T).Struct.fields) |field, field_index| {
                    if (field.field_type == Gbe.EntityId) continue;
                    if (field_index == best_field_index) {
                        const ComponentType = UnpackComponentType(field.field_type);

                        comptime var found_component_type = false;

                        // find the component list in the GBE session
                        inline for (@typeInfo(SessionType.ComponentListsType).Struct.fields) |c_field, c_field_index| {
                            if (c_field.field_type.ComponentType == ComponentType) {
                                found_component_type = true;

                                const slots = &@field(self.gs.components, c_field.name);

                                // for the best component type, we are iterating through the
                                // component array using self.index...
                                while (self.index < slots.count) {
                                    const i = self.index;
                                    self.index += 1;
                                    if (!Gbe.EntityId.isZero(slots.objects[i].entity_id)) {
                                        @field(result, field.name) = &slots.objects[i].data;
                                        entity_id = slots.objects[i].entity_id;
                                        break;
                                    }
                                } else {
                                    // hit the end of the component list - nothing left
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

                // go through other component types in the struct. look for components with the same
                // entity_id as we found from the best entry above.
                // if the field is not optional, and a component is not found, clear the result and we'll try again.
                inline for (@typeInfo(T).Struct.fields) |field, field_index| {
                    if (field_index == best_field_index) {
                        // already handled this one above
                    } else if (nope) {
                        // keep going till we get out of the loop (not allowed to break out of an
                        // inline loop using a runtime condition)
                    } else if (comptime field.field_type == Gbe.EntityId) {
                        // entity id (special field), will fill in later.
                    } else {
                        const ComponentType = UnpackComponentType(field.field_type);

                        comptime var found_component_type = false;

                        inline for (@typeInfo(SessionType.ComponentListsType).Struct.fields) |c_field, c_field_index| {
                            if (nope) {
                                // keep going till we get out of the loop (not allowed to break out
                                // of an inline loop using a runtime condition)
                            } if (c_field.field_type.ComponentType == ComponentType) {
                                // this component array corresponds to the field in the iterator struct...
                                found_component_type = true;

                                const slots = &@field(self.gs.components, c_field.name);

                                // look for a component with an entity_id matching the entity we're currently looking at.
                                for (slots.objects[0..slots.count]) |*object, i| {
                                    if (Gbe.EntityId.eql(object.entity_id, entity_id)) {
                                        @field(result, field.name) = &slots.objects[i].data;
                                        break;
                                    }
                                } else {
                                    // requested component not present in this entity.
                                    if (@typeId(field.field_type) == .Optional) {
                                        @field(result, field.name) = null;
                                    } else {
                                        // it was required. break out of the inline loops. we'll try again with a
                                        // new first component
                                        nope = true;
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

                if (!nope) {
                    // if there's an entity id field, fill it in now
                    inline for (@typeInfo(T).Struct.fields) |field| {
                        if (comptime field.field_type == Gbe.EntityId) {
                            @field(result, field.name) = entity_id;
                        }
                    }

                    if (maybe_out_id) |out_id| {
                        out_id.* = entity_id;
                    }

                    return result;
                }
            }
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
