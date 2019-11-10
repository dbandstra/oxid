const std = @import("std");
const Gbe = @import("gbe_main.zig");

// `SessionType` param to these functions must have be of type `Gbe.Session(...)`

// TODO - implement a system that exposes an iterator instead of running
// everything internally

pub const ThinkResult = enum {
    RemoveSelf,
    Remain,
};

fn getRunFunctionType(comptime SessionType: type, comptime SystemType: type) type {
    inline for (@typeInfo(SystemType).Struct.fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "context")) {
            return fn(*SessionType, field.field_type)void;
        }
    }
    // no context field in SystemType = no context argument in the run function
    return fn(*SessionType)void;
}

pub fn buildSystem(
    comptime SessionType: type,
    comptime SystemType: type,
    comptime think: fn(*SessionType, SystemType)ThinkResult,
) getRunFunctionType(SessionType, SystemType) {
    const ContextType = inline for (@typeInfo(SystemType).Struct.fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "context")) {
            break field.field_type;
        }
    } else void;

    const Impl = struct {
        fn runOne(
            gs: *SessionType,
            context: ContextType,
            self_id: Gbe.EntityId,
            comptime MainComponentType: type,
            main_component: *MainComponentType,
        ) ThinkResult {
            // fill in the fields of the `system` structure
            var self: SystemType = undefined;
            inline for (@typeInfo(SystemType).Struct.fields) |field| {
                if (comptime std.mem.eql(u8, field.name, "context")) {
                    self.context = context;
                    continue;
                }
                // if the field is of type EntityId, fill it in....
                if (field.field_type == Gbe.EntityId) {
                    @field(self, field.name) = self_id;
                    continue;
                }
                // otherwise, it must be a pointer to a component, or an optional
                // pointer to a component
                comptime const ComponentType = unpackComponentType(field.field_type);
                @field(self, field.name) =
                    if (ComponentType == MainComponentType)
                        main_component
                    else if (@typeId(field.field_type) == .Optional)
                        gs.find(self_id, ComponentType)
                    else
                        gs.find(self_id, ComponentType) orelse return .Remain;
            }
            // call the think function
            return think(gs, self);
        }

        fn runAll(
            gs: *SessionType,
            context: ContextType,
            comptime MainComponentType: type,
        ) void {
            var it = gs.iter(MainComponentType); while (it.next()) |object| {
                const result = runOne(gs, context, object.entity_id, MainComponentType, &object.data);
                if (result == .RemoveSelf) {
                    gs.markEntityForRemoval(object.entity_id);
                }
            }
        }

        // variant of `run` that is simpler (definitely) but slower (probably). but
        // the effect should be exactly the same
        fn runSimple(gs: *SessionType, context: ContextType) void {
            inline for (@typeInfo(SystemType).Struct.fields) |field| {
                if (comptime std.mem.eql(u8, field.name, "context")) continue;
                if (field.field_type == Gbe.EntityId) continue;
                runAll(gs, context, unpackComponentType(field.field_type));
                return;
            }
        }

        fn run(gs: *SessionType, context: ContextType) void {
            // only if all fields are optional will we consider optional fields when
            // determining the best component type
            comptime var all_fields_optional = true;

            inline for (@typeInfo(SystemType).Struct.fields) |field| {
                if (comptime std.mem.eql(u8, field.name, "context")) continue;
                if (field.field_type == Gbe.EntityId) continue;
                if (@typeId(field.field_type) != .Optional) {
                    all_fields_optional = false;
                }
            }

            // go through the fields in the SystemType struct (where each field
            // is either an EntityId or a pointer to a component). decide which
            // component type to do the outermost iteration over. choose the
            // component type with the lowest amount of active entities.
            var best: usize = std.math.maxInt(usize);
            var which: ?usize = null;

            inline for (@typeInfo(SystemType).Struct.fields) |field, i| {
                if (comptime std.mem.eql(u8, field.name, "context")) continue;
                if (field.field_type == Gbe.EntityId) continue;
                // skip optional fields, unless all fields are optional
                if (@typeId(field.field_type) == .Optional and !all_fields_optional) {
                    continue;
                }
                comptime const field_type = unpackComponentType(field.field_type);
                if (@field(&gs.components, @typeName(field_type)).count < best) {
                    best = @field(&gs.components, @typeName(field_type)).count;
                    which = i;
                }
            }

            // run the iteration
            if (which) |which_index| {
                inline for (@typeInfo(SystemType).Struct.fields) |field, i| {
                    if (i == which_index) {
                        if (comptime std.mem.eql(u8, field.name, "context")) {
                            unreachable;
                        }
                        if (field.field_type == Gbe.EntityId) {
                            // this actually avoids the compile error in unpackComponentType
                            unreachable;
                        }
                        runAll(gs, context, unpackComponentType(field.field_type));
                        return;
                    }
                }
                unreachable;
            }
        }

        fn unpackComponentType(comptime field_type: type) type {
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
    };

    if (ContextType == void) {
        // stupid convenience feature - if there's no `context`, the run
        // function won't have a context argument
        return struct { fn f(gs: *SessionType) void { Impl.run(gs, {}); } }.f;
    } else {
        // return Impl.runSimple;
        return Impl.run;
    }
}
