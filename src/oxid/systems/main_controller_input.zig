const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.mc.game_running_state) |*grs| {
        if (grs.exit_dialog_open) {
            handleExitDialogInput(gs, self.mc, grs);
        } else {
            handleGameRunningInput(gs, grs);
        }
    } else {
        handleMainMenuInput(gs, self.mc);
    }
    return true;
}

fn handleExitDialogInput(gs: *GameSession, mc: *c.MainController, grs: *c.MainController.GameRunningState) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Escape,
            .No => {
                if (event.data.down) {
                    grs.exit_dialog_open = false;
                }
            },
            .Yes => {
                if (event.data.down) {
                    leaveGame(gs, mc);
                }
            },
            else => {},
        }
    }
}

fn handleGameRunningInput(gs: *GameSession, grs: *c.MainController.GameRunningState) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Escape => {
                if (event.data.down) {
                    grs.exit_dialog_open = true;
                }
            },
            .ToggleDrawBoxes => {
                if (event.data.down) {
                    grs.render_move_boxes = !grs.render_move_boxes;
                }
            },
            else => {},
        }
    }
}

fn handleMainMenuInput(gs: *GameSession, mc: *c.MainController) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Escape => {
                if (event.data.down) {
                    _ = p.EventQuit.spawn(gs, c.EventQuit {}) catch undefined;
                }
            },
            .Shoot => {
                if (event.data.down) {
                    startGame(gs, mc);
                }
            },
            else => {},
        }
    }
}

fn startGame(gs: *GameSession, mc: *c.MainController) void {
    mc.game_running_state = c.MainController.GameRunningState {
        .render_move_boxes = false,
        .exit_dialog_open = false,
    };

    _ = p.GameController.spawn(gs) catch undefined;
    _ = p.PlayerController.spawn(gs) catch undefined;
}

fn leaveGame(gs: *GameSession, mc: *c.MainController) void {
    // go through all the players and post their scores (if the player ran out of
    // lives and got a game over, they've already posted their score, but posting
    // it again won't cause any problem)
    var it0 = gs.iter(c.PlayerController); while (it0.next()) |object| {
        _ = p.EventPostScore.spawn(gs, c.EventPostScore {
            .score = object.data.score,
        }) catch undefined;
    }

    mc.game_running_state = null;

    // remove all entities except the MainController and EventPostScore
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        const ComponentType = field.field_type.ComponentType;
        if (ComponentType != c.MainController and ComponentType != c.EventPostScore) {
            var it = gs.iter(ComponentType); while (it.next()) |object| {
                gs.markEntityForRemoval(object.entity_id);
            }
        }
    }
}
