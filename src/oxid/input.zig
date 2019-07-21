const Key = @import("../common/key.zig").Key;

pub const Command = enum {
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
        .Up => Command.Up,
        .Down => Command.Down,
        .Left => Command.Left,
        .Right => Command.Right,
        .Space => Command.Shoot,
        .Return => Command.KillAllMonsters,
        .F2 => Command.ToggleDrawBoxes,
        .F3 => Command.ToggleGodMode,
        .Escape => Command.Escape,
        .Y => Command.Yes,
        .N => Command.No,
        else => null,
    };
}
