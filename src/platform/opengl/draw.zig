const builtin = @import("builtin");
usingnamespace if (builtin.arch == .wasm32)
    @import("zig-webgl")
else
    @import("gl").namespace;
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const warn = @import("../../warn.zig").warn;
const shaders = @import("shaders.zig");
const shader_textured = @import("shader_textured.zig");
const draw = @import("../../common/draw.zig");

const buffer_vertices = 4 * 512; // render up to 512 quads at once

pub const GLSLVersion = enum { v120, v130, webgl };

pub const Texture = struct {
    handle: GLuint,
};

const DrawBuffer = struct {
    active: bool,
    outline: bool,
    vertex2f: [2 * buffer_vertices]GLfloat,
    texcoord2f: [2 * buffer_vertices]GLfloat,
    num_vertices: usize,
};

pub const DrawState = struct {
    // dimensions of the game viewport, which will be scaled up to fit the system window
    virtual_window_width: u32,
    virtual_window_height: u32,
    shader_textured: shader_textured.Shader,
    dyn_vertex_buffer: GLuint,
    dyn_texcoord_buffer: GLuint,
    draw_buffer: DrawBuffer,
    projection: [16]f32,
    blank_tex: Texture,
    blank_tileset: draw.Tileset,
    // some stuff
    clear_screen: bool,
};

pub fn updateVBO(vbo: GLuint, maybe_data2f: ?[]f32) void {
    const size = buffer_vertices * 2 * @sizeOf(GLfloat);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size, null, GL_STREAM_DRAW);
    if (maybe_data2f) |data2f| {
        std.debug.assert(data2f.len == 2 * buffer_vertices);
        glBufferData(GL_ARRAY_BUFFER, size, &data2f[0], GL_STREAM_DRAW);
    }
}

pub fn init(ds: *DrawState, params: struct {
    hunk: *Hunk,
    virtual_window_width: u32,
    virtual_window_height: u32,
    glsl_version: GLSLVersion,
}) shaders.InitError!void {
    ds.shader_textured = try shader_textured.create(&params.hunk.low(), params.glsl_version);
    errdefer shaders.destroy(ds.shader_textured.program);

    glGenBuffers(1, &ds.dyn_vertex_buffer);
    errdefer glDeleteBuffers(1, &ds.dyn_vertex_buffer);
    updateVBO(ds.dyn_vertex_buffer, null);

    glGenBuffers(1, &ds.dyn_texcoord_buffer);
    errdefer glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    updateVBO(ds.dyn_texcoord_buffer, null);

    glDisable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glFrontFace(GL_CCW);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);

    ds.virtual_window_width = params.virtual_window_width;
    ds.virtual_window_height = params.virtual_window_height;
    ds.draw_buffer.active = false;
    ds.draw_buffer.num_vertices = 0;

    const blank_tex_pixels = &[_]u8{ 255, 255, 255, 255 };
    ds.blank_tex = uploadTexture(1, 1, blank_tex_pixels);
    ds.blank_tileset = .{
        .texture = ds.blank_tex,
        .xtiles = 1,
        .ytiles = 1,
    };

    ds.clear_screen = true;
}

pub fn deinit(ds: *DrawState) void {
    glDeleteBuffers(1, &ds.dyn_vertex_buffer);
    glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    shaders.destroy(ds.shader_textured.program);
}

pub fn uploadTexture(width: usize, height: usize, pixels: []const u8) Texture {
    var texid: GLuint = undefined;
    glGenTextures(1, &texid);
    glBindTexture(GL_TEXTURE_2D, texid);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glTexImage2D(
        GL_TEXTURE_2D,
        0,
        GL_RGBA,
        @intCast(GLsizei, width),
        @intCast(GLsizei, height),
        0,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        pixels.ptr,
    );
    return .{
        .handle = texid,
    };
}

pub fn ortho(left: f32, right: f32, bottom: f32, top: f32) [16]f32 {
    return .{
        2.0 / (right - left), 0.0,                  0.0,  -(right + left) / (right - left),
        0.0,                  2.0 / (top - bottom), 0.0,  -(top + bottom) / (top - bottom),
        0.0,                  0.0,                  -1.0, 0.0,
        0.0,                  0.0,                  0.0,  1.0,
    };
}

pub fn prepare(ds: *DrawState) void {
    const w = ds.virtual_window_width;
    const h = ds.virtual_window_height;
    const fw = @intToFloat(f32, w);
    const fh = @intToFloat(f32, h);
    ds.projection = ortho(0, fw, fh, 0);
    glViewport(0, 0, @intCast(c_int, w), @intCast(c_int, h));
    if (ds.clear_screen) {
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
        ds.clear_screen = false;
    }
}

pub fn begin(ds: *DrawState, tex_id: GLuint, maybe_color: ?draw.Color, alpha: f32, outline: bool) void {
    std.debug.assert(!ds.draw_buffer.active);
    std.debug.assert(ds.draw_buffer.num_vertices == 0);

    ds.shader_textured.bind(.{
        .tex = 0,
        .color = if (maybe_color) |color|
            .{
                .r = @intToFloat(f32, color.r) / 255.0,
                .g = @intToFloat(f32, color.g) / 255.0,
                .b = @intToFloat(f32, color.b) / 255.0,
                .a = alpha,
            }
        else
            .{
                .r = 1.0,
                .g = 1.0,
                .b = 1.0,
                .a = alpha,
            },
        .mvp = ds.projection[0..],
        .vertex_buffer = null,
        .texcoord_buffer = null,
    });

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex_id);

    ds.draw_buffer.active = true;
    ds.draw_buffer.outline = outline;
}

pub fn end(ds: *DrawState) void {
    std.debug.assert(ds.draw_buffer.active);

    flush(ds);

    ds.draw_buffer.active = false;
}

pub fn tile(
    ds: *DrawState,
    tileset: draw.Tileset,
    dtile: draw.Tile,
    x0: i32,
    y0: i32,
    w: i32,
    h: i32,
    transform: draw.Transform,
) void {
    std.debug.assert(ds.draw_buffer.active);
    if (dtile.tx >= tileset.xtiles or dtile.ty >= tileset.ytiles) {
        return;
    }
    const fx0 = @intToFloat(f32, x0);
    const fy0 = @intToFloat(f32, y0);
    const fx1 = fx0 + @intToFloat(f32, w);
    const fy1 = fy0 + @intToFloat(f32, h);

    const s0 = @intToFloat(f32, dtile.tx) / @intToFloat(f32, tileset.xtiles);
    const t0 = @intToFloat(f32, dtile.ty) / @intToFloat(f32, tileset.ytiles);
    const s1 = s0 + 1 / @intToFloat(f32, tileset.xtiles);
    const t1 = t0 + 1 / @intToFloat(f32, tileset.ytiles);

    const verts_per_tile: usize = 6; // two triangles

    if (ds.draw_buffer.num_vertices + verts_per_tile > buffer_vertices) {
        flush(ds);
    }
    const num_vertices = ds.draw_buffer.num_vertices;
    std.debug.assert(num_vertices + verts_per_tile <= buffer_vertices);

    const vertex2f = ds.draw_buffer.vertex2f[num_vertices * 2 .. (num_vertices + verts_per_tile) * 2];
    const texcoord2f = ds.draw_buffer.texcoord2f[num_vertices * 2 .. (num_vertices + verts_per_tile) * 2];

    // top left, bottom left, bottom right
    // bottom right, top right, top left
    std.mem.copy(
        GLfloat,
        vertex2f,
        &[12]GLfloat{ fx0, fy0, fx0, fy1, fx1, fy1, fx1, fy1, fx1, fy0, fx0, fy0 },
    );
    std.mem.copy(
        GLfloat,
        texcoord2f,
        switch (transform) {
            .identity => &[12]f32{ s0, t0, s0, t1, s1, t1, s1, t1, s1, t0, s0, t0 },
            .flip_vert => &[12]f32{ s0, t1, s0, t0, s1, t0, s1, t0, s1, t1, s0, t1 },
            .flip_horz => &[12]f32{ s1, t0, s1, t1, s0, t1, s0, t1, s0, t0, s1, t0 },
            .rotate_cw => &[12]f32{ s0, t1, s1, t1, s1, t0, s1, t0, s0, t0, s0, t1 },
            .rotate_ccw => &[12]f32{ s1, t0, s0, t0, s0, t1, s0, t1, s1, t1, s1, t0 },
        },
    );

    ds.draw_buffer.num_vertices = num_vertices + verts_per_tile;
}

fn flush(ds: *DrawState) void {
    if (ds.draw_buffer.num_vertices == 0) {
        return;
    }

    ds.shader_textured.update(.{
        .vertex_buffer = ds.dyn_vertex_buffer,
        .vertex2f = ds.draw_buffer.vertex2f[0..],
        .texcoord_buffer = ds.dyn_texcoord_buffer,
        .texcoord2f = ds.draw_buffer.texcoord2f[0..],
    });

    if (ds.draw_buffer.outline) {
        if (builtin.arch == .wasm32) {
            // webgl does not support glPolygonMode
        } else {
            glPolygonMode(GL_FRONT, GL_LINE);
            glDrawArrays(GL_TRIANGLES, 0, @intCast(GLsizei, ds.draw_buffer.num_vertices));
            glPolygonMode(GL_FRONT, GL_FILL);
        }
    } else {
        glDrawArrays(GL_TRIANGLES, 0, @intCast(GLsizei, ds.draw_buffer.num_vertices));
    }

    ds.draw_buffer.num_vertices = 0;
}
