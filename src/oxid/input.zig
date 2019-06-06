const Key = @import("../common/event.zig").Key;

pub const Command = enum{
    Left,
    Right,
    Up,
    Down,
    Shoot,
    ToggleGodMode,
    ToggleDrawBoxes,
    KillAllMonsters,
    Escape,
    Yes,
    No,
};

// TODO - multiple input profiles
// TODO - user-configurable
pub fn getCommandForKey(key: Key) ?Command {
    return switch (key) {
        Key.Up => Command.Up,
        Key.Down => Command.Down,
        Key.Left => Command.Left,
        Key.Right => Command.Right,
        Key.Space => Command.Shoot,
        Key.Return => Command.KillAllMonsters,
        Key.F2 => Command.ToggleDrawBoxes,
        Key.F3 => Command.ToggleGodMode,
        Key.Escape => Command.Escape,
        Key.Y => Command.Yes,
        Key.N => Command.No,
        else => null,
    };
}
