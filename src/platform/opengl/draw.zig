const builtin = @import("builtin");
usingnamespace
    if (builtin.arch == .wasm32)
        @import("../../web.zig")
    else
        @cImport({
            @cInclude("epoxy/gl.h");
        });
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const warn = @import("../../warn.zig").warn;
const shaders = @import("shaders.zig");
const shader_textured = @import("shader_textured.zig");
const draw = @import("../../common/draw.zig");

pub const GlitchMode = enum {
    Normal,
    QuadStrips,
    WholeTilesets,
};

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

pub const DrawInitParams = struct {
    hunk: *Hunk,
    virtual_window_width: u32,
    virtual_window_height: u32,
};

pub const buffer_vertices = 4*512; // render up to 512 quads at once

pub const DrawState = struct {
    // dimensions of the game viewport, which will be scaled up to fit the system
    // window
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
    glitch_mode: GlitchMode,
    clear_screen: bool,
};

pub fn updateVbo(vbo: GLuint, maybe_data2f: ?[]f32) void {
    const size = buffer_vertices * 2 * @sizeOf(GLfloat);
    const null_data =
        if (builtin.arch == .wasm32)
            @intToPtr(?[*]const f32, 0)
        else
            @intToPtr(?*const c_void, 0);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size, null_data, GL_STREAM_DRAW);
    if (maybe_data2f) |data2f| {
        std.debug.assert(data2f.len == 2 * buffer_vertices);
        glBufferData(GL_ARRAY_BUFFER, size, &data2f[0], GL_STREAM_DRAW);
    }
}

pub const InitError = error {
    UnsupportedOpenGLVersion,
} || shaders.InitError;

fn detectGLSLVersion() InitError!shaders.GLSLVersion {
    if (builtin.arch == .wasm32) {
        return shaders.GLSLVersion.WebGL;
    } else {
        const v = glGetString(GL_VERSION);

        if (v != 0) { // null check
            if (v[1] == '.') {
                if (v[0] == '2' and v[2] != '0') {
                    return shaders.GLSLVersion.V120;
                } else if (v[0] >= '3' and v[0] <= '9') {
                    return shaders.GLSLVersion.V130;
                }
            }

            warn("Unsupported OpenGL version: {}\n", std.mem.toSliceConst(u8, v));
        } else {
            warn("Failed to get OpenGL version.\n");
        }

        return error.UnsupportedOpenGLVersion;
    }
}

pub fn init(ds: *DrawState, params: DrawInitParams) InitError!void {
    const glsl_version = try detectGLSLVersion();

    ds.shader_textured = try shader_textured.create(&params.hunk.low(), glsl_version);
    errdefer shaders.destroy(ds.shader_textured.program);

    if (builtin.arch == .wasm32) {
        ds.dyn_vertex_buffer = glCreateBuffer();
    } else {
        glGenBuffers(1, &ds.dyn_vertex_buffer);
    }
    updateVbo(ds.dyn_vertex_buffer, null);
    errdefer glDeleteBuffers(1, &ds.dyn_vertex_buffer);

    if (builtin.arch == .wasm32) {
        ds.dyn_texcoord_buffer = glCreateBuffer();
    } else {
        glGenBuffers(1, &ds.dyn_texcoord_buffer);
    }
    updateVbo(ds.dyn_texcoord_buffer, null);
    errdefer glDeleteBuffers(1, &ds.dyn_texcoord_buffer);

    glDisable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glFrontFace(GL_CCW);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);

    ds.virtual_window_width = params.virtual_window_width;
    ds.virtual_window_height = params.virtual_window_height;
    ds.draw_buffer.num_vertices = 0;

    const blank_tex_pixels = [_]u8{255, 255, 255, 255};
    ds.blank_tex = uploadTexture(1, 1, blank_tex_pixels);
    ds.blank_tileset = draw.Tileset {
        .texture = ds.blank_tex,
        .xtiles = 1,
        .ytiles = 1,
    };

    ds.glitch_mode = GlitchMode.Normal;
    ds.clear_screen = true;
}

pub fn deinit(ds: *DrawState) void {
    if (builtin.arch == .wasm32) {
        glDeleteBuffer(ds.dyn_vertex_buffer);
        glDeleteBuffer(ds.dyn_texcoord_buffer);
    } else {
        glDeleteBuffers(1, &ds.dyn_vertex_buffer);
        glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    }
    shaders.destroy(ds.shader_textured.program);
}

pub fn uploadTexture(width: usize, height: usize, pixels: []const u8) Texture {
    var texid: GLuint = undefined;
    if (builtin.arch == .wasm32) {
        texid = glCreateTexture();
    } else {
        glGenTextures(1, &texid);
    }
    glBindTexture(GL_TEXTURE_2D, texid);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    if (builtin.arch == .wasm32) {
        glTexImage2D(
            GL_TEXTURE_2D, // target
            0, // level
            GL_RGBA, // internalFormat
            @intCast(c_int, width),
            @intCast(c_int, height),
            0, // border
            GL_RGBA, // format
            GL_UNSIGNED_BYTE, // type
            pixels.ptr,
            width * height * 4,
        );
    } else {
        glTexImage2D(
            GL_TEXTURE_2D, // target
            0, // level
            GL_RGBA, // internalFormat
            @intCast(c_int, width),
            @intCast(c_int, height),
            0, // border
            GL_RGBA, // format
            GL_UNSIGNED_BYTE, // type
            &pixels[0],
        );
    }
    return Texture {
        .handle = texid,
    };
}

pub fn cycleGlitchMode(ds: *DrawState) void {
    const i = @enumToInt(ds.glitch_mode);
    const count = @memberCount(GlitchMode);
    ds.glitch_mode =
        if (i + 1 < count)
            @intToEnum(GlitchMode, i + 1)
        else
            @intToEnum(GlitchMode, 0);
    ds.clear_screen = true;
}

pub fn ortho(left: f32, right: f32, bottom: f32, top: f32) [16]f32 {
    return [16]f32 {
        2.0 / (right - left), 0.0, 0.0, -(right + left) / (right - left),
        0.0, 2.0 / (top - bottom), 0.0, -(top + bottom) / (top - bottom),
        0.0, 0.0, -1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
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

    ds.shader_textured.bind(shader_textured.BindParams {
        .tex = 0,
        .color =
            if (maybe_color) |color|
                shader_textured.Color {
                    .r = @intToFloat(f32, color.r) / 255.0,
                    .g = @intToFloat(f32, color.g) / 255.0,
                    .b = @intToFloat(f32, color.b) / 255.0,
                    .a = alpha,
                }
            else
                shader_textured.Color {
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
    x0: i32, y0: i32, w: i32, h: i32,
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

    var s0 = @intToFloat(f32, dtile.tx) / @intToFloat(f32, tileset.xtiles);
    var t0 = @intToFloat(f32, dtile.ty) / @intToFloat(f32, tileset.ytiles);
    var s1 = s0 + 1 / @intToFloat(f32, tileset.xtiles);
    var t1 = t0 + 1 / @intToFloat(f32, tileset.ytiles);

    if (ds.glitch_mode == .WholeTilesets) {
        // draw the whole tileset scaled down. with transparency this leads to
        // smearing. it's interesting how the level itself is "hidden" to begin
        // with
        s0 = 0;
        t0 = 0;
        s1 = 1;
        t1 = 1;
    }

    // wasm doesn't support quads, so we have to emit two triangles
    const verts_per_tile = if (builtin.arch == .wasm32) usize(6) else usize(4);

    if (ds.draw_buffer.num_vertices + verts_per_tile > buffer_vertices) {
        flush(ds);
    }
    const num_vertices = ds.draw_buffer.num_vertices;
    std.debug.assert(num_vertices + verts_per_tile <= buffer_vertices);

    const vertex2f = ds.draw_buffer.vertex2f[num_vertices * 2..(num_vertices + verts_per_tile) * 2];
    const texcoord2f = ds.draw_buffer.texcoord2f[num_vertices * 2..(num_vertices + verts_per_tile) * 2];

    if (builtin.arch == .wasm32) {
        // top left, bottom left, bottom right
        // bottom right, top right, top left
        // so, compared to quad:
        // same, same, same, <-dupe, same, (first)
        std.mem.copy(
            GLfloat,
            vertex2f,
            [12]GLfloat{fx0,fy0, fx0,fy1, fx1,fy1, fx1,fy1, fx1,fy0, fx0,fy0},
        );
        std.mem.copy(
            GLfloat,
            texcoord2f,
            switch (transform) {
                .Identity =>
                    [12]f32{s0,t0, s0,t1, s1,t1, s1,t1, s1,t0, s0,t0},
                .FlipVertical =>
                    [12]f32{s0,t1, s0,t0, s1,t0, s1,t0, s1,t1, s0,t1},
                .FlipHorizontal =>
                    [12]f32{s1,t0, s1,t1, s0,t1, s0,t1, s0,t0, s1,t0},
                .RotateClockwise =>
                    [12]f32{s0,t1, s1,t1, s1,t0, s1,t0, s0,t0, s0,t1},
                .RotateCounterClockwise =>
                    [12]f32{s1,t0, s0,t0, s0,t1, s0,t1, s1,t1, s1,t0},
            },
        );
    } else {
    // top left, bottom left, bottom right, top right
    std.mem.copy(
        GLfloat,
        vertex2f,
        [8]GLfloat{fx0, fy0, fx0, fy1, fx1, fy1, fx1, fy0},
    );
    std.mem.copy(
        GLfloat,
        texcoord2f,
        switch (transform) {
            .Identity =>
                [8]f32{s0, t0, s0, t1, s1, t1, s1, t0},
            .FlipVertical =>
                [8]f32{s0, t1, s0, t0, s1, t0, s1, t1},
            .FlipHorizontal =>
                [8]f32{s1, t0, s1, t1, s0, t1, s0, t0},
            .RotateClockwise =>
                [8]f32{s0, t1, s1, t1, s1, t0, s0, t0},
            .RotateCounterClockwise =>
                [8]f32{s1, t0, s0, t0, s0, t1, s1, t1},
        },
    );
    }

    if (ds.glitch_mode == .QuadStrips and builtin.arch != .wasm32) {
        // swap last two vertices so that the order becomes top left, bottom left,
        // top right, bottom right (suitable for quad strips rather than individual
        // quads)
        std.mem.swap(GLfloat, &vertex2f[4], &vertex2f[6]);
        std.mem.swap(GLfloat, &vertex2f[5], &vertex2f[7]);
        std.mem.swap(GLfloat, &texcoord2f[4], &texcoord2f[6]);
        std.mem.swap(GLfloat, &texcoord2f[5], &texcoord2f[7]);
    }

    ds.draw_buffer.num_vertices = num_vertices + verts_per_tile;
}

fn flush(ds: *DrawState) void {
    if (ds.draw_buffer.num_vertices == 0) {
        return;
    }

    ds.shader_textured.update(shader_textured.UpdateParams {
        .vertex_buffer = ds.dyn_vertex_buffer,
        .vertex2f = ds.draw_buffer.vertex2f[0..],
        .texcoord_buffer = ds.dyn_texcoord_buffer,
        .texcoord2f = ds.draw_buffer.texcoord2f[0..],
    });

    if (builtin.arch != .wasm32) {
        if (ds.draw_buffer.outline) {
            glPolygonMode(GL_FRONT, GL_LINE);
        }
    }

    glDrawArrays(
        if (builtin.arch == .wasm32)
            GLenum(GL_TRIANGLES)
        else if (ds.glitch_mode == .QuadStrips)
            GLenum(GL_QUAD_STRIP)
        else
            GLenum(GL_QUADS),
        0,
        @intCast(if (builtin.arch == .wasm32) c_uint else c_int, ds.draw_buffer.num_vertices),
    );

    if (builtin.arch != .wasm32) {
        if (ds.draw_buffer.outline) {
            glPolygonMode(GL_FRONT, GL_FILL);
        }
    }

    ds.draw_buffer.num_vertices = 0;
}
