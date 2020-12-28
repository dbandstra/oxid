// pdraw implementation backed by SDL2's SDL_render API.

usingnamespace @import("../platform/sdl.zig");
const draw = @import("../common/draw.zig");

pub const Texture = struct {
    texture: *SDL_Texture,
    w: u31,
    h: u31,
};

pub const State = struct {
    renderer: *SDL_Renderer,
};

pub fn init(ds: *State, renderer: *SDL_Renderer) void {
    ds.renderer = renderer;
}

pub fn createTexture(ds: *State, w: u31, h: u31, pixels: []const u8) !Texture {
    const surface = SDL_CreateRGBSurfaceFrom(
        @intToPtr(*c_void, @ptrToInt(pixels.ptr)), // remove const (FIXME?)
        w,
        h,
        32, // bit depth
        w * 4, // pitch
        if (SDL_BYTEORDER == SDL_BIG_ENDIAN) 0xFF000000 else 0x000000FF, // red mask
        if (SDL_BYTEORDER == SDL_BIG_ENDIAN) 0x00FF0000 else 0x0000FF00, // green mask
        if (SDL_BYTEORDER == SDL_BIG_ENDIAN) 0x0000FF00 else 0x00FF0000, // blue mask
        if (SDL_BYTEORDER == SDL_BIG_ENDIAN) 0x000000FF else 0xFF000000, // alpha mask
    );
    defer SDL_FreeSurface(surface);
    const texture = SDL_CreateTextureFromSurface(ds.renderer, surface) orelse {
        return error.FailedToCreateTexture;
    };
    return Texture{ .texture = texture, .w = w, .h = h };
}

pub fn destroyTexture(texture: Texture) void {
    SDL_DestroyTexture(texture.texture);
}

pub fn setColor(ds: *State, color: draw.Color) void {
    _ = SDL_SetRenderDrawColor(ds.renderer, color.g, color.g, color.b, 0xff);
}

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
    _ = SDL_RenderCopyEx(
        ds.renderer,
        tileset.texture.texture,
        &SDL_Rect{
            .x = @intCast(c_int, dtile.tx) * @intCast(c_int, tileset.texture.w / tileset.xtiles),
            .y = @intCast(c_int, dtile.ty) * @intCast(c_int, tileset.texture.h / tileset.ytiles),
            .w = w,
            .h = h,
        },
        &SDL_Rect{ .x = x, .y = y, .w = w, .h = h },
        switch (transform) {
            .identity, .flip_horz, .flip_vert => 0,
            .rotate_cw => 90,
            .rotate_ccw => -90,
        },
        null,
        switch (transform) {
            .identity, .rotate_cw, .rotate_ccw => @intToEnum(SDL_RendererFlip, SDL_FLIP_NONE),
            .flip_horz => @intToEnum(SDL_RendererFlip, SDL_FLIP_HORIZONTAL),
            .flip_vert => @intToEnum(SDL_RendererFlip, SDL_FLIP_VERTICAL),
        },
    );
}

pub fn fill(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    _ = SDL_RenderFillRect(ds.renderer, &SDL_Rect{ .x = x, .y = y, .w = w, .h = h });
}

pub fn rect(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    _ = SDL_RenderDrawRect(ds.renderer, &SDL_Rect{ .x = x, .y = y, .w = w, .h = h });
}

pub fn flush(ds: *State) void {}
