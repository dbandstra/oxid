const draw = @import("opengl/draw.zig");
const texture = @import("opengl/texture.zig");
const audio = @import("audio.zig");
const platform = @import("platform.zig");

pub const InitParams = platform.InitParams;
pub const State = platform.State;
pub const Texture = texture.Texture;

pub const init = platform.init;
pub const deinit = platform.deinit;
pub const pollEvent = platform.pollEvent;
pub const preDraw = platform.preDraw;
pub const postDraw = platform.postDraw;

pub const cycleGlitchMode = draw.cycleGlitchMode;
pub const drawBegin = draw.begin;
pub const drawEnd = draw.end;
pub const drawTile = draw.tile;
pub const drawUntexturedRect = draw.untexturedRect;

pub const uploadTexture = texture.uploadTexture;

pub const loadSound = audio.loadSound;
pub const playSound = audio.playSound;
pub const setMute = audio.setMute;
