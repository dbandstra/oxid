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
    if (self.mc.menu_stack_len == 0) {
        if (self.mc.game_running_state) |*grs| {
            handleGameRunningInput(gs, self.mc, grs);
        }
    } else {
        switch (self.mc.menu_stack_array[self.mc.menu_stack_len - 1]) {
            .MainMenu => |*mms| {
                handleMainMenuInput(gs, self.mc, mms);
            },
            .InGameMenu => |*igms| {
                handleInGameMenuInput(gs, self.mc, igms);
            },
            .OptionsMenu => |*oms| {
                handleOptionsMenuInput(gs, self.mc, oms);
            },
        }
    }
    return true;
}

fn handleGameRunningInput(gs: *GameSession, mc: *c.MainController, grs: *c.MainController.GameRunningState) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Escape => {
                if (event.data.down) {
                    p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                    pushMenu(mc, c.MainController.Menu { .InGameMenu = .Continue });
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

fn pushMenu(mc: *c.MainController, menu: c.MainController.Menu) void {
    if (mc.menu_stack_len < mc.menu_stack_array.len) {
        mc.menu_stack_array[mc.menu_stack_len] = menu;
        mc.menu_stack_len += 1;
    }
}

fn popMenu(mc: *c.MainController) void {
    if (mc.menu_stack_len > 0) {
        mc.menu_stack_len -= 1;
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
                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => {
                cursorDown(c.MainController.MainMenuState, cursor_pos);
                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Shoot => {
                switch (cursor_pos.*) {
                    .NewGame => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                        popMenu(mc);
                        startGame(gs, mc);
                    },
                    .Options => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                        pushMenu(mc, c.MainController.Menu { .OptionsMenu = .Mute });
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

fn handleInGameMenuInput(gs: *GameSession, mc: *c.MainController, cursor_pos: *c.MainController.InGameMenuState) void {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        switch (event.data.command) {
            .Up => {
                cursorUp(c.MainController.InGameMenuState, cursor_pos);
                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => {
                cursorDown(c.MainController.InGameMenuState, cursor_pos);
                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Shoot => {
                switch (cursor_pos.*) {
                    .Continue => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                        popMenu(mc);
                    },
                    .Options => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                        pushMenu(mc, c.MainController.Menu { .OptionsMenu = .Mute });
                    },
                    .Leave => {
                        leaveGame(gs, mc);
                        // after, cause leaveGame deletes a bunch of stuff...
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                    },
                }
            },
            .Escape => {
                p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                popMenu(mc);
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
                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => {
                cursorDown(c.MainController.OptionsMenuState, cursor_pos);
                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Shoot => {
                switch (cursor_pos.*) {
                    .Mute => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                        _ = p.EventSystemCommand.spawn(gs, .ToggleMute) catch undefined;
                    },
                    .Fullscreen => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                        _ = p.EventSystemCommand.spawn(gs, .ToggleFullscreen) catch undefined;
                    },
                    .Back => {
                        p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                        popMenu(mc);
                    },
                }
            },
            .Escape => {
                p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                popMenu(mc);
            },
            else => {},
        }
    }
}

fn startGame(gs: *GameSession, mc: *c.MainController) void {
    mc.game_running_state = c.MainController.GameRunningState {
        .render_move_boxes = false,
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
    mc.menu_stack_array[0] = c.MainController.Menu { .MainMenu = .NewGame };
    mc.menu_stack_len = 1;

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
