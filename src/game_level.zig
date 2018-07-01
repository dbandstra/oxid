const assert = @import("std").debug.assert;

const SUBPIXELS = @import("math.zig").SUBPIXELS;
const Vec2 = @import("math.zig").Vec2;

// there are 16 pixels to a grid cell
pub const GRIDSIZE_PIXELS = 16;

pub const GRIDSIZE_SUBPIXELS = GRIDSIZE_PIXELS * SUBPIXELS;

pub const TerrainType = enum{
  Floor,
  Wall,
  Pit, // blocks creatures but not bullets
};

pub fn Level(comptime w: usize, comptime h: usize) type {
  return struct {
    const Self = this;

    w: usize,
    h: usize,
    data: [w*h]u8,

    pub fn init(data: [w*h]u8) Self {
      return Self{
        .w = w,
        .h = h,
        .data = data,
      };
    }

    pub fn get_terrain_type(value: u8) TerrainType {
      if (value == 0x82) {
        return TerrainType.Pit;
      } else if ((value & 0x80) != 0) {
        return TerrainType.Wall;
      } else {
        return TerrainType.Floor;
      }
    }

    // currently unused
    pub fn pos_in_wall(self: *const Self, pos: Vec2) bool {
      const x = pos.x;
      const y = pos.y;

      const gx0 = @divFloor(x, GRIDSIZE_SUBPIXELS);
      const gy0 = @divFloor(y, GRIDSIZE_SUBPIXELS);
      const offx = @mod(x, GRIDSIZE_SUBPIXELS) != 0;
      const offy = @mod(y, GRIDSIZE_SUBPIXELS) != 0;

      return
        self.grid_is_wall(gx0, gy0) or
        (offx and self.grid_is_wall(gx0 + 1, gy0)) or
        (offy and self.grid_is_wall(gx0, gy0 + 1)) or
        (offx and offy and self.grid_is_wall(gx0 + 1, gy0 + 1));
    }

    pub fn box_in_wall(self: *const Self, pos: Vec2, dims: Vec2, ignore_pits: bool) bool {
      assert(dims.x > 0 and dims.y > 0);

      const x0 = pos.x;
      const y0 = pos.y;
      const x1 = pos.x + dims.x;
      const y1 = pos.y + dims.y;

      const gx0 = @divFloor(x0, GRIDSIZE_SUBPIXELS);
      const gy0 = @divFloor(y0, GRIDSIZE_SUBPIXELS);
      const gx1 = @divFloor(x1 - 1, GRIDSIZE_SUBPIXELS);
      const gy1 = @divFloor(y1 - 1, GRIDSIZE_SUBPIXELS);

      var gy: i32 = gy0;
      while (gy <= gy1) : (gy += 1) {
        var gx: i32 = gx0;
        while (gx <= gx1) : (gx += 1) {
          if (self.get_gridvalue(Vec2.init(gx, gy))) |value| {
            const tt = get_terrain_type(value);
            if (tt == TerrainType.Wall or (!ignore_pits and tt == TerrainType.Pit)) {
              return true;
            }
          }
        }
      }

      return false;
    }

    pub fn get_gridvalue(self: *const Self, pos: Vec2) ?u8 {
      if (pos.x >= 0 and pos.y >= 0) {
        const x = @intCast(usize, pos.x);
        const y = @intCast(usize, pos.y);

        if (x < self.w and y < self.h) {
          return self.data[y * self.w + x];
        }
      }

      return null;
    }

    pub fn get_grid_terrain_type(self: *const Self, pos: Vec2) TerrainType {
      if (self.get_gridvalue(pos)) |value| {
        return get_terrain_type(value);
      } else {
        return TerrainType.Wall;
      }
    }
  };
}

pub const LEVEL = Level(20, 14).init(blk: {
  const _ = 0x00;
  const O = 0x80;
  const U = 0x81;
  const x = 0x82; // pit

  break :blk []const u8{
    O,U,U,U,U,U,U,U,U,U,U,U,O,U,U,U,U,U,U,O,
    O,_,_,_,_,_,_,_,_,_,_,_,O,_,_,_,_,_,_,O,
    O,_,O,O,_,O,U,_,U,U,O,_,U,_,U,_,O,O,_,O,
    O,_,U,U,_,O,_,_,_,_,O,_,_,_,_,_,U,U,_,O,
    O,_,_,_,_,U,_,U,U,_,U,_,U,U,O,_,_,_,_,O,
    O,O,_,U,_,_,_,_,_,_,_,_,_,_,U,_,U,U,_,O,
    O,U,_,x,x,x,_,O,_,O,O,_,O,_,_,_,_,_,_,O,
    O,_,_,_,_,_,_,U,_,U,U,_,U,_,U,U,O,_,O,O,
    O,_,x,x,_,x,_,_,_,_,_,_,_,_,_,_,U,_,U,O,
    O,_,_,_,_,U,U,U,_,O,_,U,U,_,O,_,_,_,_,O,
    O,_,O,O,_,_,_,_,_,O,_,_,_,_,O,_,O,O,_,O,
    O,_,U,U,_,U,_,O,_,U,U,U,_,U,U,_,U,U,_,O,
    O,_,_,_,_,_,_,O,_,_,_,_,_,_,_,_,_,_,_,O,
    O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,
  };
});
