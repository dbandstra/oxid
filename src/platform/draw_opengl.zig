// pdraw implementation backed by GL. supports OpenGL 2.1 (GLSL v120),
// OpenGL 3.0 (GLSL v130), and WebGL 1.

usingnamespace if (std.Target.current.isWasm())
    @import("zig-webgl")
else
    @import("gl").namespace;
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const drawing = @import("../common/drawing.zig");

const buffer_vertices = 4 * 512; // render up to 512 quads at once

pub const GLSLVersion = enum {
    v120,
    v130,
    webgl,
};

pub const Texture = struct {
    handle: GLuint,
    inv_w: f32,
    inv_h: f32,
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
    vwin_w: u31,
    vwin_h: u31,
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
    vwin_w: u31,
    vwin_h: u31,
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

    ds.vwin_w = params.vwin_w;
    ds.vwin_h = params.vwin_h;
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
    const fw = @intToFloat(f32, ds.vwin_w);
    const fh = @intToFloat(f32, ds.vwin_h);
    ds.projection = ortho(0, fw, fh, 0);
    glViewport(0, 0, ds.vwin_w, ds.vwin_h);
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
    return Texture{
        .handle = texid,
        .inv_w = 1 / @intToFloat(f32, w),
        .inv_h = 1 / @intToFloat(f32, h),
    };
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

pub fn setColor(ds: *State, rgb: drawing.Color) void {
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
    const fx1 = fx0 + @intToFloat(f32, tileset.tile_w);
    const fy1 = fy0 + @intToFloat(f32, tileset.tile_h);

    const s0 = @intToFloat(f32, dtile.tx * tileset.tile_w) * tileset.texture.inv_w;
    const t0 = @intToFloat(f32, dtile.ty * tileset.tile_h) * tileset.texture.inv_h;
    const s1 = s0 + @intToFloat(f32, tileset.tile_w) * tileset.texture.inv_w;
    const t1 = t0 + @intToFloat(f32, tileset.tile_h) * tileset.texture.inv_h;

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
    name: []const u8,
    program_id: GLuint,
    vertex_id: GLuint,
    fragment_id: GLuint,
};

fn compileAndLinkShaderProgram(
    hunk_side: *HunkSide,
    name: []const u8,
    source: ShaderSource,
) !ShaderProgram {
    const vertex_id = try compileShader(
        hunk_side,
        name,
        "vertex",
        GL_VERTEX_SHADER,
        source.vertex,
    );
    errdefer glDeleteShader(vertex_id);

    const fragment_id = try compileShader(
        hunk_side,
        name,
        "fragment",
        GL_FRAGMENT_SHADER,
        source.fragment,
    );
    errdefer glDeleteShader(fragment_id);

    const program_id = glCreateProgram();
    errdefer glDeleteProgram(program_id);

    glAttachShader(program_id, vertex_id);
    errdefer glDetachShader(program_id, vertex_id);
    glAttachShader(program_id, fragment_id);
    errdefer glDetachShader(program_id, fragment_id);

    glLinkProgram(program_id);

    var status: GLint = undefined;
    glGetProgramiv(program_id, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        var buffer_size: GLint = undefined;
        glGetProgramiv(program_id, GL_INFO_LOG_LENGTH, &buffer_size);

        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        const buffer = hunk_side.allocator.alloc(u8, @intCast(usize, buffer_size) + 1) catch {
            std.log.err("Failed to link \"{}\" shader program.", .{name});
            std.log.err("Failed to retrieve program info log (out of memory).", .{});
            return error.ShaderLinkFailed;
        };

        var len: GLsizei = 0;
        glGetProgramInfoLog(program_id, @intCast(GLsizei, buffer.len), &len, buffer.ptr);
        std.log.err("Failed to link \"{}\" shader program.\n{}\n{}\n{}", .{
            name,
            "-" ** 60,
            std.mem.trimRight(u8, buffer[0..@intCast(usize, len)], "\r\n"),
            "-" ** 60,
        });
        return error.ShaderLinkFailed;
    }

    return ShaderProgram{
        .name = name,
        .program_id = program_id,
        .vertex_id = vertex_id,
        .fragment_id = fragment_id,
    };
}

fn compileShader(
    hunk_side: *HunkSide,
    name: []const u8,
    shader_type: []const u8,
    kind: GLenum,
    source: []const u8,
) !GLuint {
    const shader_id = glCreateShader(kind);
    errdefer glDeleteShader(shader_id);

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

        const buffer = hunk_side.allocator.alloc(u8, @intCast(usize, buffer_size) + 1) catch {
            std.log.err("Failed to compile \"{}\" {} shader.", .{ name, shader_type });
            std.log.err("Failed to retrieve shader info log (out of memory).", .{});
            return error.ShaderCompileFailed;
        };

        var len: GLsizei = 0;
        glGetShaderInfoLog(shader_id, @intCast(GLsizei, buffer.len), &len, buffer.ptr);
        std.log.err("Failed to compile \"{}\" {} shader.\n{}\n{}\n{}", .{
            name,
            shader_type,
            "-" ** 60,
            std.mem.trimRight(u8, buffer[0..@intCast(usize, len)], "\r\n"),
            "-" ** 60,
        });
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
    if (id == -1)
        std.log.warn("Shader program \"{}\" has no attrib \"{}\".", .{ sp.name, name });
    return id;
}

fn getUniformLocation(sp: ShaderProgram, name: [:0]const u8) GLint {
    const id = glGetUniformLocation(sp.program_id, name);
    if (id == -1)
        std.log.warn("Shader program \"{}\" has no uniform \"{}\".", .{ sp.name, name });
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

        const source: ShaderSource = .{ .vertex = first_line ++
            (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n" ++
            \\uniform mat4 MVP;
            \\
            \\void main(void) {
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        , .fragment = first_line ++
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

        const source: ShaderSource = .{ .vertex = first_line ++
            (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n" ++
            (if (old) "attribute" else "in") ++ " vec2 TexCoord;\n" ++
            (if (old) "varying" else "out") ++ " vec2 FragTexCoord;\n" ++
            \\uniform mat4 MVP;
            \\
            \\void main(void) {
            \\    FragTexCoord = TexCoord;
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        , .fragment = first_line ++
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

    pub fn init(vwin_w: u31, vwin_h: u31) !Framebuffer {
        var fb: GLuint = undefined;
        glGenFramebuffers(1, &fb);
        glBindFramebuffer(GL_FRAMEBUFFER, fb);

        var rt: GLuint = undefined;
        glGenTextures(1, &rt);
        glBindTexture(GL_TEXTURE_2D, rt);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, vwin_w, vwin_h, 0, GL_RGB, GL_UNSIGNED_BYTE, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rt, 0);

        glDrawBuffers(1, &[1]GLenum{GL_COLOR_ATTACHMENT0});

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            glDeleteTextures(1, &rt);
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            glDeleteFramebuffers(1, &fb);
            return error.FramebufferInitFailed;
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

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

    pub fn postDraw(
        fbs: *Framebuffer,
        ds: *State,
        clear_screen: bool,
        full_w: u31,
        full_h: u31,
        blit_rect: BlitRect,
        alpha: f32,
    ) void {
        flush(ds);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        if (clear_screen) {
            // clear the entire screen to black (including any possible screen
            // margin or letterboxing/pillarboxing).
            // note that we can't just clear the screen once when the program
            // starts, because of double/triple buffering. we would have to do
            // at least for the first few draws. it's simpler just to clear
            // every frame.
            glViewport(0, 0, full_w, full_h);
            glClearColor(0, 0, 0, 0);
            glClear(GL_COLOR_BUFFER_BIT);
        }

        ds.projection = ortho(0, 1, 1, 0);
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
