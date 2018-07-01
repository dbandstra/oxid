// there are 16 subpixels to a screen pixel
pub const SUBPIXELS = 16;

pub const Direction = enum {
  Left,
  Right,
  Up,
  Down,
};

pub const Vec2 = struct {
  x: i32,
  y: i32,

  pub fn init(x: i32, y: i32) Vec2 {
    return Vec2{
      .x = x,
      .y = y,
    };
  }

  pub fn add(a: *const Vec2, b: *const Vec2) Vec2 {
    return Vec2{
      .x = a.x + b.x,
      .y = a.y + b.y,
    };
  }

  pub fn scale(a: *const Vec2, f: i32) Vec2 {
    return Vec2{
      .x = a.x * f,
      .y = a.y * f,
    };
  }
};

pub fn get_dir_vec(direction: Direction) Vec2 {
  return switch (direction) {
    Direction.Up => Vec2{ .x = 0, .y = -1 },
    Direction.Down => Vec2{ .x = 0, .y = 1 },
    Direction.Left => Vec2{ .x = -1, .y = 0 },
    Direction.Right => Vec2{ .x = 1, .y = 0 },
  };
}
