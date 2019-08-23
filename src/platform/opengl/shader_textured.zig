usingnamespace @cImport({
    @cInclude("epoxy/gl.h");
});

const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
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

        glEnableVertexAttribArray(@intCast(GLuint, self.attrib_position));
        if (params.vertex_buffer) |vertex_buffer| {
            glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
            glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);
        }

        glEnableVertexAttribArray(@intCast(GLuint, self.attrib_texcoord));
        if (params.texcoord_buffer) |texcoord_buffer| {
            glBindBuffer(GL_ARRAY_BUFFER, texcoord_buffer);
            glVertexAttribPointer(@intCast(GLuint, self.attrib_texcoord), 2, GL_FLOAT, GL_FALSE, 0, null);
        }
    }

    pub fn update(self: Shader, params: UpdateParams) void {
        updateVbo(params.vertex_buffer, params.vertex2f);
        glVertexAttribPointer(@intCast(GLuint, self.attrib_position), 2, GL_FLOAT, GL_FALSE, 0, null);

        updateVbo(params.texcoord_buffer, params.texcoord2f);
        glVertexAttribPointer(@intCast(GLuint, self.attrib_texcoord), 2, GL_FLOAT, GL_FALSE, 0, null);
    }
};

fn getSourceComptime(comptime version: shaders.GLSLVersion) shaders.ShaderSource {
    const old = version == shaders.GLSLVersion.V120;

    return shaders.ShaderSource {
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
            \\  FragTexCoord = TexCoord;
            \\  gl_Position = vec4(VertexPosition, 1.0) * MVP;
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
            \\uniform vec4 Color;
            \\
            \\void main(void)
            \\{
            \\
            ++
            "  " ++ (if (old) "gl_" else "") ++ "FragColor = texture2D(Tex, FragTexCoord) * Color;\n"
            ++
            \\}
        ,
    };
}

fn getSource(version: shaders.GLSLVersion) shaders.ShaderSource {
    return switch (version) {
        .V120 => getSourceComptime(.V120),
        .V130 => getSourceComptime(.V130),
    };
}

pub fn create(hunk_side: *HunkSide, glsl_version: shaders.GLSLVersion) shaders.InitError!Shader {
    errdefer std.debug.warn("Failed to create textured shader program.\n");

    const program = try shaders.compileAndLink(hunk_side, "textured", getSource(glsl_version));

    return Shader{
        .program = program,
        .attrib_position = try shaders.getAttribLocation(program, c"VertexPosition"),
        .attrib_texcoord = try shaders.getAttribLocation(program, c"TexCoord"),
        .uniform_mvp = shaders.getUniformLocation(program, c"MVP"),
        .uniform_tex = shaders.getUniformLocation(program, c"Tex"),
        .uniform_color = shaders.getUniformLocation(program, c"Color"),
    };
}
