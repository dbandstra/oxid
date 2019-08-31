const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("warn.zig").warn;
const draw = @import("common/draw.zig");
const Font = @import("common/font.zig").Font;
const loadFont = @import("common/font.zig").loadFont;
const loadTileset = @import("oxid/graphics.zig").loadTileset;
const Key = @import("common/key.zig").Key;
const config = @import("oxid/config.zig");
const GameSession = @import("oxid/game.zig").GameSession;
const input = @import("oxid/input.zig");
const levels = @import("oxid/levels.zig");
const p = @import("oxid/prototypes.zig");
const c = @import("oxid/components.zig");

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

// returns true if the key was bound to something
pub fn spawnInputEvent(gs: *GameSession, cfg: *const config.Config, key: Key, down: bool) bool {
    const game_command =
        for (cfg.game_key_bindings) |maybe_key, i| {
            if (if (maybe_key) |k| k == key else false) {
                break @intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i));
            }
        } else null;

    const menu_command =
        for (cfg.menu_key_bindings) |maybe_key, i| {
            if (if (maybe_key) |k| k == key else false) {
                break @intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i));
            }
        } else null;

    // dang.. an event even for unbound keys. oh well
    // if (game_command != null or menu_command != null) {
        _ = p.EventRawInput.spawn(gs, c.EventRawInput {
            .game_command = game_command,
            .menu_command = menu_command,
            .key = key,
            .down = down,
        }) catch undefined;
    // }

    return game_command != null or menu_command != null;
}
