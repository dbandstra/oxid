const draw = @import("platform/opengl/draw.zig");
const texture = @import("platform/opengl/texture.zig");

pub const Colour = draw.Colour;
pub const Texture = texture.Texture;

pub const DrawState = draw.DrawState;
pub const cycleGlitchMode = draw.cycleGlitchMode;
pub const drawBegin = draw.begin;
pub const drawEnd = draw.end;
pub const drawTile = draw.tile;
pub const drawUntexturedRect = draw.untexturedRect;

pub const uploadTexture = texture.uploadTexture;
