const c = @import("components.zig");

pub const MenuOption = struct {
    label: []const u8,
    value: ?fn(mc: *const c.MainController)bool,
};

pub const MainMenu = enum {
    NewGame,
    Options,
    HighScores,
    Quit,

    pub const title = "OXID";

    pub fn getOption(cursor_pos: @This()) MenuOption {
        return switch (cursor_pos) {
            .NewGame => MenuOption { .label = "New game", .value = null },
            .Options => MenuOption { .label = "Options", .value = null },
            .HighScores => MenuOption { .label = "High scores", .value = null },
            .Quit => MenuOption { .label = "Quit", .value = null },
        };
    }
};

pub const InGameMenu = enum {
    Continue,
    Options,
    Leave,

    pub const title = "GAME PAUSED";

    pub fn getOption(cursor_pos: @This()) MenuOption {
        return switch (cursor_pos) {
            .Continue => MenuOption { .label = "Continue game", .value = null },
            .Options => MenuOption { .label = "Options", .value = null },
            .Leave => MenuOption { .label = "End game", .value = null },
        };
    }
};

pub const OptionsMenu = enum {
    Mute,
    Fullscreen,
    Back,

    pub const title = "OPTIONS";

    pub fn getOption(cursor_pos: @This()) MenuOption {
        return switch (cursor_pos) {
            .Mute => MenuOption { .label = "Mute sound", .value = getMuted },
            .Fullscreen => MenuOption { .label = "Fullscreen", .value = getFullscreen },
            .Back => MenuOption { .label = "Back", .value = null },
        };
    }

    fn getMuted(mc: *const c.MainController) bool {
        return mc.is_muted;
    }

    fn getFullscreen(mc: *const c.MainController) bool {
        return mc.is_fullscreen;
    }
};
