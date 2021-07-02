const gbe = @import("gbe");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    const gc = gs.ecs.componentIter(c.GameController).next() orelse return;

    // whenever a player dies, freeze the monsters for a while, and check if
    // game over should be triggered
    if (gs.ecs.componentIter(c.EventPlayerDied).next() != null) {
        gc.freeze_monsters_timer = constants.monster_freeze_time;

        const any_lives_left = for ([_]?gbe.EntityID{
            gc.player1_controller_id,
            gc.player2_controller_id,
        }) |maybe_id| {
            const id = maybe_id orelse continue;
            const pc = gs.ecs.findComponentByID(id, c.PlayerController) orelse continue;
            if (pc.lives > 0) break true;
        } else false;

        if (!any_lives_left)
            p.spawnEventGameOver(gs, .{});
    }

    // whenever a monster dies, check if enemy speed level should be bumped up
    var it2 = gs.ecs.componentIter(c.EventMonsterDied);
    while (it2.next() != null) {
        if (gc.monster_count <= 0)
            continue;
        gc.monster_count -= 1;
        if (gc.monster_count == 4 and gc.enemy_speed_level < 1) gc.enemy_speed_timer = 1;
        if (gc.monster_count == 3 and gc.enemy_speed_level < 2) gc.enemy_speed_timer = 1;
        if (gc.monster_count == 2 and gc.enemy_speed_level < 3) gc.enemy_speed_timer = 1;
        if (gc.monster_count == 1 and gc.enemy_speed_level < 4) gc.enemy_speed_timer = 1;
    }

    // show messages
    var it3 = gs.ecs.componentIter(c.EventShowMessage);
    while (it3.next()) |event| {
        gc.wave_message = event.message;
        gc.wave_message_timer = constants.duration60(180);
    }
}
