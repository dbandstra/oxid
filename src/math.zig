// there are 16 subpixels to a screen pixel
pub const SUBPIXELS = 16;

pub const Direction = enum {
  N,
  E,
  S,
  W,

  pub fn normal(direction: Direction) Vec2 {
    return switch (direction) {
      Direction.N => Vec2.init(0, -1),
      Direction.E => Vec2.init(1, 0),
      Direction.S => Vec2.init(0, 1),
      Direction.W => Vec2.init(-1, 0),
    };
  }

  pub fn invert(direction: Direction) Direction {
    return switch (direction) {
      Direction.N => Direction.S,
      Direction.E => Direction.W,
      Direction.S => Direction.N,
      Direction.W => Direction.E,
    };
  }

  pub fn rotate_cw(direction: Direction) Direction {
    return switch (direction) {
      Direction.N => Direction.E,
      Direction.E => Direction.S,
      Direction.S => Direction.W,
      Direction.W => Direction.N,
    };
  }

  pub fn rotate_ccw(direction: Direction) Direction {
    return switch (direction) {
      Direction.N => Direction.W,
      Direction.E => Direction.N,
      Direction.S => Direction.E,
      Direction.W => Direction.S,
    };
  }
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

  pub fn manhattan_distance(a: Vec2, b: Vec2) u32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const adx = if (dx > 0) @intCast(u32, dx) else @intCast(u32, -dx);
    const ady = if (dy > 0) @intCast(u32, dy) else @intCast(u32, -dy);
    return adx + ady;
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
