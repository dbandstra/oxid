const std = @import("std");
const Gbe = @import("gbe_main.zig");

// `SessionType` param to these functions must have be of type  `Gbe.Session(...)`

// TODO - implement a system that exposes an iterator instead of running
// everything internally

pub const ThinkResult = enum {
    RemoveSelf,
    Remain,
};

pub fn buildSystemWithContext(
    comptime SessionType: type,
    comptime SelfType: type,
    comptime ContextType: type,
    comptime think: fn(*SessionType, *ContextType, SelfType)ThinkResult,
) fn(*SessionType, *ContextType)void {
    std.debug.assert(@typeId(SelfType) == .Struct);

    const Impl = struct {
        fn runOne(
            gs: *SessionType,
            ctx: *ContextType,
            self_id: Gbe.EntityId,
            comptime MainComponentType: type,
            main_component: *MainComponentType,
        ) ThinkResult {
            // fill in the fields of the `self` structure
            var self: SelfType = undefined;
            inline for (@typeInfo(SelfType).Struct.fields) |field| {
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
            return think(gs, ctx, self);
        }

        fn runAll(
            gs: *SessionType,
            ctx: *ContextType,
            comptime MainComponentType: type,
        ) void {
            var it = gs.iter(MainComponentType); while (it.next()) |object| {
                const result = runOne(gs, ctx, object.entity_id, MainComponentType, &object.data);
                if (result == .RemoveSelf) {
                    gs.markEntityForRemoval(object.entity_id);
                }
            }
        }

        // variant of `run` that is simpler (definitely) but slower (probably). but
        // the effect should be exactly the same
        fn runSimple(gs: *SessionType, ctx: *ContextType) void {
            inline for (@typeInfo(SelfType).Struct.fields) |field| {
                if (field.field_type == Gbe.EntityId) {
                    continue;
                }
                runAll(gs, ctx, unpackComponentType(field.field_type));
                return;
            }
        }

        fn run(gs: *SessionType, ctx: *ContextType) void {
            // only if all fields are optional will we consider optional fields when
            // determining the best component type
            comptime var all_fields_optional = true;

            inline for (@typeInfo(SelfType).Struct.fields) |field| {
                if (field.field_type != Gbe.EntityId and
                        @typeId(field.field_type) != .Optional) {
                    all_fields_optional = false;
                }
            }

            // go through the fields in the SelfType struct (where each field is
            // either an EntityId or a pointer to a component). decide which
            // component type to do the outermost iteration over. choose the
            // component type with the lowest amount of active entities.
            var best: usize = std.math.maxInt(usize);
            var which: ?usize = null;

            inline for (@typeInfo(SelfType).Struct.fields) |field, i| {
                if (field.field_type == Gbe.EntityId) {
                    continue;
                }
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
            // note: i can't just look up `which_index` in Struct.fields because of a
            // compiler bug https://github.com/ziglang/zig/issues/1435
            if (which) |which_index| {
                inline for (@typeInfo(SelfType).Struct.fields) |field, i| {
                    if (i == which_index) {
                        if (field.field_type == Gbe.EntityId) {
                            // this actually avoids the compile error in unpackComponentType
                            unreachable;
                        }
                        runAll(gs, ctx, unpackComponentType(field.field_type));
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

    // return Impl.runSimple;
    return Impl.run;
}

pub fn buildSystem(
    comptime SessionType: type,
    comptime SelfType: type,
    comptime think: fn(*SessionType, SelfType)ThinkResult,
) fn(*SessionType)void {
    const WrappedThink = struct {
        fn wrappedThink(gs: *SessionType, _: *void, self: SelfType) ThinkResult {
            return think(gs, self);
        }
    };
    const wrappedRun = buildSystemWithContext(SessionType, SelfType, void,
                                              WrappedThink.wrappedThink);
    const Impl = struct {
        fn run(gs: *SessionType) void {
            wrappedRun(gs, {});
        }
    };
    return Impl.run;
}