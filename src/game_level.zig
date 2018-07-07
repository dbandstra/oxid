const assert = @import("std").debug.assert;
const Math = @import("math.zig");

// there are 16 pixels to a grid cell
pub const GRIDSIZE_PIXELS = 16;

pub const GRIDSIZE_SUBPIXELS = GRIDSIZE_PIXELS * Math.SUBPIXELS;

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
    pub fn pos_in_wall(self: *const Self, pos: Math.Vec2) bool {
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

    pub fn box_in_wall(self: *const Self, pos: Math.Vec2, bbox: Math.BoundingBox, ignore_pits: bool) bool {
      assert(bbox.mins.x < bbox.maxs.x and bbox.mins.y < bbox.maxs.y);

      const gx0 = @divFloor(pos.x + bbox.mins.x, GRIDSIZE_SUBPIXELS);
      const gy0 = @divFloor(pos.y + bbox.mins.y, GRIDSIZE_SUBPIXELS);
      const gx1 = @divFloor(pos.x + bbox.maxs.x, GRIDSIZE_SUBPIXELS);
      const gy1 = @divFloor(pos.y + bbox.maxs.y, GRIDSIZE_SUBPIXELS);

      var gy: i32 = gy0;
      while (gy <= gy1) : (gy += 1) {
        var gx: i32 = gx0;
        while (gx <= gx1) : (gx += 1) {
          if (self.get_gridvalue(Math.Vec2.init(gx, gy))) |value| {
            const tt = get_terrain_type(value);
            if (tt == TerrainType.Wall or (!ignore_pits and tt == TerrainType.Pit)) {
              return true;
            }
          }
        }
      }

      return false;
    }

    pub fn get_gridvalue(self: *const Self, pos: Math.Vec2) ?u8 {
      if (pos.x >= 0 and pos.y >= 0) {
        const x = @intCast(usize, pos.x);
        const y = @intCast(usize, pos.y);

        if (x < self.w and y < self.h) {
          return self.data[y * self.w + x];
        }
      }

      return null;
    }

    pub fn get_grid_terrain_type(self: *const Self, pos: Math.Vec2) TerrainType {
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
