const builtin = @import("builtin");
usingnamespace if (builtin.arch == .wasm32)
    @import("../../web.zig")
else
    @import("gl").namespace;
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("../../warn.zig").warn;
const shaders = @import("shaders.zig");
const updateVbo = @import("draw.zig").updateVbo;

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const BindParams = struct {
    mvp: []f32,
    tex: GLint,
    color: Color,
    vertex_buffer: ?GLuint,
    texcoord_buffer: ?GLuint,
};

pub const UpdateParams = struct {
    vertex_buffer: GLuint,
    texcoord_buffer: GLuint,
    vertex2f: []f32,
    texcoord2f: []f32,
};

pub const Shader = struct {
    program: shaders.Program,
    attrib_texcoord: GLint,
    attrib_position: GLint,
    uniform_mvp: GLint,
    uniform_tex: GLint,
    uniform_color: GLint,

    pub fn bind(self: Shader, params: BindParams) void {
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

    pub fn update(self: Shader, params: UpdateParams) void {
        updateVbo(params.vertex_buffer, params.vertex2f);
        if (self.attrib_position != -1) {
            glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
        updateVbo(params.texcoord_buffer, params.texcoord2f);
        if (self.attrib_texcoord != -1) {
            glVertexAttribPointer(@intCast(GLuint, self.attrib_texcoord), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
    }
};

fn getSourceComptime(comptime version: shaders.GLSLVersion) shaders.ShaderSource {
    const first_line = switch (version) {
        .v120 => "#version 120\n",
        .v130 => "#version 130\n",
        .webgl => "precision mediump float;\n",
    };

    const old = version == .v120 or version == .webgl;

    return shaders.ShaderSource{
        .vertex = first_line ++
            (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n" ++
            (if (old) "attribute" else "in") ++ " vec2 TexCoord;\n" ++
            (if (old) "varying" else "out") ++ " vec2 FragTexCoord;\n" ++
            \\uniform mat4 MVP;
            \\
            \\void main(void)
            \\{
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
            \\void main(void)
            \\{
            \\
        ++
            "    " ++ (if (old) "gl_" else "") ++ "FragColor = texture2D(Tex, FragTexCoord) * Color;\n" ++
            \\}
            };
}

fn getSource(version: shaders.GLSLVersion) shaders.ShaderSource {
    return switch (version) {
        .v120 => getSourceComptime(.v120),
        .v130 => getSourceComptime(.v130),
        .webgl => getSourceComptime(.webgl),
    };
}

pub fn create(hunk_side: *HunkSide, glsl_version: shaders.GLSLVersion) shaders.InitError!Shader {
    errdefer warn("Failed to create textured shader program.\n", .{});

    const program = try shaders.compileAndLink(hunk_side, "textured", getSource(glsl_version));

    return Shader{
        .program = program,
        .attrib_position = shaders.getAttribLocation(program, "VertexPosition"),
        .attrib_texcoord = shaders.getAttribLocation(program, "TexCoord"),
        .uniform_mvp = shaders.getUniformLocation(program, "MVP"),
        .uniform_tex = shaders.getUniformLocation(program, "Tex"),
        .uniform_color = shaders.getUniformLocation(program, "Color"),
    };
}
