const std = @import("std");
const gbe = @import("gbe");
const ComponentLists = @import("game.zig").ComponentLists;
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

// run before "middleware" (rendering, sound, etc)
pub fn gameFrame(gs: *GameSession, context: GameFrameContext, draw: bool, paused: bool) void {
    @import("systems/main_controller_input.zig").run(gs);
    @import("systems/game_controller_input.zig").run(gs);
    @import("systems/player_input.zig").run(gs);

    if (gs.ecs.findFirst(c.MainController).?.game_running_state) |grs| {
        if (!paused) {
            @import("systems/game_controller.zig").run(gs);
            @import("systems/player_controller.zig").run(gs);
            @import("systems/animation.zig").run(gs);
            @import("systems/player_movement.zig").run(gs, context);
            @import("systems/monster_movement.zig").run(gs);
            @import("systems/bullet.zig").run(gs);
            @import("systems/creature.zig").run(gs);
            @import("systems/remove_timer.zig").run(gs);

            physicsFrame(gs);

            // pickups react to event_collide, spawn event_confer_bonus
            @import("systems/pickup_collide.zig").run(gs);
            // bullets react to event_collide, spawn event_take_damage
            @import("systems/bullet_collide.zig").run(gs);
            // monsters react to event_collide, damage others
            @import("systems/monster_touch_response.zig").run(gs);
            // player reacts to event_confer_bonus, gets bonus effect
            @import("systems/player_reaction.zig").run(gs);

            // creatures react to event_take_damage, die
            @import("systems/creature_take_damage.zig").run(gs);

            // player controller reacts to 'player died' event
            @import("systems/player_controller_react.zig").run(gs);
            // game controller reacts to 'player died' / 'player out of lives' event
            @import("systems/game_controller_react.zig").run(gs);
        }
    }

    gs.ecs.applyRemovals();

    if (draw) {
        // send draw commands (as events)
        @import("systems/animation_draw.zig").run(gs);
        @import("systems/creature_draw.zig").run(gs);
        @import("systems/simple_graphic_draw.zig").run(gs);

        if (gs.ecs.findFirst(c.MainController).?.game_running_state) |grs| {
            if (grs.render_move_boxes) {
                @import("systems/bullet_draw_box.zig").run(gs);
                @import("systems/physobject_draw_box.zig").run(gs);
                @import("systems/player_draw_box.zig").run(gs);
            }
        }
    }
}

// run after "middleware" (rendering, sound, etc)
pub fn gameFrameCleanup(gs: *GameSession) void {
    // mark all events for removal
    inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
        const ComponentType = field.field_type.ComponentType;

        if (comptime std.mem.startsWith(u8, @typeName(ComponentType), "Event")) {
            var id: gbe.EntityId = undefined;
            var it = gs.ecs.iter(ComponentType);
            while (it.nextWithId(&id) != null) {
                gs.ecs.markEntityForRemoval(id);
            }
        }
    }

    gs.ecs.applyRemovals();
}
