usingnamespace @import("../platform/sdl.zig");
const Hunk = @import("zig-hunk").Hunk;
const draw = @import("../common/draw.zig");

pub const Texture = struct {
    texture: *SDL_Texture,
    w: u31,
    h: u31,
};

pub const State = struct {
    virtual_window_width: u32,
    virtual_window_height: u32,
    renderer: *SDL_Renderer,
};

pub fn init(ds: *State, params: struct {
    hunk: *Hunk,
    virtual_window_width: u32,
    virtual_window_height: u32,
    renderer: *SDL_Renderer,
}) !void {
    ds.virtual_window_width = params.virtual_window_width;
    ds.virtual_window_height = params.virtual_window_height;
    ds.renderer = params.renderer;
}

pub fn deinit(ds: *State) void {}

pub fn uploadTexture(ds: *State, w: u31, h: u31, pixels: []const u8) !Texture {
    const depth = 32;
    const pitch = w * 4;
    const rmask = 0x000000FF;
    const gmask = 0x0000FF00;
    const bmask = 0x00FF0000;
    const amask = 0xFF000000;
    const surface = SDL_CreateRGBSurfaceFrom(
        @intToPtr(*c_void, @ptrToInt(pixels.ptr)), // remove const (FIXME?)
        w,
        h,
        depth,
        pitch,
        rmask,
        gmask,
        bmask,
        amask,
    );
    defer SDL_FreeSurface(surface);
    const texture = SDL_CreateTextureFromSurface(ds.renderer, surface) orelse {
        return error.FailedToUploadTexture;
    };
    return Texture{
        .texture = texture,
        .w = w,
        .h = h,
    };
}

// TODO function to delete texture

pub fn prepare(ds: *State) void {}

pub fn begin(ds: *State, texture: Texture, maybe_color: ?draw.Color, alpha: f32, outline: bool) void {}

pub fn end(ds: *State) void {}

pub fn tile(
    ds: *State,
    tileset: draw.Tileset,
    dtile: draw.Tile,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    transform: draw.Transform,
) void {
    const tile_w = @intCast(c_int, tileset.texture.w / tileset.xtiles);
    const tile_h = @intCast(c_int, tileset.texture.h / tileset.ytiles);
    const src_rect: SDL_Rect = .{
        .x = @intCast(c_int, dtile.tx) * tile_w,
        .y = @intCast(c_int, dtile.ty) * tile_h,
        .w = w,
        .h = h,
    };
    const dest_rect: SDL_Rect = .{ .x = x, .y = y, .w = w, .h = h };
    var angle: f64 = 0;
    var flip = @intToEnum(SDL_RendererFlip, SDL_FLIP_NONE);
    switch (transform) {
        .identity => {},
        .flip_horz => flip = @intToEnum(SDL_RendererFlip, SDL_FLIP_HORIZONTAL),
        .flip_vert => flip = @intToEnum(SDL_RendererFlip, SDL_FLIP_VERTICAL),
        .rotate_cw => angle = 90,
        .rotate_ccw => angle = -90,
    }
    _ = SDL_RenderCopyEx(ds.renderer, tileset.texture.texture, &src_rect, &dest_rect, angle, null, flip);
}

pub fn fill(ds: *State, color: draw.Color, x: i32, y: i32, w: i32, h: i32) void {
    const rect: SDL_Rect = .{ .x = x, .y = y, .w = w, .h = h };
    _ = SDL_SetRenderDrawColor(ds.renderer, color.g, color.g, color.b, 0xff);
    _ = SDL_RenderFillRect(ds.renderer, &rect);
    _ = SDL_SetRenderDrawColor(ds.renderer, 0xff, 0xff, 0xff, 0xff);
}
