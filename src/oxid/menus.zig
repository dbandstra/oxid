pub const Menu = union(enum) {
    MainMenu: MainMenu,
    InGameMenu: InGameMenu,
    ReallyEndGameMenu,
    OptionsMenu: OptionsMenu,
    KeyBindingsMenu: KeyBindingsMenu,
    HighScoresMenu: HighScoresMenu,
};

pub const MainMenu = struct {
    pub const Option = enum {
        NewGame,
        Options,
        HighScores,
        Quit,
    };

    cursor_pos: Option,
};

pub const InGameMenu = struct {
    pub const Option = enum {
        Continue,
        Options,
        Leave,
    };

    cursor_pos: Option,
};

pub const OptionsMenu = struct {
    pub const Option = enum {
        Volume,
        Fullscreen,
        KeyBindings,
        Back,
    };

    cursor_pos: Option,
};

pub const KeyBindingsMenu = struct {
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
};

pub const HighScoresMenu = struct {
    pub const Option = enum {
        Close,
    };

    cursor_pos: Option,
};
