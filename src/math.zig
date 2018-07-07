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

  pub fn add(a: Vec2, b: Vec2) Vec2 {
    return Vec2{
      .x = a.x + b.x,
      .y = a.y + b.y,
    };
  }

  pub fn scale(a: Vec2, f: i32) Vec2 {
    return Vec2{
      .x = a.x * f,
      .y = a.y * f,
    };
  }

  pub fn equals(a: Vec2, b: Vec2) bool {
    return a.x == b.x and a.y == b.y;
  }
};

pub const BoundingBox = struct {
  mins: Vec2,
  maxs: Vec2,

  pub fn move(bbox: BoundingBox, vec: Vec2) BoundingBox {
    return BoundingBox{
      .mins = Vec2.add(bbox.mins, vec),
      .maxs = Vec2.add(bbox.maxs, vec),
    };
  }
};

pub fn get_dir_vec(direction: Direction) Vec2 {
  return switch (direction) {
    Direction.Up => Vec2.init(0, -1),
    Direction.Down => Vec2.init(0, 1),
    Direction.Left => Vec2.init(-1, 0),
    Direction.Right => Vec2.init(1, 0),
  };
}

pub fn reverse_direction(direction: Direction) Direction {
  return switch (direction) {
    Direction.Up => Direction.Down,
    Direction.Down => Direction.Up,
    Direction.Left => Direction.Right,
    Direction.Right => Direction.Left,
  };
}

pub fn rotate_cw(direction: Direction) Direction {
  return switch (direction) {
    Direction.Up => Direction.Right,
    Direction.Down => Direction.Left,
    Direction.Left => Direction.Up,
    Direction.Right => Direction.Down,
  };
}

pub fn rotate_ccw(direction: Direction) Direction {
  return switch (direction) {
    Direction.Up => Direction.Left,
    Direction.Down => Direction.Right,
    Direction.Left => Direction.Down,
    Direction.Right => Direction.Up,
  };
}
