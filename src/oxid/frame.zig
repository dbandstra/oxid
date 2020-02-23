const std = @import("std");
const gbe = @import("gbe");
const component_defs = @import("game.zig").component_defs;
const GameSession = @import("game.zig").GameSession;
const physicsFrame = @import("physics.zig").physicsFrame;
const c = @import("components.zig");
const p = @import("prototypes.zig");

pub const GameFrameContext = struct {
    friendly_fire: bool,
};

pub fn gameInit(gs: *GameSession) !void {
    _ = try p.MainController.spawn(gs);
}

fn runSystem(
    gs: *GameSession,
    context: GameFrameContext,
    comptime name: []const u8,
) void {
    const func = @import("systems/" ++ name ++ ".zig").run;

    if (@typeInfo(@TypeOf(func)).Fn.args.len == 2) {
        func(gs, context);
    } else {
        func(gs);
    }

    // apply spawns and removals
    gs.ecs.settle();
}

// run before "middleware" (rendering, sound, etc)
pub fn gameFrame(
    gs: *GameSession,
    ctx: GameFrameContext,
    draw: bool,
    paused: bool,
) void {
    runSystem(gs, ctx, "main_controller_input");
    runSystem(gs, ctx, "game_controller_input");
    runSystem(gs, ctx, "player_input");

    if (gs.ecs.findFirstComponent(c.MainController).?.game_running_state) |grs| {
        if (!paused) {
            runSystem(gs, ctx, "game_controller");
            runSystem(gs, ctx, "player_controller");
            runSystem(gs, ctx, "animation");
            runSystem(gs, ctx, "player_movement");
            runSystem(gs, ctx, "monster_movement");
            runSystem(gs, ctx, "bullet");
            runSystem(gs, ctx, "creature");
            runSystem(gs, ctx, "remove_timer");

            physicsFrame(gs);
            gs.ecs.settle();

            // pickups react to event_collide, spawn event_confer_bonus
            runSystem(gs, ctx, "pickup_collide");
            // bullets react to event_collide, spawn event_take_damage
            runSystem(gs, ctx, "bullet_collide");
            // monsters react to event_collide, damage others
            runSystem(gs, ctx, "monster_touch_response");
            // player reacts to event_confer_bonus, gets bonus effect
            runSystem(gs, ctx, "player_reaction");

            // creatures react to event_take_damage, die
            runSystem(gs, ctx, "creature_take_damage");

            // player controller reacts to 'player died' event
            runSystem(gs, ctx, "player_controller_react");
            // game controller reacts to 'player died' / 'player out of lives' event
            runSystem(gs, ctx, "game_controller_react");
        }
    }

    if (draw) {
        // send draw commands (as events)
        runSystem(gs, ctx, "animation_draw");
        runSystem(gs, ctx, "creature_draw");
        runSystem(gs, ctx, "simple_graphic_draw");

        if (gs.ecs.findFirstComponent(c.MainController).?.game_running_state) |grs| {
            if (grs.render_move_boxes) {
                runSystem(gs, ctx, "bullet_draw_box");
                runSystem(gs, ctx, "physobject_draw_box");
                runSystem(gs, ctx, "player_draw_box");
            }
        }
    }
}

// run after "middleware" (rendering, sound, etc)
pub fn gameFrameCleanup(gs: *GameSession) void {
    // mark all events for removal
    inline for (component_defs) |cdef| {
        if (comptime !std.mem.startsWith(u8, @typeName(cdef.Type), "Event")) {
            continue;
        }
        gs.ecs.markAllForRemoval(cdef.Type);
    }

    gs.ecs.settle();
}
