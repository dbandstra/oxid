const std = @import("std");
const GameSession = @import("game.zig").GameSession;
const physicsFrame = @import("physics.zig").physicsFrame;
const c = @import("components.zig");
const p = @import("prototypes.zig");
const datafile = @import("datafile.zig");

pub fn gameInit(gs: *GameSession, params: p.MainController.Params) !void {
    _ = try p.MainController.spawn(gs, params);
}

// run before "middleware" (rendering, sound, etc)
pub fn gameFrame(gs: *GameSession) void {
    @import("systems/input_router.zig").run(gs);

    @import("systems/main_controller_input.zig").run(gs);

    // note: ideally these would be inside the frame loop, but we have to make
    // sure that key-up events take effect even when the game is paused
    @import("systems/game_controller_input.zig").run(gs);
    @import("systems/player_input.zig").run(gs);

    const mc = gs.findFirst(c.MainController).?;
    if (mc.game_running_state) |grs| {
        if (mc.menu_stack_len == 0) {
            @import("systems/game_controller.zig").run(gs);
            @import("systems/player_controller.zig").run(gs);
            @import("systems/animation.zig").run(gs);
            @import("systems/player_movement.zig").run(gs);
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

    // main controller reacts to 'post score' event
    @import("systems/main_controller_react.zig").run(gs);

    gs.applyRemovals();

    // send draw commands (as events)
    @import("systems/animation_draw.zig").run(gs);
    @import("systems/creature_draw.zig").run(gs);
    @import("systems/simple_graphic_draw.zig").run(gs);

    if (gs.findFirst(c.MainController).?.game_running_state) |grs| {
        if (grs.render_move_boxes) {
            @import("systems/bullet_draw_box.zig").run(gs);
            @import("systems/physobject_draw_box.zig").run(gs);
            @import("systems/player_draw_box.zig").run(gs);
        }
    }
}

// run after "middleware" (rendering, sound, etc)
pub fn gameFrameCleanup(gs: *GameSession) void {
    markAllEventsForRemoval(gs);
    gs.applyRemovals();
}

fn markAllEventsForRemoval(gs: *GameSession) void {
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        const ComponentType = field.field_type.ComponentType;
        if (std.mem.startsWith(u8, @typeName(ComponentType), "Event")) {
            var it = gs.iter(ComponentType); while (it.next()) |object| {
                gs.markEntityForRemoval(object.entity_id);
            }
        }
    }
}
