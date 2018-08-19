const c = @import("c.zig");
const Event = @import("../event.zig").Event;
const Key = @import("../event.zig").Key;

fn getKey(sym: c.SDL_Keycode) ?Key {
  return switch (sym) {
    c.SDLK_ESCAPE => Key.Escape,
    c.SDLK_BACKSPACE => Key.Backspace,
    c.SDLK_RETURN => Key.Return,
    c.SDLK_F2 => Key.F2,
    c.SDLK_F3 => Key.F3,
    c.SDLK_F4 => Key.F4,
    c.SDLK_UP => Key.Up,
    c.SDLK_DOWN => Key.Down,
    c.SDLK_LEFT => Key.Left,
    c.SDLK_RIGHT => Key.Right,
    c.SDLK_SPACE => Key.Space,
    c.SDLK_TAB => Key.Tab,
    c.SDLK_BACKQUOTE => Key.Backquote,
    else => null,
  };
}

pub fn translateEvent(sdl_event: c.SDL_Event) ?Event {
  switch (sdl_event.type) {
    c.SDL_KEYDOWN => {
      if (sdl_event.key.repeat == 0) {
        if (getKey(sdl_event.key.keysym.sym)) |key| {
          return Event{ .KeyDown = key};
        }
      }
    },
    c.SDL_KEYUP => {
      if (getKey(sdl_event.key.keysym.sym)) |key| {
        return Event{ .KeyUp = key };
      }
    },
    c.SDL_QUIT => {
      return Event{ .Quit = {} };
    },
    else => {},
  }

  return null;
}
