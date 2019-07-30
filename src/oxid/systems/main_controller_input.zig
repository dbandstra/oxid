const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const audio = @import("../audio.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    switch (self.mc.state) {
        .MainMenu => |*mms| {
            handleMainMenuInput(gs, self.mc, mms);
        },
        .OptionsMenu => |*oms| {
            handleOptionsMenuInput(gs, self.mc, oms);
        },
        .GameRunning => |*grs| {
            if (grs.exit_dialog_open) {
                handleExitDialogInput(gs, self.mc, grs);
            } else {
                handleGameRunningInput(gs, grs);
            }
        },
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

fn cursorUp(comptime T: type, cursor_pos: *T) void {
    const index = @enumToInt(cursor_pos.*);
    const last = @intCast(@typeOf(index), @typeInfo(T).Enum.fields.len - 1);
    cursor_pos.* = @intToEnum(T, if (index > 0) index - 1 else last);
}

fn cursorDown(comptime T: type, cursor_pos: *T) void {
    const index = @enumToInt(cursor_pos.*);
    const last = @intCast(@typeOf(index), @typeInfo(T).Enum.fields.len - 1);
    cursor_pos.* = @intToEnum(T, if (index < last) index + 1 else 0);
}

fn handleMainMenuInput(gs: *GameSession, mc: *c.MainController, cursor_pos: *c.MainController.MainMenuState) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        switch (event.data.command) {
            .Up => {
                cursorUp(c.MainController.MainMenuState, cursor_pos);
                p.playSynth(gs, audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => {
                cursorDown(c.MainController.MainMenuState, cursor_pos);
                p.playSynth(gs, audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Shoot => {
                switch (cursor_pos.*) {
                    .NewGame => {
                        p.playSynth(gs, audio.MenuDingVoice.NoteParams { .unused = undefined });
                        startGame(gs, mc);
                    },
                    .Options => {
                        p.playSynth(gs, audio.MenuDingVoice.NoteParams { .unused = undefined });
                        mc.state = c.MainController.State {
                            .OptionsMenu = .Mute,
                        };
                    },
                    .Quit => {
                        _ = p.EventSystemCommand.spawn(gs, .Quit) catch undefined;
                    },
                }
            },
            else => {},
        }
    }
}

fn handleOptionsMenuInput(gs: *GameSession, mc: *c.MainController, cursor_pos: *c.MainController.OptionsMenuState) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        switch (event.data.command) {
            .Up => {
                cursorUp(c.MainController.OptionsMenuState, cursor_pos);
                p.playSynth(gs, audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => {
                cursorDown(c.MainController.OptionsMenuState, cursor_pos);
                p.playSynth(gs, audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Shoot => {
                switch (cursor_pos.*) {
                    .Mute => {
                        p.playSynth(gs, audio.MenuDingVoice.NoteParams { .unused = undefined });
                        _ = p.EventSystemCommand.spawn(gs, .ToggleMute) catch undefined;
                    },
                    .Fullscreen => {
                        p.playSynth(gs, audio.MenuDingVoice.NoteParams { .unused = undefined });
                        _ = p.EventSystemCommand.spawn(gs, .ToggleFullscreen) catch undefined;
                    },
                    .Back => {
                        p.playSynth(gs, audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                        mc.state = c.MainController.State {
                            .MainMenu = .Options,
                        };
                    },
                }
            },
            .Escape => {
                p.playSynth(gs, audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                mc.state = c.MainController.State {
                    .MainMenu = .Options,
                };
            },
            else => {},
        }
    }
}

fn startGame(gs: *GameSession, mc: *c.MainController) void {
    mc.state = c.MainController.State {
        .GameRunning = c.MainController.GameRunningState {
            .render_move_boxes = false,
            .exit_dialog_open = false,
        },
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

    mc.state = c.MainController.State {
        .MainMenu = .NewGame,
    };

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
