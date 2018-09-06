const Key = @import("../event.zig").Key;

pub const Command = enum {
  Left,
  Right,
  Up,
  Down,
  Shoot,
  ToggleGodMode,
  TogglePaused,
  ToggleDrawBoxes,
  FastForward,
  KillAllMonsters,
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
    Key.Tab => Command.TogglePaused,
    Key.Return => Command.KillAllMonsters,
    Key.Backquote => Command.FastForward,
    Key.F2 => Command.ToggleDrawBoxes,
    Key.F3 => Command.ToggleGodMode,
    else => null,
  };
}
