const c = @import("../c.zig");
const math3d = @import("math3d.zig");
const debug_gl = @import("debug_gl.zig");
const c_allocator = @import("std").heap.c_allocator;

pub const AllShaders = struct{
    primitive: ShaderProgram,
    primitive_attrib_position: c.GLint,
    primitive_uniform_mvp: c.GLint,
    primitive_uniform_color: c.GLint,

    texture: ShaderProgram,
    texture_attrib_tex_coord: c.GLint,
    texture_attrib_position: c.GLint,
    texture_uniform_mvp: c.GLint,
    texture_uniform_tex: c.GLint,
    texture_uniform_alpha: c.GLint,

    pub fn destroy(as: *AllShaders) void {
        as.primitive.destroy();
        as.texture.destroy();
    }
};

pub const ShaderProgram = struct{
    program_id: c.GLuint,
    vertex_id: c.GLuint,
    fragment_id: c.GLuint,

    pub fn bind(sp: *const ShaderProgram) void {
        c.glUseProgram(sp.program_id);
    }

    pub fn attribLocation(sp: *const ShaderProgram, name: [*]const u8) !c.GLint {
        const id = c.glGetAttribLocation(sp.program_id, name);
        if (id == -1) {
            _ = c.printf(c"invalid attrib: %s\n", name);
            return error.ShaderInvalidAttrib;
        }
        return id;
    }

    pub fn uniformLocation(sp: *const ShaderProgram, name: [*]const u8) c.GLint {
        const id = c.glGetUniformLocation(sp.program_id, name);
        if (id == -1) {
            _ = c.printf(c"(warning) invalid uniform: %s\n", name);
        }
        return id;
    }

    pub fn setUniformInt(sp: *const ShaderProgram, uniform_id: c.GLint, value: c_int) void {
        if (uniform_id != -1) {
            c.glUniform1i(uniform_id, value);
        }
    }

    pub fn setUniformFloat(sp: *const ShaderProgram, uniform_id: c.GLint, value: f32) void {
        if (uniform_id != -1) {
            c.glUniform1f(uniform_id, value);
        }
    }

    pub fn setUniformVec2(sp: *const ShaderProgram, uniform_id: c.GLint, x: f32, y: f32) void {
        if (uniform_id != -1) {
            c.glUniform2f(uniform_id, x, y);
        }
    }

    pub fn setUniformVec3(sp: *const ShaderProgram, uniform_id: c.GLint, x: f32, y: f32, z: f32) void {
        if (uniform_id != -1) {
            c.glUniform3f(uniform_id, x, y, z);
        }
    }

    pub fn setUniformVec4(sp: *const ShaderProgram, uniform_id: c.GLint, x: f32, y: f32, z: f32, w: f32) void {
        if (uniform_id != -1) {
            c.glUniform4f(uniform_id, x, y, z, w);
        }
    }

    pub fn setUniformMat4x4(sp: *const ShaderProgram, uniform_id: c.GLint, value: *const math3d.Mat4x4) void {
        if (uniform_id != -1) {
            c.glUniformMatrix4fv(uniform_id, 1, c.GL_FALSE, value.data[0][0..].ptr);
        }
    }

    pub fn destroy(sp: *ShaderProgram) void {
        c.glDetachShader(sp.program_id, sp.fragment_id);
        c.glDetachShader(sp.program_id, sp.vertex_id);

        c.glDeleteShader(sp.fragment_id);
        c.glDeleteShader(sp.vertex_id);

        c.glDeleteProgram(sp.program_id);
    }
};

pub const ShaderVersion = enum{ V120, V130 };

const ShaderSource = struct{
    vertex: []const u8,
    fragment: []const u8,
};

fn getPrimitiveShaderSource(comptime version: ShaderVersion) ShaderSource {
    const old = version == ShaderVersion.V120;

    return ShaderSource{
        .vertex =
            "#version " ++ (if (old) "120" else "130") ++ "\n"
            ++
            (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n"
            ++
            \\uniform mat4 MVP;
            \\
            \\void main(void) {
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
        .fragment =
            "#version " ++ (if (old) "120" else "130") ++ "\n"
            ++
            (if (old) "" else "out vec4 FragColor;\n")
            ++
            \\uniform vec4 Color;
            \\
            \\void main(void) {
            ++
            (if (old) "gl_" else "") ++ "FragColor = Color;\n"
            ++
            \\}
        ,
    };
}

fn getTextureShaderSource(comptime version: ShaderVersion) ShaderSource {
    const old = version == ShaderVersion.V120;

    return ShaderSource{
        .vertex =
            "#version " ++ (if (old) "120" else "130") ++ "\n"
            ++
            (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n"
            ++
            (if (old) "attribute" else "in") ++ " vec2 TexCoord;\n"
            ++
            (if (old) "varying" else "out") ++ " vec2 FragTexCoord;\n"
            ++
            \\uniform mat4 MVP;
            \\
            \\void main(void)
            \\{
            \\    FragTexCoord = TexCoord;
            \\    gl_Position = vec4(VertexPosition, 1.0) * MVP;
            \\}
        ,
        .fragment =
            "#version " ++ (if (old) "120" else "130") ++ "\n"
            ++
            (if (old) "varying" else "in") ++ " vec2 FragTexCoord;\n"
            ++
            (if (old) "" else "out vec4 FragColor;\n")
            ++
            \\uniform sampler2D Tex;
            \\uniform float Alpha;
            \\
            \\void main(void)
            \\{
            ++
            (if (old) "gl_" else "") ++ "FragColor = texture2D(Tex, FragTexCoord);\n"
            ++
            (if (old) "gl_" else "") ++ "FragColor.a *= Alpha;\n"
            ++
            \\}
        ,
    };
}

pub fn createAllShaders(shader_version: ShaderVersion) !AllShaders {
    var as: AllShaders = undefined;

    as.primitive = try createShader(
        switch (shader_version) {
            ShaderVersion.V120 => getPrimitiveShaderSource(ShaderVersion.V120),
            ShaderVersion.V130 => getPrimitiveShaderSource(ShaderVersion.V130),
        },
    );

    as.primitive_attrib_position = try as.primitive.attribLocation(c"VertexPosition");
    as.primitive_uniform_mvp = as.primitive.uniformLocation(c"MVP");
    as.primitive_uniform_color = as.primitive.uniformLocation(c"Color");

    as.texture = try createShader(
        switch (shader_version) {
            ShaderVersion.V120 => getTextureShaderSource(ShaderVersion.V120),
            ShaderVersion.V130 => getTextureShaderSource(ShaderVersion.V130),
        },
    );

    as.texture_attrib_tex_coord = try as.texture.attribLocation(c"TexCoord");
    as.texture_attrib_position = try as.texture.attribLocation(c"VertexPosition");
    as.texture_uniform_mvp = as.texture.uniformLocation(c"MVP");
    as.texture_uniform_tex = as.texture.uniformLocation(c"Tex");
    as.texture_uniform_alpha = as.texture.uniformLocation(c"Alpha");

    debug_gl.assertNoError();

    return as;
}

fn createShader(source: ShaderSource) !ShaderProgram {
    var sp: ShaderProgram = undefined;
    sp.vertex_id = try initShader(source.vertex, c"vertex", c.GL_VERTEX_SHADER);
    sp.fragment_id = try initShader(source.fragment, c"fragment", c.GL_FRAGMENT_SHADER);

    sp.program_id = c.glCreateProgram();
    c.glAttachShader(sp.program_id, sp.vertex_id);
    c.glAttachShader(sp.program_id, sp.fragment_id);
    c.glLinkProgram(sp.program_id);

    var ok: c.GLint = undefined;
    c.glGetProgramiv(sp.program_id, c.GL_LINK_STATUS, c.ptr(&ok));
    if (ok != 0) {
        return sp;
    }

    var error_size: c.GLint = undefined;
    c.glGetProgramiv(sp.program_id, c.GL_INFO_LOG_LENGTH, c.ptr(&error_size));
    const message = try c_allocator.alloc(u8, @intCast(usize, error_size));
    c.glGetProgramInfoLog(sp.program_id, error_size, c.ptr(&error_size), message.ptr);
    _ = c.printf(c"Error linking shader program: %s\n", message.ptr);
    return error.ShaderError;
}

fn initShader(source: []const u8, name: [*]const u8, kind: c.GLenum) !c.GLuint {
    const shader_id = c.glCreateShader(kind);
    const source_ptr: ?[*]const u8 = source.ptr;
    const source_len = @intCast(c.GLint, source.len);
    c.glShaderSource(shader_id, 1, c.ptr(&source_ptr), c.ptr(&source_len));
    c.glCompileShader(shader_id);

    var ok: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_COMPILE_STATUS, c.ptr(&ok));
    if (ok != 0) {
        return shader_id;
    }

    var error_size: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_INFO_LOG_LENGTH, c.ptr(&error_size));

    const message = try c_allocator.alloc(u8, @intCast(usize, error_size));
    c.glGetShaderInfoLog(shader_id, error_size, c.ptr(&error_size), message.ptr);
    _ = c.printf(c"Error compiling %s shader:\n%s\n", name, message.ptr);
    return error.ShaderError;
}
