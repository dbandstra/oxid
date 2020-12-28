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

const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const DrawBuffer = struct {
    tex_handle: GLuint,
    shader: enum { solid, textured },
    outline: bool,
    vertex2f: [2 * buffer_vertices]GLfloat,
    texcoord2f: [2 * buffer_vertices]GLfloat,
    num_vertices: usize,
};

pub const State = struct {
    // dimensions of the game viewport, which will be scaled up to fit the system window
    virtual_window_width: u32,
    virtual_window_height: u32,
    shader_solid: SolidShader,
    shader_textured: TexturedShader,
    dyn_vertex_buffer: GLuint,
    dyn_texcoord_buffer: GLuint,
    color: Color,
    draw_buffer: DrawBuffer,
    projection: [16]f32,
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

pub fn init(ds: *State, comptime glsl_version: GLSLVersion, params: struct {
    hunk: *Hunk,
    virtual_window_width: u32,
    virtual_window_height: u32,
}) !void {
    ds.shader_solid = try SolidShader.create(&params.hunk.low(), glsl_version);
    errdefer destroyShaderProgram(ds.shader_solid.program);
    ds.shader_textured = try TexturedShader.create(&params.hunk.low(), glsl_version);
    errdefer destroyShaderProgram(ds.shader_textured.program);

    glGenBuffers(1, &ds.dyn_vertex_buffer);
    errdefer glDeleteBuffers(1, &ds.dyn_vertex_buffer);
    updateVBO(ds.dyn_vertex_buffer, null);

    glGenBuffers(1, &ds.dyn_texcoord_buffer);
    errdefer glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    updateVBO(ds.dyn_texcoord_buffer, null);

    ds.virtual_window_width = params.virtual_window_width;
    ds.virtual_window_height = params.virtual_window_height;
    ds.color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
    ds.draw_buffer.num_vertices = 0;

    glDisable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glFrontFace(GL_CCW);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);

    setViewport(ds);
}

pub fn deinit(ds: *State) void {
    glDeleteBuffers(1, &ds.dyn_texcoord_buffer);
    glDeleteBuffers(1, &ds.dyn_vertex_buffer);
    destroyShaderProgram(ds.shader_textured.program);
    destroyShaderProgram(ds.shader_solid.program);
}

fn setViewport(ds: *State) void {
    const w = ds.virtual_window_width;
    const h = ds.virtual_window_height;
    const fw = @intToFloat(f32, w);
    const fh = @intToFloat(f32, h);
    ds.projection = ortho(0, fw, fh, 0);
    glViewport(0, 0, @intCast(c_int, w), @intCast(c_int, h));
}

pub fn createTexture(ds: *State, w: u31, h: u31, pixels: []const u8) !Texture {
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

pub fn destroyTexture(texture: Texture) void {
    glDeleteTextures(1, &texture.handle);
}

fn ortho(left: f32, right: f32, bottom: f32, top: f32) [16]f32 {
    return .{
        2.0 / (right - left), 0.0,                  0.0,  -(right + left) / (right - left),
        0.0,                  2.0 / (top - bottom), 0.0,  -(top + bottom) / (top - bottom),
        0.0,                  0.0,                  -1.0, 0.0,
        0.0,                  0.0,                  0.0,  1.0,
    };
}

pub fn setColor(ds: *State, rgb: draw.Color) void {
    const color: Color = .{
        .r = @intToFloat(f32, rgb.r) / 255.0,
        .g = @intToFloat(f32, rgb.g) / 255.0,
        .b = @intToFloat(f32, rgb.b) / 255.0,
        .a = 1.0,
    };
    if (color.r == ds.color.r and color.g == ds.color.g and
        color.b == ds.color.b and color.a == ds.color.a)
        return;
    flush(ds);
    ds.color = color;
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

    const verts_per_tile = 6; // two triangles

    if (ds.draw_buffer.num_vertices > 0) {
        if (ds.draw_buffer.tex_handle != tileset.texture.handle or
            ds.draw_buffer.outline != false or
            ds.draw_buffer.shader != .textured or
            ds.draw_buffer.num_vertices + verts_per_tile > buffer_vertices)
            flush(ds);
    }

    const num_verts = ds.draw_buffer.num_vertices;
    std.debug.assert(num_verts + verts_per_tile <= buffer_vertices);

    const fx0 = @intToFloat(f32, x);
    const fy0 = @intToFloat(f32, y);
    const fx1 = fx0 + @intToFloat(f32, w);
    const fy1 = fy0 + @intToFloat(f32, h);

    const s0 = @intToFloat(f32, dtile.tx) / @intToFloat(f32, tileset.xtiles);
    const t0 = @intToFloat(f32, dtile.ty) / @intToFloat(f32, tileset.ytiles);
    const s1 = s0 + 1 / @intToFloat(f32, tileset.xtiles);
    const t1 = t0 + 1 / @intToFloat(f32, tileset.ytiles);

    ds.draw_buffer.vertex2f[num_verts * 2 ..][0..12].* = [12]GLfloat{
        fx0, fy0, fx0, fy1, fx1, fy1,
        fx1, fy1, fx1, fy0, fx0, fy0,
    };
    ds.draw_buffer.texcoord2f[num_verts * 2 ..][0..12].* = switch (transform) {
        .identity => [12]GLfloat{ s0, t0, s0, t1, s1, t1, s1, t1, s1, t0, s0, t0 },
        .flip_vert => [12]GLfloat{ s0, t1, s0, t0, s1, t0, s1, t0, s1, t1, s0, t1 },
        .flip_horz => [12]GLfloat{ s1, t0, s1, t1, s0, t1, s0, t1, s0, t0, s1, t0 },
        .rotate_cw => [12]GLfloat{ s0, t1, s1, t1, s1, t0, s1, t0, s0, t0, s0, t1 },
        .rotate_ccw => [12]GLfloat{ s1, t0, s0, t0, s0, t1, s0, t1, s1, t1, s1, t0 },
    };

    ds.draw_buffer.tex_handle = tileset.texture.handle;
    ds.draw_buffer.outline = false;
    ds.draw_buffer.shader = .textured;
    ds.draw_buffer.num_vertices = num_verts + verts_per_tile;
}

pub fn fill(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    const verts_per_tile = 6; // two triangles

    if (ds.draw_buffer.num_vertices > 0) {
        if (ds.draw_buffer.outline != false or
            ds.draw_buffer.shader != .solid or
            ds.draw_buffer.num_vertices + verts_per_tile > buffer_vertices)
            flush(ds);
    }

    const num_verts = ds.draw_buffer.num_vertices;
    std.debug.assert(num_verts + verts_per_tile <= buffer_vertices);

    const fx0 = @intToFloat(f32, x);
    const fy0 = @intToFloat(f32, y);
    const fx1 = fx0 + @intToFloat(f32, w);
    const fy1 = fy0 + @intToFloat(f32, h);

    ds.draw_buffer.vertex2f[num_verts * 2 ..][0..12].* = [12]GLfloat{
        fx0, fy0, fx0, fy1, fx1, fy1,
        fx1, fy1, fx1, fy0, fx0, fy0,
    };

    ds.draw_buffer.outline = false;
    ds.draw_buffer.shader = .solid;
    ds.draw_buffer.num_vertices = num_verts + verts_per_tile;
}

pub fn rect(ds: *State, x: i32, y: i32, w: i32, h: i32) void {
    const verts_per_tile = 8; // for GL_LINES

    if (ds.draw_buffer.num_vertices > 0) {
        if (ds.draw_buffer.outline != true or
            ds.draw_buffer.shader != .solid or
            ds.draw_buffer.num_vertices + verts_per_tile > buffer_vertices)
            flush(ds);
    }

    const num_verts = ds.draw_buffer.num_vertices;
    std.debug.assert(num_verts + verts_per_tile <= buffer_vertices);

    const fx0 = @intToFloat(f32, x);
    const fy0 = @intToFloat(f32, y);
    const fx1 = fx0 + @intToFloat(f32, w);
    const fy1 = fy0 + @intToFloat(f32, h);

    ds.draw_buffer.vertex2f[num_verts * 2 ..][0..16].* = [16]GLfloat{
        fx0, fy0, fx0, fy1,
        fx0, fy1, fx1, fy1,
        fx1, fy1, fx1, fy0,
        fx1, fy0, fx0, fy0,
    };

    ds.draw_buffer.outline = true;
    ds.draw_buffer.shader = .solid;
    ds.draw_buffer.num_vertices = num_verts + verts_per_tile;
}

pub fn flush(ds: *State) void {
    if (ds.draw_buffer.num_vertices == 0)
        return;

    switch (ds.draw_buffer.shader) {
        .solid => {
            ds.shader_solid.bind(.{
                .color = ds.color,
                .mvp = &ds.projection,
                .vertex_buffer = ds.dyn_vertex_buffer,
                .vertex2f = &ds.draw_buffer.vertex2f,
            });
        },
        .textured => {
            ds.shader_textured.bind(.{
                .tex = 0,
                .color = ds.color,
                .mvp = &ds.projection,
                .vertex_buffer = ds.dyn_vertex_buffer,
                .vertex2f = &ds.draw_buffer.vertex2f,
                .texcoord_buffer = ds.dyn_texcoord_buffer,
                .texcoord2f = &ds.draw_buffer.texcoord2f,
            });

            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, ds.draw_buffer.tex_handle);
        },
    }

    if (ds.draw_buffer.outline) {
        glDrawArrays(GL_LINES, 0, @intCast(GLsizei, ds.draw_buffer.num_vertices));
    } else {
        glDrawArrays(GL_TRIANGLES, 0, @intCast(GLsizei, ds.draw_buffer.num_vertices));
    }

    ds.draw_buffer.num_vertices = 0;
}

// shader code

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

const SolidShader = struct {
    program: ShaderProgram,
    attrib_position: GLint,
    uniform_mvp: GLint,
    uniform_color: GLint,

    fn create(hunk_side: *HunkSide, comptime glsl_version: GLSLVersion) !SolidShader {
        const first_line = switch (glsl_version) {
            .v120 => "#version 120\n",
            .v130 => "#version 130\n",
            .webgl => "precision mediump float;\n",
        };

        const old = glsl_version == .v120 or glsl_version == .webgl;

        const source: ShaderSource = .{
            .vertex = first_line ++
                (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n" ++
                \\uniform mat4 MVP;
                \\
                \\void main(void) {
                \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
                \\}
            ,
            .fragment = first_line ++
                (if (old) "" else "out vec4 FragColor;\n") ++
                \\uniform vec4 Color;
                \\
                \\void main(void) {
                \\
                ++
                "    " ++ (if (old) "gl_" else "") ++ "FragColor = Color;\n" ++
                \\}
        };

        const program = try compileAndLinkShaderProgram(hunk_side, "solid", source);

        return SolidShader{
            .program = program,
            .attrib_position = getAttribLocation(program, "VertexPosition"),
            .uniform_mvp = getUniformLocation(program, "MVP"),
            .uniform_color = getUniformLocation(program, "Color"),
        };
    }

    fn bind(self: SolidShader, params: struct {
        mvp: []f32,
        color: Color,
        vertex_buffer: GLuint,
        vertex2f: []f32,
    }) void {
        glUseProgram(self.program.program_id);

        if (self.uniform_color != -1) {
            glUniform4f(self.uniform_color, params.color.r, params.color.g, params.color.b, params.color.a);
        }
        if (self.uniform_mvp != -1) {
            std.debug.assert(params.mvp.len == 16);
            glUniformMatrix4fv(self.uniform_mvp, 1, GL_FALSE, params.mvp.ptr);
        }
        if (self.attrib_position != -1) {
            updateVBO(params.vertex_buffer, params.vertex2f);
            glEnableVertexAttribArray(@intCast(GLuint, self.attrib_position));
            glBindBuffer(GL_ARRAY_BUFFER, params.vertex_buffer);
            glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
    }
};

const TexturedShader = struct {
    program: ShaderProgram,
    attrib_texcoord: GLint,
    attrib_position: GLint,
    uniform_mvp: GLint,
    uniform_tex: GLint,
    uniform_color: GLint,

    fn create(hunk_side: *HunkSide, comptime glsl_version: GLSLVersion) !TexturedShader {
        const first_line = switch (glsl_version) {
            .v120 => "#version 120\n",
            .v130 => "#version 130\n",
            .webgl => "precision mediump float;\n",
        };

        const old = glsl_version == .v120 or glsl_version == .webgl;

        const source: ShaderSource = .{
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

        const program = try compileAndLinkShaderProgram(hunk_side, "textured", source);

        return TexturedShader{
            .program = program,
            .attrib_position = getAttribLocation(program, "VertexPosition"),
            .attrib_texcoord = getAttribLocation(program, "TexCoord"),
            .uniform_mvp = getUniformLocation(program, "MVP"),
            .uniform_tex = getUniformLocation(program, "Tex"),
            .uniform_color = getUniformLocation(program, "Color"),
        };
    }

    fn bind(self: TexturedShader, params: struct {
        mvp: []f32,
        tex: GLint,
        color: Color,
        vertex_buffer: GLuint,
        texcoord_buffer: GLuint,
        vertex2f: []f32,
        texcoord2f: []f32,
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
            updateVBO(params.vertex_buffer, params.vertex2f);
            glEnableVertexAttribArray(@intCast(GLuint, self.attrib_position));
            glBindBuffer(GL_ARRAY_BUFFER, params.vertex_buffer);
            glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
        if (self.attrib_texcoord != -1) {
            updateVBO(params.texcoord_buffer, params.texcoord2f);
            glEnableVertexAttribArray(@intCast(GLuint, self.attrib_texcoord));
            glBindBuffer(GL_ARRAY_BUFFER, params.texcoord_buffer);
            glVertexAttribPointer(@intCast(GLuint, self.attrib_texcoord), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
    }
};

// following is an optional feature that allows you to draw to an off-screen
// framebuffer, then scale it up to fit the window for a pixellated look. note:
// web builds do not need this because they can just scale up the DOM canvas.
// requires either OpenGL 3+ or GL_ARB_framebuffer_object.

pub const Framebuffer = struct {
    framebuffer: GLuint,
    render_texture: GLuint,

    pub const BlitRect = struct {
        x: i32,
        y: i32,
        w: u31,
        h: u31,
    };

    pub fn init(w: u31, h: u31) !Framebuffer {
        var fb: GLuint = undefined;
        glGenFramebuffers(1, &fb);
        glBindFramebuffer(GL_FRAMEBUFFER, fb);

        var rt: GLuint = undefined;
        glGenTextures(1, &rt);
        glBindTexture(GL_TEXTURE_2D, rt);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rt, 0);

        glDrawBuffers(1, &[1]GLenum{GL_COLOR_ATTACHMENT0});

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            glDeleteTextures(1, &rt);
            glDeleteFramebuffers(1, &fb);
            return error.FramebufferInitFailed;
        }

        return Framebuffer{
            .framebuffer = fb,
            .render_texture = rt,
        };
    }

    pub fn deinit(fbs: *Framebuffer) void {
        glDeleteTextures(1, &fbs.render_texture);
        glDeleteFramebuffers(1, &fbs.framebuffer);
    }

    pub fn preDraw(fbs: *Framebuffer) void {
        glBindFramebuffer(GL_FRAMEBUFFER, fbs.framebuffer);
    }

    pub fn postDraw(fbs: *Framebuffer, ds: *State, blit_rect: BlitRect, alpha: f32) void {
        flush(ds);

        // blit renderbuffer to screen
        ds.projection = ortho(0, 1, 1, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(blit_rect.x, blit_rect.y, blit_rect.w, blit_rect.h);

        ds.draw_buffer.vertex2f[0..12].* = .{ 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0 };
        ds.draw_buffer.texcoord2f[0..12].* = .{ 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1 };

        ds.shader_textured.bind(.{
            .tex = 0,
            .color = .{ .r = 1, .g = 1, .b = 1, .a = alpha },
            .mvp = &ds.projection,
            .vertex_buffer = ds.dyn_vertex_buffer,
            .vertex2f = &ds.draw_buffer.vertex2f,
            .texcoord_buffer = ds.dyn_texcoord_buffer,
            .texcoord2f = &ds.draw_buffer.texcoord2f,
        });

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, fbs.render_texture);

        glDrawArrays(GL_TRIANGLES, 0, 6);

        // reset viewport
        setViewport(ds);
    }
};
