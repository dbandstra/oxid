const gbe = @import("../common/gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const input = @import("../input.zig");

const SystemData = struct{
    mc: *C.MainController,
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

fn handleExitDialogInput(gs: *GameSession, mc: *C.MainController, grs: *C.MainController.GameRunningState) void {
    var it = gs.iter(C.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            input.Command.Escape,
            input.Command.No => {
                if (event.data.down) {
                    grs.exit_dialog_open = false;
                }
            },
            input.Command.Yes => {
                if (event.data.down) {
                    leaveGame(gs, mc);
                }
            },
            else => {},
        }
    }
}

fn handleGameRunningInput(gs: *GameSession, grs: *C.MainController.GameRunningState) void {
    var it = gs.iter(C.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            input.Command.Escape => {
                if (event.data.down) {
                    grs.exit_dialog_open = true;
                }
            },
            input.Command.ToggleDrawBoxes => {
                if (event.data.down) {
                    grs.render_move_boxes = !grs.render_move_boxes;
                }
            },
            else => {},
        }
    }
}

fn handleMainMenuInput(gs: *GameSession, mc: *C.MainController) void {
    var it = gs.iter(C.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            input.Command.Escape => {
                if (event.data.down) {
                    _ = Prototypes.EventQuit.spawn(gs, C.EventQuit{}) catch undefined;
                }
            },
            input.Command.Shoot => {
                if (event.data.down) {
                    startGame(gs, mc);
                }
            },
            else => {},
        }
    }
}

fn startGame(gs: *GameSession, mc: *C.MainController) void {
    mc.game_running_state = C.MainController.GameRunningState{
        .render_move_boxes = false,
        .exit_dialog_open = false,
    };

    _ = Prototypes.GameController.spawn(gs) catch undefined;
    _ = Prototypes.PlayerController.spawn(gs) catch undefined;
}

fn leaveGame(gs: *GameSession, mc: *C.MainController) void {
    // go through all the players and post their scores (if the player ran out of
    // lives and got a game over, they've already posted their score, but posting
    // it again won't cause any problem)
    var it0 = gs.iter(C.PlayerController); while (it0.next()) |object| {
        _ = Prototypes.EventPostScore.spawn(gs, C.EventPostScore{
            .score = object.data.score,
        }) catch undefined;
    }

    mc.game_running_state = null;

    // remove all entities except the MainController and EventPostScore
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        const ComponentType = field.field_type.ComponentType;
        if (ComponentType != C.MainController and
                ComponentType != C.EventPostScore) {
            var it = gs.iter(ComponentType); while (it.next()) |object| {
                gs.markEntityForRemoval(object.entity_id);
            }
        }
    }
}
