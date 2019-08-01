pub const MenuOption = struct {
    label: []const u8,
};

pub const MainMenu = enum {
    NewGame,
    Options,
    Quit,

    pub const title = "OXID";

    pub fn getOption(cursor_pos: @This()) MenuOption {
        return switch (cursor_pos) {
            .NewGame => MenuOption { .label = "New game" },
            .Options => MenuOption { .label = "Options" },
            .Quit => MenuOption { .label = "Quit" },
        };
    }
};

pub const InGameMenu = enum {
    Continue,
    Options,
    Leave,

    pub const title = "OXID";

    pub fn getOption(cursor_pos: @This()) MenuOption {
        return switch (cursor_pos) {
            .Continue => MenuOption { .label = "Continue game" },
            .Options => MenuOption { .label = "Options" },
            .Leave => MenuOption { .label = "End game" },
        };
    }
};

pub const OptionsMenu = enum {
    Mute,
    Fullscreen,
    Back,

    pub const title = "Options";

    pub fn getOption(cursor_pos: @This()) MenuOption {
        return switch (cursor_pos) {
            .Mute => MenuOption { .label = "Toggle mute" },
            .Fullscreen => MenuOption { .label = "Toggle fullscreen" },
            .Back => MenuOption { .label = "Back" },
        };
    }
};
