// pdraw implementation backed by SDL2's SDL_render API.

usingnamespace @import("../platform/sdl.zig");
const drawing = @import("../common/drawing.zig");

pub const Texture = struct {
    texture: *SDL_Texture,
    w: u31,
    h: u31,
};

pub const State = struct {
    renderer: *SDL_Renderer,
    color: drawing.Color,
};

pub fn init(ds: *State, renderer: *SDL_Renderer) void {
    ds.renderer = renderer;
    ds.color = .{ .r = 0xff, .g = 0xff, .b = 0xff };
}

pub fn createTexture(ds: *State, w: u31, h: u31, pixels: []const u8) !Texture {
    const surface = SDL_CreateRGBSurfaceFrom(
        // cast away const. i don't believe SDL modifies the pixels
        @intToPtr(*c_void, @ptrToInt(pixels.ptr)),
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

pub fn setColor(ds: *State, color: drawing.Color) void {
    ds.color = color;
    _ = SDL_SetRenderDrawColor(ds.renderer, color.g, color.g, color.b, 0xff);
}

pub fn fill(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    _ = SDL_RenderFillRect(ds.renderer, &SDL_Rect{ .x = x, .y = y, .w = w, .h = h });
}

pub fn rect(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    _ = SDL_RenderDrawRect(ds.renderer, &SDL_Rect{ .x = x, .y = y, .w = w, .h = h });
}

pub fn tile(
    ds: *State,
    tileset: drawing.Tileset,
    dtile: drawing.Tile,
    x: i32,
    y: i32,
    transform: drawing.Transform,
) void {
    if (dtile.tx >= tileset.num_cols or dtile.ty >= tileset.num_rows)
        return;

    _ = SDL_SetTextureColorMod(tileset.texture.texture, ds.color.r, ds.color.g, ds.color.b);
    _ = SDL_RenderCopyEx(
        ds.renderer,
        tileset.texture.texture,
        &SDL_Rect{
            .x = dtile.tx * tileset.tile_w,
            .y = dtile.ty * tileset.tile_h,
            .w = tileset.tile_w,
            .h = tileset.tile_h,
        },
        &SDL_Rect{ .x = x, .y = y, .w = tileset.tile_w, .h = tileset.tile_h },
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

pub fn flush(ds: *State) void {}
