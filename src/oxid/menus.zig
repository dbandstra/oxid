const c = @import("components.zig");
const input = @import("input.zig");

pub const MenuOption = struct {
    label: []const u8,
    value: ?fn(mc: *const c.MainController)bool,
};

pub const MainMenu = struct {
    pub const title = "OXID";

    pub const Option = enum {
        NewGame,
        Options,
        HighScores,
        Quit,
    };

    cursor_pos: Option,

    pub fn getOption(cursor_pos: Option) MenuOption {
        return switch (cursor_pos) {
            .NewGame => MenuOption { .label = "New game", .value = null },
            .Options => MenuOption { .label = "Options", .value = null },
            .HighScores => MenuOption { .label = "High scores", .value = null },
            .Quit => MenuOption { .label = "Quit", .value = null },
        };
    }
};

pub const InGameMenu = struct {
    pub const title = "GAME PAUSED";

    pub const Option = enum {
        Continue,
        Options,
        Leave,
    };

    cursor_pos: Option,

    pub fn getOption(cursor_pos: Option) MenuOption {
        return switch (cursor_pos) {
            .Continue => MenuOption { .label = "Continue game", .value = null },
            .Options => MenuOption { .label = "Options", .value = null },
            .Leave => MenuOption { .label = "End game", .value = null },
        };
    }
};

pub const OptionsMenu = struct {
    pub const title = "OPTIONS";

    pub const Option = enum {
        Mute,
        Fullscreen,
        KeyBindings,
        Back,
    };

    cursor_pos: Option,

    pub fn getOption(cursor_pos: Option) MenuOption {
        return switch (cursor_pos) {
            .Mute => MenuOption { .label = "Mute sound", .value = getMuted },
            .Fullscreen => MenuOption { .label = "Fullscreen", .value = getFullscreen },
            .KeyBindings => MenuOption { .label = "Key bindings", .value = null },
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

pub const KeyBindingsMenu = struct {
    pub const title = "KEY BINDINGS";

    pub const Option = enum {
        Up,
        Down,
        Left,
        Right,
        Shoot,
        Close,
    };

    cursor_pos: Option,
    rebinding: bool,

    pub fn getOption(cursor_pos: Option) MenuOption {
        return switch (cursor_pos) {
            .Up    => MenuOption { .label = "Up:    ", .value = null },
            .Down  => MenuOption { .label = "Down:  ", .value = null },
            .Left  => MenuOption { .label = "Left:  ", .value = null },
            .Right => MenuOption { .label = "Right: ", .value = null },
            .Shoot => MenuOption { .label = "Shoot: ", .value = null },
            .Close => MenuOption { .label = "Close", .value = null },
        };
    }

    pub fn getGameCommand(cursor_pos: Option) ?input.GameCommand {
        return switch (cursor_pos) {
            .Up => input.GameCommand.Up,
            .Down => input.GameCommand.Down,
            .Left => input.GameCommand.Left,
            .Right => input.GameCommand.Right,
            .Shoot => input.GameCommand.Shoot,
            .Close => null,
        };
    }
};

pub const HighScoresMenu = struct {
    pub const title = "HIGH SCORES";

    pub const Option = enum {
        Close,
    };

    cursor_pos: Option,

    pub fn getOption(cursor_pos: Option) MenuOption {
        return switch (cursor_pos) {
            .Close => MenuOption { .label = "Close", .value = null },
        };
    }
};
