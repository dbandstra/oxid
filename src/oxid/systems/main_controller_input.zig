const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const audio = @import("../audio.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const menus = @import("../menus.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.mc.game_running_state) |*grs| {
        handleGameRunningInput(gs, self.mc, grs);
    }
    if (self.mc.menu_stack_len > 0) {
        switch (self.mc.menu_stack_array[self.mc.menu_stack_len - 1]) {
            .MainMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.MainMenu, menu_state); },
            .InGameMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.InGameMenu, menu_state); },
            .ReallyEndGameMenu => { handleReallyEndGamePromptInput(gs, self.mc); },
            .OptionsMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.OptionsMenu, menu_state); },
            .HighScoresMenu => |*menu_state| { handleMenuInput(gs, self.mc, menus.HighScoresMenu, menu_state); },
        }
    }
    return true;
}

fn handleGameRunningInput(gs: *GameSession, mc: *c.MainController, grs: *c.MainController.GameRunningState) void {
    var it = gs.iter(c.EventGameInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Escape => {
                if (event.data.down) {
                    p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                    if (if (gs.findFirst(c.GameController)) |gc| gc.game_over else true) {
                        pushMenu(mc, c.MainController.Menu { .MainMenu = .NewGame });
                    } else {
                        pushMenu(mc, c.MainController.Menu { .InGameMenu = .Continue });
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

fn handleReallyEndGamePromptInput(gs: *GameSession, mc: *c.MainController) void {
    var it = gs.iter(c.EventMenuInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        switch (event.data.command) {
            .Escape,
            .No => {
                popMenu(mc);
                p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
            },
            .Yes => {
                leaveGame(gs, mc);
                p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
            },
            else => {},
        }
    }
}

fn handleMenuInput(gs: *GameSession, mc: *c.MainController, comptime T: type, cursor_pos: *T) void {
    var it = gs.iter(c.EventMenuInput); while (it.next()) |event| {
        if (!event.data.down) {
            continue;
        }
        switch (event.data.command) {
            .Up => if (@typeInfo(T).Enum.fields.len > 1) {
                const index = @enumToInt(cursor_pos.*);
                const last = @intCast(@typeOf(index), @typeInfo(T).Enum.fields.len - 1);
                cursor_pos.* = @intToEnum(T, if (index > 0) index - 1 else last);

                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Down => if (@typeInfo(T).Enum.fields.len > 1) {
                const index = @enumToInt(cursor_pos.*);
                const last = @intCast(@typeOf(index), @typeInfo(T).Enum.fields.len - 1);
                cursor_pos.* = @intToEnum(T, if (index < last) index + 1 else 0);

                p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
            .Escape => {
                if (T != menus.MainMenu) { // you can't back off of the main menu
                    popMenu(mc);
                    p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                }
            },
            .Enter => {
                switch (T) {
                    menus.MainMenu => { mainMenuAction(gs, mc, cursor_pos.*); },
                    menus.InGameMenu => { inGameMenuAction(gs, mc, cursor_pos.*); },
                    menus.OptionsMenu => { optionsMenuAction(gs, mc, cursor_pos.*); },
                    menus.HighScoresMenu => { highScoresMenuAction(gs, mc, cursor_pos.*); },
                    else => {},
                }
                p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
            },
            else => {},
        }
    }
}

fn mainMenuAction(gs: *GameSession, mc: *c.MainController, cursor_pos: menus.MainMenu) void {
    switch (cursor_pos) {
        .NewGame => {
            popMenu(mc);
            startGame(gs, mc);
        },
        .Options => {
            pushMenu(mc, c.MainController.Menu { .OptionsMenu = .Mute });
        },
        .HighScores => {
            pushMenu(mc, .HighScoresMenu);
        },
        .Quit => {
            _ = p.EventSystemCommand.spawn(gs, .Quit) catch undefined;
        },
    }
}

fn inGameMenuAction(gs: *GameSession, mc: *c.MainController, cursor_pos: menus.InGameMenu) void {
    switch (cursor_pos) {
        .Continue => {
            popMenu(mc);
        },
        .Options => {
            pushMenu(mc, c.MainController.Menu { .OptionsMenu = .Mute });
        },
        .Leave => {
            pushMenu(mc, c.MainController.Menu.ReallyEndGameMenu);
        },
    }
}

fn optionsMenuAction(gs: *GameSession, mc: *c.MainController, cursor_pos: menus.OptionsMenu) void {
    switch (cursor_pos) {
        .Mute => {
            _ = p.EventSystemCommand.spawn(gs, .ToggleMute) catch undefined;
        },
        .Fullscreen => {
            _ = p.EventSystemCommand.spawn(gs, .ToggleFullscreen) catch undefined;
        },
        .Back => {
            popMenu(mc);
        },
    }
}

fn highScoresMenuAction(gs: *GameSession, mc: *c.MainController, cursor_pos: menus.HighScoresMenu) void {
    switch (cursor_pos) {
        .Close => {
            popMenu(mc);
        },
    }
}

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

    if (gs.findFirst(c.PlayerController)) |pc| {
        pc.* = p.PlayerController.defaults;
    } else {
        _ = p.PlayerController.spawn(gs) catch undefined;
    }
}

fn leaveGame(gs: *GameSession, mc: *c.MainController) void {
    // go through all the players and post their scores
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
