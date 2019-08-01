const Key = @import("../common/key.zig").Key;

pub const MenuCommand = enum {
    Up,
    Down,
    Escape,
    Enter,
    Yes,
    No,
};

pub const GameCommand = enum {
    Left,
    Right,
    Up,
    Down,
    Shoot,
    ToggleGodMode,
    ToggleDrawBoxes,
    KillAllMonsters,
    Escape,
};

pub fn getMenuCommandForKey(key: Key) ?MenuCommand {
    return switch (key) {
        .Up => MenuCommand.Up,
        .Down => MenuCommand.Down,
        .Return => MenuCommand.Enter,
        .Escape => MenuCommand.Escape,
        .Y => MenuCommand.Yes,
        .N => MenuCommand.No,
        else => null,
    };
}

pub fn getGameCommandForKey(key: Key) ?GameCommand {
    return switch (key) {
        .Up => GameCommand.Up,
        .Down => GameCommand.Down,
        .Left => GameCommand.Left,
        .Right => GameCommand.Right,
        .Space => GameCommand.Shoot,
        .Backspace => GameCommand.KillAllMonsters,
        .F2 => GameCommand.ToggleDrawBoxes,
        .F3 => GameCommand.ToggleGodMode,
        .Escape => GameCommand.Escape,
        else => null,
    };
}
