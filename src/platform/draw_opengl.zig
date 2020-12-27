// simple 2D drawing library implementation, supports OpenGL 2.1 (GLSL v120),
// OpenGL 3.0 (GLSL v130), and WebGL 1.

const builtin = @import("builtin");
usingnamespace if (builtin.arch == .wasm32)
    @import("zig-webgl")
else
    @import("gl").namespace;
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const plog = @import("root").plog;
const indentingWriter = @import("../common/indenting_writer.zig").indentingWriter;
const draw = @import("../common/draw.zig");

const buffer_vertices = 4 * 512; // render up to 512 quads at once

pub const GLSLVersion = enum {
    v120,
    v130,
    webgl,
};

pub const Texture = struct {
    handle: GLuint,
};

const DrawBuffer = struct {
    tex_handle: GLuint,
    vertex2f: [2 * buffer_vertices]GLfloat,
    texcoord2f: [2 * buffer_vertices]GLfloat,
    num_vertices: usize,
};

pub const State = struct {
    // dimensions of the game viewport, which will be scaled up to fit the system window
    virtual_window_width: u32,
    virtual_window_height: u32,
    shader_textured: TexturedShader,
    dyn_vertex_buffer: GLuint,
    dyn_texcoord_buffer: GLuint,
    color: draw.Color,
    alpha: f32,
    outline: bool,
    draw_buffer: DrawBuffer,
    projection: [16]f32,
    blank_tileset: draw.Tileset,
};

fn updateVBO(vbo: GLuint, maybe_data2f: ?[]f32) void {
    const size = buffer_vertices * 2 * @sizeOf(GLfloat);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size, null, GL_STREAM_DRAW);
    if (maybe_data2f) |data2f| {
        std.debug.assert(data2f.len == 2 * buffer_vertices);
        glBufferData(GL_ARRAY_BUFFER, size, &data2f[0], GL_STREAM_DRAW);
    }
}

pub fn init(ds: *State, params: struct {
    hunk: *Hunk,
    virtual_window_width: u32,
    virtual_window_height: u32,
    glsl_version: GLSLVersion,
}) !void {
    ds.shader_textured = try createTexturedShader(&params.hunk.low(), params.glsl_version);
    errdefer destroyShaderProgram(ds.shader_textured.program);

    glGenBuffers(1, &ds.dyn_vertex_buffer);
    errdefer glDeleteBuffers(1, &ds.dyn_vertex_buffer);
    updateVBO(ds.dyn_vertex_buffer, null);

    glGenBuffers(1, &ds.dyn_texcoord_buffer);
    errdefer glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    updateVBO(ds.dyn_texcoord_buffer, null);

    ds.virtual_window_width = params.virtual_window_width;
    ds.virtual_window_height = params.virtual_window_height;
    ds.color = draw.pure_white;
    ds.alpha = 1.0;
    ds.outline = false;
    ds.draw_buffer.num_vertices = 0;

    ds.blank_tileset = .{
        .texture = try uploadTexture(ds, 1, 1, &[_]u8{ 255, 255, 255, 255 }),
        .xtiles = 1,
        .ytiles = 1,
    };

    glDisable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glFrontFace(GL_CCW);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
}

pub fn deinit(ds: *State) void {
    glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    glDeleteBuffers(1, &ds.dyn_vertex_buffer);
    destroyShaderProgram(ds.shader_textured.program);
}

pub fn uploadTexture(ds: *State, w: u31, h: u31, pixels: []const u8) !Texture {
    var texid: GLuint = undefined;
    glGenTextures(1, &texid);
    glBindTexture(GL_TEXTURE_2D, texid);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels.ptr);
    return Texture{ .handle = texid };
}

// this is only `pub` so `draw_framebuffer_opengl.zig` can access it
pub fn ortho(left: f32, right: f32, bottom: f32, top: f32) [16]f32 {
    return .{
        2.0 / (right - left), 0.0,                  0.0,  -(right + left) / (right - left),
        0.0,                  2.0 / (top - bottom), 0.0,  -(top + bottom) / (top - bottom),
        0.0,                  0.0,                  -1.0, 0.0,
        0.0,                  0.0,                  0.0,  1.0,
    };
}

pub fn prepare(ds: *State) void {
    const w = ds.virtual_window_width;
    const h = ds.virtual_window_height;
    const fw = @intToFloat(f32, w);
    const fh = @intToFloat(f32, h);
    ds.projection = ortho(0, fw, fh, 0);
    glViewport(0, 0, @intCast(c_int, w), @intCast(c_int, h));
}

pub fn setColor(ds: *State, color: draw.Color, alpha: f32) void {
    if (color.r == ds.color.r and color.g == ds.color.g and
        color.b == ds.color.b and alpha == ds.alpha)
        return;
    flush(ds);
    ds.color = color;
    ds.alpha = alpha;
}

pub fn setOutline(ds: *State, outline: bool) void {
    if (outline == ds.outline)
        return;
    flush(ds);
    ds.outline = outline;
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
    if (dtile.tx >= tileset.xtiles or dtile.ty >= tileset.ytiles)
        return;

    const fx0 = @intToFloat(f32, x);
    const fy0 = @intToFloat(f32, y);
    const fx1 = fx0 + @intToFloat(f32, w);
    const fy1 = fy0 + @intToFloat(f32, h);

    const s0 = @intToFloat(f32, dtile.tx) / @intToFloat(f32, tileset.xtiles);
    const t0 = @intToFloat(f32, dtile.ty) / @intToFloat(f32, tileset.ytiles);
    const s1 = s0 + 1 / @intToFloat(f32, tileset.xtiles);
    const t1 = t0 + 1 / @intToFloat(f32, tileset.ytiles);

    const verts_per_tile = 6; // two triangles

    if (ds.draw_buffer.num_vertices > 0) {
        if (ds.draw_buffer.tex_handle != tileset.texture.handle or
            ds.draw_buffer.num_vertices + verts_per_tile > buffer_vertices)
            flush(ds);
    }

    const num_verts = ds.draw_buffer.num_vertices;
    std.debug.assert(num_verts + verts_per_tile <= buffer_vertices);

    // top left, bottom left, bottom right - bottom right, top right, top left
    ds.draw_buffer.vertex2f[num_verts * 2 ..][0 .. verts_per_tile * 2].* =
        [12]GLfloat{ fx0, fy0, fx0, fy1, fx1, fy1, fx1, fy1, fx1, fy0, fx0, fy0 };
    ds.draw_buffer.texcoord2f[num_verts * 2 ..][0 .. verts_per_tile * 2].* =
        switch (transform) {
        .identity => [12]f32{ s0, t0, s0, t1, s1, t1, s1, t1, s1, t0, s0, t0 },
        .flip_vert => [12]f32{ s0, t1, s0, t0, s1, t0, s1, t0, s1, t1, s0, t1 },
        .flip_horz => [12]f32{ s1, t0, s1, t1, s0, t1, s0, t1, s0, t0, s1, t0 },
        .rotate_cw => [12]f32{ s0, t1, s1, t1, s1, t0, s1, t0, s0, t0, s0, t1 },
        .rotate_ccw => [12]f32{ s1, t0, s0, t0, s0, t1, s0, t1, s1, t1, s1, t0 },
    };

    ds.draw_buffer.tex_handle = tileset.texture.handle;
    ds.draw_buffer.num_vertices = num_verts + verts_per_tile;
}

pub fn fill(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    tile(ds, ds.blank_tileset, .{ .tx = 0, .ty = 0 }, x, y, w, h, .identity);
}

pub fn flush(ds: *State) void {
    if (ds.draw_buffer.num_vertices == 0)
        return;

    ds.shader_textured.bind(.{
        .tex = 0,
        .color = .{
            .r = @intToFloat(f32, ds.color.r) / 255.0,
            .g = @intToFloat(f32, ds.color.g) / 255.0,
            .b = @intToFloat(f32, ds.color.b) / 255.0,
            .a = ds.alpha,
        },
        .mvp = &ds.projection,
        .vertex_buffer = null,
        .texcoord_buffer = null,
    });
    ds.shader_textured.update(.{
        .vertex_buffer = ds.dyn_vertex_buffer,
        .vertex2f = &ds.draw_buffer.vertex2f,
        .texcoord_buffer = ds.dyn_texcoord_buffer,
        .texcoord2f = &ds.draw_buffer.texcoord2f,
    });

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, ds.draw_buffer.tex_handle);

    if (ds.outline) {
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

// generic shader code

const ShaderSource = struct {
    vertex: []const u8,
    fragment: []const u8,
};

const ShaderProgram = struct {
    program_id: GLuint,
    vertex_id: GLuint,
    fragment_id: GLuint,
};

fn compileAndLinkShaderProgram(hunk_side: *HunkSide, description: []const u8, source: ShaderSource) !ShaderProgram {
    errdefer plog.warn("Failed to compile and link shader program \"{}\".\n", .{description});

    const vertex_id = try compileShader(hunk_side, source.vertex, "vertex", GL_VERTEX_SHADER);
    const fragment_id = try compileShader(hunk_side, source.fragment, "fragment", GL_FRAGMENT_SHADER);

    const program_id = glCreateProgram();
    glAttachShader(program_id, vertex_id);
    glAttachShader(program_id, fragment_id);
    glLinkProgram(program_id);

    var status: GLint = undefined;
    glGetProgramiv(program_id, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        var buffer_size: GLint = undefined;
        glGetProgramiv(program_id, GL_INFO_LOG_LENGTH, &buffer_size);

        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        if (hunk_side.allocator.alloc(u8, @intCast(usize, buffer_size) + 1)) |buffer| {
            var len: GLsizei = 0;
            glGetProgramInfoLog(program_id, @intCast(GLsizei, buffer.len), &len, buffer.ptr);
            const log = buffer[0..@intCast(usize, len)];
            indentingWriter(plog.warnWriter(), 4).writer().writeAll(log) catch {};
            plog.flushWarnWriter();
        } else |_| plog.warn("Failed to retrieve program info log (out of memory).\n", .{});

        return error.ShaderLinkFailed;
    }

    return ShaderProgram{
        .program_id = program_id,
        .vertex_id = vertex_id,
        .fragment_id = fragment_id,
    };
}

fn compileShader(hunk_side: *HunkSide, source: []const u8, shader_type: []const u8, kind: GLenum) !GLuint {
    errdefer plog.warn("Failed to compile {} shader.\n", .{shader_type});

    const shader_id = glCreateShader(kind);
    const source_len = @intCast(GLint, source.len);
    glShaderSource(shader_id, 1, &source.ptr, &source_len);
    glCompileShader(shader_id);

    var status: GLint = undefined;
    glGetShaderiv(shader_id, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        var buffer_size: GLint = undefined;
        glGetShaderiv(shader_id, GL_INFO_LOG_LENGTH, &buffer_size);

        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        if (hunk_side.allocator.alloc(u8, @intCast(usize, buffer_size) + 1)) |buffer| {
            var len: GLsizei = 0;
            glGetShaderInfoLog(shader_id, @intCast(GLsizei, buffer.len), &len, buffer.ptr);
            const log = buffer[0..@intCast(usize, len)];
            indentingWriter(plog.warnWriter(), 4).writer().writeAll(log) catch {};
            plog.flushWarnWriter();
        } else |_| plog.warn("Failed to retrieve shader info log (out of memory).\n", .{});

        return error.ShaderCompileFailed;
    }

    return shader_id;
}

fn destroyShaderProgram(sp: ShaderProgram) void {
    glDetachShader(sp.program_id, sp.fragment_id);
    glDetachShader(sp.program_id, sp.vertex_id);

    glDeleteShader(sp.fragment_id);
    glDeleteShader(sp.vertex_id);

    glDeleteProgram(sp.program_id);
}

fn getAttribLocation(sp: ShaderProgram, name: [:0]const u8) GLint {
    const id = glGetAttribLocation(sp.program_id, name);
    if (id == -1) plog.warn("(warning) invalid attrib: {}\n", .{name});
    return id;
}

fn getUniformLocation(sp: ShaderProgram, name: [:0]const u8) GLint {
    const id = glGetUniformLocation(sp.program_id, name);
    if (id == -1) plog.warn("(warning) invalid uniform: {}\n", .{name});
    return id;
}

// "textured" shader

const TexturedShader = struct {
    program: ShaderProgram,
    attrib_texcoord: GLint,
    attrib_position: GLint,
    uniform_mvp: GLint,
    uniform_tex: GLint,
    uniform_color: GLint,

    fn bind(self: TexturedShader, params: struct {
        mvp: []f32,
        tex: GLint,
        color: struct { r: f32, g: f32, b: f32, a: f32 },
        vertex_buffer: ?GLuint,
        texcoord_buffer: ?GLuint,
    }) void {
        glUseProgram(self.program.program_id);

        if (self.uniform_tex != -1) {
            glUniform1i(self.uniform_tex, params.tex);
        }
        if (self.uniform_color != -1) {
            glUniform4f(self.uniform_color, params.color.r, params.color.g, params.color.b, params.color.a);
        }
        if (self.uniform_mvp != -1) {
            std.debug.assert(params.mvp.len == 16);
            glUniformMatrix4fv(self.uniform_mvp, 1, GL_FALSE, params.mvp.ptr);
        }

        if (self.attrib_position != -1) {
            glEnableVertexAttribArray(@intCast(GLuint, self.attrib_position));
            if (params.vertex_buffer) |vertex_buffer| {
                glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
                glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);
            }
        }
        if (self.attrib_texcoord != -1) {
            glEnableVertexAttribArray(@intCast(GLuint, self.attrib_texcoord));
            if (params.texcoord_buffer) |texcoord_buffer| {
                glBindBuffer(GL_ARRAY_BUFFER, texcoord_buffer);
                glVertexAttribPointer(@intCast(GLuint, self.attrib_texcoord), 2, GL_FLOAT, GL_FALSE, 0, null);
            }
        }
    }

    fn update(self: TexturedShader, params: struct {
        vertex_buffer: GLuint,
        texcoord_buffer: GLuint,
        vertex2f: []f32,
        texcoord2f: []f32,
    }) void {
        updateVBO(params.vertex_buffer, params.vertex2f);
        if (self.attrib_position != -1) {
            glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
        updateVBO(params.texcoord_buffer, params.texcoord2f);
        if (self.attrib_texcoord != -1) {
            glVertexAttribPointer(@intCast(GLuint, self.attrib_texcoord), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
    }
};

fn getTexturedShaderSource(comptime version: GLSLVersion) ShaderSource {
    const first_line = switch (version) {
        .v120 => "#version 120\n",
        .v130 => "#version 130\n",
        .webgl => "precision mediump float;\n",
    };

    const old = version == .v120 or version == .webgl;

    return .{
        .vertex = first_line ++
            (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n" ++
            (if (old) "attribute" else "in") ++ " vec2 TexCoord;\n" ++
            (if (old) "varying" else "out") ++ " vec2 FragTexCoord;\n" ++
            \\uniform mat4 MVP;
            \\
            \\void main(void) {
            \\    FragTexCoord = TexCoord;
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
        .fragment = first_line ++
            (if (old) "varying" else "in") ++ " vec2 FragTexCoord;\n" ++
            (if (old) "" else "out vec4 FragColor;\n") ++
            \\uniform sampler2D Tex;
            \\uniform vec4 Color;
            \\
            \\void main(void) {
            \\
            ++
            "    " ++ (if (old) "gl_" else "") ++ "FragColor = texture2D(Tex, FragTexCoord) * Color;\n" ++
            \\}
    };
}

fn createTexturedShader(hunk_side: *HunkSide, glsl_version: GLSLVersion) !TexturedShader {
    errdefer plog.warn("Failed to create textured shader program.\n", .{});

    const program = try compileAndLinkShaderProgram(
        hunk_side,
        "textured",
        switch (glsl_version) {
            .v120 => getTexturedShaderSource(.v120),
            .v130 => getTexturedShaderSource(.v130),
            .webgl => getTexturedShaderSource(.webgl),
        },
    );

    return TexturedShader{
        .program = program,
        .attrib_position = getAttribLocation(program, "VertexPosition"),
        .attrib_texcoord = getAttribLocation(program, "TexCoord"),
        .uniform_mvp = getUniformLocation(program, "MVP"),
        .uniform_tex = getUniformLocation(program, "Tex"),
        .uniform_color = getUniformLocation(program, "Color"),
    };
}
