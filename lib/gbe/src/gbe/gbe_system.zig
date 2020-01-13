const std = @import("std");
const Gbe = @import("gbe_main.zig");

// `SessionType` param to these functions must be of type `Gbe.Session(...)`

pub const ThinkResult = enum {
    RemoveSelf,
    Remain,
};

pub fn buildSystem(
    comptime SessionType: type,
    comptime SystemType: type,
    comptime think: fn(*SessionType, SystemType)ThinkResult,
) fn(*SessionType)void {
    const Impl = struct {
        fn run(gs: *SessionType) void {
            var it = gs.entityIter(SystemType);
            var entity_id: Gbe.EntityId = undefined;
            while (it.nextWithId(&entity_id)) |entry| {
                const result = think(gs, entry);
                if (result == .RemoveSelf) {
                    gs.markEntityForRemoval(entity_id);
                }
            }
        }
    };
    return Impl.run;
}

pub fn buildSystemWithContext(
    comptime SessionType: type,
    comptime SystemType: type,
    comptime ContextType: type,
    comptime think: fn(*SessionType, SystemType, ContextType)ThinkResult,
) fn(*SessionType, ContextType)void {
    const Impl = struct {
        fn run(gs: *SessionType, ctx: ContextType) void {
            var it = gs.entityIter(SystemType);
            var entity_id: Gbe.EntityId = undefined;
            while (it.nextWithId(&entity_id)) |entry| {
                const result = think(gs, entry, ctx);
                if (result == .RemoveSelf) {
                    gs.markEntityForRemoval(entity_id);
                }
            }
        }
    };
    return Impl.run;
}
