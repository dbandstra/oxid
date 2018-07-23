const GameSession = @import("game.zig").GameSession;

pub const InputEvent = enum {
  Left,
  Right,
  Up,
  Down,
  Shoot,
};

pub fn gameInput(gs: *GameSession, event: InputEvent, down: bool) void {
  switch (event) {
    InputEvent.Left => {
      gs.in_left = down;
    },
    InputEvent.Right => {
      gs.in_right = down;
    },
    InputEvent.Up => {
      gs.in_up = down;
    },
    InputEvent.Down => {
      gs.in_down = down;
    },
    InputEvent.Shoot => {
      gs.in_shoot = down;
    },
  }
}
