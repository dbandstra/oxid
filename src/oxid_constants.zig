const levels = @import("oxid/levels.zig");

// this many pixels is added to the top of the window for font stuff
pub const hud_height = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const virtual_window_width: u31 = levels.width * levels.pixels_per_tile; // 320
pub const virtual_window_height: u31 = levels.height * levels.pixels_per_tile + hud_height; // 240
