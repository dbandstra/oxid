const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("warn.zig").warn;
const draw = @import("common/draw.zig");
const Font = @import("common/font.zig").Font;
const loadFont = @import("common/font.zig").loadFont;
const loadTileset = @import("oxid/graphics.zig").loadTileset;
const InputSource = @import("common/key.zig").InputSource;
const areInputSourcesEqual = @import("common/key.zig").areInputSourcesEqual;
const config = @import("oxid/config.zig");
const GameSession = @import("oxid/game.zig").GameSession;
const input = @import("oxid/input.zig");
const levels = @import("oxid/levels.zig");
const p = @import("oxid/prototypes.zig");
const c = @import("oxid/components.zig");
const menus = @import("oxid/menus.zig");
const MenuInputParams = @import("oxid/menu_input.zig").MenuInputParams;
const menuInput = @import("oxid/menu_input.zig").menuInput;
const audio = @import("oxid/audio.zig");

// this many pixels is added to the top of the window for font stuff
pub const hud_height = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const virtual_window_width = levels.width * levels.pixels_per_tile; // 320
pub const virtual_window_height = levels.height * levels.pixels_per_tile + hud_height; // 240

pub const GameStatic = struct {
    tileset: draw.Tileset,
    palette: [48]u8,
    font: Font,
};

pub fn loadStatic(static: *GameStatic, hunk_side: *HunkSide) bool {
    loadFont(hunk_side, &static.font) catch |err| {
        warn("Failed to load font: {}\n", err);
        return false;
    };

    loadTileset(hunk_side, &static.tileset, static.palette[0..]) catch |err| {
        warn("Failed to load tileset: {}\n", err);
        return false;
    };

    return true;
}

pub fn inputEvent(gs: *GameSession, cfg: config.Config, source: InputSource, down: bool, menu_stack: *menus.MenuStack, menu_context: menus.MenuContext) ?menus.Effect {
    if (down) {
        const maybe_menu_command =
            for (cfg.menu_bindings) |maybe_source, i| {
                if (if (maybe_source) |s| areInputSourcesEqual(s, source) else false) {
                    break @intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i));
                }
            } else null;

        // if menu is open, input goes to it
        if (menu_stack.len > 0) {
            // note that the menu receives input even if the menu_command is null
            // (used by the key rebinding menu)
            const result = menuInput(menu_stack, MenuInputParams {
                .source = source,
                .maybe_command = maybe_menu_command,
                .menu_context = menu_context,
            }) orelse return null;

            if (result.sound) |sound| {
                switch (sound) {
                    .Blip => {
                        p.playSynth(gs, "MenuBlip", audio.MenuBlipVoice.NoteParams {
                            .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                        });
                    },
                    .Ding => {
                        p.playSynth(gs, "MenuDing", audio.MenuDingVoice.NoteParams { .unused = undefined });
                    },
                    .Backoff => {
                        p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });
                    },
                }
            }

            return result.effect;
        }

        // menu is not open, but should we open it?
        if (maybe_menu_command) |menu_command| {
            if (menu_command == .Escape) {
                // assuming that if the menu isn't open, we must be in game
                p.playSynth(gs, "MenuBackoff", audio.MenuBackoffVoice.NoteParams { .unused = undefined });

                return menus.Effect { .Push = menus.Menu { .InGameMenu = menus.InGameMenu.init() } };
            }
        }
    }

    // game command?
    for (cfg.game_bindings) |maybe_source, i| {
        if (if (maybe_source) |s| areInputSourcesEqual(s, source) else false) {
            _ = p.EventGameInput.spawn(gs, c.EventGameInput {
                .command = @intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i)),
                .down = down,
            }) catch undefined;

            // returning non-null signifies that the input event was handled
            return menus.Effect { .NoOp = {} };
        }
    }

    return null;
}

// i feel like this functions are too heavy to be done inline by this system.
// they should be created as events and handled by middleware?
pub fn startGame(gs: *GameSession) void {
    const mc = &gs.findFirstObject(c.MainController).?.data;

    // remove all entities except the MainController, GameController,
    // PlayerController, and EventPostScore
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        switch (field.field_type.ComponentType) {
            c.MainController,
            c.GameController,
            c.PlayerController => {},
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

pub fn abortGame(gs: *GameSession) void {
    const mc = &gs.findFirstObject(c.MainController).?.data;

    mc.game_running_state = null;

    // remove all entities except the MainController and EventPostScore
    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
        switch (field.field_type.ComponentType) {
            c.MainController => {},
            else => |ComponentType| {
                var it = gs.iter(ComponentType); while (it.next()) |object| {
                    gs.markEntityForRemoval(object.entity_id);
                }
            },
        }
    }
}
