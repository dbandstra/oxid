const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const audio = @import("../audio.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const menus = @import("../menus.zig");
const input = @import("../input.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    self.mc.menu_anim_time +%= 1; // not really "input" but whatever

    if (self.mc.game_running_state) |*grs| {
        handleGameRunningInput(gs, self.mc, grs);
    }
    if (self.mc.menu_stack_len > 0) {
        switch (self.mc.menu_stack_array[self.mc.menu_stack_len - 1]) {
            .MainMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.MainMenu, menu_state); },
            .InGameMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.InGameMenu, menu_state); },
            .ReallyEndGameMenu => { handleReallyEndGamePromptInput(gs, self.mc); },
            .OptionsMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.OptionsMenu, menu_state); },
            .KeyBindingsMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.KeyBindingsMenu, menu_state); },
            .HighScoresMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.HighScoresMenu, menu_state); },
        }
    }
    return .Remain;
}

fn handleGameRunningInput(gs: *GameSession, mc: *c.MainController, grs: *c.MainController.GameRunningState) void {
    var it = gs.iter(c.EventGameInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Escape => {
                if (event.data.down) {
                    p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                    if (if (gs.findFirst(c.GameController)) |gc| gc.game_over else true) {
                        postScores(gs, mc);
                        pushMenu(mc, menus.Menu { .MainMenu = menus.MainMenu { .cursor_pos = .NewGame } });
                    } else {
                        pushMenu(mc, menus.Menu { .InGameMenu = menus.InGameMenu { .cursor_pos = .Continue } });
                    }
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

fn pushMenu(mc: *c.MainController, menu: menus.Menu) void {
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

fn handleReallyEndGamePromptInput(gs: *GameSession, mc: *c.MainController) void {
    var it = gs.iter(c.EventMenuInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        switch (if (event.data.command) |command| command else continue) {
            .Escape,
            .No => {
                popMenu(mc);
                p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
            },
            .Yes => {
                postScores(gs, mc);
                abortGame(gs, mc);
                p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
            },
            else => {},
        }
    }
}

fn getGameCommand(cursor_pos: menus.KeyBindingsMenu.Option) ?input.GameCommand {
    return switch (cursor_pos) {
        .Up => input.GameCommand.Up,
        .Down => input.GameCommand.Down,
        .Left => input.GameCommand.Left,
        .Right => input.GameCommand.Right,
        .Shoot => input.GameCommand.Shoot,
        .Close => null,
    };
}

fn handleMenuInput(gs: *GameSession, mc: *c.MainController, comptime T: type, menu_state: *T) void {
    var it = gs.iter(c.EventMenuInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        if (T == menus.KeyBindingsMenu and menu_state.rebinding) {
            _ = p.EventSystemCommand.spawn(gs, c.EventSystemCommand {
                .BindGameCommand = c.BindGameCommand {
                    .command = getGameCommand(menu_state.cursor_pos) orelse continue,
                    .key = event.data.key,
                },
            }) catch undefined;
            menu_state.rebinding = false;
            continue;
        }
        switch (if (event.data.command) |command| command else continue) {
            .Up => if (@typeInfo(T.Option).Enum.fields.len > 1) {
                const index = @enumToInt(menu_state.cursor_pos);
                const last = @intCast(@typeOf(index), @typeInfo(T.Option).Enum.fields.len - 1);
                menu_state.cursor_pos = @intToEnum(T.Option, if (index > 0) index - 1 else last);

                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => if (@typeInfo(T.Option).Enum.fields.len > 1) {
                const index = @enumToInt(menu_state.cursor_pos);
                const last = @intCast(@typeOf(index), @typeInfo(T.Option).Enum.fields.len - 1);
                menu_state.cursor_pos = @intToEnum(T.Option, if (index < last) index + 1 else 0);

                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Left => {
                if (T == menus.OptionsMenu) {
                    if (menu_state.cursor_pos == .Volume and mc.volume > 0) {
                        _ = p.EventSystemCommand.spawn(gs, c.EventSystemCommand {
                            .SetVolume = if (mc.volume > 10) mc.volume - 10 else 0,
                        }) catch undefined;
                    }
                }
                p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
            },
            .Right => {
                if (T == menus.OptionsMenu) {
                    if (menu_state.cursor_pos == .Volume and mc.volume < 100) {
                        _ = p.EventSystemCommand.spawn(gs, c.EventSystemCommand {
                            .SetVolume = if (mc.volume < 90) mc.volume + 10 else 100,
                        }) catch undefined;
                    }
                }
                p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
            },
            .Escape => {
                if (T != menus.MainMenu) { // you can't back off of the main menu
                    popMenu(mc);
                    p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                }
            },
            .Enter => {
                switch (T) {
                    menus.MainMenu => mainMenuAction(gs, mc, menu_state),
                    menus.InGameMenu => inGameMenuAction(gs, mc, menu_state),
                    menus.OptionsMenu => optionsMenuAction(gs, mc, menu_state),
                    menus.KeyBindingsMenu => keyBindingsMenuAction(gs, mc, menu_state),
                    menus.HighScoresMenu => highScoresMenuAction(gs, mc, menu_state),
                    else => {},
                }
                p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
            },
            else => {},
        }
    }
}

fn mainMenuAction(gs: *GameSession, mc: *c.MainController, menu_state: *menus.MainMenu) void {
    switch (menu_state.cursor_pos) {
        .NewGame => {
            popMenu(mc);
            startGame(gs, mc);
        },
        .Options => {
            pushMenu(mc, menus.Menu { .OptionsMenu = menus.OptionsMenu { .cursor_pos = .Volume } });
        },
        .HighScores => {
            pushMenu(mc, .HighScoresMenu);
        },
        .Quit => {
            _ = p.EventSystemCommand.spawn(gs, .Quit) catch undefined;
        },
    }
}

fn inGameMenuAction(gs: *GameSession, mc: *c.MainController, menu_state: *menus.InGameMenu) void {
    switch (menu_state.cursor_pos) {
        .Continue => {
            popMenu(mc);
        },
        .Options => {
            pushMenu(mc, menus.Menu { .OptionsMenu = menus.OptionsMenu { .cursor_pos = .Volume } });
        },
        .Leave => {
            pushMenu(mc, menus.Menu.ReallyEndGameMenu);
        },
    }
}

fn optionsMenuAction(gs: *GameSession, mc: *c.MainController, menu_state: *menus.OptionsMenu) void {
    switch (menu_state.cursor_pos) {
        .Volume => {},
        .Fullscreen => {
            _ = p.EventSystemCommand.spawn(gs, .ToggleFullscreen) catch undefined;
        },
        .KeyBindings => {
            pushMenu(mc, menus.Menu { .KeyBindingsMenu = menus.KeyBindingsMenu { .cursor_pos = .Up, .rebinding = false } });
        },
        .Back => {
            popMenu(mc);
        },
    }
}

fn highScoresMenuAction(gs: *GameSession, mc: *c.MainController, menu_state: *menus.HighScoresMenu) void {
    switch (menu_state.cursor_pos) {
        .Close => {
            popMenu(mc);
        },
    }
}

fn keyBindingsMenuAction(gs: *GameSession, mc: *c.MainController, menu_state: *menus.KeyBindingsMenu) void {
    switch (menu_state.cursor_pos) {
        .Up,
        .Down,
        .Left,
        .Right,
        .Shoot => {
            _ = p.EventSystemCommand.spawn(gs, c.EventSystemCommand {
                .BindGameCommand = c.BindGameCommand {
                    .command = getGameCommand(menu_state.cursor_pos).?,
                    .key = null,
                },
            }) catch undefined;
            menu_state.rebinding = true;
            mc.menu_anim_time = 0;
        },
        .Close => {
            popMenu(mc);
        },
    }
}

fn postScores(gs: *GameSession, mc: *c.MainController) void {
    // go through all the players and post their scores
    var it0 = gs.iter(c.PlayerController); while (it0.next()) |object| {
        _ = p.EventPostScore.spawn(gs, c.EventPostScore {
            .score = object.data.score,
        }) catch undefined;
    }
}

// i feel like this functions are too heavy to be done inline by this system.
// they should be created as events and handled by middleware?
fn startGame(gs: *GameSession, mc: *c.MainController) void {
    // remove all entities except the MainController, GameController,
    // PlayerController, and EventPostScore
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        switch (field.field_type.ComponentType) {
            c.MainController,
            c.GameController,
            c.PlayerController,
            c.EventPostScore => {},
            else => |ComponentType| {
                var it = gs.iter(ComponentType); while (it.next()) |object| {
                    gs.markEntityForRemoval(object.entity_id);
                }
            },
        }
    }

    mc.game_running_state = c.MainController.GameRunningState {
        .render_move_boxes = false,
    };

    // reuse these if present
    if (gs.findFirst(c.GameController)) |gc| {
        gc.* = p.GameController.defaults;
    } else {
        _ = p.GameController.spawn(gs) catch undefined;
    }

    // FIXME - this doesn't properly handle the case of multiple
    // PlayerControllers existing, although that doesn't currently happen
    if (gs.findFirst(c.PlayerController)) |pc| {
        pc.* = p.PlayerController.defaults;
    } else {
        _ = p.PlayerController.spawn(gs) catch undefined;
    }
}

fn abortGame(gs: *GameSession, mc: *c.MainController) void {
    mc.game_running_state = null;
    mc.menu_stack_array[0] = menus.Menu { .MainMenu = menus.MainMenu { .cursor_pos = .NewGame } };
    mc.menu_stack_len = 1;

    // remove all entities except the MainController and EventPostScore
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        switch (field.field_type.ComponentType) {
            c.MainController,
            c.EventPostScore => {},
            else => |ComponentType| {
                var it = gs.iter(ComponentType); while (it.next()) |object| {
                    gs.markEntityForRemoval(object.entity_id);
                }
            },
        }
    }
}
